# Workflow: Release Seat

**Return held seats to available status when holds expire, are cancelled, or payment fails**

---

## 1. Purpose & Overview

**Release Seat** is a family of workflows (not a single workflow) that handles releasing seats from hold state back to available. This can happen in four scenarios:

1. **TTL Expiration** (automatic) — Hold reaches `held_until` timestamp → `WorkerCleanupHolds` Oban job fires
2. **User Cancellation** (manual) — User clicks "Cancel" in checkout UI → Immediate release
3. **Payment Failure** (automatic) — Payment processor declines → `complete_checkout` workflow releases
4. **Admin Override** (manual) — Support agent releases seat for customer service

**Why it matters:**

- **Prevents seat trapping:** Holds auto-expire to prevent seats being locked indefinitely
- **Recycles inventory:** Abandoned carts free up seats for other customers
- **Maintains occupancy accuracy:** Seat counts updated in real-time across dashboards
- **Enables overbooking recovery:** Abandoned seats recycled before next flash-sale window
- **Audit trail:** Every release logged with reason + timestamp (compliance + troubleshooting)

---

## 2. Scenarios & Entry Points

### Scenario A: TTL Expiration (Automatic)

**Trigger:** `WorkerCleanupHolds` Oban job (scheduled by `reserve_seat` workflow)

**Timing:** Scheduled for `held_until + 10 seconds` (buffer for clock skew)

**Entry Point:**
```
reserve_seat creates SeatHold
  ↓
Oban schedules WorkerCleanupHolds job at held_until+10s
  ↓
[5 minutes later] Job fires automatically
  ↓
Release Seat (Scenario A) executes
```

**Who Calls:** Oban job queue (no user involvement)

**Context:** Seat has not been checked out; hold simply expired

---

### Scenario B: User Cancellation (Manual)

**Trigger:** User clicks "Cancel" or "Abandon Cart" in checkout UI

**Timing:** Immediate

**Entry Point:**
```
User in checkout cart → User clicks "Cancel Order"
  ↓
Checkout UI sends POST /api/checkouts/{id}/cancel
  ↓
Controller invokes Release Seat (Scenario B)
  ↓
All holds for this checkout released immediately
```

**Who Calls:** Authenticated user via API endpoint

**Context:** Checkout session exists (from `start_checkout`); user explicitly abandons

**Example Payload:**
```json
POST /api/checkouts/550e8400-e29b-41d4-a716-446655440000/cancel
Authorization: Bearer {token}
Content-Type: application/json

{
  "reason": "user_cancelled",
  "notes": "Customer decided against purchase"
}
```

---

### Scenario C: Payment Failure (Automatic)

**Trigger:** Payment processor declines authorization

**Timing:** During `complete_checkout` workflow, after payment fails

**Entry Point:**
```
complete_checkout sends payment to Stripe
  ↓
Stripe returns 402 Payment Required
  ↓
complete_checkout detects failure
  ↓
Invokes Release Seat (Scenario C) automatically
  ↓
Seats released, customer notified
```

**Who Calls:** System (complete_checkout workflow)

**Context:** Payment failed; holds should be released for other customers

---

### Scenario D: Admin Override (Manual)

**Trigger:** Support agent manually releases via admin panel

**Timing:** Immediate (on-demand)

**Entry Point:**
```
Admin sees customer complaint
  ↓
Admin navigates to customer's checkouts
  ↓
Admin clicks "Release Seats" button
  ↓
Release Seat (Scenario D) executes with admin context
```

**Who Calls:** Authenticated admin user via admin API

**Context:** Customer service intervention (seats stuck, system error recovery)

---

## 3. Data Flow Diagram

