# Caching Layer

## Purpose

This directory manages the **multi-layered caching strategy** for VoelgoedEvents, designed to achieve sub-100ms API response times for high-concurrency operations like seat availability checks, ticket sales, and dashboard metrics.

The `caching/` directory contains **state mirrors** that accelerate reads by layering fast access stores (ETS, Redis) in front of the source of truth (Postgres via Ash).

---

## Architecture: Three-Tier Caching Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                      API Request                            │
└─────────────────────┬───────────────────────────────────────┘
                      ▼
         ┌────────────────────────────┐
         │  Hot Cache (ETS/GenServer) │ ◄─── In-memory, per-node
         │  Latency: < 10ms           │
         │  TTL: 1-5 minutes          │
         └────────────┬───────────────┘
                      │ MISS
                      ▼
         ┌────────────────────────────┐
         │  Warm Cache (Redis)        │ ◄─── Shared across nodes
         │  Latency: 10-50ms          │
         │  TTL: 5-30 minutes         │
         └────────────┬───────────────┘
                      │ MISS
                      ▼
         ┌────────────────────────────┐
         │  Cold Storage (Postgres)   │ ◄─── Source of truth
         │  Latency: 50-200ms         │      (via Ash domain)
         │  TTL: Permanent            │
         └────────────────────────────┘
```

### **Layer 1: Hot Cache (ETS/GenServer)**

**Technology:** Erlang Term Storage (ETS) or GenServer state  
**Scope:** Per-node (not shared across cluster)  
**Latency Target:** < 10ms  
**TTL:** 1-5 minutes

**Best For:**

- Hot counters (tickets sold, check-ins)
- Frequently accessed metrics
- Session data for current users
- Seat availability snapshots

**Example:**

```elixir
defmodule Voelgoedevents.Caching.ETS do
  def get(key) do
    case :ets.lookup(:voelgoedevents_cache, key) do
      [{^key, value, expires_at}] when expires_at > now() ->
        {:ok, value}
      _ ->
        :miss
    end
  end

  def put(key, value, ttl: ttl_seconds) do
    expires_at = System.system_time(:second) + ttl_seconds
    :ets.insert(:voelgoedevents_cache, {key, value, expires_at})
  end
end
```

### **Layer 2: Warm Cache (Redis)**

**Technology:** Redis  
**Scope:** Cluster-wide (shared across all nodes)  
**Latency Target:** 10-50ms  
**TTL:** 5-30 minutes

**Best For:**

- Seat hold tracking (Redis ZSET with TTL)
- Event details
- Ticket type inventories
- Financial summaries
- Multi-node session sharing

**Example:**

```elixir
defmodule Voelgoedevents.Caching.Redis do
  alias Voelgoedevents.Infrastructure.RedisClient

  def get(key) do
    case RedisClient.command(["GET", key]) do
      {:ok, nil} -> :miss
      {:ok, value} -> {:ok, Jason.decode!(value)}
    end
  end

  def put(key, value, ttl: ttl_seconds) do
    json = Jason.encode!(value)
    RedisClient.pipeline([
      ["SET", key, json],
      ["EXPIRE", key, ttl_seconds]
    ])
  end
end
```

### **Layer 3: Cold Storage (Postgres via Ash)**

**Technology:** PostgreSQL (accessed via Ash)  
**Scope:** Permanent source of truth  
**Latency:** 50-200ms (with indexes)  
**TTL:** Permanent

**This is NOT a cache** - it's the authoritative data store. All writes MUST go here first.

---

## Critical Write-Through Rule

### ⚠️ **ALL STATE CHANGES MUST WRITE THROUGH ASH FIRST**

Caches are **read-only mirrors**. You **MUST NEVER** write directly to cache as the source of truth.

### Correct Write Pattern (Write-Through)

```elixir
# ✅ CORRECT: Write to Ash domain first, then invalidate/update cache

