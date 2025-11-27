# OTP Architecture for VoelgoedEvents: Performance-First Design

**Comprehensive guide to actor-based architecture for high-scale event ticketing**

---

## CRITICAL PREAMBLE: Process Explosion Anti-Pattern ⚠️

### The Wrong Approach (Seat-per-Actor)

```
❌ DON'T DO THIS:
EventSupervisor
  ├─ Seat Actor 1
  ├─ Seat Actor 2
  ├─ Seat Actor 3
  ...
  └─ Seat Actor 50,000

Problems:
  - 50,000 processes = 150-250 MB memory (just for seat actors)
  - 50,000 registered names = registry lookup overhead
  - Supervision tree becomes massive bottleneck
  - Startup time > 10 seconds for single event
  - Crash of one seat actor triggers cascading supervision work
  - NOT the Elixir way for this scale
```

### The Right Approach (Aggregation-per-Event)

```
✅ DO THIS:
EventSupervisor (DynamicSupervisor)
  ├─ EventServer #1 (holds 50,000 seats in Redis/ETS/Bitmap)
  ├─ EventServer #2 (holds 30,000 seats in Redis/ETS/Bitmap)
  └─ EventServer #3 (holds 20,000 seats in Redis/ETS/Bitmap)

Benefits:
  - 3 processes instead of 100,000+
  - All seat data in compressed Redis Hashes/Bitmaps
  - Fast startup, minimal memory
  - Single EventServer coordinates all seat operations
  - Failures isolated to one event at a time
  - Scales horizontally (cluster of nodes)
```

**This document reflects the RIGHT approach: Aggregation over Granularity.**

---

## 1. Core OTP Concepts (Voelgoed-Specific)

### What is an Actor in Our Context?

An **actor** in VoelgoedEvents is a GenServer process that:
- **Owns one logical domain:** Event, Checkout Session, Hold Monitor
- **Encapsulates state** in Redis + process memory (hybrid)
- **Serializes access** to shared resources (e.g., seat availability)
- **Coordinates complex workflows** across multiple steps
- **Can fail independently** and be restarted safely

**NOT:** An actor per seat, per hold detail, or per ticket.

### Why Actors for Event Ticketing? (Aggregation Model)

```
Performance-Critical Challenge:
  1000 users simultaneously booking seats for same event
  ↓
  Problem: Concurrent writes to "available_seats" count
  ↓
  Solution: One EventServer per event serializes all seat operations
  
EventServer Approach:
  - All users send booking requests to single EventServer process
  - EventServer uses Redis for durable state, ETS for caching
  - Serialization happens inside the actor (no locks, no race conditions)
  - Event state updates atomically via transactions
  
Result:
  ✅ No database locks (all serialized at process level)
  ✅ Consistent seat counts (single source of truth)
  ✅ Scales to millions of bookings per hour
  ✅ Memory efficient (one actor per event, not per seat)
```

**The Elixir Way for Ticketing:** Use OTP to coordinate workflows, not to represent individual entities.

---

## 2. Naming Conventions (VoelgoedEvents Standard)

### Root Application Namespace

```
Application Name: VoelgoedEvents
Root Directory: lib/voelgoedevents/
Config Namespace: :voelgoedevents

❌ WRONG:
  lib/voelgoed/
  Voelgoed.Supervisor
  :voelgoed config

✅ CORRECT:
  lib/voelgoedevents/
  VoelgoedEvents.Supervisor
  :voelgoedevents config
```

### Module Organization

```
lib/voelgoedevents/
├── application.ex                           (root supervision tree)
├── supervisor/
│   ├── event_supervisor.ex                  (DynamicSupervisor for EventServers)
│   ├── checkout_supervisor.ex               (DynamicSupervisor for CheckoutSessions)
│   ├── hold_supervisor.ex                   (DynamicSupervisor for HoldMonitors)
│   └── analytics_supervisor.ex              (subsupervisor for background jobs)
│
├── actors/
│   ├── event_server.ex                      (one per event, coordinates all seats)
│   ├── checkout_session.ex                  (one per user checkout, transient)
│   ├── hold_monitor.ex                      (optional, per-user or global sweep)
│   └── event_monitor.ex                     (aggregates occupancy, optional)
│
├── cache/
│   ├── occupancy_cache.ex                   (singleton, fast occupancy lookups)
│   ├── recent_scans_cache.ex                (singleton, entry gate cache)
│   └── pricing_cache.ex                     (singleton, pricing rules cache)
│
├── registry/
│   └── seat_hold_registry.ex                (manages Redis + ETS + DB layers)
│
├── workers/
│   ├── release_expired_seats_job.ex         (Oban job, cleanup expired holds)
│   ├── aggregate_analytics_job.ex           (Oban job, event aggregation)
│   ├── refresh_occupancy_cache_job.ex       (Oban job, cache refresh)
│   └── sync_offline_scans_job.ex            (Oban job, offline PWA batch sync)
│
├── ets/
│   └── supervisor.ex                        (ETS table initialization)
│
└── telemetry/
    └── metrics.ex                           (health checks, monitoring)
```

### Naming Patterns by Component Type

```
GenServer (Long-Lived):
  ✅ VoelgoedEvents.Actors.EventServer
  ✅ VoelgoedEvents.Cache.OccupancyCache
  ✅ VoelgoedEvents.Actors.HoldMonitor

GenServer (Short-Lived):
  ✅ VoelgoedEvents.Actors.CheckoutSession
  
Supervisor:
  ✅ VoelgoedEvents.Supervisor
  ✅ VoelgoedEvents.Supervisor.EventSupervisor
  
Oban Job:
  ✅ VoelgoedEvents.Workers.ReleaseExpiredSeatsJob
  
Module (No Process):
  ✅ VoelgoedEvents.Registry.SeatHoldRegistry
  ✅ VoelgoedEvents.Telemetry.Metrics
```