```
┌─────────────────────────────────────────────┐
│ Multiple Scenarios (A, B, C, or D)          │
│ Entry: Job / API / System                   │
└────────────────┬────────────────────────────┘
                 │
                 ↓
    ┌────────────────────────────┐
    │ Fetch Checkout Session     │
    │ (if applicable)            │
    └────────────┬───────────────┘
                 │
                 ↓
    ┌────────────────────────────┐
    │ Find all active holds      │
    │ for user/checkout          │
    └────────────┬───────────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
   Per hold:         For each seat:
   - Status check    - Verify :held
   - Not already     - Ticket check
     converted       - Version fetch
                        (for optlock)
        │                 │
        └────────┬────────┘
                 ↓
    ┌────────────────────────────┐
    │ Atomic Transaction:        │
    │ 1. Mark hold :cancelled    │
    │ 2. Set seat :available     │
    │ 3. Clear seat_hold_id      │
    │ 4. Increment version       │
    └────────────┬───────────────┘
                 │
        ┌────────┴─────────────┬──────────────┬────────────┐
        ↓                      ↓              ↓            ↓
   ┌─ ETS ──┐        ┌─ Redis ─┐      ┌─ Oban ──┐   ┌─ PubSub ──┐
   │ Delete  │        │ Delete   │      │ Cancel   │   │ Broadcast │
   │ entry   │        │ 3 keys   │      │ cleanup  │   │ occupancy │
   └────────┘        └──────────┘      └──────────┘   └───────────┘
        │                   │                │              │
        └───────────────────┼────────────────┼──────────────┘
                           ↓
                ┌───────────────────────┐
                │ Audit Log Entry:      │
                │ action: seat_released │
                │ reason: [A/B/C/D]     │
                └───────────────────────┘
                           │
                           ↓
                     HTTP 200 OK
                (or job completion)
```

---

## 4. Preconditions (Must Be True Before Release)

### Authentication & Multi-Tenancy
- ✅ User authenticated (for Scenarios B & D; Scenarios A & C are system-initiated)
- ✅ User has membership in organization (for manual scenarios)
- ✅ Organization ID known and scoped (for all scenarios)
- ✅ No cross-tenant data access (all queries filter by org_id)