def reserve_seat(seat_id) do
  # 1. Write to source of truth (Postgres via Ash)
  case Seat.update(seat_id, %{status: :held}) do
    {:ok, seat} ->
      # 2. Invalidate old cache entries
      invalidate_seat_cache(seat_id)
      invalidate_event_cache(seat.event_id)

      # 3. Optionally warm cache with new value
      warm_seat_cache(seat)

      {:ok, seat}

    {:error, reason} ->
      {:error, reason}
  end
end

defp invalidate_seat_cache(seat_id) do
  ETS.delete("seat:#{seat_id}")
  Redis.delete("seat:#{seat_id}")

  # Broadcast to other nodes
  Phoenix.PubSub.broadcast(
    Voelgoedevents.PubSub,
    "cache:invalidation",
    {:invalidate, "seat:#{seat_id}"}
  )
end
```

### Incorrect Write Pattern (Cache-First)

```elixir
# ❌ INCORRECT: Writing to cache without Ash
def reserve_seat(seat_id) do
  # ❌ WRONG: Cache becomes inconsistent with DB
  ETS.put("seat:#{seat_id}", %{status: :held})

  # ❌ What if this fails? Cache says held, DB says available
  Seat.update(seat_id, %{status: :held})
end
```

### Why This Matters

1. **Data Integrity:** Postgres (via Ash) is the source of truth - it has transactions, constraints, validations
2. **Crash Safety:** If node crashes after cache write but before DB write, data is lost
3. **Multi-Node Consistency:** Other nodes reading from DB will see stale data
4. **Rollback Support:** Can't roll back cache writes if Ash action fails

---

## Cache Invalidation Strategy

### **1. Time-Based Expiration (TTL)**

Cache entries automatically expire after TTL:

```elixir
# Hot cache: 1 minute TTL
ETS.put("event:#{id}", event, ttl: 60)

# Warm cache: 5 minutes TTL
Redis.put("event:#{id}", event, ttl: 300)
```

### **2. Event-Based Invalidation**

Invalidate immediately when source data changes:

```elixir
# Ash Notifier (triggered automatically on state changes)
defmodule Voelgoedevents.Ash.Notifiers.CacheInvalidator do
  use Ash.Notifier

  def notify(%Ash.Notifier.Notification{action: action, resource: Seat, data: seat}) do
    # Invalidate seat cache on any create/update/destroy
    Caching.invalidate("seat:#{seat.id}")
    Caching.invalidate("event:#{seat.event_id}:seats:availability")
    :ok
  end
end
```

### **3. PubSub-Based Multi-Node Invalidation**

When one node invalidates cache, broadcast to others:

```elixir
defmodule Voelgoedevents.Caching.Invalidator do
  def invalidate(key) do
    # Delete from local node
    ETS.delete(key)
    Redis.delete(key)

    # Notify other nodes
    Phoenix.PubSub.broadcast(
      Voelgoedevents.PubSub,
      "cache:invalidation",
      {:invalidate, key}
    )
  end

  # Handle invalidation messages from other nodes
  def handle_info({:invalidate, key}, state) do
    ETS.delete(key)
    {:noreply, state}
  end
