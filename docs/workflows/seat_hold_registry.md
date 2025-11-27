# Seat Hold Registry

**Authoritative runtime system for tracking all active seat holds across cache layers to prevent overselling during high-concurrency load**

---

## 1. Purpose & Overview

**Seat Hold Registry** is the **runtime state management system** (not a user-facing workflow) that maintains and synchronizes seat holds across three storage layers: ETS (hot), Redis (warm), and PostgreSQL (cold). This document specifies data models, key formats, consistency contracts, and operational procedures for the registry.

**Why it matters:**

- **Prevents overselling:** Duplicate hold detection across concurrent requests
- **Scales horizontally:** No table-level locks, uses optimistic concurrency
- **Enables fast lookups:** < 1ms with ETS, < 10ms with Redis
- **Supports distributed systems:** Cluster-wide consistency via Redis replication
- **Provides observability:** Occupancy aggregation for dashboards + analytics
- **Maintains audit trail:** All state changes durable in PostgreSQL (compliance)

---

## 2. Registry Architecture: Three-Tier Storage Model

The registry coordinates three persistent storage layers, each optimized for different access patterns:

### Layer 1: ETS (Hot Cache, Per-Node)

**Purpose:** Ultra-fast duplicate detection on current Elixir node (< 1ms)

**Table Name:** `:seat_holds_hot`

**Key Structure:**
```elixir
{org_id :: UUID, seat_id :: UUID}
```
- **org_id:** Organization UUID (tenant isolation)
- **seat_id:** Seat UUID (specific seat)
- Keying by both ensures: Org1's Seat-A ≠ Org2's Seat-A

**Value Structure:**
```elixir
%{
  hold_id: UUID,              # Links to SeatHold record
  user_id: UUID,              # Who is holding
  seat_id: UUID,              # Redundant for safety
  event_id: UUID,             # Event being held for
  held_until: DateTime,       # Expiry time (when hold dies)
  status: :active | :expired, # Current state
  timestamp: DateTime,        # When inserted into cache
  source: :web | :scanner     # Origin of hold
}
```

**Indexing & Operations:**
- Primary lookup: `{org_id, seat_id}` → O(1) hash table
- Scan: All holds for org (admin dashboard) → O(n)
- Operations:
  ```elixir
  # Fast lookup
  :ets.lookup(:seat_holds_hot, {org_id, seat_id})
  
  # Insert after successful hold creation
  :ets.insert(:seat_holds_hot, {{org_id, seat_id}, %{...}})
  
  # Delete when hold expires or converts
  :ets.delete(:seat_holds_hot, {org_id, seat_id})
  
  # Scan all holds for org
  :ets.tab2list(:seat_holds_hot)
  |> Enum.filter(fn {{o, _}, _} -> o == org_id end)
  ```

**TTL Management:**
- No built-in TTL in ETS
- Cleanup via `WorkerCleanupHolds` Oban job (runs every minute)
- Job scans ETS, deletes expired entries

**Performance Characteristics:**
- Lookup: O(1), < 1ms
- Insert: O(1), < 1ms
- Delete: O(1), < 1ms
- Memory: ~500 bytes per hold (typical)

---

### Layer 2: Redis (Warm Cache, Cluster-Wide)

**Purpose:** Cross-node consistency, distributed duplicate detection, expiry tracking

**Namespace:** `voelgoed:org:{org_id}:*` (all keys org-scoped for multi-tenancy)

**Three Redis data structures (coordinated):**

#### 2a. ZSET: Holds Sorted by Expiry (For Cleanup Scans)

**Key:** `voelgoed:org:{org_id}:event:{event_id}:seat_holds`

**Purpose:** Enable efficient `ZRANGEBYSCORE` to find all holds expiring before time T (used by cleanup job)

**Score:** Unix timestamp of `held_until`

**Member:** `{seat_id}:{hold_id}:{user_id}:{held_until_iso}`

**Example:**
```
Key: voelgoed:org:abc123:event:def456:seat_holds
ZSET Members (sorted by expiry timestamp):
  Score: 1732620300  Member: "seat-001:hold-001:user-001:2025-11-26T14:05:00Z"
  Score: 1732620360  Member: "seat-002:hold-002:user-002:2025-11-26T14:06:00Z"
  Score: 1732620420  Member: "seat-003:hold-003:user-001:2025-11-26T14:07:00Z"
```