---

## 3. Supervision Tree: Voelgoed-Optimized Design

### Architecture Diagram

```
VoelgoedEvents.Supervisor (root, :one_for_one)
  │
  ├── INFRASTRUCTURE LAYER
  │   ├── {Registry, keys: :unique, name: VoelgoedEvents.Registry}
  │   ├── {Registry, keys: :duplicate, name: VoelgoedEvents.BroadcastRegistry}
  │   ├── VoelgoedEvents.Repo
  │   ├── {Phoenix.PubSub, name: VoelgoedEvents.PubSub}
  │   ├── VoelgoedWeb.Telemetry
  │   ├── {Redix, [url: redis_url, name: VoelgoedEvents.Redis]}
  │   └── {Oban, [repo: VoelgoedEvents.Repo, queues: [...]]}
  │
  ├── CACHING LAYER (Singletons)
  │   ├── VoelgoedEvents.ETS.Supervisor
  │   ├── VoelgoedEvents.Cache.OccupancyCache
  │   ├── VoelgoedEvents.Cache.RecentScansCache
  │   └── VoelgoedEvents.Cache.PricingCache
  │
  ├── ACTOR SUPERVISORS (Dynamic)
  │   └── {Supervisor, [...], name: VoelgoedEvents.Supervisor.Dynamic}
  │       ├── {DynamicSupervisor, 
  │       │     strategy: :one_for_one,
  │       │     name: VoelgoedEvents.Supervisor.Event}
  │       │   └── EventServer 1 (event_id: "evt-001")
  │       │   └── EventServer 2 (event_id: "evt-002")
  │       │   └── ...
  │       │
  │       ├── {DynamicSupervisor,
  │       │     strategy: :one_for_one,
  │       │     name: VoelgoedEvents.Supervisor.Checkout}
  │       │   └── CheckoutSession 1 (checkout_id: "chk-001")
  │       │   └── CheckoutSession 2 (chk-002")
  │       │   └── ...
  │       │
  │       └── {DynamicSupervisor,
  │             strategy: :one_for_one,
  │             name: VoelgoedEvents.Supervisor.Hold}
  │           └── HoldMonitor 1 (optional)
  │           └── HoldMonitor 2 (optional)
  │           └── or single HoldSweeper job
  │
  ├── BACKGROUND JOBS (Oban)
  │   └── {Supervisor,
  │         [strategy: :one_for_one],
  │         name: VoelgoedEvents.Supervisor.Analytics}
  │       ├── VoelgoedEvents.Workers.ReleaseExpiredSeatsJob
  │       ├── VoelgoedEvents.Workers.AggregateAnalyticsJob
  │       ├── VoelgoedEvents.Workers.RefreshOccupancyCacheJob
  │       └── VoelgoedEvents.Workers.SyncOfflineScansJob
  │
  └── WEB LAYER
      └── VoelgoedWeb.Endpoint
```

### Key Principles

1. **Flat infrastructure layer** (all dependencies at root)
2. **Subsupervisor for dynamic actors** (cleaner hierarchy)
3. **One actor per event, not per seat** (performance-first)
4. **Redis as system of record** (not process memory)
5. **Hybrid state model** (ETS cache + Redis durable)

---

## 4. GenServer Patterns for VoelgoedEvents

### Pattern 1: EventServer (Aggregation Actor, Permanent)

#### 4.1: Hydration Strategy (Crash Recovery) ⚡ ENTERPRISE-CRITICAL

**The Rule: Actors MUST hydrate state from Redis on startup. No empty state.**

