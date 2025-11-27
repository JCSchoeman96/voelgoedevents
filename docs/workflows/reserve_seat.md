# Workflow: Reserve Seat

**Create a short-term hold on a specific seat during selection phase (5-minute TTL window)**

---

## 1. Workflow Purpose & Context

**Reserve Seat** creates an exclusive, time-limited lock on a seat during the customer selection phase. A seat hold prevents double-booking while a customer decides quantity/payment method, provides UX confidence ("Your seat is reserved"), and expires automatically after 5 minutes if not converted to a ticket purchase.

**Why it's essential:**
- Prevents overselling (two customers can't buy the same seat simultaneously)
- Avoids pessimistic database locks (no table-level locks, scales horizontally)
- Bridges gap between "customer viewing seats" and "customer paying" (asynchronous workflow)
- Enables dashboard/LiveView real-time occupancy updates via PubSub
- Establishes audit trail for seat ownership history and dispute resolution

---

## 2. Actors & Systems

### End-User/Client
- **Svelte PWA browser** — User selects seat, clicks "Hold This Seat"
- Submits: `POST /api/events/{event_id}/seats/{seat_id}/reserve`
- Expects: HTTP 201 with hold confirmation + countdown timer (5:00 → 4:59 → ...)

### VoelgoedEvents Backend (Coordinating Systems)

#### Ash Domains
- **Accounts Domain** — Validates user authentication + organization membership
- **Events Domain** — Verifies event state (`:published` or `:live`)
- **Seating Domain** — Manages Seat state machine + SeatHold records
- **Ticketing Domain** — (Optional) Links holds to pricing/checkout context

#### Request/Response
- **Phoenix Controller** (`VoelgoedeventsWeb.Seats.ReserveController`) — Pure I/O, delegates to Ash actions
- **LiveView** (optional) — Real-time occupancy bar (connected subscribers)

#### State Storage Layers
- **PostgreSQL (Cold)** — Durable SeatHold records, audit trail, source of truth
- **Redis (Warm)** — Cluster-wide hold registry with TTL tracking (5-min auto-expire)
- **ETS (Hot)** — Optional per-node in-memory cache (< 1ms lookup, auto-evict)

#### Background Jobs
- **Oban Worker** (`Voelgoedevents.Queues.WorkerCleanupHolds`) — Scheduled for +5 min, auto-releases expired holds

#### Real-Time Notification
- **PubSub** — Broadcasts occupancy changes for LiveView dashboards + analytics

### External Systems
- **Stripe/PayPal** — Not involved in this workflow (payment deferred to `complete_checkout`)

---

## 3. Data Flow Diagram

```
┌─ Browser (Svelte) ────────────────────────┐
│  User clicks "Hold Seat"                  │
│  Sends: event_id, seat_id                 │
└──────────────────┬────────────────────────┘
                   │ POST /api/events/{event_id}/seats/{seat_id}/reserve
                   ↓
┌─ Phoenix Controller ──────────────────────────┐
│  Extract: event_id, seat_id from params      │
│  From session: user_id, organization_id      │
│  Validate: UUIDs, not empty                  │
└──────────────────┬────────────────────────────┘
                   │
                   ↓ Ash gets
┌─ Events Domain (Event) ────────────────────┐
│  Verify: event exists, status = published  │
│  Verify: belongs to org_id                 │
└──────────────────┬────────────────────────────┘
                   │
                   ↓ Ash gets
┌─ Seating Domain (Seat) ────────────────────┐
│  Verify: seat exists, status = available   │
│  Verify: belongs to event + org_id         │
│  Extract: block_id, capacity constraints   │
└──────────────────┬────────────────────────────┘
                   │
        ┌──────────┴─────────────┐
        ↓ ETS (fast check)       ↓ Redis (cluster consistency)
   ┌─ ETS ───┐            ┌─ Redis ──┐
   │ Already │            │ Check    │
   │ held?   │            │ cluster  │
   └─────────┘            │ holds    │
        │                 └──────────┘
        └──────────┬─────────────┘
                   ↓ Optimistic lock check
        ┌──────────────────────────┐
        │ Fetch seat version (DB)  │
        │ Prepare lock: WHERE v=X  │
        └──────────┬───────────────┘
                   ↓ Transaction
        ┌──────────────────────────────────┐
        │ 1. INSERT SeatHold (status=active) │
        │ 2. UPDATE Seat (status=held)      │
        │    WHERE version = expected       │
        └──────────┬───────────────────────┘
                   │
        ┌──────────┴──────────┬────────────┐
        ↓                     ↓            ↓
   ┌─ ETS ─┐        ┌─ Redis ─┐      ┌─ Oban ──┐
   │Insert │        │ZADD+SET │      │Schedule  │
   │entry  │        │with TTL │      │+5 min    │
   └────────┘       │& expire │      │cleanup   │
        │           └─────────┘      └──────────┘
        │                 │                │
        └─────────────────┼────────────────┘
                          ↓ PubSub + Audit Log
                 ┌──────────────────────┐
                 │ Broadcast occupancy  │
                 │ Log audit entry      │
                 │ (async, non-block)   │
                 └────────┬─────────────┘
                          ↓ HTTP 201
                 ┌──────────────────────┐
                 │ Response JSON:       │
                 │ - hold_id            │
                 │ - expires_in_seconds │
                 │ - seat details       │
                 └──────────────────────┘
                          │
                          ↓ Browser
                 ┌──────────────────────┐
                 │ Display hold confirm │
                 │ Start 5-min countdown│
                 │ "Hold expires in..." │
                 │ → Proceed to Checkout│
                 └──────────────────────┘
```

---

## 4. Preconditions (Must Be True Before Starting)

### Authentication & Tenancy
- ✅ User must be authenticated (session contains `user_id`)
- ✅ User must belong to an organization (session contains `organization_id`)
- ✅ User must have permission to reserve in this org (role/policy check)
- ✅ No cross-tenant data leakage (all queries scoped to `organization_id`)

### Event Requirements
- ✅ Event must exist in `Voelgoedevents.Ash.Resources.Events.Event`
- ✅ Event must be in `:published` or `:live` state (not draft/archived/cancelled)
- ✅ Event must be owned by user's organization
- ✅ Event sale window must be open (now within sale_start ≤ now ≤ sale_end)

### Seat Requirements
- ✅ Seat must exist in `Voelgoedevents.Ash.Resources.Seating.Seat`
- ✅ Seat must belong to the event
- ✅ Seat must belong to user's organization (via event)
- ✅ Seat must be in `:available` status (not held/sold/blocked)

### Seating Layout Requirements
- ✅ Seating layout must be configured for event (block capacity rules exist)
- ✅ Block capacity must have remaining seats (held_count + sold_count < block.capacity)
- ✅ No existing active hold by another user for this seat
- ✅ Redis cluster healthy (graceful fallback to ETS + DB if degraded)

### External System Requirements
- ✅ At least one store is available (Postgres mandatory, Redis/ETS optional)
- ✅ Network connectivity to all backends (DB, Redis, optional ETS)
- ✅ Oban job queue accepting new jobs (for TTL cleanup scheduling)

---

## 5. Postconditions (What Is True After Success)

### Persistent State (PostgreSQL)
✅ **SeatHold record created** with:
   - `id` (UUID, newly generated)
   - `seat_id, event_id, organization_id`
   - `user_id` (who made the reservation)
   - `status: :active`
   - `held_until: now() + 5 minutes`
   - `source: :web` (or `:scanner` for scanning devices)
   - `created_at, updated_at` timestamps
   - Indexed for quick "is seat held?" lookups

✅ **Seat record updated** with:
   - `status: :held` (was `:available`)
   - `held_until: now() + 5 minutes` (denormalized for cache invalidation)
   - `locked_at: now()`
   - `seat_hold_id: hold.id` (foreign key reference)
   - `version: incremented` (optimistic lock counter)

### Cache Layers
✅ **ETS (per-node hot cache):**
   - Key: `{org_id, seat_id}`
   - Value: `%{hold_id, user_id, seat_id, held_until, timestamp, status: :active}`
   - TTL: 5 minutes (auto-evict)
   - Scope: This node only (other nodes use Redis)

✅ **Redis (cluster-wide warm cache):**
   - ZSET Key: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`
     - Score: Unix timestamp of expiry (enables efficient expiry scans)
     - Member: `{seat_id}:{hold_id}:{user_id}:{held_until_iso}`
   - STRING Key: `voelgoed:org:{org_id}:seat:{seat_id}:hold`
     - Value: `{hold_id}:{user_id}:{unix_timestamp}`
     - TTL: 300 seconds (auto-expire)
   - Scope: Cluster-wide (all nodes see same data)

✅ **Occupancy Cache (Invalidated):**
   - Key: `voelgoed:org:{org_id}:event:{event_id}:occupancy`
   - Action: Cleared (will be recomputed on next query)
   - Reason: Available count changed (decreased by 1)

### Background Jobs
✅ **Oban Job Scheduled:**
   - Worker: `Voelgoedevents.Queues.WorkerCleanupHolds`
   - Scheduled time: `held_until + 10 second buffer`
   - Payload: `{hold_id, seat_id, event_id, organization_id, user_id}`
   - Max retries: 3 with exponential backoff
   - Execution: Mark hold as `:expired`, revert seat to `:available`, broadcast PubSub

### Audit & Notifications
✅ **Audit Log Entry Created:**
   - Action: `seat_reserved`
   - Entity: SeatHold (id, type)
   - Changes: `{seat_id, event_id, held_until, source}`
   - User: `user_id`, IP address, User-Agent
   - Timestamp: `DateTime.utc_now()`

✅ **Domain Event Emitted:**
   - Event: `SeatReserved`
   - Payload: `{hold_id, seat_id, event_id, user_id, organization_id, held_until, timestamp}`
   - Consumers: Analytics, Oban, PubSub

✅ **PubSub Broadcast:**
   - Topic: `occupancy:{org_id}:{event_id}`
   - Message: Occupancy counts + new hold event
   - Subscribers: Admin dashboard LiveView, analytics workers

### API Response
✅ **HTTP 201 Created** returned to client with JSON:
   ```json
   {
     "hold_id": "uuid-...",
     "seat_id": "uuid-...",
     "event_id": "uuid-...",
     "block_name": "Section A",
     "row": "10",
     "seat_number": "42",
     "status": "held",
     "held_until": "2025-11-26T14:05:30Z",
     "expires_in_seconds": 300,
     "message": "Seat reserved for 5 minutes. Proceed to checkout."
   }
   ```

### Failure Cases
❌ **On any error**, the following are **guaranteed NOT to happen:**
   - No SeatHold record created
   - Seat status unchanged (remains `:available`)
   - No cache entries written
   - No Oban job scheduled
   - Audit log entry created with `seat_reserve_failed` (not `seat_reserved`)
   - HTTP 4xx/5xx with error message

---

## 6. Detailed Step-by-Step Workflow (Happy Path)

### Phase 1: Request Validation & Authentication

**Step 1: Client Sends Reserve Request**

```json
POST /api/events/550e8400-e29b-41d4-a716-446655440001/seats/550e8400-e29b-41d4-a716-446655440002/reserve
Content-Type: application/json
Authorization: Bearer {session_token}

{
  "source": "web"
}
```

**Step 2: Phoenix Controller Extracts & Validates**

- Extract from URL path:
  - `event_id` (UUID format)
  - `seat_id` (UUID format)
- Extract from query/body (optional):
  - `source` (`:web` or `:scanner`, defaults to `:web`)
- Extract from session:
  - `user_id` (authenticated user)
  - `organization_id` (user's organization)
- Validate request shape:
  - `event_id` must be valid UUID
  - `seat_id` must be valid UUID
  - `source` (if provided) must be in allowed values
- If any validation fails → Return `{:error, :invalid_request}` HTTP 400

**Step 3: Verify User Authentication & Organization**

- Check session: Is `user_id` present and not nil?
- Check session: Is `organization_id` present and not nil?
- Query user from Ash: Does user exist and not deleted?
- Query organization from Ash: Does org exist?
- If any check fails → Return `{:error, :unauthorized}` HTTP 401

### Phase 2: Event & Seat Validation

**Step 4: Verify Event Exists & Is Published**

- Ash get: `Voelgoedevents.Ash.Resources.Events.Event`
  - Filter: `id: event_id, organization_id: org_id`
  - Filter: `status: {:in, [:published, :live]}`
- If not found → Return `{:error, :event_not_available}` HTTP 404
- If wrong status → Return `{:error, :event_not_available}` HTTP 400
- If org mismatch → Return `{:error, :event_not_found}` HTTP 404 (don't leak org data)
- Extract: `event_id` (confirmed), layout configuration

**Step 5: Verify Event Sale Window Open**

- Check: `event.sale_start ≤ now() ≤ event.sale_end`
- If outside window → Return `{:error, :event_sales_closed}` HTTP 400
- Check: Event not cancelled or archived
- If cancelled → Return `{:error, :event_unavailable}` HTTP 400

**Step 6: Verify Seat Exists & Belongs to Event**

- Ash get: `Voelgoedevents.Ash.Resources.Seating.Seat`
  - Filter: `id: seat_id, event_id: event_id, organization_id: org_id`
- If not found → Return `{:error, :seat_not_found}` HTTP 404
- Extract: `seat.status, seat.block_id, seat.row_letter, seat.seat_number`
- Check: `seat.status == :available`
- If not available → Return `{:error, :seat_not_available, %{current_status: seat.status}}` HTTP 409 (Conflict)

### Phase 3: Cache Layer Consistency Checks

**Step 7: Check ETS Hot Cache (Per-Node)**

- Query ETS table: `:seat_holds_hot`
- Key: `{org_id, seat_id}`
- If found:
  - Extract: `held_until, user_id`
  - Check: Is `held_until > DateTime.utc_now()` and `user_id != current_user_id`?
    - If YES → Return `{:error, :seat_already_held_by_another_user, %{expires_in: X}}` HTTP 409
    - If NO (expired or same user) → Continue to Step 8
- If not found in ETS → Continue to Step 8 (proceed to Redis check)

**Step 8: Check Redis Warm Cache (Cluster-Wide Consistency)**

- Redis GET command:
  - Key: `voelgoed:org:{org_id}:seat:{seat_id}:hold`
- If nil (not in Redis):
  - Continue to Step 10 (database write)
- If value found:
  - Parse value: `{hold_id}:{user_id}:{unix_timestamp}`
  - Convert timestamp to DateTime
  - Check: Is `held_until > DateTime.utc_now()` and `user_id != current_user_id`?
    - If YES → Return `{:error, :seat_held_by_another_user, %{expires_at: iso, expires_in: seconds}}` HTTP 409
    - If NO (expired or same user) → Continue to Step 10

**Step 9: Consistency Reconciliation (Optional)**

- If ETS says held but Redis says available → Trust Redis, clear ETS entry, log warning
- If Redis says held but ETS says available → No action (ETS might just be stale on this node)
- If both agree (held or available) → Continue

### Phase 4: Database Transaction & Optimistic Lock

**Step 10: Fetch Current Seat State (For Optimistic Lock)**

- Ash get: `Voelgoedevents.Ash.Resources.Seating.Seat`
  - Filter: `id: seat_id, organization_id: org_id`
- Extract: `seat.version` (current optimistic lock version)
- Extract: `seat.status` (must still be `:available`)
- If status != `:available` → Return `{:error, :seat_no_longer_available}` HTTP 409
- Store: `current_version = seat.version`

**Step 11: Prepare Optimistic Lock & Transaction**

- Calculate new state:
  - `held_until = DateTime.add(DateTime.utc_now(), 5 * 60, :second)` (5 minutes)
  - `new_seat_version = current_version + 1`
- Prepare for database transaction:
  - Ash will include validation: `WHERE seats.version = ^current_version`
  - If another process incremented version between Step 10 and transaction start → Retry logic

**Step 12: Create SeatHold Record (Transactional)**

- Ash action: Create on `Voelgoedevents.Ash.Resources.Seating.SeatHold`
  - Arguments:
    ```elixir
    %{
      "seat_id" => seat_id,
      "event_id" => event_id,
      "user_id" => user_id,
      "organization_id" => org_id,
      "status" => :active,
      "held_until" => held_until,
      "source" => source || :web,
      "notes" => nil
    }
    ```
  - Validations (in order):
    - `:seat_not_held` — Verify no active hold from another user
    - `:not_oversold` — Get block capacity, count (held + sold), verify < capacity
    - `:event_published` — Re-check event state
    - `:user_exists` — Verify user_id is valid

- On success: SeatHold record created, assigned UUID `hold.id`
- On failure (`optimization_lock_failed`):
  - Retry entire workflow with backoff (exponential: 10ms, 20ms, 40ms)
  - Max attempts: 3
  - If all retries fail → Return `{:error, :seat_reservation_failed}` HTTP 500

**Step 13: Update Seat Status (Atomic with SeatHold Create)**

- Ash action: Update `Voelgoedevents.Ash.Resources.Seating.Seat` within same transaction
  - Action: `:hold`
  - Attributes:
    ```elixir
    %{
      "status" => :held,
      "held_until" => held_until,
      "locked_at" => DateTime.utc_now(),
      "seat_hold_id" => hold.id,
      "version" => new_seat_version
    }
    ```
  - SQL executed (with optimistic lock):
    ```sql
    UPDATE seats
    SET status = 'held',
        held_until = :held_until,
        locked_at = :now,
        seat_hold_id = :hold_id,
        version = :new_version
    WHERE id = :seat_id
      AND version = :current_version
      AND organization_id = :org_id
    RETURNING *;
    ```
  - If version mismatch: Entire transaction rolls back → Retry from Step 10

**Step 14: Commit Database Transaction**

- Both SeatHold insert and Seat update succeed atomically, or both fail
- PostgreSQL assigns timestamps (created_at, updated_at)
- Hold record now durable in database

---

### Phase 5: Cache Population (All Layers)

**Step 15: Populate ETS Hot Cache**

- Table: `:seat_holds_hot`
- Key: `{org_id, seat_id}`
- Value:
  ```elixir
  %{
    hold_id: hold.id,
    user_id: user_id,
    seat_id: seat_id,
    held_until: held_until,
    timestamp: DateTime.utc_now(),
    status: :active
  }
  ```
- Command: `:ets.insert(:seat_holds_hot, {key, value})`
- TTL: Rely on ETS auto-eviction at 5 minutes (configured at table creation)
- Or manual cleanup via Oban job

**Step 16: Populate Redis Warm Cache (Cluster-Replicated)**

- ZSET (for expiry scans):
  - Key: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`
  - Score: `DateTime.to_unix(held_until)` (enables sorted expiry queries)
  - Member: `{seat_id}:{hold_id}:{user_id}:{DateTime.to_iso8601(held_until)}`
  - Command: `ZADD voelgoed:org:{org_id}:event:{event_id}:seat_holds UNIX_TIMESTAMP member`

- STRING (for fast lookup):
  - Key: `voelgoed:org:{org_id}:seat:{seat_id}:hold`
  - Value: `{hold_id}:{user_id}:{unix_timestamp}`
  - TTL: 300 seconds (auto-expire)
  - Command: `SET voelgoed:org:{org_id}:seat:{seat_id}:hold value EX 300`

- Propagation: Automatic across Redis cluster nodes (replication)

**Step 17: Invalidate Occupancy Derived Cache**

- Clear occupancy count cache (will be recomputed on next query)
- Key: `voelgoed:org:{org_id}:event:{event_id}:occupancy`
- Command: `DEL voelgoed:org:{org_id}:event:{event_id}:occupancy`
- Reason: Seat now unavailable → available_count decreased by 1

---

### Phase 6: Background Jobs & Events

**Step 18: Schedule Oban Cleanup Job**

- Worker: `Voelgoedevents.Queues.WorkerCleanupHolds`
- Scheduled time: `held_until + 10 second buffer`
  - Example: Hold expires at 14:05:00, job scheduled for 14:05:10
  - Buffer ensures: Small clock skew doesn't cause premature release
- Payload:
  ```elixir
  %{
    "hold_id" => hold.id,
    "seat_id" => seat_id,
    "event_id" => event_id,
    "organization_id" => org_id,
    "user_id" => user_id
  }
  ```
- Max attempts: 3 with exponential backoff
- On job execution (at scheduled time):
  1. Verify hold exists and `status == :active`
  2. Verify `held_until <= DateTime.utc_now()`
  3. Mark hold as `:expired` (Ash update)
  4. Revert seat to `:available` (Ash update)
  5. Clean Redis entries (DEL)
  6. Broadcast PubSub occupancy change
  7. Log audit entry: `seat_hold_expired`

**Step 19: Emit Domain Event**

- Event: `SeatReserved` (domain event, not Ash resource)
- Payload:
  ```elixir
  %SeatReserved{
    hold_id: hold.id,
    seat_id: seat_id,
    event_id: event_id,
    user_id: user_id,
    organization_id: org_id,
    held_until: held_until,
    timestamp: DateTime.utc_now()
  }
  ```
- Published to Ash event bus
- Consumers: Analytics, Oban, PubSub, reporting

**Step 20: Broadcast PubSub Notification**

- Topic: `occupancy:{org_id}:{event_id}`
- Message:
  ```json
  {
    "event": "seat_held",
    "seat_id": "uuid-...",
    "hold_id": "uuid-...",
    "event_id": "uuid-...",
    "total_available": X,
    "total_held": X+1,
    "total_sold": X,
    "percent_available": Y,
    "percent_held": Z,
    "timestamp": "2025-11-26T14:00:30Z"
  }
  ```
- Subscribers: Admin dashboard LiveView, analytics workers, real-time occupancy displays
- Non-blocking: Fire-and-forget, doesn't impact response time

---

### Phase 7: Audit & Response

**Step 21: Write Audit Log**

- Entry:
  ```elixir
  %{
    organization_id: org_id,
    user_id: user_id,
    action: :seat_reserved,
    entity_type: :SeatHold,
    entity_id: hold.id,
    changes: %{
      seat_id: seat_id,
      event_id: event_id,
      status: :active,
      held_until: held_until,
      source: source
    },
    ip_address: conn.remote_ip,
    user_agent: get_req_header(conn, "user-agent") |> List.first(),
    timestamp: DateTime.utc_now()
  }
  ```
- Persisted to audit log table (for compliance, troubleshooting, dispute resolution)

**Step 22: Return Success Response**

```json
HTTP/1.1 201 Created
Content-Type: application/json
Cache-Control: no-cache, no-store

{
  "data": {
    "hold_id": "550e8400-e29b-41d4-a716-446655440003",
    "seat_id": "550e8400-e29b-41d4-a716-446655440002",
    "event_id": "550e8400-e29b-41d4-a716-446655440001",
    "block_name": "Section A",
    "row": "10",
    "seat_number": "42",
    "status": "held",
    "held_until": "2025-11-26T14:05:30Z",
    "held_until_unix": 1732620330,
    "expires_in_seconds": 300,
    "message": "Seat reserved for 5 minutes. Proceed to checkout."
  }
}
```

**Step 23: Client-Side: Display Hold Confirmation & Start Countdown**

- Browser receives response and:
  1. Displays hold confirmation message
  2. Shows seat details (row, section, number)
  3. Starts 5-minute countdown timer (300 → 299 → ... → 0)
  4. Display: "Seat held for 4:59..." that decrements every second
  5. When countdown reaches 0:00 → Show "Hold expired" message
  6. Button: "Proceed to Checkout" (routes to checkout flow)
  7. If user navigates away without checkout → Hold persists (server-side TTL)

---

## 7. Edge Cases & Failure Modes

| Edge Case | Cause | Prevention | Recovery |
|-----------|-------|-----------|----------|
| **Overselling** | Two users hold same seat simultaneously | Optimistic lock on Seat.version | Auto-retry with updated version (up to 3x) |
| **Duplicate hold (same user)** | User clicks reserve button twice rapidly | ETS + Redis check before DB write | Return existing hold if active + valid |
| **Hold expires during checkout** | Customer takes > 5 min at payment screen | Client-side timer warns at 4:30 min | Server rejects checkout if hold expired; user re-selects |
| **Redis unavailable during write** | Redis cluster down | ETS cache still works, graceful fallback | Use DB + ETS, eventual consistency via Oban reconciliation |
| **ETS auto-evict timing issues** | Clock skew, table thrashing | Configure ETS TTL conservatively | Oban job is source of truth for cleanup |
| **Oban job fires while hold converting** | Race condition: hold expired but checkout converting | Check hold.status before releasing | No-op if already `:converted` |
| **Multi-tenant isolation breach** | Org1 user reserves Org2 seat | All queries filter by organization_id | Authorization policy enforces at Ash level |
| **Duplicate Oban job execution** | Job retried twice or scheduled twice | Oban unique constraints + idempotency | Job is idempotent (check status first) |
| **Network timeout (client)** | Client doesn't receive 201 response | Client times out after 30 seconds | Manual retry or verify seat status via GET |
| **Stale cache during partition** | Redis partition: node A has hold, B doesn't | DB is source of truth | Reconciliation job during recovery |
| **Block at capacity** | Pricing rule or block capacity changed | Re-check capacity before creating | Return 409 `:block_at_capacity` |
| **Seat already sold** | Inventory error or race condition | Verify seat.status before hold | Return 409 `:seat_not_available` |
| **Event draft/archived** | Admin changed event state during selection | Re-check event.status before hold | Return 400 `:event_not_available` |
| **Session expired** | User takes > 30 min to select seats | Re-authenticate at step 3 | Return 401 `:unauthorized` |

---

## 8. Multi-Tenancy Requirements

### Organization Isolation (Mandatory)

**Session Extraction (Never from Request Params):**
```elixir
# ✅ CORRECT
org_id = conn.assigns[:organization_id]  # From session/JWT
user_id = conn.assigns[:user_id]          # From session/JWT

# ❌ WRONG
org_id = params["organization_id"]  # Would leak data between tenants
```

**All Queries Must Filter by `organization_id`:**
```elixir
# ✅ CORRECT
{:ok, event} = Ash.get(Event,
  filter: [
    id: event_id,
    organization_id: org_id,
    status: {:in, [:published, :live]}
  ])

# ❌ WRONG (no org filter)
{:ok, event} = Ash.get(Event,
  filter: [id: event_id, status: :published])
```

**Redis Key Namespacing (Mandatory):**
```
All keys must include organization_id as first component:

voelgoed:org:{org_id}:event:{event_id}:seat_holds
voelgoed:org:{org_id}:seat:{seat_id}:hold
voelgoed:org:{org_id}:event:{event_id}:occupancy

NO exceptions — prevents any cross-org data access via key collision
```

**ETS Partitioning:**
```elixir
# ✅ CORRECT
Key: {org_id, seat_id}  # org_id is first element
# Prevents collision: Org1's seat1 different from Org2's seat1

# ❌ WRONG
Key: seat_id  # No org scoping — allows cross-org confusion
```

**SeatHold Creation (Always Include Org):**
```elixir
# ✅ CORRECT
Ash.create(SeatHold, %{
  "organization_id" => org_id,  # ← Required
  "seat_id" => seat_id,
  "event_id" => event_id,
  ...
})

# ❌ WRONG (no org, relies on relationship inference)
Ash.create(SeatHold, %{
  "seat_id" => seat_id,
  # org_id inferred from seat → risky!
})
```

**Verification at Each Step:**
- Step 4: Event must have `organization_id: org_id`
- Step 6: Seat must belong to org (via event)
- Step 12: SeatHold must include `organization_id: org_id`
- All cache keys must include `org_id`
- All audit logs must include `organization_id`

---

## 9. Performance & Caching Strategy

### Three-Tier Caching Approach

**Hot Layer: ETS (Per-Node)**
- Scope: Single Elixir node
- Access: < 1ms (in-memory hash lookup)
- Use case: Ultra-fast "is seat held?" checks on hot path
- TTL: 5 minutes (auto-evict)
- Data: Minimal
  ```elixir
  %{
    hold_id: UUID,
    user_id: UUID,
    seat_id: UUID,
    held_until: DateTime,
    timestamp: DateTime,
    status: :active
  }
  ```
- Operations:
  ```elixir
  :ets.lookup(:seat_holds_hot, {org_id, seat_id})    # O(1) read
  :ets.insert(:seat_holds_hot, {key, value})         # O(1) write
  :ets.delete(:seat_holds_hot, {org_id, seat_id})    # O(1) delete
  ```

**Warm Layer: Redis (Cluster-Wide)**
- Scope: Entire distributed system
- Access: 5-20ms (network + replication)
- Use case: Cross-node consistency, distributed duplicate detection
- TTL: 5 minutes (auto-expire)
- Data structures:
  - **ZSET:** For efficient expiry scans
    - Key: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`
    - Score: Unix timestamp (held_until)
    - Member: `{seat_id}:{hold_id}:{user_id}:{iso_timestamp}`
  - **STRING:** For fast seat lookup
    - Key: `voelgoed:org:{org_id}:seat:{seat_id}:hold`
    - Value: `{hold_id}:{user_id}:{unix_timestamp}`
- Replication: Automatic across cluster nodes
- Operations:
  ```
  ZADD voelgoed:org:ORG:event:EVT:seat_holds TIMESTAMP member
  ZRANGE voelgoed:org:ORG:event:EVT:seat_holds 0 -1 BYSCORE 0 CURRENT_UNIX
  SET voelgoed:org:ORG:seat:SEAT:hold value EX 300
  GET voelgoed:org:ORG:seat:SEAT:hold
  ```

**Cold Layer: PostgreSQL (Durable)**
- Scope: System of record
- Access: 10-50ms (depends on table size, index hit rate)
- Use case: Durability, audit trail, reconciliation
- Data: Complete SeatHold + Seat records
- Indexes:
  - `(seat_id, status)` — Quick "is seat held?" lookup
  - `(event_id, user_id)` — "What holds does this user have?"
  - `(held_until)` — TTL expiry sweeps
  - `(organization_id)` — Multi-tenant isolation
- Consistency Model: ETS + Redis are eventually consistent with Postgres (DB is authority)

### Caching Invalidation Pattern

```
1. Write to PostgreSQL (authoritative)
   └─ Atomic: INSERT SeatHold + UPDATE Seat (with optimistic lock)

2. Write-through to ETS (hot layer)
   └─ Immediate: :ets.insert(:seat_holds_hot, {key, value})
   └─ TTL: 5 min auto-evict

3. Write-through to Redis (warm layer)
   └─ Immediate: ZADD + SET commands
   └─ TTL: 300 seconds auto-expire

4. Broadcast PubSub (subscribers)
   └─ Immediate: occupancy change notification
   └─ Subscribers: Admin dashboard, other nodes, analytics

5. Invalidate derived caches
   └─ Clear: voelgoed:org:{org_id}:event:{event_id}:occupancy
   └─ Will be recomputed on next occupancy query
```

### Performance Rules

- ✅ No extra DB reads on hot paths: Check ETS or Redis first
- ✅ Batch writes: Multiple seat updates in single transaction (if needed)
- ✅ Avoid table scans: Use indexes, don't iterate all seats to check availability
- ✅ No N+1 queries: Load related data (block capacity) upfront
- ✅ PubSub broadcasts: Non-blocking, async notification
- ✅ Oban for cleanup: TTL expiry handled by background job, not request path

---

## 10. Seat Hold Registry & Ephemeral State

### Conceptual Hold Registry

The seat hold registry (defined in `docs/architecture/03_caching_and_realtime.md` and `docs/ephemeral_realtime_state.md`) is the runtime tracking of all active holds across the cluster. It answers:

- **"Is seat X held right now?"** → ETS lookup, then Redis ZSET/STRING
- **"What's the occupancy of event Y?"** → Aggregate held + sold counts
- **"When do holds in event Z expire?"** → Redis ZSET score scan
- **"Which holds are due for cleanup?"** → Oban query at scheduled times

### Registry Data Structures

| Structure | Location | Purpose | Query |
|-----------|----------|---------|-------|
| ETS table `:seat_holds_hot` | Node memory | Per-node hot cache | `{org_id, seat_id}` |
| Redis ZSET | Cluster | Sorted by expiry | ZRANGE by score |
| Redis STRING | Cluster | Fast lookup | GET `voelgoed:org:...:seat:SEAT:hold` |
| PostgreSQL `seat_holds` | Durable | Truth of record | SELECT WHERE status=:active |
| PostgreSQL `seats` | Durable | Seat status | SELECT WHERE status=:held |

### Expiry Semantics

- **Active Hold:** `held_until > DateTime.utc_now()` and `status == :active`
- **Expired Hold:** `held_until <= DateTime.utc_now()` (TTL elapsed)
- **Converted Hold:** `status == :converted` (hold → ticket in `complete_checkout` workflow)
- **Cancelled Hold:** `status == :cancelled` (user explicitly released)
- **Cleanup:** Oban job runs at `held_until + 10s` to mark expired and release seat

---

## 11. Related Implementation Targets

### Ash Resources & Support Modules (To Be Created/Enhanced)

**1. SeatHold Resource**
```
Module: Voelgoedevents.Ash.Resources.Seating.SeatHold
File: lib/voelgoedevents/ash/resources/seating/seat_hold.ex

Attributes:
  - id (UUID, primary key)
  - seat_id, event_id, user_id, organization_id
  - status (:active, :converted, :expired, :cancelled)
  - held_until, source (:web, :scanner), notes
  - created_at, updated_at

Actions:
  - :create (with validations for oversell check + uniqueness)
  - :expire (mark hold as :expired)
  - :convert_to_ticket (transition to :converted)
  - :cancel (user-initiated release)

Validations:
  - :seat_not_held_by_other_user
  - :not_oversold (total held + sold < block capacity)
  - :event_published
  - :user_exists
```

**2. Seat Resource (Enhanced)**
```
Module: Voelgoedevents.Ash.Resources.Seating.Seat
File: lib/voelgoedevents/ash/resources/seating/seat.ex

State Machine:
  :available → :held → :sold
            → :blocked (admin)

Attributes (new/enhanced):
  - status (atom state machine)
  - held_until (DateTime, nullable)
  - locked_at (DateTime, nullable)
  - seat_hold_id (UUID, foreign key)
  - version (integer, optimistic lock)

Actions:
  - :hold (available → held, with version increment)
  - :sell (held → sold)
  - :release (held → available)
  - :block (any → blocked)

Validations:
  - :status_available (for :hold action)
  - :version_matches (optimistic lock guard)
```

**3. SeatHoldChange Support Module**
```
Module: Voelgoedevents.Ash.Support.Changes.SeatHoldChange
File: lib/voelgoedevents/ash/support/changes/seat_hold_change.ex

Purpose: Transactional wrapper for Seat hold creation
- Validates seat availability
- Creates SeatHold record
- Updates Seat status
- Populates caches (ETS, Redis)
- Logs audit entry
- Returns unified response

Used by: Phoenix controller as high-level orchestration
```

**4. Oban Worker for Cleanup**
```
Module: Voelgoedevents.Queues.WorkerCleanupHolds
File: lib/voelgoedevents/queues/worker_cleanup_holds.ex

Triggered: At held_until + 10 seconds per hold
Payload:
  - hold_id, seat_id, event_id, org_id, user_id

Job logic:
  1. Verify hold exists + status == :active
  2. Verify held_until <= now
  3. Mark hold :expired via Ash
  4. Revert seat :available via Ash
  5. Clean Redis entries
  6. Broadcast PubSub
  7. Log audit entry

Idempotency: Safe to re-run (checks status)
Max retries: 3 with exponential backoff
```

### Phoenix Controller Integration (Sketch)

```elixir
# lib/voelgoedevents_web/controllers/seats_controller.ex

defmodule VoelgoedeventsWeb.SeatsController do
  def reserve(conn, %{"event_id" => event_id, "seat_id" => seat_id}) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    
    case Voelgoedevents.Workflows.Seating.ReserveSeat.run(
      event_id,
      seat_id,
      user_id,
      org_id
    ) do
      {:ok, {hold, seat}} ->
        conn
        |> put_status(201)
        |> json(render_hold_response(hold, seat))
      
      {:error, reason} ->
        conn
        |> put_status(error_status_code(reason))
        |> json(%{error: reason})
    end
  end
end
```

---

## 12. Multi-Tenancy & Domain Integration

### Involved Ash Domains

| Domain | Resources | Role in Workflow |
|--------|-----------|------------------|
| **Accounts** | User, Organization | Validates authentication + org context |
| **Events** | Event | Verifies event published + owns event |
| **Seating** | Seat, SeatHold, Layout, Block | Core seat hold logic |
| **Ticketing** | (optional) Ticket, Pricing | Pricing context for future integration |

### References to Architecture & Domain Docs

- `docs/MASTER_BLUEPRINT.md` — Overall system architecture
- `docs/DOMAIN_MAP.md` — Domain boundaries + resource relationships
- `docs/domain/seating.md` — Seat state machine, layout/block rules
- `docs/domain/events_venues.md` — Event lifecycle + publish requirements
- `docs/domain/ticketing_pricing.md` — Pricing rules (future context)
- `docs/domain/ephemeral_realtime_state.md` — Hold registry storage patterns
- `docs/architecture/02_multi_tenancy.md` — Organization isolation patterns
- `docs/architecture/03_caching_and_realtime.md` — Three-tier cache strategy

---

## 13. Security & Authorization

### Ash Policies (To Be Implemented)

```elixir
# lib/voelgoedevents/policies/seat_hold_policy.ex

defmodule Voelgoedevents.Policies.SeatHoldPolicy do
  use Ash.Policy

  authorization do
    # Only authenticated users
    authorize_if :user_authenticated
    
    # Event must be published
    authorize_if :event_published
    
    # User's org must own event
    authorize_if :organization_matches
    
    # Seat must be available (not held/sold/blocked)
    authorize_if :seat_available
    
    # Rate limit: Max 10 seats reserved per 5 minutes
    authorize_if :rate_limit_not_exceeded
    
    # Deny all other access
    forbid_if :not_authenticated
  end
end
```

### Input Validation

- **Event ID:** UUID format validation
- **Seat ID:** UUID format validation
- **Source:** Must be `:web` or `:scanner` (enum)
- **No user-provided prices:** All pricing server-side (not here, future integration)

### Sensitive Data Handling

- **Don't expose:** Which user holds a seat (return generic "seat held" message to other users)
- **Do expose:** Expiry countdown (helps customer make decision)
- **Log:** Full hold details in audit log (compliance + troubleshooting)
- **PII:** User ID stored in hold but not returned to other customers

---

## 14. Related Workflows & Dependencies

### Downstream Dependencies
- **`start_checkout.md`** — Consumes active holds to create checkout session
- Workflow: User clicks "Proceed to Checkout" → Fetches all active holds for user
- Dependency: Holds must still be active (not expired)

- **`complete_checkout.md`** — Converts holds to tickets
- Workflow: Payment authorized → Hold transitions `:active` → `:converted` → Ticket created
- Dependency: Hold must exist + be active at payment time

### Cleanup Dependencies
- **`release_seat.md`** — Related cleanup (Oban expires and releases)
- Triggered: Oban job at `held_until + 10s`
- Impact: SeatHold `:active` → `:expired`, Seat `:held` → `:available`

### Analytics Dependencies
- **`funnel_builder.md`** — Tracks conversion funnel
- Consumes: `SeatReserved` domain event
- Metrics: Reservation rate, hold-to-checkout conversion, abandonment

---

## 15. Success Criteria & Acceptance Tests

### Functional Requirements (Must Have)
- [ ] User can reserve available seat (HTTP 201 response)
- [ ] SeatHold record created in Postgres
- [ ] Seat status changed to `:held`
- [ ] ETS entry created for fast lookup
- [ ] Redis entries created (ZSET + STRING)
- [ ] Oban job scheduled for +5 min cleanup
- [ ] Domain event emitted
- [ ] Audit log entry recorded
- [ ] PubSub notification broadcast
- [ ] 5-minute expiry enforced (hold expires, seat released)

### Performance Requirements (Should Have)
- [ ] Reserve response < 200ms (p95)
- [ ] ETS lookup < 1ms
- [ ] Redis write < 50ms
- [ ] Database transaction < 100ms
- [ ] Handle 100+ concurrent reserves/sec per event

### Security Requirements (Must Have)
- [ ] No cross-tenant data leakage (org_id filtering verified)
- [ ] User can only hold seats in their org's events
- [ ] Pricing/cost not exposed to client (future proofing)
- [ ] Rate limiting prevents abuse (10 holds per 5 min per user)

### Edge Cases (Must Handle)
- [ ] Overselling prevented (optimistic lock tested under concurrent load)
- [ ] Redis failure gracefully handled (fallback to ETS + DB)
- [ ] Duplicate reserves by same user (idempotent response)
- [ ] Hold expiry mid-checkout (server rejects stale hold)
- [ ] Event state change during reserve (re-check at each step)
- [ ] Block capacity changed (re-check before creating hold)

---

**END OF RESERVE SEAT WORKFLOW SPECIFICATION**