**Operations:**
```elixir
# Add new hold to ZSET
def redis_add_hold_to_zset(org_id, event_id, hold) do
  key = "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"
  score = DateTime.to_unix(hold.held_until)
  member = "#{hold.seat_id}:#{hold.id}:#{hold.user_id}:#{DateTime.to_iso8601(hold.held_until)}"
  Redix.command!(:redis, ["ZADD", key, score, member])
end

# Find holds expiring within next N seconds (for cleanup job)
def redis_find_expiring_soon(org_id, event_id, within_seconds) do
  key = "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"
  now_unix = DateTime.utc_now() |> DateTime.to_unix()
  cutoff_unix = DateTime.utc_now() |> DateTime.add(within_seconds, :second) |> DateTime.to_unix()
  
  {:ok, members} = Redix.command(:redis, ["ZRANGEBYSCORE", key, now_unix, cutoff_unix])
  members |> Enum.map(&parse_hold_member/1)
end

# Remove hold from ZSET
def redis_remove_from_zset(org_id, event_id, hold) do
  key = "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"
  member = "#{hold.seat_id}:#{hold.id}:#{hold.user_id}:#{DateTime.to_iso8601(hold.held_until)}"
  Redix.command!(:redis, ["ZREM", key, member])
end

# Count all holds for event
def redis_count_holds_zset(org_id, event_id) do
  key = "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"
  {:ok, count} = Redix.command(:redis, ["ZCARD", key])
  count
end
```

**TTL:** Relies on STRING key TTL (see below); ZSET members expire when corresponding STRING expires

---

#### 2b. STRING: Per-Seat Fast Lookup (For Duplicate Detection)

**Key:** `voelgoed:org:{org_id}:seat:{seat_id}:hold`

**Purpose:** O(1) answer to "Is this seat currently held?" without ZSET scan

**Value Format:** `{hold_id}:{user_id}:{unix_timestamp}`

**Example:**
```
Key: voelgoed:org:abc123:seat:seat-001:hold
Value: "hold-001:user-001:1732620300"
TTL: 300 seconds (5 minutes) — auto-expire by Redis
```

**Operations:**
```elixir
# Check if seat held
def redis_is_seat_held?(org_id, seat_id) do
  key = "voelgoed:org:#{org_id}:seat:#{seat_id}:hold"
  case Redix.command!(:redis, ["GET", key]) do
    nil -> 
      false
    data ->
      [_, _, unix_ts_str] = String.split(data, ":")
      unix_ts = String.to_integer(unix_ts_str)
      expiry = DateTime.from_unix!(unix_ts)
      DateTime.compare(expiry, DateTime.utc_now()) == :gt
  end
end

# Set hold with auto-expiry
def redis_set_seat_hold(org_id, hold) do
  key = "voelgoed:org:#{org_id}:seat:#{hold.seat_id}:hold"
  value = "#{hold.id}:#{hold.user_id}:#{DateTime.to_unix(hold.held_until)}"
  Redix.command!(:redis, ["SET", key, value, "EX", "300"])
  # EX 300 = expires in 5 minutes automatically
end

# Delete hold
def redis_delete_seat_hold(org_id, seat_id) do
  key = "voelgoed:org:#{org_id}:seat:#{seat_id}:hold"
  Redix.command!(:redis, ["DEL", key])
end
```

**TTL:** 300 seconds (5 minutes), auto-expire by Redis

**Performance:** O(1), < 10ms network latency

---

#### 2c. HASH: Detailed Hold Metadata (Optional, For Analytics)

**Key:** `voelgoed:org:{org_id}:hold:{hold_id}:meta`

**Purpose:** Store additional hold details without querying database (e.g., for admin dashboard)

**Fields:**
```
HSET voelgoed:org:abc123:hold:hold-001:meta
  seat_id "seat-001"
  user_id "user-001"
  event_id "event-001"
  held_until "2025-11-26T14:05:30Z"
  created_at "2025-11-26T14:00:30Z"
  source "web"
  status "active"
```