```elixir
# lib/voelgoedevents/actors/event_server.ex

defmodule VoelgoedEvents.Actors.EventServer do
  use GenServer, restart: :permanent
  require Logger
  
  # Timeout: Idle EventServers hibernate after 30 minutes to save memory
  @idle_timeout 30 * 60 * 1000  # 30 minutes
  
  # Event state coordinator: One actor manages ALL seats for one event
  def start_link(opts) do
    event_id = Keyword.fetch!(opts, :event_id)
    org_id = Keyword.fetch!(opts, :org_id)
    
    GenServer.start_link(
      __MODULE__,
      {event_id, org_id},
      name: {:via, Registry, {VoelgoedEvents.Registry, {:event, event_id}}}
    )
  end
  
  # Public API: Attempt to book a seat
  def book_seat(event_id, seat_id, user_id, hold_duration_sec) do
    case Registry.lookup(VoelgoedEvents.Registry, {:event, event_id}) do
      [{pid, _}] ->
        GenServer.call(pid, {:book_seat, seat_id, user_id, hold_duration_sec}, 5_000)
      
      [] ->
        {:error, :event_not_found}
    end
  end
  
  # Public API: Get current occupancy snapshot
  def get_occupancy(event_id) do
    case Registry.lookup(VoelgoedEvents.Registry, {:event, event_id}) do
      [{pid, _}] ->
        GenServer.call(pid, :get_occupancy, 1_000)
      
      [] ->
        nil
    end
  end
  
  # ⚡ HYDRATION: Load state from Redis on startup
  @impl true
  def init({event_id, org_id}) do
    Logger.info("EventServer starting (HYDRATION): event=#{event_id}")
    
    # Step 1: Try to load cached state from Redis
    case load_state_from_redis(event_id, org_id) do
      {:ok, occupancy} ->
        Logger.info("EventServer hydrated from Redis: event=#{event_id}")
        
        init_subscriptions(event_id)
        
        {:ok,
         %{
           event_id: event_id,
           org_id: org_id,
           occupancy: occupancy,
           last_refresh: DateTime.utc_now(),
           last_activity: DateTime.utc_now()
         },
         {:continue, :schedule_refresh}}
      
      {:error, :redis_empty} ->
        # Step 2: Fallback to database (heavy query)
        Logger.warn("EventServer hydrating from DB (SLOW): event=#{event_id}")
        
        occupancy = rebuild_occupancy_from_db(event_id, org_id)
        
        # Cache result immediately in Redis for next restart
        save_state_to_redis(event_id, org_id, occupancy)
        
        init_subscriptions(event_id)
        
        {:ok,
         %{
           event_id: event_id,
           org_id: org_id,
           occupancy: occupancy,
           last_refresh: DateTime.utc_now(),
           last_activity: DateTime.utc_now()
         },
         {:continue, :schedule_refresh}}
      
      {:error, reason} ->
        Logger.error("EventServer hydration failed: event=#{event_id}, reason=#{reason}")
        {:stop, reason}
    end
  end
  
  # Handle: Schedule periodic refresh
  @impl true
  def handle_continue(:schedule_refresh, state) do
    # Periodic occupancy refresh (every 10 seconds)
    Process.send_after(self(), :refresh_occupancy, 10_000)
    {:noreply, state}
  end
  
  # Handle: Book a seat
  @impl true
  def handle_call({:book_seat, seat_id, user_id, hold_duration_sec}, _from, state) do
    # 1. Check Redis for seat availability
    case VoelgoedEvents.Registry.SeatHoldRegistry.attempt_hold(
      state.event_id,
      state.org_id,
      seat_id,
      user_id,
      hold_duration_sec
    ) do
      {:ok, hold} ->
        # 2. Create Checkout actor for this session
        {:ok, _checkout_pid} =
          DynamicSupervisor.start_child(
            VoelgoedEvents.Supervisor.Checkout,
            {
              VoelgoedEvents.Actors.CheckoutSession,
              [
                checkout_id: hold.id,
                user_id: user_id,
                event_id: state.event_id,
                org_id: state.org_id
              ]
            }
          )
        
        # 3. Update local occupancy cache
        new_occupancy = refresh_occupancy_internal(state.event_id, state.org_id)
        
        # 4. Write to Redis (write-through for resilience)
        save_state_to_redis(state.event_id, state.org_id, new_occupancy)
        
        # 5. Broadcast occupancy change
        Phoenix.PubSub.broadcast(
          VoelgoedEvents.PubSub,
          "event:#{state.event_id}:occupancy",
          {:occupancy_changed, new_occupancy}
        )
        
        new_state = %{state | occupancy: new_occupancy, last_activity: DateTime.utc_now()}
        {:reply, {:ok, hold}, new_state, @idle_timeout}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state, @idle_timeout}
    end
  end
  
  # Handle: Get occupancy
  @impl true
  def handle_call(:get_occupancy, _from, state) do
    {:reply, state.occupancy, state, @idle_timeout}
  end
  
  # Handle: Periodic occupancy refresh
  @impl true
  def handle_info(:refresh_occupancy, state) do
    new_occupancy = refresh_occupancy_internal(state.event_id, state.org_id)
    
    # Broadcast only if changed
    if new_occupancy != state.occupancy do
      save_state_to_redis(state.event_id, state.org_id, new_occupancy)
      
      Phoenix.PubSub.broadcast(
        VoelgoedEvents.PubSub,
        "event:#{state.event_id}:occupancy",
        {:occupancy_changed, new_occupancy}
      )
    end
    
    # Schedule next refresh
    Process.send_after(self(), :refresh_occupancy, 10_000)
    
    new_state = %{state | occupancy: new_occupancy, last_refresh: DateTime.utc_now()}
    {:noreply, new_state, @idle_timeout}
  end
  
  # Handle: Idle timeout (30 minutes of inactivity)
  @impl true
  def handle_info(:timeout, state) do
    Logger.info("EventServer hibernating (idle 30min): event=#{state.event_id}")
    {:noreply, state, :hibernate}
  end
  
  # Handle: Seat status change notification
  @impl true
  def handle_info({:seat_status_changed, _seat_data}, state) do
    {:noreply, state, @idle_timeout}
  end
  
  # === HYDRATION HELPERS ===
  
  defp load_state_from_redis(event_id, org_id) do
    key = "voelgoedevents:event:#{event_id}:occupancy"
    
    case Redix.command(VoelgoedEvents.Redis, ["GET", key]) do
      {:ok, nil} ->
        {:error, :redis_empty}
      
      {:ok, json} ->
        {:ok, Jason.decode!(json)}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp save_state_to_redis(event_id, org_id, occupancy) do
    key = "voelgoedevents:event:#{event_id}:occupancy"
    value = Jason.encode!(occupancy)
    
    # TTL: 1 hour (if no activity, cache expires)
    Redix.command(VoelgoedEvents.Redis, ["SET", key, value, "EX", "3600"])
  end
  
  defp rebuild_occupancy_from_db(event_id, org_id) do
    # Heavy query: Calculate from authoritative database
    VoelgoedEvents.Registry.SeatHoldRegistry.calculate_occupancy(
      event_id,
      org_id
    )
  end
  
  defp refresh_occupancy_internal(event_id, org_id) do
    VoelgoedEvents.Registry.SeatHoldRegistry.calculate_occupancy(
      event_id,
      org_id
    )
  end
  
  defp init_subscriptions(event_id) do
    Phoenix.PubSub.subscribe(
      VoelgoedEvents.PubSub,
      "event:#{event_id}:seats"
    )
  end
end
```