### Hold Requirements
- ✅ Active `SeatHold` record exists in PostgreSQL
- ✅ Hold status is `:active` (not already converted or cancelled)
- ✅ Hold's `held_until` timestamp has passed (for Scenario A)
- ✅ Associated `Seat` exists and is in `:held` status
- ✅ Seat's `seat_hold_id` references this hold
- ✅ No active `Ticket` created from this hold (or if ticket exists, it's not yet paid)

### Registry State
- ✅ Seat Hold Registry (ETS + Redis) may have cached the hold
- ✅ Seat status reflects `:held` in PostgreSQL (source of truth)
- ✅ Occupancy cache may be stale; will be invalidated

### System State
- ✅ Database connection available
- ✅ Redis available (or graceful fallback configured)
- ✅ Oban job queue operational (for cancelling cleanup job)
- ✅ PubSub configured for occupancy broadcasts

---

## 5. Postconditions (What Is True After Success)

### Persistent State (PostgreSQL)

✅ **SeatHold record updated:**
```
status: :active → :cancelled
cancelled_at: DateTime.utc_now()
cancellation_reason: "ttl_expired" | "user_cancelled" | "payment_failed" | "admin_override"
notes: Optional explanation text
```

✅ **Seat record updated:**
```
status: :held → :available
held_until: (any value) → nil
locked_at: (any value) → nil
seat_hold_id: {hold_id} → nil
version: incremented by 1 (optimistic lock)
updated_at: DateTime.utc_now()
```

✅ **No Ticket Created** (or ticket remains in pending state, not sold):
- Ticket resource not involved in release
- If ticket exists, it's treated as transitional state only

### Cache Layers (Invalidation)

✅ **ETS (Hot Cache):**
- Entry deleted: `:ets.delete(:seat_holds_hot, {org_id, seat_id})`
- Per-node cleanup automatic

✅ **Redis (Warm Cache):**
- ZSET member removed: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`
- STRING key deleted: `voelgoed:org:{org_id}:seat:{seat_id}:hold`
- HASH key deleted: `voelgoed:org:{org_id}:hold:{hold_id}:meta` (if present)
- Occupancy cache invalidated: `voelgoed:org:{org_id}:event:{event_id}:occupancy`

✅ **Oban (Background Jobs):**
- Scheduled cleanup job cancelled (for this hold)
- If Scenario A: job that triggered the release completes successfully
- If Scenario B/D: any pending cleanup job discarded (already released)

### Notifications & Audit

✅ **PubSub Broadcast:**
```
Topic: occupancy:{org_id}:{event_id}
Message: {
  event: :seat_released,
  seat_id: UUID,
  hold_id: UUID,
  reason: "ttl_expired" | "user_cancelled" | "payment_failed" | "admin_override",
  available_count: N,
  held_count: N-1,
  sold_count: N,
  timestamp: ISO8601
}
```

✅ **Audit Log Entry:**
```
{
  organization_id: org_id,
  user_id: user_id | nil,  # nil for system actions
  action: :seat_released,
  entity_type: :SeatHold,
  entity_id: hold_id,
  changes: {
    seat_id: seat_id,
    event_id: event_id,
    previous_status: :active,
    new_status: :cancelled,
    reason: "ttl_expired" | ...
  },
  ip_address: IP (for manual scenarios),
  user_agent: UA (for manual scenarios),
  timestamp: DateTime.utc_now()
}
```

✅ **Analytics Event (Optional):**
- Domain event: `SeatReleased` published to event bus
- Consumed by: `funnel_builder` for drop-off tracking

### API Response (For Manual Scenarios)

✅ **HTTP 200 OK** (Scenario B: User Cancellation)
```json
{
  "status": "cancelled",
  "checkout_id": "uuid-...",
  "released_seats": [
    {"seat_id": "uuid-1", "block": "Section A", "row": "10", "number": "42"},
    {"seat_id": "uuid-2", "block": "Section A", "row": "10", "number": "43"}
  ],
  "released_count": 2,
  "message": "Your order has been cancelled. Seats are now available for other customers."
}
```

✅ **HTTP 200 OK** (Scenario D: Admin Override)
```json
{
  "status": "released",
  "hold_id": "uuid-...",
  "seats_released": 3,
  "reason": "admin_override",
  "message": "Seats released by admin"
}
```

### Failure Cases (Guaranteed NOT to happen on error)

❌ On **any error**, the following are guaranteed NOT to happen:
- No partial releases (transaction atomicity)
- No seats stranded in :held status (rollback on failure)
- No cache corruption (all-or-nothing invalidation)
- No double releases (idempotency checks prevent this)

---

## 6. Detailed Step-by-Step Workflow (Happy Path)

### Phase 1: Trigger & Validation

**Step 1: Determine Release Scenario**

- **Scenario A (TTL):** Oban job begins with hold_id in args
- **Scenario B (Cancel):** User sends API request with checkout_id
- **Scenario C (Payment Fail):** System calls release function with failure context
- **Scenario D (Admin):** Admin sends API request with hold_id list

**Step 2: Extract Multi-Tenant Context**

```elixir
# Scenario A: org_id from job args
# Scenario B/D: org_id from session (never from request params)
# Scenario C: org_id from system context

org_id = get_org_id_from_context()
user_id = get_user_id_if_applicable()  # nil for Scenarios A & C
```

**Step 3: Fetch Checkpoint Entity**

- **Scenario A:** Fetch SeatHold by ID
- **Scenario B:** Fetch Checkout by ID → find associated holds
- **Scenario C:** Fetch holds by checkout ID
- **Scenario D:** Fetch holds by ID list

```elixir
case scenario do
  :ttl_expiration ->
    {:ok, hold} = Ash.get(SeatHold, hold_id, filter: [organization_id: org_id])
  
  :user_cancellation ->
    {:ok, checkout} = Ash.get(Checkout, checkout_id, filter: [organization_id: org_id])
    {:ok, holds} = Ash.read(SeatHold, filter: [
      checkout_id: checkout_id,
      organization_id: org_id,
      status: :active
    ])
  
  :payment_failure ->
    {:ok, holds} = fetch_holds_for_checkout(checkout_id, org_id)
  
  :admin_override ->
    {:ok, holds} = Ash.read(SeatHold, filter: [
      id: {:in, hold_id_list},
      organization_id: org_id
    ])
end
```

**Step 4: Validate Release Eligibility**

- Check: Hold status is `:active` (not already converted/cancelled)
- Check: Seat status is `:held` (not already sold)
- Check: No active payment processing (for Scenarios B & D)

```elixir
Enum.each(holds, fn hold ->
  unless hold.status == :active do
    Logger.info("Hold #{hold.id} already #{hold.status}, skipping")
    skip_hold(hold)
  end
  
  {:ok, seat} = Ash.get(Seat, hold.seat_id, filter: [organization_id: org_id])
  
  case seat.status do
    :sold ->
      Logger.info("Seat #{hold.seat_id} already sold, holding release")
      skip_hold(hold)  # Don't release sold seats!
    
    :available ->
      Logger.warn("Seat #{hold.seat_id} already available (double-release?)")
      skip_hold(hold)  # Idempotent: already released
    
    :held ->
      continue_to_release(hold, seat)  # Proceed
  end
end)
```

---

### Phase 2: Atomic Release Transaction

**Step 5: Fetch Current Seat State (For Optimistic Lock)**

```elixir
{:ok, seat} = Ash.get(Seat, hold.seat_id, 
  filter: [organization_id: org_id])

current_version = seat.version
```

**Step 6: Start Database Transaction**

```elixir
transaction_result = Ash.Repo.transaction(fn ->
  # Steps 7-8 execute atomically
  {:ok, {updated_hold, updated_seat}}
end)

case transaction_result do
  {:ok, {hold, seat}} ->
    continue_to_phase_3(hold, seat)
  
  {:error, :optimistic_lock_failed} ->
    # Seat.version changed between Step 5 and Step 6
    # Retry with backoff (Oban will handle for Scenarios A & C)
    {:error, :lock_failed}
  
  {:error, reason} ->
    Logger.error("Transaction failed: #{inspect(reason)}")
    {:error, reason}
end
```

**Step 7: Mark SeatHold as Cancelled (Atomic)**

```elixir
# Within transaction
{:ok, updated_hold} = Ash.update(hold, :release, %{
  "status" => :cancelled,
  "cancelled_at" => DateTime.utc_now(),
  "cancellation_reason" => cancellation_reason,  # ttl_expired | user_cancelled | payment_failed | admin_override
  "notes" => optional_notes
}, authorize?: false)
```

**Step 8: Mark Seat as Available (Atomic with Optimistic Lock)**

```elixir
# Within transaction
new_version = current_version + 1

{:ok, updated_seat} = Ash.update(seat, :release, %{
  "status" => :available,
  "held_until" => nil,
  "locked_at" => nil,
  "seat_hold_id" => nil,
  "version" => new_version
}, authorize?: false)

# SQL executed (with version check):
# UPDATE seats
# SET status = 'available',
#     held_until = NULL,
#     locked_at = NULL,
#     seat_hold_id = NULL,
#     version = :new_version
# WHERE id = :seat_id
#   AND version = :current_version
#   AND organization_id = :org_id
# RETURNING *;

# If version != current_version: transaction rolls back
```

**Step 9: Commit Transaction**

```elixir
# Transaction automatically commits if no errors during Step 7-8
Logger.info("Seat released (atomic): #{hold.id} → #{seat.id}")
```

---

### Phase 3: Cache Invalidation (Seat Hold Registry)

**Step 10: Delete ETS Entry (Per-Node Hot Cache)**

```elixir
# Delete immediately (fastest)
ets_key = {org_id, seat.seat_id}
:ets.delete(:seat_holds_hot, ets_key)

Logger.debug("ETS entry deleted: #{inspect(ets_key)}")
```

**Step 11: Delete Redis Entries (Cluster-Wide Warm Cache)**

```elixir
# Delete ZSET member
zset_key = "voelgoed:org:#{org_id}:event:#{hold.event_id}:seat_holds"
# Member format: "seat_id:hold_id:user_id:held_until_iso"
member = "#{hold.seat_id}:#{hold.id}:#{hold.user_id}:#{DateTime.to_iso8601(hold.held_until)}"
Redix.command!(:redis, ["ZREM", zset_key, member])

# Delete per-seat STRING
string_key = "voelgoed:org:#{org_id}:seat:#{hold.seat_id}:hold"
Redix.command!(:redis, ["DEL", string_key])

# Delete hold metadata HASH
meta_key = "voelgoed:org:#{org_id}:hold:#{hold.id}:meta"
Redix.command!(:redis, ["DEL", meta_key])

# Invalidate occupancy cache (forces recompute)
occupancy_key = "voelgoed:org:#{org_id}:event:#{hold.event_id}:occupancy"
Redix.command!(:redis, ["DEL", occupancy_key])

Logger.debug("Redis entries deleted for hold: #{hold.id}")
```

**Step 12: Cancel Oban Cleanup Job (If Not Already Running)**

```elixir
# For Scenarios B, C, D: Cancel the scheduled cleanup job
# (For Scenario A, the job is currently running, so this is no-op)

case Oban.cancel_job(:ticketing, %{
  job_key: "release_seat_hold:#{hold.id}"
}) do
  {:ok, _job} ->
    Logger.info("Oban cleanup job cancelled for hold: #{hold.id}")
  
  :not_found ->
    Logger.debug("No scheduled cleanup job found (or already running)")
end
```

---

### Phase 4: Notifications & Audit

**Step 13: Broadcast PubSub Occupancy Update**

```elixir
# Real-time update for dashboards + analytics
topic = "occupancy:#{org_id}:#{hold.event_id}"

message = %{
  event: :seat_released,
  seat_id: hold.seat_id,
  hold_id: hold.id,
  reason: cancellation_reason,
  timestamp: DateTime.to_iso8601(DateTime.utc_now()),
  
  # Optional: include updated occupancy (cached or computed)
  occupancy: %{
    available: count_seats(:available, hold.event_id, org_id),
    held: count_seats(:held, hold.event_id, org_id),
    sold: count_seats(:sold, hold.event_id, org_id)
  }
}

Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, topic, message)