**Operations:**
```elixir
# Store hold metadata
def redis_store_hold_meta(org_id, hold) do
  key = "voelgoed:org:#{org_id}:hold:#{hold.id}:meta"
  Redix.command!(:redis, [
    "HSET", key,
    "seat_id", hold.seat_id,
    "user_id", hold.user_id,
    "event_id", hold.event_id,
    "held_until", DateTime.to_iso8601(hold.held_until),
    "created_at", DateTime.to_iso8601(hold.created_at),
    "source", hold.source,
    "status", "active"
  ])
  # TTL: 300 seconds
  Redix.command!(:redis, ["EXPIRE", key, "300"])
end

# Get hold metadata
def redis_get_hold_meta(org_id, hold_id) do
  key = "voelgoed:org:#{org_id}:hold:#{hold_id}:meta"
  {:ok, data} = Redix.command(:redis, ["HGETALL", key])
  data |> Enum.chunk_every(2) |> Enum.into(%{}, fn [k, v] -> {k, v} end)
end
```

**TTL:** 300 seconds (5 minutes), auto-expire

---

### Layer 3: PostgreSQL (Cold Cache, Authoritative)

**Purpose:** Durable storage, audit trail, analytics, recovery source

**Tables:**

```sql
-- SeatHold Table (persists all holds)
CREATE TABLE seat_holds (
  id UUID PRIMARY KEY,
  seat_id UUID NOT NULL REFERENCES seats(id),
  event_id UUID NOT NULL REFERENCES events(id),
  user_id UUID NOT NULL REFERENCES users(id),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  status ENUM ('active', 'converted', 'expired', 'cancelled') NOT NULL,
  held_until TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  expired_at TIMESTAMP,
  converted_at TIMESTAMP,
  source ENUM ('web', 'scanner', 'offline_sync') NOT NULL,
  notes TEXT,
  
  -- Prevent multiple active holds on same seat
  UNIQUE (seat_id, status) WHERE status = 'active'
);

-- Indexes for fast queries
CREATE INDEX idx_seat_holds_org_user ON seat_holds(organization_id, user_id, status);
CREATE INDEX idx_seat_holds_event_status ON seat_holds(event_id, status);
CREATE INDEX idx_seat_holds_expiry ON seat_holds(held_until) WHERE status = 'active';

-- Seat Table (denormalized for cache invalidation)
CREATE TABLE seats (
  id UUID PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  block_id UUID NOT NULL REFERENCES blocks(id),
  seat_number VARCHAR(10) NOT NULL,
  row_letter VARCHAR(5) NOT NULL,
  status ENUM ('available', 'held', 'sold', 'blocked') NOT NULL,
  held_until TIMESTAMP,
  locked_at TIMESTAMP,
  seat_hold_id UUID REFERENCES seat_holds(id),
  ticket_id UUID REFERENCES tickets(id),
  version INTEGER DEFAULT 1,  -- Optimistic lock
  
  UNIQUE (event_id, row_letter, seat_number)
);

CREATE INDEX idx_seats_event_status ON seats(event_id, status);
CREATE INDEX idx_seats_block_status ON seats(block_id, status);
```

**Query Patterns:**
```elixir
# Count holds by status
def db_count_holds_by_status(event_id, org_id) do
  Ash.read(SeatHold, filter: [
    event_id: event_id,
    organization_id: org_id,
    status: :active
  ])
end

# Find expired holds for cleanup
def db_find_expired_holds(org_id) do
  now = DateTime.utc_now()
  Ash.read(SeatHold, filter: [
    organization_id: org_id,
    status: :active,
    held_until: {:less_than, now}
  ])
end

# Update hold status
def db_update_hold_status(hold, new_status) do
  Ash.update(hold, :expire, %{
    "status" => new_status,
    "expired_at" => DateTime.utc_now()
  })
end
```

---

## 3. Consistency Rules & Synchronization

### Write Path (Creating a Hold)

**Workflow: `reserve_seat.md` → Registry → Databases**