end
```

---

## Performance Targets

| Operation               | Cold (Postgres) | Warm (Redis) | Hot (ETS) | Target       |
| ----------------------- | --------------- | ------------ | --------- | ------------ |
| Seat availability check | 100-200ms       | 20-50ms      | < 10ms    | ✅ Sub-100ms |
| Event details           | 80-150ms        | 15-30ms      | < 5ms     | ✅ Sub-100ms |
| Dashboard metrics       | 200-500ms       | 50-100ms     | 10-20ms   | ✅ Sub-100ms |
| Ticket sold count       | 50-100ms        | 10-20ms      | < 5ms     | ✅ Sub-100ms |

**Goal:** 90% of reads served from hot/warm cache = sub-100ms response time

---

## Cache Modules

### **Recommended Structure**

```
caching/
├── README.md (this file)
├── ets.ex                    # Generic ETS cache interface
├── redis.ex                  # Generic Redis cache interface
├── invalidator.ex            # PubSub-based invalidation broadcaster
├── seat_cache.ex             # Seat availability caching logic
├── event_cache.ex            # Event details caching
├── metrics_cache.ex          # Dashboard metrics caching
└── fee_model_cache.ex        # Fee policy caching (Phase 21.6.1)
```

### **Module Responsibilities**

Each cache module (e.g., `seat_cache.ex`) should:

1. Define **cache keys** (e.g., `"seat:#{seat_id}"`, `"event:#{event_id}:seats:availability"`)
2. Define **TTLs** for each key type
3. Provide **high-level read functions** that handle cache hierarchy
4. Provide **invalidation functions** that clear all related keys
5. **NEVER write to cache as source of truth** - always read-through/write-through

### **Example: Seat Cache Module**

```elixir
defmodule Voelgoedevents.Caching.SeatCache do
  @moduledoc """
  Caching layer for seat availability.

  This module manages the cache hierarchy for seat data:
  - ETS: 1 minute TTL (hot)
  - Redis: 5 minutes TTL (warm)
  - Postgres: Source of truth (cold)
  """

  alias Voelgoedevents.Caching.{ETS, Redis}
  alias Voelgoedevents.Ash.Resources.Seating.Seat

  @ets_ttl 60        # 1 minute
  @redis_ttl 300     # 5 minutes

  @doc """
  Get seat by ID with cache hierarchy.

  1. Check ETS (< 10ms)
  2. Check Redis (10-50ms)
  3. Query Postgres via Ash (50-200ms)
  4. Backfill caches on miss
  """
  def get(seat_id) do
    cache_key = "seat:#{seat_id}"

    with :miss <- ETS.get(cache_key),
         :miss <- Redis.get(cache_key) do
      # Cache miss - query source of truth
      case Seat.get(seat_id) do
        {:ok, seat} ->
          # Backfill caches
          warm_cache(cache_key, seat)
          {:ok, seat}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, seat} -> {:ok, seat}
    end
  end

  @doc """
  Get seat availability bitmap for event.

  Returns: %{seat_id => :available | :held | :sold}

  Optimized for rendering seat maps (thousands of seats).
  """
  def get_availability_map(event_id) do
    cache_key = "event:#{event_id}:seats:availability"

    with :miss <- ETS.get(cache_key),
         :miss <- Redis.get(cache_key) do
      # Build availability map from DB
      seats = Seat.list_by_event(event_id)
      availability_map = Map.new(seats, &{&1.id, &1.status})

      # Cache with shorter TTL (seats change frequently)
      ETS.put(cache_key, availability_map, ttl: 30)
      Redis.put(cache_key, availability_map, ttl: 60)

      {:ok, availability_map}
    else
      {:ok, map} -> {:ok, map}
    end
  end

  @doc """
  Invalidate seat cache.

  Call this after ANY seat state change via Ash.
  """
  def invalidate(seat_id, event_id) do
    Caching.Invalidator.invalidate("seat:#{seat_id}")
    Caching.Invalidator.invalidate("event:#{event_id}:seats:availability")
  end

  defp warm_cache(key, value) do
    ETS.put(key, value, ttl: @ets_ttl)
    Redis.put(key, value, ttl: @redis_ttl)
  end
end
```

---

## Testing Strategy

### **1. Cache Hit/Miss Scenarios**

```elixir
defmodule Voelgoedevents.Caching.SeatCacheTest do
  test "cache hierarchy: ETS hit" do
    seat = build(:seat)
    SeatCache.warm_cache("seat:#{seat.id}", seat)

    # Should return from ETS (< 10ms)
    assert {:ok, ^seat} = SeatCache.get(seat.id)
  end

  test "cache hierarchy: Redis fallback" do
    seat = build(:seat)

    # Warm Redis but not ETS
    Redis.put("seat:#{seat.id}", seat, ttl: 300)

    # Should return from Redis and backfill ETS
    assert {:ok, ^seat} = SeatCache.get(seat.id)
    assert {:ok, ^seat} = ETS.get("seat:#{seat.id}")
  end

  test "cache hierarchy: DB fallback" do
    seat = insert(:seat)

    # Cold start - no cache
    assert {:ok, ^seat} = SeatCache.get(seat.id)

    # Should now be in both caches
    assert {:ok, ^seat} = ETS.get("seat:#{seat.id}")
    assert {:ok, ^seat} = Redis.get("seat:#{seat.id}")
  end