Logger.debug("PubSub broadcast: #{topic}")
```

**Step 14: Create Audit Log Entry**

```elixir
audit_entry = %{
  organization_id: org_id,
  user_id: user_id || nil,  # nil for system actions (Scenarios A & C)
  action: :seat_released,
  entity_type: :SeatHold,
  entity_id: hold.id,
  
  changes: %{
    seat_id: hold.seat_id,
    event_id: hold.event_id,
    previous_status: :active,
    new_status: :cancelled,
    reason: cancellation_reason,
    held_duration_seconds: DateTime.diff(DateTime.utc_now(), hold.created_at, :second)
  },
  
  metadata: %{
    scenario: scenario,  # :ttl_expiration, :user_cancellation, etc.
    checkout_id: checkout_id || nil,
    ip_address: ip || nil,
    user_agent: ua || nil
  },
  
  timestamp: DateTime.utc_now()
}

{:ok, _} = Ash.create!(AuditLog, audit_entry)

Logger.info("Audit log created: seat_released for hold #{hold.id}")
```

**Step 15: Emit Domain Event (Optional)**

```elixir
# Published to event bus for consumers (funnel_builder, analytics)
domain_event = %SeatReleased{
  hold_id: hold.id,
  seat_id: hold.seat_id,
  event_id: hold.event_id,
  user_id: hold.user_id,
  organization_id: org_id,
  reason: cancellation_reason,
  held_duration_seconds: DateTime.diff(DateTime.utc_now(), hold.created_at, :second),
  timestamp: DateTime.utc_now()
}