**Key Points:**
- ✅ Hydration on init: Load from Redis (fast) or DB (fallback)
- ✅ Write-through: Every state change saved to Redis immediately
- ✅ Idle hibernation: After 30 min inactivity, process sleeps (saves memory)
- ✅ Crash recovery: Restart loads cached state, no data loss

---

### Pattern 2: CheckoutSession (Temporary Actor, Transient)

```elixir
# lib/voelgoedevents/actors/checkout_session.ex

defmodule VoelgoedEvents.Actors.CheckoutSession do
  use GenServer, restart: :transient
  require Logger
  
  # Timeout: Checkout expires after 15 minutes of inactivity
  @checkout_timeout 15 * 60 * 1000
  
  # Per-user checkout session: Auto-expires after 15 minutes
  def start_link(opts) do
    checkout_id = Keyword.fetch!(opts, :checkout_id)
    user_id = Keyword.fetch!(opts, :user_id)
    event_id = Keyword.fetch!(opts, :event_id)
    org_id = Keyword.fetch!(opts, :org_id)
    
    GenServer.start_link(
      __MODULE__,
      %{
        checkout_id: checkout_id,
        user_id: user_id,
        event_id: event_id,
        org_id: org_id,
        created_at: DateTime.utc_now(),
        status: :active,
        seats: [],
        total_cents: 0,
        expires_at: DateTime.add(DateTime.utc_now(), 15 * 60, :second)
      },
      name: {:via, Registry, {VoelgoedEvents.Registry, {:checkout, checkout_id}}}
    )
  end
  
  # Public API: Add seat to cart
  def add_seat(checkout_id, seat_id) do
    case Registry.lookup(VoelgoedEvents.Registry, {:checkout, checkout_id}) do
      [{pid, _}] ->
        GenServer.call(pid, {:add_seat, seat_id}, 5_000)
      
      [] ->
        {:error, :checkout_not_found}
    end
  end
  
  # Public API: Complete payment
  def complete_payment(checkout_id, payment_token) do
    case Registry.lookup(VoelgoedEvents.Registry, {:checkout, checkout_id}) do
      [{pid, _}] ->
        GenServer.call(pid, {:complete_payment, payment_token}, 10_000)
      
      [] ->
        {:error, :checkout_not_found}
    end
  end
  
  @impl true
  def init(state) do
    Logger.info("CheckoutSession started: id=#{state.checkout_id}, user=#{state.user_id}")
    
    # Set expiration timer (15 minutes)
    timeout_ms = DateTime.diff(state.expires_at, DateTime.utc_now(), :millisecond)
    Process.send_after(self(), :checkout_expired, timeout_ms)
    
    {:ok, state, @checkout_timeout}
  end
  
  # Handle: Add seat
  @impl true
  def handle_call({:add_seat, seat_id}, _from, state) do
    new_seats = [seat_id | state.seats]
    new_state = %{state | seats: new_seats}
    {:reply, {:ok, new_seats}, new_state, @checkout_timeout}
  end
  
  # Handle: Complete payment
  @impl true
  def handle_call({:complete_payment, payment_token}, _from, state) do
    case process_payment(state, payment_token) do
      {:ok, tickets} ->
        # Broadcast completion event
        Phoenix.PubSub.broadcast(
          VoelgoedEvents.PubSub,
          "checkout:#{state.checkout_id}",
          {:payment_completed, tickets}
        )
        
        # Exit normally (not restarted, transient)
        {:stop, :normal, {:ok, tickets}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state, @checkout_timeout}
    end
  end
  
  # Handle: Checkout expired (15-minute TTL or inactivity)
  @impl true
  def handle_info(:checkout_expired, state) do
    Logger.warn("CheckoutSession expired: id=#{state.checkout_id}")
    
    # Release holds on seats
    Enum.each(state.seats, fn seat_id ->
      VoelgoedEvents.Registry.SeatHoldRegistry.release_hold(
        state.event_id,
        state.org_id,
        seat_id
      )
    end)
    
    # Exit normally (transient: don't restart)
    {:stop, :normal, state}
  end
  
  # Handle: Inactivity timeout
  @impl true
  def handle_info(:timeout, state) do
    Logger.warn("CheckoutSession inactivity timeout: id=#{state.checkout_id}")
    
    # Release holds
    Enum.each(state.seats, fn seat_id ->
      VoelgoedEvents.Registry.SeatHoldRegistry.release_hold(
        state.event_id,
        state.org_id,
        seat_id
      )
    end)
    
    {:stop, :normal, state}
  end
  
  defp process_payment(state, payment_token) do
    case VoelgoedEvents.Payments.charge_card(payment_token, state.total_cents) do
      {:ok, transaction_id} ->
        tickets = Enum.map(state.seats, fn seat_id ->
          VoelgoedEvents.Tickets.create_ticket(
            event_id: state.event_id,
            seat_id: seat_id,
            user_id: state.user_id,
            transaction_id: transaction_id
          )
        end)
        
        {:ok, tickets}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Key Points:**
- ✅ Transient: Dies on normal exit (payment complete)
- ✅ Auto-expiry: 15 min TTL or inactivity timeout
- ✅ Cleanup: Always release holds when exiting
- ✅ No permanent memory leak: Process cleans itself up

---

### Pattern 3: OccupancyCache (Singleton Cache, Permanent)

```elixir
# lib/voelgoedevents/cache/occupancy_cache.ex