```
Step 1: Validate in-memory state (ETS + Redis)
  └─ Check ETS for existing hold on this seat (per-node)
  └─ Check Redis for existing hold (cluster-wide)
  └─ If held by other user: return error immediately

Step 2: Write to PostgreSQL (authoritative)
  └─ INSERT SeatHold record (status = :active)
  └─ UPDATE Seat record (status = :held, version++)
  └─ Both atomic with optimistic lock on Seat.version
  └─ If version mismatch: entire transaction rolls back → retry

Step 3: Write to Redis (warm layer, replicated)
  └─ ZADD to ZSET: voelgoed:org:ORG:event:EVT:seat_holds
  └─ SET STRING: voelgoed:org:ORG:seat:SEAT:hold (EX 300)
  └─ HSET HASH: voelgoed:org:ORG:hold:HOLD:meta (EXPIRE 300)
  └─ All propagated to cluster nodes via replication

Step 4: Write to ETS (hot layer, per-node)
  └─ INSERT to :seat_holds_hot
  └─ Key: {org_id, seat_id}
  └─ Value: hold info
  └─ No TTL: cleanup job manages expiry

Result: Consistent state across all layers (best effort)
```

### Read Path (Checking if Seat Held)

**Fast → Warm → Cold fallback pattern:**

```
Attempt 1: ETS Hot Cache (this node)
  ├─ Lookup: :ets.lookup(:seat_holds_hot, {org_id, seat_id})
  ├─ Hit: Return hold info immediately (< 1ms)
  ├─ Miss: Continue to Step 2
  
Attempt 2: Redis Warm Cache (cluster)
  ├─ GET: voelgoed:org:ORG:seat:SEAT:hold
  ├─ Hit: Return hold info (< 10ms, includes network)
  ├─ Miss: Continue to Step 3
  
Attempt 3: PostgreSQL Cold Layer
  ├─ Query: SELECT * FROM seat_holds WHERE seat_id = ? AND status = 'active'
  ├─ Hit: Return hold info (10-50ms, full query)
  ├─ Miss: Seat is available
  ├─ Populate ETS + Redis for next request
```

**Cache Hit Rates (typical):**
- ETS: 60-80% (per-node, benefits single-user flow)
- Redis: 85-95% (cluster-wide, benefits cross-node requests)
- DB fallback: 5-15% (stale cache or partitions)

---

### Invalidation Rules (When Hold Expires or Converts)

**Trigger:** `WorkerCleanupHolds` Oban job OR `complete_checkout` workflow

```elixir
# Cleanup sequence (order matters for consistency):

# 1. DELETE from ETS immediately (fastest)
:ets.delete(:seat_holds_hot, {org_id, seat_id})

# 2. DELETE from Redis (cluster cleanup)
Redix.command!(:redis, ["DEL", "voelgoed:org:#{org_id}:seat:#{seat_id}:hold"])
Redix.command!(:redis, ["ZREM", "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds", member])
Redix.command!(:redis, ["DEL", "voelgoed:org:#{org_id}:hold:#{hold_id}:meta"])

# 3. UPDATE Postgres (write-through to authoritative source)
Ash.update(hold, :expire, %{
  "status" => new_status,
  "expired_at" => DateTime.utc_now()
})

# 4. INVALIDATE occupancy cache (forces recompute next request)
Redix.command!(:redis, ["DEL", "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"])

# 5. BROADCAST PubSub (notify subscribers)
Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, "occupancy:#{org_id}:#{event_id}", 
  %{event: :occupancy_changed, timestamp: DateTime.utc_now()})
```

**Consistency Guarantee:** If any step fails, transaction rolls back. No partial invalidation.

---

## 4. Occupancy Calculation & Caching

### Occupancy Snapshot Concept

An **occupancy snapshot** is a point-in-time aggregation of seat counts:
```elixir
%{
  available: 150,      # Seats not held or sold
  held: 45,            # Seats actively held (in carts)
  sold: 155,           # Seats purchased/tickets created
  blocked: 0,          # Seats disabled by admin
  total: 350,          # available + held + sold + blocked
  
  # Percentages
  percent_available: 42.9,
  percent_held: 12.9,
  percent_sold: 44.3
}
```

### Calculation Algorithm

**Source:** PostgreSQL (authoritative)

```elixir
def calculate_occupancy_snapshot(event_id, org_id) do
  # Read from database (source of truth)
  {:ok, seats} = Ash.read(Seat, filter: [
    event_id: event_id,
    organization_id: org_id
  ])
  
  # Aggregate by status
  available = Enum.count(seats, fn s -> s.status == :available end)
  held = Enum.count(seats, fn s -> s.status == :held end)
  sold = Enum.count(seats, fn s -> s.status == :sold end)
  blocked = Enum.count(seats, fn s -> s.status == :blocked end)
  
  total = available + held + sold + blocked
  
  %{
    available: available,
    held: held,
    sold: sold,
    blocked: blocked,
    total: total,
    percent_available: (available / total) * 100,
    percent_held: (held / total) * 100,
    percent_sold: (sold / total) * 100,
    timestamp: DateTime.utc_now()
  }
end
```