Ash.notify(domain_event)
```

---

### Phase 5: Response & Completion

**Step 16: Return Success Response**

**Scenario A (TTL - Oban Job):**
```elixir
Logger.info("WorkerCleanupHolds completed: hold #{hold.id} released")
:ok  # Oban marks job as succeeded
```

**Scenario B (User Cancellation - API):**
```elixir
{:ok, %{
  status: "cancelled",
  checkout_id: checkout_id,
  released_seats: released_seats_summary,
  released_count: length(released_seats),
  message: "Your order has been cancelled."
}}
```

**Scenario C (Payment Failure - System):**
```elixir
Logger.info("Payment failure: released #{length(holds)} holds for checkout #{checkout_id}")
{:ok, :released}  # Returns to complete_checkout workflow
```

**Scenario D (Admin Override - API):**
```elixir
{:ok, %{
  status: "released",
  hold_id: hold_id,
  seats_released: length(released_seats),
  reason: "admin_override",
  message: "Seats released by admin"
}}
```

---

## 7. Edge Cases & Failure Modes

| Edge Case | Cause | Prevention | Recovery |
|-----------|-------|-----------|----------|
| **Hold already cancelled** | Double-release or already processed | Check hold.status != :active | Skip (idempotent) |
| **Seat already sold** | Checkout completed before release | Verify seat.status == :held | Skip (don't release sold seats!) |
| **Seat already available** | Double-release edge case | Check seat.status | No-op (idempotent) |
| **Optimistic lock conflict** | Concurrent seat updates | Retry with backoff | Oban job retries 3x automatically |
| **Transaction rollback** | DB constraint violated | Transaction is atomic | Retry entire operation |
| **Hold not found** | Record deleted externally | Graceful handling | Log as not_found, proceed |
| **Database outage** | PostgreSQL unavailable | Connection pooling + failover | Oban queues job, retries when DB recovers |
| **Redis unavailable** | Cache cluster down | Graceful fallback (proceed without cache) | Warn but don't fail |
| **ETS table missing** | Initialization failure | Verify table exists on startup | Continue (non-critical) |
| **PubSub broadcast fails** | No subscribers or network issue | Async broadcast (fire-and-forget) | Log warning, don't block release |
| **Oban job cancellation fails** | Job already executing | Graceful error handling | Log warning, continue |
| **Ticket exists (paid)** | Edge case: ticket created before release | Verify ticket.status | Reject release (return error) |
| **Checkout has payment in-flight** | Race condition | Lock checkout during payment | Retry release after payment resolves |

---

## 8. Multi-Tenancy & Isolation

**Reference:** `docs/architecture/02_multi_tenancy.md`

### Critical Rules (All Scenarios)

**Rule 1: Extract org_id from Session (Never Request Params)**
```elixir
# ✅ CORRECT (Scenarios B & D)
org_id = conn.assigns[:organization_id]