defmodule VoelgoedEvents.Cache.OccupancyCache do
  use GenServer
  require Logger
  
  # Singleton: Fast occupancy lookups across all events
  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      %{},
      name: __MODULE__
    )
  end
  
  # Public API: Get occupancy (fast, ETS-backed)
  def get(event_id, org_id) do
    GenServer.call(__MODULE__, {:get, event_id, org_id}, 1_000)
  end
  
  # Public API: Update occupancy (async)
  def update(event_id, org_id, occupancy_data) do
    GenServer.cast(__MODULE__, {:update, event_id, org_id, occupancy_data})
  end
  
  @impl true
  def init(_opts) do
    Logger.info("OccupancyCache started")
    {:ok, %{}}
  end
  
  # Handle: Get occupancy
  @impl true
  def handle_call({:get, event_id, org_id}, _from, state) do
    key = {event_id, org_id}
    
    case state[key] do
      nil ->
        # Cache miss: calculate from Redis
        occupancy = VoelgoedEvents.Registry.SeatHoldRegistry.calculate_occupancy(
          event_id,
          org_id
        )
        
        {:reply, occupancy, state}
      
      cached ->
        # Cache hit
        {:reply, cached, state}
    end
  end
  
  # Handle: Update occupancy (async, non-blocking)
  @impl true
  def handle_cast({:update, event_id, org_id, occupancy_data}, state) do
    key = {event_id, org_id}
    new_state = Map.put(state, key, occupancy_data)
    {:noreply, new_state}
  end
end
```

---

## 5. Scaling Strategy: Partitioning for Mega Events 🚀 ENTERPRISE-CRITICAL

### Standard Events (< 10k Seats)

```
✅ ONE EventServer per event
  - Handles: 100-500 concurrent booking attempts
  - Latency: 10-50ms per booking
  - Mailbox: Minimal, never overloaded
```

### Mega Events (10k+ Seats, 1000+ concurrent)

```
⚠️ BOTTLENECK RISK: Single EventServer mailbox can get congested

Solution: Partition by Sector

EventSupervisor
  ├─ EventServer_SectorA (seats 1-10k)
  │   └── Handles concurrency from 1/4 of users
  ├─ EventServer_SectorB (seats 10k-20k)
  │   └── Handles concurrency from 1/4 of users
  ├─ EventServer_SectorC (seats 20k-30k)
  │   └── Handles concurrency from 1/4 of users
  └─ EventServer_SectorD (seats 30k-40k)
      └── Handles concurrency from 1/4 of users

Benefits:
  ✅ 4x parallel capacity (1000 → 250 users per process)
  ✅ Latency stays 10-50ms (not 100-200ms)
  ✅ No single point of failure
```

### Implementation Pattern

```elixir
# lib/voelgoedevents/supervisor/partitioned_events.ex

defmodule VoelgoedEvents.Supervisor.PartitionedEvents do
  def get_sector_for_seat(event_id, seat_id, partitions \\ 4) do
    # Deterministic partition: seat_id % 4
    partition = :erlang.phash2(seat_id, partitions)
    "#{event_id}:sector_#{partition}"
  end
  
  def book_seat(event_id, seat_id, user_id, hold_duration_sec) do
    sector_key = get_sector_for_seat(event_id, seat_id)
    
    # Find or create EventServer for this sector
    case Registry.lookup(VoelgoedEvents.Registry, {:event_sector, sector_key}) do
      [{pid, _}] ->
        # Sector exists, book on it
        GenServer.call(pid, {:book_seat, seat_id, user_id, hold_duration_sec})
      
      [] ->
        # First booking for this sector, create sector EventServer
        {:ok, pid} = DynamicSupervisor.start_child(
          VoelgoedEvents.Supervisor.Event,
          {VoelgoedEvents.Actors.EventServer, [
            event_id: sector_key,
            org_id: get_org_id(event_id)
          ]}
        )
        
        GenServer.call(pid, {:book_seat, seat_id, user_id, hold_duration_sec})
    end
  end
end
```

**When to Partition:**
- ✅ Event > 10,000 seats AND expected > 500 concurrent users
- ⚠️ Monitor booking latency: If > 100ms, partition immediately
- ℹ️ MVP: Start with 1 process per event, partition only if needed

---

## 6. Registry Pattern: Safe Process Discovery

### Setup

```elixir
# lib/voelgoedevents/application.ex

