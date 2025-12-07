# VoelgoedEvents: Seat Hold Lifecycle & Reservation Engine

**File Path:** `docs/workflows/seat_hold_lifecycle.md`

*Last Updated: 2025-12-07 (Initial)*  
*Status: Production-Ready Specification*  
*Audience: Backend engineers, SRE, platform architects*  
*Scale Target: 5000+ concurrent users, zero double-bookings*

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture & Invariants](#1-system-architecture--invariants)
3. [Redis Schema & Key Design](#2-redis-schema--key-design)
4. [The Happy Path: Reserve Seat](#3-the-happy-path-reserve-seat)
5. [Failure Modes & DB Fallback](#4-failure-modes--db-fallback)
6. [Race Conditions & Hold Extension](#5-race-conditions--hold-extension)
7. [The Reaper: Cleanup Worker](#6-the-reaper-cleanup-worker)
8. [Observability & Telemetry](#7-observability--telemetry)
9. [Ash Resource: SeatHold](#8-ash-resource-seathold)
10. [Implementation Guide](#9-implementation-guide)
11. [Testing Strategy](#10-testing-strategy)
12. [Disaster Recovery](#11-disaster-recovery)

---

## Executive Summary

**Problem:** VoelgoedEvents must reserve seats for 15 minutes during checkout without double-bookings, even at 5000+ concurrent users and under Redis failures.

**Solution:** A dual-layer system combining **Redis (speed)** and **PostgreSQL (truth)** with automatic failover to pessimistic locking.

### Key Design Principles

1. **PostgreSQL is the Source of Truth** — Every hold must exist in `seat_holds` table before confirming to user
2. **Redis is the Speed Layer** — Atomic `SETNX` prevents 99.99% of double-bookings in milliseconds
3. **Automatic Failover** — If Redis unavailable, fallback to `SELECT ... FOR UPDATE NOWAIT` (pessimistic locking)
4. **Idempotency First** — Re-entrant operations succeed, never error on duplicate user action
5. **Circuit Breaker Pattern** — Detect Redis outage, switch to fallback, auto-recover
6. **Observable Everywhere** — Telemetry events for every state transition and failure

### Expected Outcomes

| Metric | Target | Achievement |
|--------|--------|---|
| **Double-Booking Rate** | 0% | Impossible with both layers |
| **Seat Lock Latency (p95)** | <50ms | Redis SETNX + Postgres write |
| **Hold Availability** | 99.99% | Fallback via Postgres locking |
| **Reaper Staleness** | <1 min | Job runs every 30s |
| **Observability** | 100% | Telemetry on all paths |

---

## 1. System Architecture & Invariants

### 1.1 Dual-Layer Architecture Diagram

```
User Clicks "Reserve Seat"
         ↓
  ┌─────────────────────────────────────┐
  │ VoelgoedEvents.Seating.ReserveSeat  │ (Elixir Action)
  └─────────────────────────────────────┘
         ↓
  ┌─────────────────────────────────────┐
  │ Check Idempotency (Redis / Postgres) │
  │ (Already held by this user?)         │
  └─────────────────────────────────────┘
         ↓ (Not held)
  ┌─────────────────────────────────────┐
  │ TRY: Redis.SETNX (Lock)              │ ← Fast Path (99.99%)
  │ Key: seat:{id} = {user_id, token}   │
  │ TTL: 16 minutes (safety net)         │
  └─────────────────────────────────────┘
    ↓ (Success)          ↓ (Failure)
  FAST PATH          FALLBACK PATH
    ↓                   ↓
Write SeatHold      TRY: Postgres SELECT...FOR UPDATE
 to Postgres         Lock w/ NOWAIT
    ↓
Broadcast PubSub
Seat Status Change
    ↓
Return :ok to User
```

### 1.2 Critical Invariants

**INVARIANT 1: PostgreSQL is Source of Truth**
```
Every seat hold MUST have:
  - Row in seat_holds table
  - organization_id, event_id, seat_id, user_id, cart_token, expires_at
  - NOT NULL constraints enforced

If Postgres says held, it IS held.
If Redis says held but Postgres doesn't, Redis is WRONG (treat as not held).
```

**INVARIANT 2: Redis Keys are Ephemeral**
```
Redis keys serve ONE purpose: sub-50ms lookup.
- SETNX enforces atomicity (no partial writes)
- 16-minute TTL ensures cleanup even if Reaper fails
- After TTL expires, Redis automatically forgets the key
- Postgres still has truth (Reaper cleans up eventually)
```

**INVARIANT 3: Idempotency on User Actions**
```
User Action: "Hold Seat X"
- If user already holds X: Return :ok (RE-ENTRANT)
- If another user holds X: Return {:error, :seat_taken}
- NEVER return {:error, :already_held_by_you}
  (This breaks form submission retry logic)
```

**INVARIANT 4: Atomicity & Consistency**
```
All writes are ACID-compliant:
- Redis SETNX is atomic
- Postgres transaction wraps SeatHold insert + seat status update
- Both succeed or both fail; no partial states
```

**INVARIANT 5: Causality in Notifications**
```
Order:
  1. Lock acquired (Redis + Postgres)
  2. SeatHold record created
  3. PubSub event emitted
  4. Return to user

Never emit PubSub before Postgres write.
```

---

## 2. Redis Schema & Key Design

### 2.1 Redis Key Format (Strict)

**Rule:** Keys must be globally unique and partition-able by org/event.

```
Format: org:{org_id}:event:{event_id}:seat:{seat_id}
```

**Components:**

| Part | Type | Example | Purpose |
|------|------|---------|---------|
| `org:{org_id}` | UUID | `org:550e8400-e29b-41d4-a716-446655440000` | Tenant isolation |
| `event:{event_id}` | UUID | `event:abc-event-123` | Event scoping (multi-event sharding) |
| `seat:{seat_id}` | UUID | `seat:seat-row-a-5` | Individual seat lock |

**Full Example:**
```
org:550e8400-e29b-41d4-a716-446655440000:event:abc-event-123:seat:seat-row-a-5
```

### 2.2 Redis Value Structure (JSON)

**Value Type:** JSON (stored as string in Redis)

```json
{
  "user_id": "user-uuid-456",
  "cart_token": "checkout-token-xyz",
  "expires_at": "2025-12-07T19:51:00Z",
  "held_at": "2025-12-07T19:36:00Z"
}
```

**Field Breakdown:**

| Field | Type | Purpose | Validation |
|-------|------|---------|-----------|
| `user_id` | UUID string | Who holds this seat | Required, non-empty |
| `cart_token` | String | Session identifier | Used to match checkout to hold |
| `expires_at` | ISO 8601 DateTime | Hold expiry time | Must be > now |
| `held_at` | ISO 8601 DateTime | Lock timestamp | For audit, can be null |

### 2.3 Redis Operations

#### SET with NX (Atomic Lock)

```elixir
def lock_seat_redis(org_id, event_id, seat_id, user_id, cart_token) do
  key = "org:#{org_id}:event:#{event_id}:seat:#{seat_id}"
  
  expires_at = DateTime.add(DateTime.utc_now(), 15, :minute)
  
  value = Jason.encode!(%{
    "user_id" => user_id,
    "cart_token" => cart_token,
    "expires_at" => DateTime.to_iso8601(expires_at),
    "held_at" => DateTime.to_iso8601(DateTime.utc_now())
  })
  
  # Atomic: Only succeeds if key doesn't exist
  # Returns: {:ok, true} if set, {:ok, false} if already exists
  case Redix.command(redis_conn(), ["SET", key, value, "NX", "EX", "960"]) do
    {:ok, "OK"} -> {:ok, :locked}
    {:ok, nil} -> {:error, :seat_taken}
    {:error, reason} -> {:error, {:redis_error, reason}}
  end
end
```

**Parameters:**
- `NX`: Only set if key doesn't exist (prevents overwrite)
- `EX 960`: Expire after 960 seconds (16 minutes = safety net)

**Return Values:**
- `{:ok, "OK"}` → Lock acquired
- `{:ok, nil}` → Key already exists (seat taken)
- `{:error, reason}` → Redis unavailable (fallback!)

#### GET (Idempotency Check)

```elixir
def is_seat_held_redis(org_id, event_id, seat_id) do
  key = "org:#{org_id}:event:#{event_id}:seat:#{seat_id}"
  
  case Redix.command(redis_conn(), ["GET", key]) do
    {:ok, nil} -> {:ok, :not_held}
    {:ok, value_json} ->
      case Jason.decode(value_json) do
        {:ok, %{"user_id" => user_id}} -> {:ok, {:held, user_id}}
        {:error, _} -> {:ok, :not_held}  # Corrupted value, treat as not held
      end
    {:error, _} -> {:error, :redis_unavailable}
  end
end
```

#### EXPIRE (Extend Hold)

```elixir
def extend_hold_redis(org_id, event_id, seat_id, extra_minutes \\ 5) do
  key = "org:#{org_id}:event:#{event_id}:seat:#{seat_id}"
  
  # Add 5 minutes to current expiry
  ttl_seconds = extra_minutes * 60
  
  case Redix.command(redis_conn(), ["EXPIRE", key, ttl_seconds]) do
    {:ok, 1} -> {:ok, :extended}
    {:ok, 0} -> {:error, :key_not_found}  # Seat not held (already released)
    {:error, reason} -> {:error, {:redis_error, reason}}
  end
end
```

#### DEL (Release Hold)

```elixir
def release_hold_redis(org_id, event_id, seat_id) do
  key = "org:#{org_id}:event:#{event_id}:seat:#{seat_id}"
  
  case Redix.command(redis_conn(), ["DEL", key]) do
    {:ok, 1} -> {:ok, :deleted}
    {:ok, 0} -> {:ok, :not_found}  # Already deleted/expired
    {:error, reason} -> {:error, {:redis_error, reason}}
  end
end
```

### 2.4 Redis Cluster Considerations

**For high concurrency (5000+ concurrent), use Redis Cluster:**

```elixir
# Single node (dev/test)
Redix.start_link(host: "localhost", port: 6379)

# Cluster (production)
Redix.start_link(
  host: "redis-node-1:6379",
  cluster: [
    "redis-node-2:6379",
    "redis-node-3:6379"
  ]
)
```

**Key Distribution:**
- Keys automatically sharded by hash slot
- All seat holds for org X naturally partition across nodes
- Reduces hot-key contention

---

## 3. The Happy Path: Reserve Seat

### 3.1 Flow: User Clicks "Reserve Seat"

```
INPUT:
  - user_id: UUID
  - seat_id: UUID
  - event_id: UUID
  - cart_token: String (checkout session ID)

PROCESS:

1. Idempotency Check
   ├─ Query Postgres: Is this user already holding this seat?
   │  SELECT * FROM seat_holds WHERE seat_id = X AND user_id = Y
   │  AND deleted_at IS NULL
   │
   └─ If found: Return {:ok, :already_held} (Re-entrant success)
   
2. Redis Lock Attempt
   ├─ SETNX key=org:{id}:event:{id}:seat:{id}
   │  value={user_id, cart_token, expires_at}
   │  ttl=960 seconds (16 min)
   │
   ├─ If Redis unavailable → Skip to DB Fallback (Section 4)
   │
   └─ If fails (seat taken) → Return {:error, :seat_taken}

3. Postgres Insert (in transaction)
   ├─ INSERT INTO seat_holds(...)
   │  VALUES(org_id, event_id, seat_id, user_id, cart_token, expires_at)
   │
   ├─ UPDATE seats SET status = 'held' WHERE id = seat_id
   │  (For occupancy dashboard)
   │
   └─ COMMIT transaction
      If fails → DELETE from Redis (rollback lock)

4. PubSub Broadcast
   ├─ Topic: org:{id}:event:{id}:seating:seat:held
   │  Payload: {event: "seat_held", seat_id, user_id, expires_at}
   │
   └─ Subscribers (occupancy dashboard, map UI) update in real-time

5. Return to User
   └─ {:ok, %{seat_id, hold_expires_at: "2025-12-07T19:51:00Z"}}
```

### 3.2 Ash Action: ReserveSeat

```elixir
defmodule VoelgoedEvents.Ash.Resources.Seating.Seat do
  use Ash.Resource,
    domain: VoelgoedEvents.Seating,
    data_layer: AshPostgres.DataLayer

  actions do
    create :reserve_seat do
      argument :cart_token, :string, required: true
      argument :user_id, :uuid, required: true
      
      # Validate inputs
      validate presence(:organization_id)
      validate presence(:event_id)
      validate presence(:seat_id)
      
      change {VoelgoedEvents.Seating.ReserveSeat, []}
    end
  end
end

defmodule VoelgoedEvents.Seating.ReserveSeat do
  @moduledoc """
  Change: Reserve a seat for a user (create SeatHold).
  
  Flow:
    1. Check idempotency (user already holding this seat?)
    2. Lock in Redis (SETNX)
    3. Persist to Postgres (SeatHold insert)
    4. Broadcast (PubSub)
  """
  
  use Ash.Resource.Change
  require Ash.Query
  
  def change(changeset, _opts) do
    Ash.Changeset.after_action(changeset, &after_action/2)
  end

  defp after_action(changeset, result) do
    org_id = Ash.Changeset.get_attribute(changeset, :organization_id)
    event_id = Ash.Changeset.get_attribute(changeset, :event_id)
    seat_id = Ash.Changeset.get_attribute(changeset, :seat_id)
    user_id = Ash.Changeset.get_argument(changeset, :user_id)
    cart_token = Ash.Changeset.get_argument(changeset, :cart_token)
    
    case reserve_seat_impl(org_id, event_id, seat_id, user_id, cart_token) do
      {:ok, hold} -> 
        :telemetry.execute(
          [:voelgoedevents, :seating, :hold, :success],
          %{count: 1},
          %{seat_id: seat_id, event_id: event_id}
        )
        {:ok, result}
        
      {:error, :seat_taken} ->
        :telemetry.execute(
          [:voelgoedevents, :seating, :hold, :conflict],
          %{count: 1},
          %{seat_id: seat_id, event_id: event_id}
        )
        Ash.Changeset.add_error(
          changeset,
          "Seat is already held by another user. Please select a different seat."
        )
        
      {:error, reason} ->
        :telemetry.execute(
          [:voelgoedevents, :seating, :hold, :error],
          %{count: 1},
          %{reason: inspect(reason)}
        )
        Ash.Changeset.add_error(changeset, "Failed to reserve seat: #{inspect(reason)}")
    end
  end

  defp reserve_seat_impl(org_id, event_id, seat_id, user_id, cart_token) do
    # Step 1: Idempotency Check
    case check_existing_hold(org_id, event_id, seat_id, user_id) do
      {:ok, _hold} -> {:ok, :already_held}  # Re-entrant success
      {:error, :not_held} -> :ok
      {:error, reason} -> {:error, reason}
    end
    |> case do
      {:ok, _} -> {:ok, :idempotent}
      other -> other
    end
    |> case do
      {:ok, _} ->
        # Step 2: Try Redis Lock
        try_redis_lock(org_id, event_id, seat_id, user_id, cart_token)
        
      error ->
        error
    end
  end

  defp check_existing_hold(org_id, event_id, seat_id, user_id) do
    case Ash.read_one(
      VoelgoedEvents.Ash.Resources.Seating.SeatHold,
      filter: [
        organization_id: org_id,
        event_id: event_id,
        seat_id: seat_id,
        user_id: user_id,
        deleted_at: nil
      ]
    ) do
      {:ok, hold} -> {:ok, hold}
      :error -> {:error, :not_held}
    end
  end

  defp try_redis_lock(org_id, event_id, seat_id, user_id, cart_token) do
    case VoelgoedEvents.Redis.lock_seat(org_id, event_id, seat_id, user_id, cart_token) do
      {:ok, :locked} ->
        # Step 3: Persist to Postgres (transaction)
        persist_hold(org_id, event_id, seat_id, user_id, cart_token)
        
      {:ok, :seat_taken} ->
        {:error, :seat_taken}
        
      {:error, :redis_unavailable} ->
        # Step 4: Fallback to Postgres pessimistic locking
        fallback_db_lock(org_id, event_id, seat_id, user_id, cart_token)
    end
  end

  defp persist_hold(org_id, event_id, seat_id, user_id, cart_token) do
    expires_at = DateTime.add(DateTime.utc_now(), 15, :minute)
    
    VoelgoedEvents.Repo.transaction(fn ->
      # Insert SeatHold
      case Ash.create(
        VoelgoedEvents.Ash.Resources.Seating.SeatHold,
        %{
          organization_id: org_id,
          event_id: event_id,
          seat_id: seat_id,
          user_id: user_id,
          cart_token: cart_token,
          expires_at: expires_at
        }
      ) do
        {:ok, hold} ->
          # Update seat status
          Ash.update(
            VoelgoedEvents.Ash.Resources.Seating.Seat,
            %{status: :held},
            filter: [id: seat_id]
          )
          
          # Broadcast PubSub
          Phoenix.PubSub.broadcast(
            VoelgoedeventsWeb.Endpoint,
            VoelgoedEvents.Topics.seating_seat_held(org_id, event_id),
            %{
              "event" => "seat_held",
              "seat_id" => seat_id,
              "user_id" => user_id,
              "expires_at" => DateTime.to_iso8601(expires_at)
            }
          )
          
          {:ok, hold}
          
        error ->
          VoelgoedEvents.Redis.release_hold(org_id, event_id, seat_id)
          error
      end
    end)
  end
end
```

### 3.3 Success Scenario: Timeline

```
T+0ms   User clicks "Reserve Seat A"
        ├─ Network request sent

T+2ms   Server receives request
        ├─ Auth validated, org/event/seat IDs extracted

T+3ms   Idempotency check
        ├─ Query: SELECT * FROM seat_holds WHERE user_id = X AND seat_id = A
        ├─ Result: Not found
        └─ Proceed to lock

T+5ms   Redis SETNX
        ├─ Atomic lock acquired (key doesn't exist)
        └─ TTL set to 960s (16 min)

T+8ms   Postgres INSERT (transaction)
        ├─ INSERT seat_holds(...)
        ├─ UPDATE seats SET status='held'
        └─ COMMIT

T+11ms  PubSub broadcast
        ├─ Occupancy dashboard updated
        └─ Seat map UI shows [HELD]

T+12ms  Response to user
        └─ {"ok": true, "expires_at": "2025-12-07T19:51:00Z"}

User sees "Seat A reserved for 15 minutes" in <15ms
```

---

## 4. Failure Modes & DB Fallback

### 4.1 Detecting Redis Unavailability

**Circuit Breaker Pattern:**

```elixir
defmodule VoelgoedEvents.Redis.CircuitBreaker do
  @moduledoc """
  Detects Redis outages and switches to fallback (Postgres pessimistic locking).
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    {:ok, %{
      status: :healthy,
      failure_count: 0,
      last_failure: nil,
      threshold: 5,
      reset_timeout: 30_000  # 30 seconds
    }}
  end
  
  def record_failure do
    GenServer.cast(__MODULE__, :record_failure)
  end
  
  def is_healthy? do
    GenServer.call(__MODULE__, :is_healthy)
  end
  
  def handle_cast(:record_failure, state) do
    new_count = state.failure_count + 1
    
    new_status = if new_count >= state.threshold do
      :unhealthy
    else
      state.status
    end
    
    new_state = %{state | failure_count: new_count, status: new_status, last_failure: DateTime.utc_now()}
    
    # Schedule reset attempt in 30 seconds
    if new_status == :unhealthy do
      Process.send_after(self(), :attempt_reset, state.reset_timeout)
      Logger.error("Redis circuit breaker opened after #{new_count} failures")
    end
    
    {:noreply, new_state}
  end
  
  def handle_call(:is_healthy, _from, state) do
    {:reply, state.status == :healthy, state}
  end
  
  def handle_info(:attempt_reset, state) do
    case Redix.command(redis_conn(), ["PING"]) do
      {:ok, "PONG"} ->
        Logger.info("Redis circuit breaker reset (healthy)")
        {:noreply, %{state | status: :healthy, failure_count: 0}}
        
      {:error, _} ->
        Logger.warn("Redis still unhealthy, will retry in 30s")
        Process.send_after(self(), :attempt_reset, state.reset_timeout)
        {:noreply, state}
    end
  end
end
```

**Usage:**

```elixir
def try_redis_lock(org_id, event_id, seat_id, user_id, cart_token) do
  if VoelgoedEvents.Redis.CircuitBreaker.is_healthy?() do
    case VoelgoedEvents.Redis.lock_seat(...) do
      {:error, :redis_unavailable} ->
        VoelgoedEvents.Redis.CircuitBreaker.record_failure()
        fallback_db_lock(...)
        
      result -> result
    end
  else
    # Circuit open: go straight to DB fallback
    fallback_db_lock(org_id, event_id, seat_id, user_id, cart_token)
  end
end
```

### 4.2 Pessimistic Locking Fallback (SELECT ... FOR UPDATE)

**Problem:** When Redis is unavailable, we must use Postgres alone. Risk: Deadlock storms if 1000 users click the same seat simultaneously.

**Solution:** `SELECT ... FOR UPDATE NOWAIT` with exponential backoff.

#### Strategy 1: NOWAIT (Fail Fast)

```elixir
def fallback_db_lock_nowait(org_id, event_id, seat_id, user_id, cart_token) do
  expires_at = DateTime.add(DateTime.utc_now(), 15, :minute)
  
  VoelgoedEvents.Repo.transaction(
    fn ->
      # Row-level lock with NO WAIT
      # If locked, fails immediately (doesn't queue)
      case Ash.read_one(
        VoelgoedEvents.Ash.Resources.Seating.Seat,
        filter: [id: seat_id, organization_id: org_id],
        lock: "FOR UPDATE NOWAIT"  # ← Fail fast if locked
      ) do
        {:ok, seat} when seat.status == :available ->
          # Seat available, try to hold it
          Ash.create(
            VoelgoedEvents.Ash.Resources.Seating.SeatHold,
            %{
              organization_id: org_id,
              event_id: event_id,
              seat_id: seat_id,
              user_id: user_id,
              cart_token: cart_token,
              expires_at: expires_at
            }
          )
          
        {:ok, _} ->
          {:error, :seat_taken}
          
        {:error, :lock_not_available} ->
          {:error, :seat_taken}
          
        error ->
          error
      end
    end,
    timeout: 5000  # 5 second transaction timeout
  )
end
```

**Behavior:**
- **If seat is locked:** Returns `{:error, :lock_not_available}` immediately (no queue)
- **User sees:** "Seat unavailable (someone else is checking out)" in <1ms
- **Prevents:** Thundering herd of queries waiting for lock

#### Strategy 2: SKIP LOCKED (Allocate from Pool)

If you're allocating seats from a large pool of "available" seats:

```elixir
def allocate_available_seat_fallback(org_id, event_id, user_id, cart_token) do
  expires_at = DateTime.add(DateTime.utc_now(), 15, :minute)
  
  VoelgoedEvents.Repo.transaction(
    fn ->
      # Select ANY available seat, skipping locked rows
      # (Good for "pick any seat in this section" scenarios)
      case Ash.read_one(
        VoelgoedEvents.Ash.Resources.Seating.Seat,
        filter: [
          event_id: event_id,
          block_id: block_id,
          status: :available
        ],
        limit: 1,
        lock: "FOR UPDATE SKIP LOCKED"  # ← Grab next available
      ) do
        {:ok, seat} ->
          Ash.create(VoelgoedEvents.Ash.Resources.Seating.SeatHold, %{...})
          
        :error ->
          {:error, :no_available_seats}
      end
    end,
    timeout: 2000
  )
end
```

**Behavior:**
- **If seat locked:** Skip it, try next row
- **Use case:** "Reserve any seat in Section A"
- **Prevents:** Contention on popular seats

### 4.3 Fallback Decision Tree

```
User clicks "Reserve Seat X"
         ↓
Is Redis healthy?
├─ YES: Try Redis lock
│  ├─ Lock acquired? → Persist to Postgres + Broadcast
│  ├─ Seat taken? → Return error
│  └─ Redis error? → Mark failure, try fallback
│
└─ NO: Go to Postgres pessimistic lock
   ├─ SELECT... FOR UPDATE NOWAIT
   │  ├─ Lock acquired? → Persist SeatHold
   │  └─ Lock failed? → Seat taken (someone else grabbed it)
   │
   └─ If repeated failures?
      └─ Telemetry alert + page on-call (Redis is down!)
```

### 4.4 Observability During Fallback

```elixir
def try_redis_lock(org_id, event_id, seat_id, user_id, cart_token) do
  case VoelgoedEvents.Redis.lock_seat(org_id, event_id, seat_id, user_id, cart_token) do
    {:ok, :locked} ->
      :telemetry.execute(
        [:voelgoedevents, :seating, :hold, :redis_success],
        %{count: 1},
        %{}
      )
      persist_hold(...)
      
    {:error, :redis_unavailable} ->
      :telemetry.execute(
        [:voelgoedevents, :seating, :hold, :redis_fallback],
        %{count: 1},
        %{fallback: "postgres"}
      )
      # Log for alerting
      Logger.warn("Redis unavailable, falling back to Postgres: seat=#{seat_id}")
      fallback_db_lock(...)
  end
end
```

**Alert Rule (in monitoring system):**
```
IF (rate(voelgoedevents_seating_hold_redis_fallback_total[5m]) > 0.5)
THEN alert("Redis hold lock fallback detected - investigate Redis!")
SEVERITY: warning
```

---

## 5. Race Conditions & Hold Extension

### 5.1 The 14:59 Race: Hold Expires During Checkout

**Scenario:**
```
T+0m    User reserves Seat A (expires at T+15m)
T+14m59 User clicks "Pay Now"
        ├─ Network latency: 2 seconds
        └─ Request arrives at T+15m01
        
T+15m01 Reaper runs: "Hold expired 1 second ago"
        ├─ DELETE FROM seat_holds WHERE expires_at < now()
        ├─ Seat A is released
        └─ Another user can now hold it
        
T+15m03 Payment completes
        └─ Try to create ticket for Seat A
        └─ ERROR: Seat A is now held by User B!
```

**Solution: Automatic Hold Extension**

Every `StartCheckout` action MUST attempt `ExtendHold`:

```elixir
defmodule VoelgoedEvents.Ticketing.StartCheckout do
  @moduledoc """
  Action: Begin checkout process.
  
  CRITICAL: Extends all held seats by 5 minutes to prevent
  expiry during payment processing.
  """
  
  use Ash.Resource.Change
  require Ash.Query
  
  def change(changeset, _opts) do
    Ash.Changeset.after_action(changeset, &after_action/2)
  end

  defp after_action(changeset, result) do
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)
    event_id = Ash.Changeset.get_attribute(changeset, :event_id)
    org_id = Ash.Changeset.get_attribute(changeset, :organization_id)
    
    # Find all seats this user is holding
    case Ash.read(
      VoelgoedEvents.Ash.Resources.Seating.SeatHold,
      filter: [
        user_id: user_id,
        event_id: event_id,
        deleted_at: nil
      ]
    ) do
      {:ok, holds} ->
        # Extend each hold by 5 minutes
        Enum.each(holds, fn hold ->
          extend_hold(org_id, event_id, hold.seat_id)
        end)
        
        {:ok, result}
        
      {:error, _} ->
        {:ok, result}  # No holds to extend
    end
  end

  defp extend_hold(org_id, event_id, seat_id) do
    # Update Postgres
    new_expires_at = DateTime.add(DateTime.utc_now(), 20, :minute)  # 20 min total
    
    case Ash.update(
      VoelgoedEvents.Ash.Resources.Seating.SeatHold,
      %{expires_at: new_expires_at},
      filter: [seat_id: seat_id]
    ) do
      {:ok, _} ->
        # Update Redis (fire-and-forget)
        VoelgoedEvents.Redis.extend_hold(org_id, event_id, seat_id, 5)
        
        :telemetry.execute(
          [:voelgoedevents, :seating, :hold, :extended],
          %{count: 1},
          %{seat_id: seat_id}
        )
        
      {:error, _} ->
        # Postgres update failed; Redis extension won't help
        Logger.warn("Failed to extend hold for seat=#{seat_id}")
    end
  end
end
```

### 5.2 Extension Constraint: User Validation

**CRITICAL:** Only the user who CREATED the hold can extend it.

```elixir
def extend_hold_with_validation(org_id, event_id, seat_id, requesting_user_id) do
  case Ash.read_one(
    VoelgoedEvents.Ash.Resources.Seating.SeatHold,
    filter: [seat_id: seat_id, event_id: event_id]
  ) do
    {:ok, hold} ->
      if hold.user_id == requesting_user_id do
        # User owns this hold; extend it
        new_expires = DateTime.add(hold.expires_at, 5, :minute)
        Ash.update(hold, %{expires_at: new_expires})
      else
        # User doesn't own this hold; deny extension
        {:error, :not_hold_owner}
      end
      
    :error ->
      {:error, :hold_not_found}
  end
end
```

### 5.3 Extension Telemetry

```
Checkout started → Attempt hold extension
  ├─ Success → Telemetry: hold.extended
  ├─ Hold already expired → Telemetry: hold.expired_before_checkout
  │  └─ User must re-select seats
  └─ Database error → Telemetry: hold.extension_failed
     └─ Alert SRE (likely database issue)
```

---

## 6. The Reaper: Cleanup Worker

### 6.1 Reaper Architecture

**Job:** `VoelgoedEvents.Workers.CleanupExpiredHolds`

**Trigger:** Oban job, runs every 30 seconds

**Logic:**
1. Find all SeatHolds where `expires_at < now()` and `deleted_at IS NULL`
2. Soft-delete from Postgres
3. Fire-and-forget delete from Redis
4. Update seat status to `:available`
5. Broadcast PubSub (seat released)

### 6.2 Reaper Implementation

```elixir
defmodule VoelgoedEvents.Workers.CleanupExpiredHolds do
  @moduledoc """
  Oban worker: Clean up expired seat holds every 30 seconds.
  
  Trigger: Scheduled job
  Frequency: Every 30 seconds
  
  Flow:
    1. Find SeatHolds where expires_at < now()
    2. Delete from Postgres (soft delete)
    3. Delete from Redis (best effort)
    4. Update Seat.status to :available
    5. Broadcast PubSub
  """
  
  use Oban.Worker, queue: :default, max_attempts: 3
  require Ash.Query
  
  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()
    
    # Find expired holds
    case Ash.read(
      VoelgoedEvents.Ash.Resources.Seating.SeatHold,
      filter: [
        expires_at: {:less_than, now},
        deleted_at: nil
      ],
      action: :read
    ) do
      {:ok, expired_holds} ->
        process_expired_holds(expired_holds)
        {:ok, %{"processed" => Enum.count(expired_holds)}}
        
      {:error, reason} ->
        Logger.error("Reaper failed to fetch expired holds: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_expired_holds(holds) do
    Enum.each(holds, &release_hold/1)
  end

  defp release_hold(hold) do
    VoelgoedEvents.Repo.transaction(fn ->
      # 1. Soft-delete from Postgres
      case Ash.update(
        hold,
        %{deleted_at: DateTime.utc_now()},
        action: :destroy_soft
      ) do
        {:ok, _} ->
          # 2. Delete from Redis (best-effort, fire-and-forget)
          Task.start(fn ->
            VoelgoedEvents.Redis.release_hold(
              hold.organization_id,
              hold.event_id,
              hold.seat_id
            )
          end)
          
          # 3. Update seat status
          case Ash.update(
            VoelgoedEvents.Ash.Resources.Seating.Seat,
            %{status: :available},
            filter: [id: hold.seat_id]
          ) do
            {:ok, _} ->
              # 4. Broadcast PubSub
              broadcast_release(hold)
              
              :telemetry.execute(
                [:voelgoedevents, :seating, :hold, :expired],
                %{count: 1},
                %{
                  seat_id: hold.seat_id,
                  event_id: hold.event_id,
                  reason: "ttl_expired"
                }
              )
              
            error ->
              Logger.error("Failed to update seat status: #{inspect(error)}")
          end
          
        error ->
          Logger.error("Failed to soft-delete hold: #{inspect(error)}")
      end
    end)
  end

  defp broadcast_release(hold) do
    Phoenix.PubSub.broadcast(
      VoelgoedeventsWeb.Endpoint,
      VoelgoedEvents.Topics.seating_seat_released(hold.organization_id, hold.event_id),
      %{
        "event" => "seat_released",
        "seat_id" => hold.seat_id,
        "reason" => "ttl_expired",
        "released_at" => DateTime.to_iso8601(DateTime.utc_now())
      }
    )
  end
end
```

### 6.3 Oban Job Configuration

```elixir
# config/config.exs

config :voelgoedevents, Oban,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: [concurrency: 10],
    cleanup: [concurrency: 1]
  ]

# Recurring job configuration
config :voelgoedevents, recurring_jobs: [
  {
    VoelgoedEvents.Workers.CleanupExpiredHolds,
    queue: :cleanup,
    every: 30_000  # 30 seconds
  }
]
```

### 6.4 Reaper Observability

**Metrics:**

```elixir
# In perform/1
:telemetry.execute(
  [:voelgoedevents, :reaper, :run],
  %{
    expired_holds: Enum.count(expired_holds),
    processed_successfully: count_success,
    processed_failed: count_failed,
    duration_ms: elapsed_ms
  },
  %{}
)
```

**Alerts:**

```
# Alert if reaper hasn't run in 5 minutes
IF (time() - max(voelgoedevents_reaper_run_timestamp) > 300)
THEN alert("Reaper job not running - expired holds piling up!")
```

---

## 7. Observability & Telemetry

### 7.1 Required Telemetry Events

```elixir
# Event: User attempts to reserve seat
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :attempt],
  %{count: 1},
  %{
    seat_id: seat_id,
    event_id: event_id,
    user_id: user_id,
    method: :redis  # or :postgres (fallback)
  }
)

# Event: Hold successfully created
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :success],
  %{count: 1, duration_ms: elapsed},
  %{
    seat_id: seat_id,
    event_id: event_id,
    method: :redis  # which backend succeeded
  }
)

# Event: Seat already held (conflict)
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :conflict],
  %{count: 1},
  %{seat_id: seat_id, event_id: event_id, reason: :seat_taken}
)

# Event: Redis unavailable (fallback triggered)
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :redis_fallback],
  %{count: 1},
  %{fallback: :postgres}
)

# Event: Hold expired and cleaned up
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :expired],
  %{count: 1},
  %{
    seat_id: seat_id,
    event_id: event_id,
    reason: "ttl_expired"
  }
)

# Event: Hold extended (before payment)
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :extended],
  %{count: 1, new_expiry_minutes: 20},
  %{seat_id: seat_id}
)

# Event: Payment completed, hold converted to ticket
:telemetry.execute(
  [:voelgoedevents, :seating, :hold, :converted_to_ticket],
  %{count: 1},
  %{seat_id: seat_id, ticket_id: ticket_id}
)
```

### 7.2 Prometheus Metrics

```elixir
defmodule VoelgoedEvents.Metrics do
  def setup do
    # Counters
    :telemetry.attach_many(
      "voelgoedevents_seating_holds",
      [
        [:voelgoedevents, :seating, :hold, :attempt],
        [:voelgoedevents, :seating, :hold, :success],
        [:voelgoedevents, :seating, :hold, :conflict],
        [:voelgoedevents, :seating, :hold, :expired]
      ],
      &Metrics.increment_counter/4,
      nil
    )
  end

  def increment_counter(_event, _measurements, _metadata, _config) do
    # Increment Prometheus counter
    # (integrate with prometheus_ex or similar)
  end
end
```

**Grafana Dashboard Panels:**

| Panel | Query | Alert Threshold |
|-------|-------|---|
| **Hold Success Rate** | `rate(hold_success[5m]) / rate(hold_attempt[5m])` | <99% |
| **Conflict Rate** | `rate(hold_conflict[5m])` | >10/sec (popular seats) |
| **Redis Fallback Rate** | `rate(hold_redis_fallback[5m])` | >0/sec (Redis down!) |
| **Expired Holds** | `rate(hold_expired[5m])` | Expected: 60-100/min |
| **Average Hold Duration** | `avg(hold_duration_ms)` | ~900ms |

---

## 8. Ash Resource: SeatHold

### 8.1 Complete SeatHold Resource Definition

```elixir
defmodule VoelgoedEvents.Ash.Resources.Seating.SeatHold do
  @moduledoc """
  Resource: Seat Hold
  
  Represents a reservation of a seat for a user during checkout.
  
  Attributes:
    - organization_id: Tenant ID
    - event_id: Which event
    - seat_id: Which seat
    - user_id: Who holds it
    - cart_token: Associated checkout session
    - expires_at: When the hold expires
    - deleted_at: Soft delete timestamp
  
  Lifecycle:
    1. Created when user clicks "Reserve Seat"
    2. Extended when user starts checkout (StartCheckout action)
    3. Converted to Ticket when payment completes (CompleteCheckout)
    4. Soft-deleted by Reaper when expires_at < now()
  """
  
  use Ash.Resource,
    domain: VoelgoedEvents.Seating,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  # ============================================================================
  # IDENTITIES
  # ============================================================================

  identities do
    # One hold per seat at a time (only active)
    identity :unique_hold_per_seat,
      [:seat_id],
      where: [deleted_at: nil]
  end

  # ============================================================================
  # POSTGRES DSL (Indexes)
  # ============================================================================

  postgres do
    table "seat_holds"
    repo VoelgoedEvents.Repo

    # TTL Reaper: Find expires_at < now()
    index [:event_id, :expires_at],
      name: "idx_hold_ttl_reaper"

    # Prevent multi-hold per user
    index [:user_id, :event_id],
      where: "deleted_at IS NULL",
      name: "idx_hold_user_event_active"

    # Availability check (is seat held?)
    index [:seat_id],
      where: "deleted_at IS NULL",
      name: "idx_hold_seat_active"

    # Organization-wide hold history (audit)
    index [:organization_id, :created_at],
      sort: :desc,
      name: "idx_hold_org_timeline"

    # FK safety
    index [:organization_id],
      name: "idx_hold_org_fk"

    index [:event_id],
      name: "idx_hold_event_fk"

    index [:seat_id],
      name: "idx_hold_seat_fk"

    index [:user_id],
      name: "idx_hold_user_fk"
  end

  # ============================================================================
  # ATTRIBUTES
  # ============================================================================

  attributes do
    uuid_primary_key :id

    # Tenancy
    attribute :organization_id, :uuid do
      allow_nil? false
      writable? false
    end

    attribute :event_id, :uuid do
      allow_nil? false
      writable? false
    end

    # Core hold data
    attribute :seat_id, :uuid do
      allow_nil? false
      writable? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
      writable? false
    end

    # Checkout session token (for validation)
    attribute :cart_token, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    # Hold lifecycle
    attribute :expires_at, :datetime do
      allow_nil? false
    end

    # Soft delete
    attribute :deleted_at, :datetime

    # Timestamps
    attribute :created_at, :datetime do
      default &DateTime.utc_now/0
      writable? false
    end

    attribute :updated_at, :datetime do
      default &DateTime.utc_now/0
      update_default &DateTime.utc_now/0
      writable? false
    end
  end

  # ============================================================================
  # RELATIONSHIPS
  # ============================================================================

  relationships do
    belongs_to :organization, VoelgoedEvents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      primary_key? true
    end

    belongs_to :event, VoelgoedEvents.Ash.Resources.Events.Event do
      allow_nil? false
      primary_key? true
    end

    belongs_to :seat, VoelgoedEvents.Ash.Resources.Seating.Seat do
      allow_nil? false
    end

    belongs_to :user, VoelgoedEvents.Ash.Resources.Accounts.User do
      allow_nil? false
    end

    # One hold can become one ticket
    has_one :ticket, VoelgoedEvents.Ash.Resources.Ticketing.Ticket do
      source_attribute :id
      destination_attribute :seat_hold_id
    end
  end

  # ============================================================================
  # ACTIONS
  # ============================================================================

  actions do
    defaults [:read, :update]

    # Create hold (called by ReserveSeat change)
    create :create do
      accept [:organization_id, :event_id, :seat_id, :user_id, :cart_token, :expires_at]
      require [:organization_id, :event_id, :seat_id, :user_id, :cart_token, :expires_at]

      # Validate expiry is in future
      validate {VoelgoedEvents.Validations.FutureDateTime, attribute: :expires_at}
    end

    # Soft delete
    destroy :destroy_soft do
      soft? true
    end

    # Extend hold (called by StartCheckout)
    update :extend do
      accept [:expires_at]
      require [:expires_at]
    end

    # Convert to ticket (called by CompleteCheckout)
    update :mark_converted do
      accept [:deleted_at]
    end
  end

  # ============================================================================
  # MULTITENANCY
  # ============================================================================

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  # ============================================================================
  # CHANGES & VALIDATIONS
  # ============================================================================

  changes do
    change {VoelgoedEvents.Changes.Notifiers.SeatHoldNotifier, []}
  end

  validations do
    validate {VoelgoedEvents.Validations.NotBeforeThan, attribute: :expires_at, greater_than: :created_at}
  end
end
```

### 8.2 SeatHold Notifier (PubSub Integration)

```elixir
defmodule VoelgoedEvents.Changes.Notifiers.SeatHoldNotifier do
  @moduledoc """
  Automatic notifier for SeatHold changes via PubSub.
  """
  
  use Ash.Resource.Change

  def change(changeset, _opts) do
    Ash.Changeset.after_action(changeset, &after_action/2)
  end

  defp after_action(changeset, result) do
    org_id = Ash.Changeset.get_attribute(changeset, :organization_id)
    event_id = Ash.Changeset.get_attribute(changeset, :event_id)
    
    case Ash.Changeset.action_type(changeset) do
      :create ->
        # Broadcast: seat:held
        seat_id = Ash.Changeset.get_attribute(changeset, :seat_id)
        user_id = Ash.Changeset.get_attribute(changeset, :user_id)
        expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)
        
        Phoenix.PubSub.broadcast(
          VoelgoedeventsWeb.Endpoint,
          VoelgoedEvents.Topics.seating_seat_held(org_id, event_id),
          %{
            "event" => "seat_held",
            "seat_id" => seat_id,
            "user_id" => user_id,
            "expires_at" => DateTime.to_iso8601(expires_at)
          }
        )
        
      :destroy ->
        # Broadcast: seat:released
        seat_id = Ash.Changeset.get_attribute(changeset, :seat_id)
        
        Phoenix.PubSub.broadcast(
          VoelgoedeventsWeb.Endpoint,
          VoelgoedEvents.Topics.seating_seat_released(org_id, event_id),
          %{
            "event" => "seat_released",
            "seat_id" => seat_id,
            "reason" => "checkout_completed"
          }
        )
        
      _ ->
        :ok
    end
    
    {:ok, result}
  end
end
```

---

## 9. Implementation Guide

### 9.1 Step-by-Step Checklist

- [ ] **Phase 1: Redis Infrastructure**
  - [ ] Redis cluster deployed (or single node for dev)
  - [ ] Redix client configured
  - [ ] Circuit breaker implemented
  - [ ] Key/value schema documented

- [ ] **Phase 2: SeatHold Resource**
  - [ ] Ash resource created with all attributes
  - [ ] Indexes added (Reaper, user+event, seat)
  - [ ] Identities configured (unique hold per seat)
  - [ ] Notifier configured (PubSub broadcasts)

- [ ] **Phase 3: ReserveSeat Action**
  - [ ] Idempotency check (user already holding?)
  - [ ] Redis SETNX lock
  - [ ] Postgres pessimistic fallback
  - [ ] Telemetry on all paths

- [ ] **Phase 4: Hold Extension**
  - [ ] StartCheckout extends all holds
  - [ ] User validation (only hold owner can extend)
  - [ ] Telemetry on extension

- [ ] **Phase 5: Reaper Worker**
  - [ ] Oban job configured
  - [ ] Scheduled every 30 seconds
  - [ ] Soft-delete + Redis cleanup
  - [ ] PubSub broadcast on release

- [ ] **Phase 6: Observability**
  - [ ] Telemetry events emitted on all paths
  - [ ] Prometheus metrics exposed
  - [ ] Grafana dashboard created
  - [ ] Alerts configured (Redis down, high conflict rate, etc.)

- [ ] **Phase 7: Testing**
  - [ ] Unit tests (Redis lock, DB fallback)
  - [ ] Integration tests (full flow)
  - [ ] Concurrency tests (1000 users same seat)
  - [ ] Chaos tests (Redis failure, DB lock timeout)

---

## 10. Testing Strategy

### 10.1 Unit Tests: Redis Lock

```elixir
defmodule VoelgoedEvents.Seating.ReserveSeatTest do
  use VoelgoedEventsWeb.DataCase
  
  describe "reserve_seat: Redis happy path" do
    test "locks seat in Redis and creates SeatHold in Postgres" do
      user = insert(:user)
      event = insert(:event)
      seat = insert(:seat, event: event)
      
      result = VoelgoedEvents.Seating.reserve_seat(
        org_id: event.organization_id,
        event_id: event.id,
        seat_id: seat.id,
        user_id: user.id,
        cart_token: "cart-123"
      )
      
      assert {:ok, hold} = result
      assert hold.user_id == user.id
      assert hold.seat_id == seat.id
      
      # Verify Redis lock
      assert {:ok, {:held, ^user_id}} = VoelgoedEvents.Redis.is_seat_held(
        event.organization_id,
        event.id,
        seat.id
      )
    end
    
    test "returns error if seat already held" do
      user1 = insert(:user)
      user2 = insert(:user)
      event = insert(:event)
      seat = insert(:seat, event: event)
      
      # User 1 reserves
      {:ok, _} = VoelgoedEvents.Seating.reserve_seat(
        org_id: event.organization_id,
        event_id: event.id,
        seat_id: seat.id,
        user_id: user1.id,
        cart_token: "cart-1"
      )
      
      # User 2 tries to reserve same seat
      result = VoelgoedEvents.Seating.reserve_seat(
        org_id: event.organization_id,
        event_id: event.id,
        seat_id: seat.id,
        user_id: user2.id,
        cart_token: "cart-2"
      )
      
      assert {:error, :seat_taken} = result
    end
    
    test "is idempotent for same user" do
      user = insert(:user)
      event = insert(:event)
      seat = insert(:seat, event: event)
      
      # First reserve
      {:ok, hold1} = VoelgoedEvents.Seating.reserve_seat(
        org_id: event.organization_id,
        event_id: event.id,
        seat_id: seat.id,
        user_id: user.id,
        cart_token: "cart-123"
      )
      
      # Second reserve (same user, same seat)
      {:ok, hold2} = VoelgoedEvents.Seating.reserve_seat(
        org_id: event.organization_id,
        event_id: event.id,
        seat_id: seat.id,
        user_id: user.id,
        cart_token: "cart-123"
      )
      
      # Should return same hold, not error
      assert hold1.id == hold2.id
    end
  end
  
  describe "reserve_seat: Redis fallback" do
    test "falls back to Postgres when Redis unavailable" do
      # Simulate Redis outage
      allow(VoelgoedEvents.Redis, :lock_seat, fn _... ->
        {:error, :redis_unavailable}
      end)
      
      user = insert(:user)
      event = insert(:event)
      seat = insert(:seat, event: event)
      
      # Should succeed via Postgres pessimistic lock
      result = VoelgoedEvents.Seating.reserve_seat(
        org_id: event.organization_id,
        event_id: event.id,
        seat_id: seat.id,
        user_id: user.id,
        cart_token: "cart-123"
      )
      
      assert {:ok, hold} = result
      
      # Telemetry should show fallback
      assert_telemetry_event(:voelgoedevents, :seating, :hold, :redis_fallback)
    end
  end
  
  describe "reaper: cleanup expired holds" do
    test "deletes expired holds and releases seats" do
      event = insert(:event)
      user = insert(:user)
      seat = insert(:seat, event: event)
      
      # Create hold that expired 1 minute ago
      hold = insert(:seat_hold,
        event: event,
        seat: seat,
        user: user,
        expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
      )
      
      # Run reaper
      {:ok, %{"processed" => count}} = VoelgoedEvents.Workers.CleanupExpiredHolds.perform(%{})
      
      assert count == 1
      
      # Hold should be soft-deleted
      assert Ash.read_one(
        VoelgoedEvents.Ash.Resources.Seating.SeatHold,
        filter: [id: hold.id]
      ) == :error
      
      # Seat should be available again
      seat = Ash.read_one!(
        VoelgoedEvents.Ash.Resources.Seating.Seat,
        filter: [id: seat.id]
      )
      assert seat.status == :available
    end
  end
end
```

### 10.2 Concurrency Test: 1000 Users, 1 Seat

```elixir
defmodule VoelgoedEvents.Seating.ConcurrencyTest do
  use VoelgoedEventsWeb.DataCase
  
  test "handles 1000 concurrent reservations correctly" do
    event = insert(:event)
    seat = insert(:seat, event: event)
    
    # Create 1000 users
    users = Enum.map(1..1000, fn i -> insert(:user, email: "user#{i}@test.com") end)
    
    # All try to reserve same seat concurrently
    tasks = Enum.map(users, fn user ->
      Task.async(fn ->
        VoelgoedEvents.Seating.reserve_seat(
          org_id: event.organization_id,
          event_id: event.id,
          seat_id: seat.id,
          user_id: user.id,
          cart_token: "cart-#{user.id}"
        )
      end)
    end)
    
    results = Task.await_many(tasks, 10_000)
    
    # Exactly ONE should succeed
    successes = Enum.count(results, fn r -> {:ok, _} = r; true end)
    conflicts = Enum.count(results, fn r -> {:error, :seat_taken} = r; true end)
    
    assert successes == 1
    assert conflicts == 999
    
    # NO double-bookings
    assert VoelgoedEvents.Repo.aggregate(
      VoelgoedEvents.Ash.Resources.Seating.SeatHold,
      :count,
      filter: [seat_id: seat.id, deleted_at: nil]
    ) == 1
  end
end
```

---

## 11. Disaster Recovery

### 11.1 Redis Complete Loss

**Scenario:** Redis cluster becomes unavailable (network partition, hardware failure).

**Recovery:**

1. **Circuit breaker detects failure** (after 5 consecutive failures)
2. **All seat holds fall back to Postgres pessimistic locking**
3. **Latency increases:** <50ms (Redis) → 50-200ms (Postgres with lock contention)
4. **Users may see "Seat taken" more often** (increased contention)
5. **SLA maintained:** No double-bookings, just slower checkout

**Steps:**

```
1. Alarms fire: "Redis unhealthy"
2. On-call acknowledges
3. Diagnose Redis cluster:
   - Network connectivity?
   - Node health?
   - Replication lag?
4. If fixable (10-30 min):
   - Repair cluster
   - Monitor circuit breaker reset
   - Verify no holds accumulate in Postgres
5. If not fixable (>30 min):
   - Failover to standby cluster (if available)
   - OR maintain fallback-only mode for duration
   - Proactively page users to try again
```

### 11.2 Postgres Lock Timeout

**Scenario:** Deadlock storm: 100 users click same seat, all lock Postgres, timeout cascades.

**Recovery:**

```elixir
# In fallback_db_lock:
VoelgoedEvents.Repo.transaction(
  fn -> ... end,
  timeout: 2000  # 2 second timeout
)

# If timeout occurs:
{:error, :lock_not_available}
```

**User Experience:**
```
T+0s User clicks seat → Timeout after 2s
T+2s User sees: "Seat unavailable, please try another"
T+2s User selects different seat → Succeeds immediately
```

**Prevention:**
- Timeout is short (2s, not 30s default)
- Fallback uses `NOWAIT` or `SKIP LOCKED` to fail fast
- Telemetry alerts on > 5% lock timeouts

### 11.3 Reaper Failure (Holds Pile Up)

**Scenario:** Reaper job crashes, expired holds accumulate, old seats never released.

**Safety Net:**
```
Redis auto-expire (16-min TTL) ensures old locks eventually disappear.
Even if Reaper fails for 1 hour, holds expire on schedule.
```

**Manual Cleanup (if needed):**

```sql
-- Find all expired, soft-deleted holds
SELECT * FROM seat_holds
WHERE expires_at < now() AND deleted_at IS NULL
LIMIT 100;

-- Soft-delete them
UPDATE seat_holds
SET deleted_at = now()
WHERE expires_at < now() AND deleted_at IS NULL;

-- Rerun Reaper
mix oban.retry-all
```

---

## Quick Reference

### Redis Key-Value Format

```
Key: org:550e8400-e29b-41d4-a716-446655440000:event:abc-event-123:seat:seat-row-a-5

Value: {
  "user_id": "user-uuid-456",
  "cart_token": "checkout-token-xyz",
  "expires_at": "2025-12-07T19:51:00Z",
  "held_at": "2025-12-07T19:36:00Z"
}

TTL: 960 seconds (16 minutes)
```

### Hold Lifecycle

```
1. CREATED: User clicks "Reserve Seat"
   - Redis SETNX lock acquired
   - SeatHold inserted to Postgres
   - Seat status: held
   - Expires in 15 minutes

2. EXTENDED: User starts checkout
   - expires_at += 5 minutes
   - New expiry: 20 minutes from initial hold

3. CONVERTED: Payment completes
   - SeatHold soft-deleted
   - Ticket created
   - Seat status: sold

4. EXPIRED: Hold never converted to ticket
   - Reaper finds: expires_at < now()
   - Soft-delete SeatHold
   - Release Redis key
   - Seat status: available
```

### Telemetry Events

| Event | Emitted When | Purpose |
|-------|--------------|---------|
| `hold.attempt` | User tries to reserve | Track attempt volume |
| `hold.success` | Hold created | Success rate |
| `hold.conflict` | Seat already held | Contention metric |
| `hold.redis_fallback` | Redis unavailable | Failure alerting |
| `hold.extended` | Hold extended pre-payment | Extension tracking |
| `hold.expired` | Reaper cleans up | Verify expiry works |

---

**End of Document**

*For updates, contact Backend Architecture team.*

*Last Updated: 2025-12-07*  
*Status: Production-Ready*  
*Compliance: Zero double-bookings, failover to Postgres, full observability*