### Occupancy Cache (Redis, 10-Second TTL)

**Purpose:** Reduce database load from dashboard queries (can request every 1-2 seconds)

**Key:** `voelgoed:org:{org_id}:event:{event_id}:occupancy`

**Value:** JSON-encoded occupancy snapshot

**Cache Behavior:**
```elixir
def get_occupancy_cached(event_id, org_id) do
  cache_key = "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"
  
  case Redix.command!(:redis, ["GET", cache_key]) do
    nil ->
      # Cache miss: Calculate from database
      occupancy = calculate_occupancy_snapshot(event_id, org_id)
      
      # Populate cache (TTL: 10 seconds)
      Redix.command!(:redis, [
        "SET", cache_key,
        Jason.encode!(occupancy),
        "EX", "10"
      ])
      
      occupancy
    
    cached_json ->
      # Cache hit: Decode and return
      Jason.decode!(cached_json)
  end
end
```

**Invalidation:** When any hold created/expired/converted:
```elixir
# Occupancy cache is cleared, forcing recompute on next query
Redix.command!(:redis, ["DEL", "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"])
```

### Live Occupancy via OccupancySnapshot Resource

**Future:** `Voelgoedevents.Ash.Resources.Events.OccupancySnapshot` resource can:

- Store periodic snapshots (e.g., every minute for historical analysis)
- Enable occupancy trend queries (occupancy over time)
- Feed into `funnel_builder` analytics (hold rates at different capacities)

```elixir
# Example: Store occupancy every minute
%{
  event_id: event_id,
  organization_id: org_id,
  snapshot_at: DateTime.utc_now(),
  available_count: 150,
  held_count: 45,
  sold_count: 155,
  occupancy_percent: 55.7
}
|> Ash.create(OccupancySnapshot)
```

---

## 5. Concurrency & Race Conditions

### Problem: Two Concurrent Reserves on Same Seat

**Scenario:**
```
Time T0: User A clicks "Hold Seat X" (request A starts)
Time T0: User B clicks "Hold Seat X" (request B starts concurrently)

Both requests:
- Check ETS (miss — not yet cached)
- Check Redis (miss — not yet cached)
- Query Postgres (find Seat X, version = 1)
- Both compute: new_version = 2

Transaction for Request A:
  INSERT SeatHold_A
  UPDATE Seat SET version = 2 WHERE version = 1 ✓ WINS

Transaction for Request B:
  INSERT SeatHold_B
  UPDATE Seat SET version = 2 WHERE version = 1 ✗ FAILS (version already 2)
```

**Solution:** Optimistic lock + automatic retry

```elixir
def reserve_with_retry(seat_id, user_id, org_id, max_attempts \\ 3) do
  Enum.reduce_while(1..max_attempts, {:error, :max_retries}, fn attempt, _ ->
    case attempt_reserve(seat_id, user_id, org_id) do
      {:ok, hold} ->
        {:halt, {:ok, hold}}
      
      {:error, :optimistic_lock_failed} when attempt < max_attempts ->
        # Backoff: 10ms, 20ms, 40ms
        backoff_ms = 10 * (2 ** (attempt - 1))
        Process.sleep(backoff_ms)
        {:cont, {:error, :optimistic_lock_failed}}
      
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end)
end
```

### Problem: Hold Expires While Checkout Processing

**Scenario:**
```
Time T0: User holds Seat X (hold expires at T0+300s)
Time T0+299s: User proceeds to checkout
Time T0+301s: Cleanup job marks hold as :expired, releases seat
Time T0+302s: Checkout processes payment, tries to convert hold

Result: Checkout finds hold.status = :expired, rejects payment ✗
```

**Solution:** Check hold freshness in `complete_checkout` before payment