def start(_type, _args) do
  children = [
    # Unique keys: one-to-one process mapping
    {Registry, keys: :unique, name: VoelgoedEvents.Registry},
    
    # Duplicate keys: broadcast subscriptions
    {Registry, keys: :duplicate, name: VoelgoedEvents.BroadcastRegistry},
    
    # ... other children
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### Usage

```elixir
# Register process with unique key
GenServer.start_link(
  __MODULE__,
  %{},
  name: {:via, Registry, {VoelgoedEvents.Registry, {:event, event_id}}}
)

# Lookup process by key
case Registry.lookup(VoelgoedEvents.Registry, {:event, event_id}) do
  [{pid, _}] -> GenServer.call(pid, :get_occupancy)
  [] -> {:error, :not_found}
end

# Broadcast to all subscribers
Registry.dispatch(VoelgoedEvents.BroadcastRegistry, {:occupancy, event_id}, fn entries ->
  Enum.each(entries, fn {pid, _} ->
    send(pid, {:occupancy_updated, occupancy})
  end)
end)
```

---

## 7. Restart Strategies (Voelgoed-Specific)

### Permanent (Infrastructure & Aggregators)

```elixir
# Restart on ANY exit (normal or abnormal)

# Use for:
# - EventServer (aggregate actor)
# - OccupancyCache (singleton)
# - Database, PubSub, Oban

{VoelgoedEvents.Actors.EventServer, opts, restart: :permanent}
```

### Transient (Temporary Work)

```elixir
# Restart ONLY on abnormal exit (NOT on normal exit)

# Use for:
# - CheckoutSession (completes normally)
# - HoldMonitor (expires normally)
# - One-time workers

{VoelgoedEvents.Actors.CheckoutSession, opts, restart: :transient}
```

### Temporary (Never Restart)

```elixir
# Never restart (just log and continue)

# Use for:
# - Debugging actors
# - Ad-hoc tests

{VoelgoedEvents.Actors.DebugWorker, opts, restart: :temporary}
```

---

## 8. Performance Characteristics (Voelgoed Scale)

### Actor Count at Scale

```
Small Event (1,000 seats):
  - 1 EventServer
  - 0-100 CheckoutSessions (concurrent checkouts)
  - Total: ~101 processes
  - Memory: ~500 KB

Medium Event (10,000 seats):
  - 1 EventServer
  - 0-500 CheckoutSessions
  - Total: ~501 processes
  - Memory: ~2.5 MB

Large Event (100,000 seats):
  - 1 EventServer (or 4 partitioned)
  - 0-2000 CheckoutSessions
  - Total: ~2001 processes (or 4x EventServers + 2000 CheckoutSessions)
  - Memory: ~10 MB

Multiple Events (1M seats across 20 events):
  - 20 EventServers
  - 0-5000 CheckoutSessions
  - Total: ~5020 processes
  - Memory: ~25 MB

vs. Seat-per-Actor (Anti-Pattern):
  - 100,000 SeatActors = 300-500 MB memory
  - Supervision overhead = startup > 30 sec
  - Single failure cascades through tree
```

### Latency Profile

```
Occupancy lookup:          < 1ms (cache hit) or 5-20ms (cache miss + Redis)
Seat booking:              10-50ms (includes Redis write + EventServer coordination)
Registry lookup:           < 1µs (hash table)
GenServer call/response:   1-3ms (typical)
Checkout creation:         < 5ms (actor spawn + Registry insert)
Partition routing:         < 1ms (hash calculation)
```

---

## 9. Hybrid State Model (Critical for Resilience)

### The Rule: Write-Through to Redis

```elixir
# ✅ CORRECT PATTERN

# When booking a seat:
1. Write to Redis (durable)
   VoelgoedEvents.Registry.SeatHoldRegistry.attempt_hold(...)
   
2. Update process memory (cache)
   state = %{state | occupancy: new_occupancy}
   
3. Return success
   {:reply, {:ok, hold}, state}

# If EventServer crashes:
  - Redis data survives (durable)
  - EventServer restarts (:permanent)
  - On init, hydrate state from Redis
  - No data loss, no double-booking
```

### ETS as L1 Cache

```elixir
# Performance: ETS for hot data

{:ok, _} = :ets.new(:occupancy_cache, [:public, :named_table])

# Write-through pattern:
1. Write to Redis (durable)
2. Insert to ETS (hot cache)
3. Return to caller

# Read pattern:
1. Try ETS (< 1µs)
2. Fall back to Redis (< 5ms)
3. Fall back to DB (50ms+)
```

---

## 10. Recommended Supervision Tree Implementation

```elixir
# lib/voelgoedevents/application.ex

defmodule VoelgoedEvents.Application do
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # == INFRASTRUCTURE
      {Registry, keys: :unique, name: VoelgoedEvents.Registry},
      {Registry, keys: :duplicate, name: VoelgoedEvents.BroadcastRegistry},
      
      VoelgoedEvents.Repo,
      {Phoenix.PubSub, name: VoelgoedEvents.PubSub},
      {Redix, [url: redis_url(), name: VoelgoedEvents.Redis]},
      VoelgoedWeb.Telemetry,
      {Oban, oban_config()},
      
      # == ETS TABLES
      VoelgoedEvents.ETS.Supervisor,
      
      # == CACHING LAYER
      VoelgoedEvents.Cache.OccupancyCache,
      VoelgoedEvents.Cache.RecentScansCache,
      VoelgoedEvents.Cache.PricingCache,
      
      # == DYNAMIC SUPERVISORS
      {Supervisor,
        [
          [
            {DynamicSupervisor,
              strategy: :one_for_one,
              name: VoelgoedEvents.Supervisor.Event},
            {DynamicSupervisor,
              strategy: :one_for_one,
              name: VoelgoedEvents.Supervisor.Checkout},
            {DynamicSupervisor,
              strategy: :one_for_one,
              name: VoelgoedEvents.Supervisor.Hold}
          ],
          [strategy: :one_for_one, name: VoelgoedEvents.Supervisor.Dynamic]
        ]},
      
      # == BACKGROUND JOBS
      {Supervisor,
        [
          [
            VoelgoedEvents.Workers.ReleaseExpiredSeatsJob,
            VoelgoedEvents.Workers.AggregateAnalyticsJob,
            VoelgoedEvents.Workers.RefreshOccupancyCacheJob,
            VoelgoedEvents.Workers.SyncOfflineScansJob
          ],
          [strategy: :one_for_one, name: VoelgoedEvents.Supervisor.Analytics]
        ]},
      
      # == WEB
      VoelgoedWeb.Endpoint
    ]
    
    opts = [strategy: :one_for_one, name: VoelgoedEvents.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379"
  end
  
  defp oban_config do
    Application.fetch_env!(:voelgoedevents, Oban)
  end
end
```

---

## 11. Workflow Integration (Voelgoed-Specific)

### Reserve Seat Workflow

```elixir
# POST /api/events/{event_id}/seats/{seat_id}/reserve

def reserve_seat(event_id, org_id, seat_id, user_id) do
  # 1. EventServer coordinates booking
  case VoelgoedEvents.Actors.EventServer.book_seat(
    event_id,
    seat_id,
    user_id,
    hold_duration_sec: 300
  ) do
    {:ok, hold} ->
      # 2. Create CheckoutSession (actor manages user's checkout)
      {:ok, _checkout_pid} =
        DynamicSupervisor.start_child(
          VoelgoedEvents.Supervisor.Checkout,
          {
            VoelgoedEvents.Actors.CheckoutSession,
            [
              checkout_id: hold.id,
              user_id: user_id,
              event_id: event_id,
              org_id: org_id
            ]
          }
        )
      
      # 3. Schedule TTL release (Oban job)
      VoelgoedEvents.Workers.ReleaseExpiredSeatsJob.new(%{
        "hold_id" => hold.id,
        "organization_id" => org_id
      }, scheduled_at: DateTime.add(DateTime.utc_now(), 300, :second))
      |> Oban.insert()
      
      {:ok, hold}
    
    {:error, reason} ->
      {:error, reason}
  end
end
```

### Complete Checkout Workflow

```elixir
# POST /api/checkouts/{checkout_id}/complete

def complete_checkout(checkout_id, payment_token) do
  case VoelgoedEvents.Actors.CheckoutSession.complete_payment(
    checkout_id,
    payment_token
  ) do
    {:ok, tickets} ->
      {:ok, tickets}
    
    {:error, reason} ->
      {:error, reason}
  end
  # CheckoutSession exits normally (transient: no restart)
end
```

### Release Expired Seat (Oban Job)

```elixir
# lib/voelgoedevents/workers/release_expired_seats_job.ex

defmodule VoelgoedEvents.Workers.ReleaseExpiredSeatsJob do
  use Oban.Worker, queue: :default, max_attempts: 3
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"hold_id" => hold_id, "organization_id" => org_id}}) do
    # 1. Try to find CheckoutSession
    case Registry.lookup(VoelgoedEvents.Registry, {:checkout, hold_id}) do
      [{pid, _}] ->
        # Kill checkout (normal exit, transient: no restart)
        GenServer.stop(pid, :normal)
      
      [] ->
        # Already released or never checked out
        :ok
    end
    
    # 2. Release hold in Redis
    VoelgoedEvents.Registry.SeatHoldRegistry.release_hold(org_id, hold_id)
    
    :ok
  end
end
```

---

## 12. Testing OTP Components

### Test 1: EventServer Isolation

```elixir
describe "EventServer" do
  test "coordinates concurrent booking attempts" do
    event_id = "evt-001"
    
    {:ok, _pid} = VoelgoedEvents.Actors.EventServer.start_link(
      event_id: event_id,
      org_id: "org-001"
    )
    
    # Simulate concurrent bookings
    {:ok, hold_1} = VoelgoedEvents.Actors.EventServer.book_seat(
      event_id, "seat-001", "user-1", 300
    )
    
    {:ok, hold_2} = VoelgoedEvents.Actors.EventServer.book_seat(
      event_id, "seat-002", "user-2", 300
    )
    
    # Both should succeed (different seats)
    assert hold_1.seat_id == "seat-001"
    assert hold_2.seat_id == "seat-002"
  end
  
  test "rejects double-booking" do
    event_id = "evt-001"
    
    {:ok, _pid} = VoelgoedEvents.Actors.EventServer.start_link(...)
    
    # Book seat 1 twice
    {:ok, _hold_1} = VoelgoedEvents.Actors.EventServer.book_seat(
      event_id, "seat-001", "user-1", 300
    )
    
    {:error, :seat_already_held} = VoelgoedEvents.Actors.EventServer.book_seat(
      event_id, "seat-001", "user-2", 300
    )
  end
end
```

### Test 2: CheckoutSession Lifecycle

```elixir
describe "CheckoutSession" do
  test "completes payment and exits normally" do
    {:ok, checkout_pid} = VoelgoedEvents.Actors.CheckoutSession.start_link(
      checkout_id: "chk-001",
      user_id: "user-1",
      event_id: "evt-001",
      org_id: "org-001"
    )
    
    # Add seats
    {:ok, seats} = VoelgoedEvents.Actors.CheckoutSession.add_seat("chk-001", "seat-1")
    assert seats == ["seat-1"]
    
    # Complete payment
    {:ok, tickets} = VoelgoedEvents.Actors.CheckoutSession.complete_payment(
      "chk-001",
      "token_123"
    )
    
    assert length(tickets) > 0
    
    # Should exit normally (not restarted)
    refute Process.alive?(checkout_pid)
  end
  
  test "expires after 15 minutes" do
    {:ok, checkout_pid} = VoelgoedEvents.Actors.CheckoutSession.start_link(...)
    
    # Simulate timeout
    send(checkout_pid, :checkout_expired)
    Process.sleep(100)
    
    # Should exit normally
    refute Process.alive?(checkout_pid)
  end
end
```

---

## 13. Monitoring & Health Checks

### Telemetry Integration

```elixir
def init_telemetry do
  :telemetry.attach_many(
    "event_server",
    [
      [:voelgoedevents, :event_server, :book_seat, :start],
      [:voelgoedevents, :event_server, :book_seat, :stop],
      [:voelgoedevents, :event_server, :book_seat, :exception]
    ],
    &handle_event/4,
    nil
  )
end

defp handle_event(
  [:voelgoedevents, :event_server, :book_seat, :stop],
  %{duration: duration},
  %{event_id: event_id},
  _config
) do
  # Log booking latency
  Logger.debug("Booking latency: #{duration / 1_000_000}ms for event #{event_id}")
end
```

### Supervisor Health

```elixir
def supervisor_health(supervisor_name) do
  case DynamicSupervisor.count_children(supervisor_name) do
    %{active: active, specs: specs} ->
      %{active: active, specs: specs, healthy: true}
    
    {:error, _} ->
      %{healthy: false}
  end
end

# Usage:
health = supervisor_health(VoelgoedEvents.Supervisor.Event)
IO.inspect(health)
# %{active: 5, specs: 5, healthy: true}
```

---

## 14. Summary: Actor Hierarchy for Voelgoed

| Component | Type | Count | Strategy | Restart | Lifespan |
|-----------|------|-------|----------|---------|----------|
| **EventServer** | GenServer | 1/event | Aggregation | :permanent | Hours-Days |
| **CheckoutSession** | GenServer | 0-5K | Temporary | :transient | 15 min or complete |
| **HoldMonitor** | GenServer (optional) | 1-10 | Cleanup | :permanent | Hours-Days |
| **OccupancyCache** | GenServer | 1 | Singleton | :permanent | Application lifetime |
| **ReleaseExpiredJob** | Oban | Periodic | Background | N/A | Seconds (per run) |
| **AnalyticsJob** | Oban | Periodic | Background | N/A | Seconds (per run) |
| **Registry** | ETS | 2 | Infrastructure | :permanent | Application lifetime |
| **PubSub** | Phoenix | 1 | Infrastructure | :permanent | Application lifetime |
| **Repo** | Ecto | 1 | Infrastructure | :permanent | Application lifetime |

---

## 15. Anti-Patterns to Avoid

```
❌ Actor per Seat
  Problem: 50,000 processes for large event
  Solution: One EventServer, state in Redis
  
❌ Permanent CheckoutSessions
  Problem: Memory leak from dead sessions
  Solution: Use :transient, auto-expire on 15-min timeout
  
❌ Global atom names
  Problem: Atom explosion DoS vulnerability
  Solution: Use Registry for safe name management
  
❌ Synchronous entire pipeline
  Problem: Long latency on seat bookings
  Solution: Async updates (cast), Redis write-through
  
❌ State only in process memory
  Problem: Data loss on restart
  Solution: Write-through to Redis, hydrate on restart

❌ Unbounded event actor growth
  Problem: 500 future events = 500 idle processes in memory forever
  Solution: Idle hibernation (30 min) + :hibernate to save RAM
  
❌ No partition strategy for mega-events
  Problem: Single EventServer mailbox overloaded (> 100ms latency)
  Solution: Partition by sector for events > 10k seats
```

---

## 16. Implementation Roadmap

### Phase 1: Foundation
- [ ] Setup supervision tree (application.ex)
- [ ] Implement Registry for process lookup
- [ ] Create OccupancyCache singleton
- [ ] Implement Redis hydration in EventServer init/1

### Phase 2: Core Actors
- [ ] Implement EventServer with hydration (see Section 4.1)
- [ ] Implement CheckoutSession with idle timeouts
- [ ] Integrate with SeatHoldRegistry (Redis layer)
- [ ] Add telemetry for latency monitoring

### Phase 3: Integration
- [ ] Update reserve_seat workflow
- [ ] Update complete_checkout workflow
- [ ] Wire up Oban jobs for cleanup
- [ ] Test crash recovery (kill EventServer, verify state restored)

### Phase 4: Scaling
- [ ] Monitor booking latency in production
- [ ] Implement partitioning (Section 5) if latency > 100ms
- [ ] Add idle hibernation cleanup job

### Phase 5: Monitoring
- [ ] Add telemetry/metrics
- [ ] Implement health checks
- [ ] Set up alerting for mailbox congestion

---

## APPENDIX: Reference Implementation Pattern for EventServer
defmodule VoelgoedEvents.Ticketing.EventServer do
  use GenServer, restart: :transient
  require Logger

  ### 1. HYDRATION ON STARTUP
  def init({event_id, _opts}) do
    # Try to load state from Redis first (Fast)
    case Redix.command(:redix, ["GET", "event:#{event_id}:occupancy"]) do
      {:ok, nil} -> 
        # Redis empty? Fallback to DB (Slow but safe)
        state = load_from_db(event_id)
        {:ok, state}
      {:ok, binary_state} ->
        # Restore state from Redis
        {:ok, :erlang.binary_to_term(binary_state)}
    end
  end

  ### 2. WRITE-THROUGH ON CHANGE
  def handle_call({:reserve, seats}, _from, state) do
    new_state = apply_reservation(state, seats)
    
    # Critical: Write to Redis *before* replying to client
    :ok = Redix.command(:redix, ["SET", "event:#{state.id}:occupancy", :erlang.term_to_binary(new_state)])
    
    {:reply, :ok, new_state, {:continue, :hibernate}} # 3. HIBERNATE IF IDLE
  end
end

**END OF VOELGOEDEVENTS OTP ARCHITECTURE (ENTERPRISE-GRADE + PRODUCTION-READY)**