# ❌ WRONG
org_id = params["organization_id"]  # User can spoof different org!
```

**Rule 2: All Queries Include org_id Filter**
```elixir
# ✅ CORRECT
Ash.read(SeatHold, filter: [
  organization_id: org_id,
  status: :active
])

# ❌ WRONG
Ash.read(SeatHold, filter: [
  status: :active
  # Missing org_id!
])
```

**Rule 3: Redis Keys Always Include org_id**
```
✅ voelgoed:org:{org_id}:event:{event_id}:seat_holds
✅ voelgoed:org:{org_id}:seat:{seat_id}:hold
✅ voelgoed:org:{org_id}:event:{event_id}:occupancy

❌ voelgoed:event:{event_id}:seat_holds    (no org!)
❌ voelgoed:seat:{seat_id}:hold           (cross-org collision!)
```

**Rule 4: Audit Logging Always Includes org_id**
```elixir
Ash.create!(AuditLog, %{
  organization_id: org_id,  # ← REQUIRED
  user_id: user_id,
  action: :seat_released,
  ...
})
```

---

## 9. Consistency & Atomicity Guarantees

### Atomic Operations

```elixir
# Transaction ensures: both SeatHold AND Seat update, or both fail
Ash.Repo.transaction(fn ->
  # Step 7: Mark hold as cancelled
  # Step 8: Mark seat as available (with version check)
  # Both succeed or both fail (no partial updates)
end)
```

### Idempotency Guarantees

```
Running release twice produces same result:
1. First run: hold.status = :active → :cancelled ✓
2. Second run: hold.status = :cancelled → skipped (idempotent) ✓

Cache cleanup idempotent:
- ETS: :ets.delete on missing key = no-op
- Redis: DEL missing key = no-op
```

### Consistency Model

```
Three-tier cache consistency (per Seat Hold Registry):

1. Write to PostgreSQL (authoritative)
   ↓
2. Invalidate ETS immediately
   ↓
3. Invalidate Redis cluster
   ↓
4. Next read: falls back to Postgres (fresh data)
```

---

## 10. Integration Points

### With `reserve_seat.md`

```
reserve_seat creates SeatHold + schedules cleanup job
         ↓
[5 minutes pass]
         ↓
release_seat (Scenario A) fires
         ↓
Holds automatically released (or converted to tickets)
```

### With `start_checkout.md`

```
start_checkout fetches active holds
         ↓
Validates holds not expired (freshness check)
         ↓
If expired → release_seat should have cleaned up
         ↓
If not expired → hold can be converted to checkout
```

### With `complete_checkout.md`

```
complete_checkout processes payment
         ↓