```elixir
def start_payment(checkout_id, user_id, org_id) do
  case Ash.get(Checkout, checkout_id, filter: [organization_id: org_id]) do
    {:ok, checkout} ->
      # Verify all holds still active
      {:ok, holds} = Ash.read(SeatHold, filter: [
        user_id: user_id,
        organization_id: org_id,
        status: :active
      ])
      
      now = DateTime.utc_now()
      all_fresh? = Enum.all?(holds, fn h -> DateTime.compare(h.held_until, now) == :gt end)
      
      if all_fresh? do
        # Proceed with payment
        {:ok, authorize_payment(checkout)}
      else
        {:error, :holds_expired, "One or more seats are no longer held"}
      end
  end
end
```

---

## 6. Integration with `WorkerCleanupHolds` Oban Job

### Cleanup Job Responsibilities

**Worker:** `Voelgoedevents.Queues.WorkerCleanupHolds`

**Trigger:** Scheduled for each hold at `held_until + 10 seconds` (buffer for clock skew)

**Job Payload:**
```elixir
%{
  "hold_id" => hold_id,
  "seat_id" => seat_id,
  "event_id" => event_id,
  "organization_id" => org_id,
  "user_id" => user_id
}
```

**Execution Logic:**

```elixir
def perform(%Job{args: args}) do
  hold_id = args["hold_id"]
  seat_id = args["seat_id"]
  event_id = args["event_id"]
  org_id = args["organization_id"]
  
  case Ash.get(SeatHold, hold_id, filter: [organization_id: org_id]) do
    {:ok, hold} ->
      # Step 1: Verify hold still active
      if hold.status != :active do
        Logger.info("Hold #{hold_id} already #{hold.status}, skipping cleanup")
        return :ok
      end
      
      # Step 2: Verify hold is actually expired
      now = DateTime.utc_now()
      if DateTime.compare(hold.held_until, now) == :gt do
        Logger.warn("Hold #{hold_id} not yet expired, rescheduling")
        # Reschedule for 10 seconds later
        return {:error, :hold_not_yet_expired}
      end
      
      # Step 3: Mark hold as expired (Ash action)
      {:ok, _} = Ash.update(hold, :expire, %{
        "status" => :expired,
        "expired_at" => DateTime.utc_now()
      })
      
      # Step 4: Revert seat to available (Ash action)
      Ash.update(Seat, seat_id, :release, filter: [organization_id: org_id])
      
      # Step 5: Clean caches
      :ets.delete(:seat_holds_hot, {org_id, seat_id})
      redis_delete_seat_hold(org_id, seat_id)
      redis_remove_from_zset(org_id, event_id, hold)
      
      # Step 6: Invalidate occupancy cache
      Redix.command!(:redis, ["DEL", "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"])
      
      # Step 7: Broadcast PubSub
      Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, "occupancy:#{org_id}:#{event_id}",
        %{event: :seat_released, seat_id: seat_id, timestamp: DateTime.utc_now()})
      
      # Step 8: Log audit entry
      Ash.create!(AuditLog, %{
        organization_id: org_id,
        action: :seat_hold_expired,
        entity_type: :SeatHold,
        entity_id: hold_id,
        changes: %{status: :expired},
        timestamp: DateTime.utc_now()
      })
      
      :ok
    
    {:error, _} ->
      Logger.warn("Hold #{hold_id} not found, cleanup may have already run")
      :ok
  end
end
```

**Idempotency:** Job is idempotent — can be run multiple times safely:
- Checks `hold.status` before operating
- If already expired: no-op
- Safe to retry on failure

**Max Attempts:** 3 with exponential backoff (10s, 20s, 40s)

**Queue:** `Oban.Worker, queue: :cleanup, priority: 100` (lower priority, non-blocking)

---

## 7. Multi-Tenancy Rules (Critical)

**Reference:** `docs/architecture/02_multi_tenancy.md`

### Isolation at Every Layer

**Rule 1: Session Extraction (Never from Request)**
```elixir
# ✅ CORRECT
org_id = conn.assigns[:organization_id]  # From session/JWT
user_id = conn.assigns[:user_id]

# ❌ WRONG
org_id = params["organization_id"]  # User can spoof different org
```

**Rule 2: Redis Key Namespacing (Mandatory)**
```
ALL keys MUST include org_id as first component:

✅ voelgoed:org:{org_id}:event:{event_id}:seat_holds
✅ voelgoed:org:{org_id}:seat:{seat_id}:hold
✅ voelgoed:org:{org_id}:hold:{hold_id}:meta
✅ voelgoed:org:{org_id}:event:{event_id}:occupancy

❌ voelgoed:event:{event_id}:seat_holds        (no org scoping!)
❌ voelgoed:seat:{seat_id}:hold               (cross-org collision!)
```