end
```

### **2. Invalidation Tests**

```elixir
test "invalidation clears all cache layers" do
  seat = build(:seat)
  SeatCache.warm_cache("seat:#{seat.id}", seat)

  # Invalidate
  SeatCache.invalidate(seat.id, seat.event_id)

  # Should be cache miss
  assert :miss = ETS.get("seat:#{seat.id}")
  assert :miss = Redis.get("seat:#{seat.id}")
end
```

### **3. Concurrency Tests**

```elixir
test "concurrent reads don't cause duplicate DB queries" do
  seat_id = insert(:seat).id

  # Spawn 100 concurrent reads
  tasks = for _ <- 1..100 do
    Task.async(fn -> SeatCache.get(seat_id) end)
  end

  results = Task.await_many(tasks)

  # All should succeed
  assert Enum.all?(results, &match?({:ok, _}, &1))

  # DB should only be queried once (verify via query counter)
end
```

---

## Common Pitfalls to Avoid

### ❌ **Pitfall 1: Cache Stampede**

**Problem:** Cache expires → 1000 requests hit DB simultaneously

**Solution:** Use locking or "dog-pile" prevention:

```elixir
def get_with_stampede_prevention(key) do
  case ETS.get(key) do
    {:ok, value} -> {:ok, value}
    :miss ->
      # Only one process rebuilds cache
      Cachex.fetch(:cache, key, fn ->
        query_db_and_build_cache(key)
      end)
  end
end
```

### ❌ **Pitfall 2: Inconsistent Invalidation**

**Problem:** Forgot to invalidate related keys

**Solution:** Use Ash notifiers to automatically invalidate on state changes

### ❌ **Pitfall 3: Cache as Source of Truth**

**Problem:** Writing to cache but not to DB

**Solution:** ALWAYS write to Ash domain first, then invalidate cache

---

## Multi-Node Considerations

### **ETS is Per-Node**

ETS tables are local to each Erlang node. If you have 3 nodes:

- Node A writes to DB → invalidates local ETS
- Node B & C still have stale ETS data

**Solution:** Use PubSub to broadcast invalidations:

```elixir
# Node A
def update_seat(seat_id) do
  Seat.update(seat_id, ...)

  # Broadcast invalidation to all nodes
  Phoenix.PubSub.broadcast(
    Voelgoedevents.PubSub,
    "cache:invalidation",
    {:invalidate_seat, seat_id}
  )
end

# All nodes (including Node A)
def handle_info({:invalidate_seat, seat_id}, state) do
  ETS.delete("seat:#{seat_id}")
  {:noreply, state}
end
```

### **Redis is Shared**

Redis is cluster-wide, so invalidating Redis affects all nodes immediately.

---

## Monitoring & Observability

### **Track Cache Hit Rates**

```elixir
def get(key) do
  case ETS.get(key) do
    {:ok, value} ->
      :telemetry.execute([:cache, :hit], %{layer: :ets})
      {:ok, value}

    :miss ->
      :telemetry.execute([:cache, :miss], %{layer: :ets})
      fallback_to_redis(key)
  end
end
```

### **Alert on Low Hit Rates**

If ETS hit rate < 80%, investigate:

- TTL too short
- Too many invalidations
- Data set too large for ETS

---

## References

- **Roadmap Phase 8.3.2:** Seat availability caching
- **Roadmap Phase 21.6.1:** Fee model caching
- **Appendix C:** Performance & Scaling Strategy
- **Infrastructure README:** `/lib/voelgoedevents/infrastructure/README.md`

---

**Maintained By:** VoelgoedEvents Platform Team  
**Last Updated:** December 1, 2025  
**Status:** Active - Critical for performance targets