If payment succeeds:
   - Hold converted to ticket (not released)
         ↓
If payment fails:
   - complete_checkout calls release_seat (Scenario C)
   - Holds released back to available
```

### With `seat_hold_registry.md`

```
Seat Hold Registry maintains runtime state
         ↓
release_seat updates registry:
   - ETS: delete entry
   - Redis: delete 3 structures
   - PostgreSQL: update records
         ↓
Next occupancy query: reflects released seats
```

---

## 11. Implementation Targets

### Ash Actions & Changes

**1. SeatHold `:release` Action**

```
Module: Voelgoedevents.Ash.Resources.Seating.SeatHold
File: lib/voelgoedevents/ash/resources/seating/seat_hold.ex

Actions:
  :release
    - Arguments: cancellation_reason, notes (optional)
    - Changes:
      - Set status → :cancelled
      - Set cancelled_at → DateTime.utc_now()
      - Set cancellation_reason → value
    - Validations:
      - :status_active (only active holds can be released)
      - :exists (hold must exist)
```

**2. Seat `:release` Action**

```
Module: Voelgoedevents.Ash.Resources.Seating.Seat
File: lib/voelgoedevents/ash/resources/seating/seat.ex

Actions:
  :release
    - Arguments: (none)
    - Changes:
      - Set status → :available
      - Set held_until → nil
      - Set locked_at → nil
      - Set seat_hold_id → nil
      - Increment version (optimistic lock)
    - Validations:
      - :status_held (only held seats can be released)
      - :version_matches (optimistic lock guard)
```

**3. SeatHoldChange Support Module**

```
Module: Voelgoedevents.Ash.Support.Changes.SeatHoldChange
File: lib/voelgoedevents/ash/support/changes/seat_hold_change.ex

Purpose: Transactional wrapper coordinating release across layers

Responsibilities:
  1. Validate release eligibility
  2. Execute SeatHold + Seat updates (atomic)
  3. Clean cache layers (ETS, Redis)
  4. Cancel Oban cleanup job
  5. Emit domain event
  6. Log audit entry
  7. Broadcast PubSub
  8. Return unified response
```

### Oban Workers

**WorkerCleanupHolds** (Already defined in `reserve_seat.md`)

```
Module: Voelgoedevents.Queues.WorkerCleanupHolds
File: lib/voelgoedevents/queues/worker_cleanup_holds.ex

Triggers: Scenario A (TTL Expiration)
  - Scheduled by reserve_seat at held_until + 10s
  - Max attempts: 3 with exponential backoff
  - Queue: :cleanup
  - Priority: 100 (lower priority, non-blocking)
```

### Phoenix Controllers & Endpoints

**Checkout Cancellation Endpoint**

```
POST /api/checkouts/{id}/cancel
  - Scenario B (User Cancellation)
  - Authenticated user endpoint
  - Calls release_seat with scenario context

POST /api/admin/seats/release
  - Scenario D (Admin Override)
  - Admin-only endpoint
  - Batch release support
```

---

## 12. Monitoring & Observability

### Key Metrics

```
1. Release operations per minute (by scenario)
   - Scenario A (TTL): should be steady
   - Scenario B (Cancel): user behavior
   - Scenario C (Payment fail): payment processor issues
   - Scenario D (Admin): support intervention

2. Release success rate
   - Alert if > 5% failures

3. Cache invalidation latency
   - Alert if Redis > 100ms

4. Hold-to-release time
   - Scenario A: should be ~5 minutes
   - Scenario B: immediate (user-initiated)
   - Scenario C: immediate (payment fail)
```

### Alerts

```
- High failure rate: Check database, cache health
- High latency: Redis cluster degraded?
- Orphaned holds: Scheduled cleanup job failures
- Double-releases: Check for concurrent requests
```

---

## 13. Future Enhancements

- **Partial Release:** Allow releasing subset of seats from hold
- **Hold Extension:** Allow users to extend TTL before expiration
- **Bulk Release:** Admin bulk action for event recovery
- **Hold Analytics:** Track abandonment rates by seat, time-of-day, event
- **Adaptive TTL:** Vary hold duration based on occupancy pressure
- **Hold Transfers:** Allow customers to transfer holds to others

---

**END OF RELEASE SEAT WORKFLOW**