**Rule 3: ETS Key Structure**
```elixir
# ✅ CORRECT
Key: {org_id, seat_id}
# Prevents Org1's Seat-A from colliding with Org2's Seat-A

# ❌ WRONG
Key: seat_id  # Org1 and Org2 would share entries!
```

**Rule 4: Database Queries (All Include org_id)**
```elixir
# ✅ CORRECT
Ash.read(SeatHold, filter: [
  event_id: event_id,
  organization_id: org_id,  # ← ALWAYS required
  status: :active
])

# ❌ WRONG
Ash.read(SeatHold, filter: [
  event_id: event_id,
  status: :active
  # Missing org_id filter!
])
```

**Rule 5: Audit Logging (All Include org_id)**
```elixir
Ash.create!(AuditLog, %{
  organization_id: org_id,  # ← ALWAYS required
  user_id: user_id,
  action: :seat_held,
  entity_id: hold_id,
  timestamp: DateTime.utc_now()
})
```

---

## 8. Registry Maintenance & Monitoring

### Status Verification (Health Check)

```elixir
def registry_status(org_id, event_id) do
  # Count holds in each layer
  
  # ETS: Per-node (count org's holds on this node)
  ets_holds = :seat_holds_hot
    |> :ets.tab2list()
    |> Enum.filter(fn {{o, _}, _} -> o == org_id end)
    |> length()
  
  # Redis: Cluster-wide (count for event)
  {:ok, redis_holds} = Redix.command(:redis, ["ZCARD", "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"])
  
  # PostgreSQL: Authoritative (count active holds)
  {:ok, db_holds} = Ash.read(SeatHold, filter: [
    event_id: event_id,
    organization_id: org_id,
    status: :active
  ])
  db_count = length(db_holds)
  
  # Consistency check
  consistent = redis_holds == db_count
  
  %{
    ets_count: ets_holds,
    redis_count: redis_holds,
    db_count: db_count,
    consistent: consistent,
    status: if consistent, do: :ok, else: :stale,
    message: if consistent, do: "All layers in sync", else: "Consistency warning"
  }
end
```

### Emergency Reconciliation

**Use when:** Redis and Postgres counts diverge significantly

```elixir
def reconcile_registry(org_id, event_id) do
  Logger.warn("Starting registry reconciliation for org=#{org_id}, event=#{event_id}")
  
  # Step 1: Get source of truth from database
  {:ok, db_holds} = Ash.read(SeatHold, filter: [
    event_id: event_id,
    organization_id: org_id,
    status: :active
  ])
  
  # Step 2: Clear Redis for this event
  redis_key = "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"
  Redix.command!(:redis, ["DEL", redis_key])
  
  # Step 3: Clear per-seat Redis entries
  Enum.each(db_holds, fn hold ->
    redis_delete_seat_hold(org_id, hold.seat_id)
  end)
  
  # Step 4: Repopulate Redis from database
  Enum.each(db_holds, fn hold ->
    redis_add_hold_to_zset(org_id, event_id, hold)
    redis_set_seat_hold(org_id, hold)
    redis_store_hold_meta(org_id, hold)
  end)
  
  # Step 5: Clear ETS for this org (broader cleanup)
  :seat_holds_hot
    |> :ets.tab2list()
    |> Enum.filter(fn {{o, _}, _} -> o == org_id end)
    |> Enum.each(fn {key, _} -> :ets.delete(:seat_holds_hot, key) end)
  
  Logger.info("Registry reconciliation complete: #{length(db_holds)} holds restored")
  
  :ok
end
```

---

## 9. Observability & Troubleshooting

### Key Metrics to Track

```elixir
# Cache hit rate monitoring
:telemetry.attach(
  "seat-hold-cache-hits",
  [:ticketing, :seat_hold, :cache_lookup],
  fn event, measurements, metadata ->
    source = metadata[:source]  # :ets, :redis, or :db
    Logger.debug("Cache lookup: #{source}, hit: #{measurements[:hit]}")
  end,
  nil
)

# Emit metrics
def lookup_with_tracking(org_id, seat_id) do
  case :ets.lookup(:seat_holds_hot, {org_id, seat_id}) do
    [{_, hold}] ->
      :telemetry.execute([:ticketing, :seat_hold, :cache_lookup],
        %{duration: 1}, %{source: :ets, hit: true})
      {:hit, hold}
    
    [] ->
      :telemetry.execute([:ticketing, :seat_hold, :cache_lookup],
        %{duration: 10}, %{source: :redis, hit: false})
      # Continue to Redis...
  end
end
```

### Common Issues & Fixes

| Issue | Cause | Detection | Fix |
|-------|-------|-----------|-----|
| **Seat shows held but cache empty** | Redis down, TTL expired, manual DB insert | `registry_status()` shows db_count > redis_count | `reconcile_registry()` |
| **High DB load from occupancy queries** | Cache misses, frequent invalidation | Dashboard slow, CPU spike | Check cache TTL, increase to 30s if acceptable |
| **Duplicate holds detected** | Optimistic lock failed too many times | Alert on max retries exceeded | Check for hot spots (popular seats), increase backoff |
| **Hold persists after expiry** | Cleanup job failed or never ran | Manual check in DB, ETS | Check Oban job queue health, rerun manually |

---

## 10. Implementation Notes

### `SeatHoldChange` Support Module

**Location:** `lib/voelgoedevents/ash/support/changes/seat_hold_change.ex`

**Module:** `Voelgoedevents.Ash.Support.Changes.SeatHoldChange`

**Purpose:** Transactional wrapper coordinating SeatHold creation with cache population

**Responsibilities:**
1. Create SeatHold record via Ash action
2. Validate seat availability
3. Populate all three cache layers (ETS, Redis, PostgreSQL)
4. Schedule Oban cleanup job
5. Emit domain event
6. Log audit entry
7. Broadcast PubSub occupancy
8. Return unified response

**Interface Contract:**
```
Input:  event_id, seat_id, user_id, org_id, source
Output: {:ok, hold} | {:error, reason}
```

### `WorkerCleanupHolds` Oban Worker

**Location:** `lib/voelgoedevents/queues/worker_cleanup_holds.ex`

**Module:** `Voelgoedevents.Queues.WorkerCleanupHolds`

**Responsibilities:**
1. Verify hold still exists and not already expired
2. Mark hold as `:expired` via Ash
3. Revert seat to `:available` via Ash
4. Clean all cache layers
5. Invalidate occupancy cache
6. Broadcast PubSub
7. Log audit entry
8. Idempotent: Safe to run multiple times

---

## 11. Performance Characteristics

| Operation | Layer | Latency | Notes |
|-----------|-------|---------|-------|
| **Lookup (is seat held?)** | ETS | < 1ms | Hash table, per-node |
| **Lookup (is seat held?)** | Redis | < 10ms | Network I/O, cluster |
| **Lookup (is seat held?)** | PostgreSQL | 10-50ms | Index scan, full query |
| **Insert hold** | All 3 | < 100ms | Write-through, atomic |
| **Delete hold** | ETS | < 1ms | Local deletion |
| **Delete hold** | Redis | 5-20ms | Network command |
| **Count holds** | Redis ZSET | O(n), slow | Avoid in hot path |
| **Count holds** | PostgreSQL | O(log n), fast | Indexed count |
| **Occupancy calc** | PostgreSQL | 50-200ms | Scans all seats |
| **Occupancy cache hit** | Redis | < 10ms | JSON decode only |

### Scaling Rules

- **Per-node ETS:** ~10k holds before memory pressure
- **Redis cluster:** ~1M holds across all events
- **Concurrent reserves/sec:** 1000+ with optimistic lock retries
- **Max event capacity:** 100k seats (occupancy snapshot 50-200ms acceptable)

---

## 12. Future Enhancements

- **Bloom Filters:** O(1) existence check (probabilistic, false positives acceptable for holds)
- **Distributed TTL:** Oban ZSET scan instead of per-hold jobs (more efficient at scale)
- **Write-Ahead Log:** Durability guarantee before caching (higher latency trade-off)
- **Multi-DC Replication:** Cross-region Redis sync (geo-distributed systems)
- **Adaptive TTL:** Vary hold duration by occupancy pressure (flash-sale logic)
- **Registry Compaction:** Periodic cleanup to reduce Redis memory footprint

---

**END OF SEAT HOLD REGISTRY**