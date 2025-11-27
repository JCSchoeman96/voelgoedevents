# Workflow: Start Checkout

**Initiate a checkout session from held seats, applying pricing rules and discounts**

---

## 1. Workflow Purpose & Context

**Start Checkout** transitions a customer from seat selection (where holds are created via `reserve_seat` workflow) to payment authorization. This workflow:

- Validates all held seats remain active and not expired
- Calculates authoritative pricing server-side (prevents client tampering)
- Applies promotional codes and fee/tax calculations
- Creates a time-limited checkout session (~15 minutes) that gates payment access
- Prepares for the next workflow: `complete_checkout` (payment processing + ticket issuance)

**Why it's essential:**
- Ensures freshness between UI selection and payment (holds must not have expired)
- Establishes audit trail for financial compliance and dispute resolution
- Enables multi-step checkout with pause/resume capability (state recoverable from Redis)
- Protects revenue model (fees and taxes calculated consistently server-side)
- Prevents double-booking (held seats locked until checkout expires or completes)

---

## 2. Actors & Systems

### End-User/Client
- **Svelte PWA browser** — Displays selected seats, handles UI countdown timer (15 min)
- Submits: `POST /api/checkouts` with list of held seat UUIDs + optional promo code

### VoelgoedEvents Backend (Coordinating Systems)

#### Ash Domains
- **Accounts Domain** — Validates user authentication + organization context
- **Events Domain** — Verifies event state (`:published` or `:live`)
- **Seating Domain** — Validates SeatHold records (active status, not expired)
- **Ticketing Domain** — Creates Checkout + CheckoutItem records; links to PricingRule + Coupon
- **Payments Domain** — Prepares transaction ledger entries (not yet executed)

#### Request/Response
- **Phoenix Controller** (`VoelgoedeventsWeb.Checkouts.CheckoutController`) — Pure I/O layer, delegates business logic to Ash actions
- **LiveView** (optional) — Real-time checkout progress display for admin dashboard

#### State Storage Layers
- **PostgreSQL (Cold)** — Durable Checkout + CheckoutItem records, audit trail
- **Redis (Warm)** — Cluster-replicated JSON session cache (15-min TTL, instant multi-node access)
- **ETS (Hot)** — Optional per-node in-memory tracking (< 1ms lookup)

#### Background Jobs
- **Oban Worker** (`Voelgoedevents.Queues.Workers.AbandonCheckoutJob`) — Scheduled for +15 min, releases held seats if checkout not completed

#### Real-Time Notification
- **PubSub** — Broadcasts `checkout_started` event for analytics + admin dashboard

### External Payment Provider
- **Stripe/PayPal** — Abstract role; not invoked in this workflow (defer to `complete_checkout`)

---

## 3. Data Flow Diagram

```
┌─ Browser (Svelte) ─────────────────────────────────────┐
│  Selected seats: [uuid-seat-1, uuid-seat-2, ...]      │
│  Promo code: "EARLY20" (optional)                      │
└──────────────────┬──────────────────────────────────────┘
                   │ POST /api/checkouts
                   ↓
┌─ Phoenix Controller ──────────────────────────────────┐
│  Extract: held_seat_ids, promo_code                   │
│  From session: user_id, organization_id               │
│  Validate: At least 1 seat, promo code is string      │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓ Ash reads
┌─ Seating Domain (SeatHold) ───────────────────────────┐
│  Query: active holds for this user + org             │
│  Check: held_until > now (not expired)               │
│  Verify: all holds same event_id                     │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓ Ash gets
┌─ Events Domain (Event) ───────────────────────────────┐
│  Verify: event exists, status = published            │
│  Extract: event_id for pricing rules lookup          │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ↓                     ↓
┌─ Ticketing Domain ──┐  ┌─ Ticketing Domain ──┐
│ PricingRule         │  │ Coupon              │
│ (base seat prices)  │  │ (promo discount)    │
└─────────┬───────────┘  └─────────┬───────────┘
          │                        │
          └──────────┬─────────────┘
                     ↓ Calculate
        ┌────────────────────────────┐
        │ Pricing Pipeline:          │
        │  - Base price per seat     │
        │  - Apply coupon discount   │
        │  - Add platform fees (2.5%)│
        │  - Add payment fees (1.5%) │
        │  - Calculate taxes (if req)│
        │  - Total = final price     │
        └────────┬───────────────────┘
                 │
                 ↓ Ash creates
        ┌────────────────────────────┐
        │ Ticketing Domain:          │
        │  - Create Checkout         │
        │  - Create CheckoutItems    │
        │  (one per held seat)       │
        └────────┬───────────────────┘
                 │
        ┌────────┴────────┬────────────┐
        ↓                 ↓            ↓
   ┌─ Redis ────┐  ┌─ ETS ──┐  ┌─ Oban ──┐
   │ Cache      │  │ Track  │  │ Job     │
   │ (15 min)   │  │ local  │  │ +15 min │
   └────────────┘  └────────┘  └─────────┘
        │
        ↓ PubSub + Audit Log
   ┌──────────────────────────┐
   │ Broadcast + Log          │
   │  (async, non-blocking)   │
   └────────┬─────────────────┘
            │
            ↓ HTTP 200
   ┌──────────────────────────┐
   │ Response JSON:           │
   │ - checkout_id            │
   │ - total_cents            │
   │ - expires_in_seconds     │
   │ - payment_options        │
   │ - seats breakdown        │
   └──────────────────────────┘
            │
            ↓ Browser
   ┌──────────────────────────┐
   │ Display checkout summary │
   │ Start 15-min countdown   │
   │ Display payment options  │
   │ → User clicks "Pay Now"  │
   └──────────────────────────┘
```

---

## 4. Preconditions (Must Be True Before Starting)

### Authentication & Tenancy
- ✅ User must be authenticated (session contains `user_id`)
- ✅ User must have valid organization membership (session contains `organization_id`)
- ✅ No cross-tenant data leakage (all queries filtered by `organization_id`)

### Seat Hold Requirements
- ✅ At least 1 active seat hold exists for this user (no empty carts)
- ✅ All held seats belong to **same event** (single-event carts only, v1)
- ✅ No held seat has expired (hold.held_until > DateTime.utc_now())
- ✅ All held seats still in `:held` status (not already converted to tickets)
- ✅ User's hold records must exist in `Voelgoedevents.Ash.Resources.Seating.SeatHold`

### Event State
- ✅ Event must be published (status ∈ [`:published`, `:live`])
- ✅ Event is owned by the user's organization
- ✅ Event lifecycle state allows sales (sale window open, not cancelled/archived)

### Pricing Configuration
- ✅ Pricing rules exist for event (at least one block has configured price)
- ✅ Each seat block has a matching `Voelgoedevents.Ash.Resources.Ticketing.PricingRule`
- ✅ No block has zero or negative price

### Promo Code (Optional)
- ✅ If provided, must be valid string (not null, not empty)
- ✅ If provided, `Voelgoedevents.Ash.Resources.Ticketing.Coupon` record must exist
- ✅ If provided, coupon must not be expired (valid_from ≤ now ≤ valid_until)
- ✅ If provided, coupon must not exceed max usage count

---

## 5. Postconditions (What Is True After Success)

### Persistent State (PostgreSQL)
✅ **Checkout record created** with:
   - `status: :started`
   - `user_id, event_id, organization_id`
   - `subtotal_cents, discount_cents, platform_fee_cents, payment_fee_cents, tax_cents, total_cents`
   - `coupon_code: nil` or the applied promo code string
   - `expires_at: now() + 15 minutes`
   - Timestamps: `created_at`, `updated_at`

✅ **CheckoutItem records created** (one per held seat):
   - `checkout_id` (link to Checkout)
   - `seat_hold_id` (link to SeatHold)
   - `seat_id` (denormalized for quick lookup)
   - `price_cents` (individual line item price for audit)

### Cache Layers
✅ **Redis session cache:**
   - Key: `voelgoed:org:{org_id}:checkout:{checkout_id}`
   - Value: Full checkout JSON (all details needed for payment processing)
   - TTL: 900 seconds (15 minutes)
   - Scope: Cluster-wide (all nodes can read immediately)

✅ **ETS (optional per-node tracking):**
   - Key: `{org_id, checkout_id}`
   - Value: Minimal metadata (user_id, event_id, total_cents, expires_at, status)
   - TTL: 15 minutes (auto-evict)

### Background Jobs
✅ **Oban job scheduled:**
   - Worker: `Voelgoedevents.Queues.Workers.AbandonCheckoutJob`
   - Scheduled time: `now() + 15 minutes + 10 second buffer`
   - Max retries: 3 with exponential backoff
   - Execution: Releases all held seats back to available, logs abandonment

### Audit & Notifications
✅ **Audit log entry created:**
   - Action: `checkout_started`
   - Entity: Checkout (id, type)
   - Changes: All pricing details, seat count, coupon code
   - User: `user_id`, IP address, User-Agent

✅ **Domain event emitted:** `CheckoutStarted`
   - Payload: `{checkout_id, user_id, event_id, total_cents, seat_count, timestamp}`
   - Consumers: Analytics workers, Oban tasks, PubSub broadcasts

✅ **PubSub broadcast:**
   - Topic: `checkout:{org_id}:started`
   - Message: Checkout event (above)
   - Subscribers: Admin dashboard, real-time analytics, conversion tracking

### API Response
✅ **HTTP 200 OK** returned to client with JSON:
   ```json
   {
     "checkout_id": "uuid-...",
     "status": "started",
     "event_id": "uuid-...",
     "user_id": "uuid-...",
     "organization_id": "uuid-...",
     "subtotal_cents": 100000,
     "discount_cents": 10000,
     "platform_fee_cents": 2500,
     "payment_fee_cents": 1500,
     "tax_cents": 12000,
     "total_cents": 106000,
     "expires_at": "2025-11-26T14:20:30Z",
     "expires_in_seconds": 900,
     "coupon_applied": "EARLY20" | null,
     "item_count": 3,
     "items": [{ seat details }],
     "payment_options": { methods, processors, ready: true }
   }
   ```

### Failure Cases
❌ **On any error**, the following are **guaranteed NOT to happen:**
   - No Checkout record created
   - No CheckoutItem records created
   - Held seats remain held (no state changes)
   - Redis cache not populated
   - No Oban job scheduled
   - Audit log entry with `checkout_start_failed` (not `checkout_started`)
   - HTTP 4xx/5xx with error message

---

## 6. Detailed Step-by-Step Workflow (Happy Path)

### Phase 1: Request Validation & Authentication

**Step 1: Client Sends Checkout Request**

```json
POST /api/checkouts
Content-Type: application/json
Authorization: Bearer {session_token}

{
  "held_seat_ids": [
    "550e8400-e29b-41d4-a716-446655440000",
    "550e8400-e29b-41d4-a716-446655440001",
    "550e8400-e29b-41d4-a716-446655440002"
  ],
  "promo_code": "EARLY20"
}
```

**Step 2: Phoenix Controller Extracts & Validates Request**

- Extract request params:
  - `held_seat_ids` (array of UUIDs)
  - `promo_code` (optional string)
- Extract session context:
  - `user_id` (from Phoenix session)
  - `organization_id` (from Phoenix session)
- Validate request shape:
  - `held_seat_ids` must be array, not empty
  - `promo_code` (if present) must be string
- Route to Ash action or business logic function

**Step 3: Verify User Authentication & Organization**

- Query user from session — does user exist and not deleted?
- Query organization — does org exist and user has membership?
- If either fails → Return `{:error, :unauthorized}`

### Phase 2: Seat Hold Validation

**Step 4: Fetch All Active Seat Holds for User**

- Ash query: `Voelgoedevents.Ash.Resources.Seating.SeatHold`
  - Filter: `user_id: user_id, organization_id: org_id, status: :active`
- Result: List of SeatHold records
- If empty → Return `{:error, :no_active_holds, "Please select seats first"}`

**Step 5: Verify Requested Seat IDs Match Held Seats**

- Compare `held_seat_ids` (from request) with `seat_ids` (from database holds)
- If any requested seat is NOT in active holds → Return `{:error, :hold_not_found}`
- If user has more holds than requested, filter to only requested seats

**Step 6: Verify No Holds Have Expired**

- For each held seat, check: `hold.held_until > DateTime.utc_now()`
- If any hold expired → Return `{:error, :hold_expired, "Seat hold expired. Please select seats again"}`
- Timestamp tolerance: Allow up to 1 second clock skew

**Step 7: Verify All Holds Belong to Same Event**

- Extract `event_id` from first hold
- Verify all other holds have same `event_id`
- If mismatch → Return `{:error, :mixed_events, "Cannot checkout seats from different events"}`

**Step 8: Optional—Redis/ETS Consistency Check**

- For each held seat, check warm cache (Redis):
  - Key: `voelgoed:org:{org_id}:seat:{seat_id}:hold`
  - If cache says expired but DB says active → Log warning, proceed with DB (source of truth)
  - If cache says missing but DB says active → Proceed, cache will be refreshed
- Objective: Detect cascading failures early

### Phase 3: Event Validation

**Step 9: Verify Event Exists & Is Published**

- Ash get: `Voelgoedevents.Ash.Resources.Events.Event`
  - Filter: `event_id: event_id, organization_id: org_id`
  - Also filter: `status: {:in, [:published, :live]}`
- If not found or wrong status → Return `{:error, :event_not_available}`

**Step 10: Verify Event Sale Window**

- Check: Is event currently within its sale period? (event.sale_start ≤ now ≤ sale_end)
- Check: Event not cancelled or archived
- If event closed for sales → Return `{:error, :event_sales_closed}`

### Phase 4: Pricing Calculation Pipeline

**Step 11: Load Seat Details & Seating Layout**

- For each held seat, fetch from `Voelgoedevents.Ash.Resources.Seating.Seat`:
  - `block_id` (which block/section/tier)
  - `row_letter`, `seat_number` (for display)
  - `status` (should still be `:held`)
- Build lookup map: `seat_id → seat` for quick reference

**Step 12: Load Pricing Rules for Event**

- Ash read: `Voelgoedevents.Ash.Resources.Ticketing.PricingRule`
  - Filter: `event_id: event_id, organization_id: org_id, status: :active`
  - Result: List of pricing rules (typically one per block/tier)
- Typical structure:
  ```elixir
  %PricingRule{
    block_id: "uuid-section-a",
    price_cents: 50000,
    tier_name: "Section A",
    early_bird_discount_percent: 10,  # optional
    active: true
  }
  ```
- Build lookup map: `block_id → pricing_rule`
- If any held seat has no matching rule → Return `{:error, :pricing_not_configured}`

**Step 13: Calculate Base Price Per Seat**

- For each held seat:
  - Get block pricing from rule: `pricing_rule[seat.block_id].price_cents`
  - Apply early-bird discount (if applicable and valid)
  - Validate price > 0
  - Store: `{seat_id, final_price_cents}`
- Sum: `subtotal_cents = Enum.sum(prices)`

**Step 14: Validate & Apply Promo Code (If Provided)**

- If `promo_code` is nil or empty:
  - `discount_cents = 0`
  - Continue to next step
- If `promo_code` provided:
  - Ash read: `Voelgoedevents.Ash.Resources.Ticketing.Coupon`
    - Filter: `code: promo_code, event_id: event_id, organization_id: org_id, status: :active`
  - If not found or not active → Option A: Return error `{:error, :coupon_not_found}` OR Option B: Silently ignore (UX choice)
  - If found, validate:
    - `valid_from ≤ now ≤ valid_until` (date range active)
    - `uses_count < max_uses` (not exhausted)
    - User hasn't already used this coupon (if one-time-per-user)
  - Calculate discount:
    - If `discount_type: :percentage` → `discount_cents = (subtotal_cents * discount_value) / 100`
    - If `discount_type: :fixed_cents` → `discount_cents = discount_value * 100`
  - Cap: `discount_cents = min(discount_cents, coupon.max_discount_cents)`
  - Prevent negative total: `discount_cents = min(discount_cents, subtotal_cents)`

**Step 15: Calculate Platform & Payment Processor Fees**

- Platform fee (2.5% of subtotal):
  - `platform_fee_cents = round(subtotal_cents * 0.025)`
- Payment processor fee (Stripe ~1.5% + $0.30 per transaction):
  - `payment_fee_cents = round((subtotal_cents * 0.015) + 30)`
- Tip: Fees charged on full subtotal, NOT after discount (standard pricing)

**Step 16: Calculate Taxes (If Applicable)**

- Query event's jurisdiction (e.g., "ZA" for South Africa)
- Call tax calculation service/lookup:
  ```
  tax_cents = calculate_tax(jurisdiction, subtotal - discount)
  ```
- If jurisdiction not recognized → Default to 0 OR Return error (policy choice)
- South African example: VAT = 15% on taxable amount

**Step 17: Calculate Total & Validate**

```
total_cents = subtotal_cents
            - discount_cents
            + platform_fee_cents
            + payment_fee_cents
            + tax_cents
```

Validations:
- `total_cents > 0` (can't charge $0)
- `total_cents ≤ 1_000_000_00` (max ~$100k, fraud prevention)
- If either fails → Return `{:error, :invalid_total}`

---

### Phase 5: Checkout Session Creation (Database)

**Step 18: Create Checkout via Ash Action**

- Resource: `Voelgoedevents.Ash.Resources.Ticketing.Ticket` (NOTE: See Future Implementation Notes for resource placement)
- Action: `:start_checkout` (to be implemented)
- Arguments:
  ```elixir
  %{
    "user_id" => user_id,
    "event_id" => event_id,
    "organization_id" => org_id,
    "status" => :started,
    "subtotal_cents" => subtotal_cents,
    "discount_cents" => discount_cents,
    "platform_fee_cents" => platform_fee_cents,
    "payment_fee_cents" => payment_fee_cents,
    "tax_cents" => tax_cents,
    "total_cents" => total_cents,
    "coupon_code" => promo_code || nil,
    "expires_at" => DateTime.add(DateTime.utc_now(), 900)  # +15 minutes
  }
  ```
- Validations in Ash action:
  - `:user_exists` — Verify user_id valid
  - `:event_published` — Event status is :published or :live
  - `:total_valid` — total_cents > 0
- On success: Checkout record created in PostgreSQL with UUID assigned

**Step 19: Create CheckoutItem Records (Line Items)**

- For each held seat:
  - Create `Voelgoedevents.Ash.Resources.Ticketing.CheckoutItem` (or similar)
  - Arguments:
    ```elixir
    %{
      "checkout_id" => checkout_id,
      "seat_hold_id" => seat_hold_id,
      "seat_id" => seat_id,
      "price_cents" => price_cents_for_this_seat
    }
    ```
- Validate: All inserts succeed
- Count: `length(items) == length(held_seat_ids)`

**Step 20: Atomic Database Commit**

- Both Checkout and all CheckoutItems must be inserted atomically
- If any insert fails → Entire transaction rolls back
- On success: PostgreSQL assigns primary keys (UUIDs), timestamps

---

### Phase 6: Cache & Session Layer

**Step 21: Populate Redis Session Cache**

- Create JSON payload with full checkout details:
  ```json
  {
    "checkout_id": "uuid-...",
    "user_id": "uuid-...",
    "event_id": "uuid-...",
    "organization_id": "uuid-...",
    "status": "started",
    "subtotal_cents": 100000,
    "discount_cents": 10000,
    "total_cents": 106000,
    "expires_at": "2025-11-26T14:20:30Z",
    "coupon_code": "EARLY20",
    "created_at": "2025-11-26T14:05:30Z",
    "items": [
      {
        "seat_id": "uuid-...",
        "seat_hold_id": "uuid-...",
        "block_id": "uuid-section-a",
        "block_name": "Section A",
        "row": "10",
        "seat_number": "42",
        "price_cents": 35000
      },
      ...
    ]
  }
  ```
- Redis command:
  ```
  SET voelgoed:org:{org_id}:checkout:{checkout_id} {json_payload} EX 900
  ```
- TTL: 900 seconds (15 minutes) — same as checkout expiry
- Scope: Cluster-wide (all nodes immediately see via replication)
- Use: Payment step will fetch from Redis for fast authorization check

**Step 22: Optional—ETS In-Memory Tracking**

- If per-node tracking implemented:
  - Table: `:checkout_sessions`
  - Key: `{org_id, checkout_id}`
  - Value: Minimal metadata
    ```elixir
    %{
      user_id: user_id,
      event_id: event_id,
      total_cents: total_cents,
      expires_at: expires_at,
      status: :started
    }
    ```
  - Command: `:ets.insert(:checkout_sessions, {key, value})`
  - TTL: 15 minutes (auto-evict per ETS lifecycle)

---

### Phase 7: Background Jobs & Events

**Step 23: Schedule Oban Cleanup Job**

- Job: `Voelgoedevents.Queues.Workers.AbandonCheckoutJob`
- Schedule: 15 minutes from now + 10-second buffer
- Payload:
  ```elixir
  %{
    "checkout_id" => checkout_id,
    "user_id" => user_id,
    "event_id" => event_id,
    "organization_id" => org_id
  }
  ```
- Max attempts: 3 with exponential backoff
- Job execution (at scheduled time):
  1. Verify checkout still in `:started` status
  2. Release all held seats (mark SeatHolds as `:expired`)
  3. Update Checkout status to `:abandoned`
  4. Broadcast occupancy update via PubSub
  5. Log abandonment in audit trail

**Step 24: Emit Domain Event**

- Event: `CheckoutStarted` (domain event, not Ash resource)
- Payload:
  ```elixir
  %CheckoutStarted{
    checkout_id: checkout_id,
    user_id: user_id,
    event_id: event_id,
    organization_id: org_id,
    total_cents: total_cents,
    seat_count: length(held_seats),
    timestamp: DateTime.utc_now()
  }
  ```
- Published to Ash Domain event bus

**Step 25: Broadcast PubSub Notification (Optional)**

- Topic: `checkout:{org_id}:started`
- Message: CheckoutStarted event (above)
- Subscribers: Analytics workers, admin dashboard, conversion tracking
- Non-blocking: Fire-and-forget, doesn't impact response time

---

### Phase 8: Audit & Response

**Step 26: Write Audit Log**

- Entry:
  ```elixir
  %{
    organization_id: org_id,
    user_id: user_id,
    action: :checkout_started,
    entity_type: :Checkout,
    entity_id: checkout_id,
    changes: %{
      status: :started,
      total_cents: total_cents,
      seat_count: length(held_seats),
      coupon_code: promo_code || nil
    },
    ip_address: conn.remote_ip,
    user_agent: get_req_header(conn, "user-agent") |> List.first(),
    timestamp: DateTime.utc_now()
  }
  ```
- Persisted to audit log table (for compliance, troubleshooting)

**Step 27: Return Success Response**

```json
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-cache, no-store

{
  "data": {
    "checkout_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "started",
    "event_id": "550e8400-e29b-41d4-a716-446655440001",
    "user_id": "550e8400-e29b-41d4-a716-446655440002",
    "organization_id": "550e8400-e29b-41d4-a716-446655440003",
    "subtotal_cents": 100000,
    "discount_cents": 10000,
    "platform_fee_cents": 2500,
    "payment_fee_cents": 1500,
    "tax_cents": 12000,
    "total_cents": 106000,
    "total_dollars": "106.00 ZAR",
    "expires_at": "2025-11-26T14:20:30Z",
    "expires_in_seconds": 900,
    "coupon_applied": "EARLY20",
    "item_count": 3,
    "items": [
      {
        "seat_id": "550e8400-...",
        "block_name": "Section A",
        "row": "10",
        "seat_number": "42",
        "price_cents": 35000
      },
      {
        "seat_id": "550e8400-...",
        "block_name": "Section A",
        "row": "10",
        "seat_number": "43",
        "price_cents": 35000
      },
      {
        "seat_id": "550e8400-...",
        "block_name": "VIP",
        "row": "5",
        "seat_number": "1",
        "price_cents": 30000
      }
    ],
    "payment_options": {
      "methods": ["card", "bank_transfer"],
      "card_processors": ["stripe", "paypal"],
      "ready_for_payment": true,
      "next_step": "/checkout/payment"
    }
  }
}
```

**Step 28: Client-Side: Display Checkout UI**

- Browser receives response and:
  1. Displays checkout summary (seats, pricing breakdown, total)
  2. Shows 15-minute countdown timer (900 → 899 → ... → 0)
  3. Displays payment method options
  4. Button: "Proceed to Payment" → Routes to `complete_checkout` workflow

---

## 7. Failure Modes & Error Handling

| Error | HTTP Code | Cause | Recovery |
|-------|-----------|-------|----------|
| `no_active_holds` | 400 | User has no held seats | "Please select seats first" — redirect to seat selection |
| `hold_not_found` | 400 | Requested seat not held by user | "One or more seats are not held. Please select again." |
| `hold_expired` | 400 | Seat hold aged > 5 min | "Seat hold expired. Please select seats again." |
| `mixed_events` | 400 | Held seats from different events | "Cannot checkout seats from different events." |
| `event_not_available` | 404 | Event not found or not published | "Event not available." |
| `event_sales_closed` | 400 | Outside event sale window | "Ticket sales are closed for this event." |
| `pricing_not_configured` | 500 | Missing pricing rule | Admin must configure pricing rules (operational issue) |
| `coupon_not_found` | 400 | Promo code doesn't exist | "Promo code not found." OR silently skip (UX choice) |
| `coupon_expired` | 400 | Coupon past valid_until date | "Promo code expired." |
| `coupon_max_uses_reached` | 400 | Coupon max_uses exceeded | "Promo code no longer available." |
| `invalid_total` | 400 | total_cents ≤ 0 OR > max | "Invalid pricing calculation. Contact support." |
| `database_error` | 500 | Transaction failed (rare) | Log error, return "Please try again" — user can retry |
| `unauthorized` | 401 | User not authenticated | "Please log in first." |
| `organization_mismatch` | 403 | User org ≠ event org | "Access denied." |

---

## 8. Multi-Tenancy Requirements

### Organization Isolation (Mandatory)

**Session Extraction:**
```elixir
user_id = conn.assigns[:user_id]  # From session/JWT
org_id = conn.assigns[:organization_id]  # From session/JWT
# NEVER accept org_id from request params
```

**All Queries Must Filter by `organization_id`:**
```elixir
# ✅ CORRECT
{:ok, holds} = Ash.read(SeatHold,
  filter: [
    user_id: user_id,
    organization_id: org_id,
    status: :active
  ])

# ❌ WRONG (no org filter)
{:ok, holds} = Ash.read(SeatHold,
  filter: [
    user_id: user_id,
    status: :active
  ])
```

**Redis Key Namespacing:**
```
Key must include organization_id:
voelgoed:org:{org_id}:checkout:{checkout_id}

This prevents any cross-org data access via key collision
```

**Checkout Creation:**
```elixir
# ✅ ALWAYS include organization_id
Ash.create(Checkout, %{
  "organization_id" => org_id,  # ← Required
  "user_id" => user_id,
  "event_id" => event_id,
  ...
})

# Ash multitenancy policy will enforce this
```

**Verification at Each Step:**
- Step 9: Event must have `organization_id: org_id` (not just event_id)
- Step 11: Seats must belong to org (via event_id)
- Step 12: Pricing rules must be org's (via event_id)
- Step 14: Coupon must be org's (via event_id)

---

## 9. Performance & Caching Strategy

### Three-Tier Caching Approach

**Hot Layer: ETS (per-node, optional)**
- Scope: Single Elixir node
- Access: < 1ms
- Use case: Ultra-fast local lookups during payment validation
- TTL: 15 minutes
- Data: Minimal (checkout_id, expires_at, status, total)

**Warm Layer: Redis (cluster-wide)**
- Scope: Entire distributed system
- Access: 5-20ms (network + replication)
- Use case: Multi-node session recovery, fast payment lookup
- TTL: 15 minutes (900 seconds)
- Data: Full checkout state (seats, pricing, totals, all items)
- Replication: Automatic across cluster nodes

**Cold Layer: PostgreSQL (durable)**
- Scope: System of record
- Access: 10-50ms
- Use case: Audit trail, analytics, financial reporting
- Retention: Permanent (retention policy per org)
- Data: Complete Checkout + CheckoutItem records + audit trail
- Indexes: `(user_id, created_at)`, `(event_id, status)`, `(expires_at)`

### Performance Rules

- ✅ No extra DB reads on happy path (Redis sufficient for payment)
- ✅ Batch insert CheckoutItems (multi-row insert, not loop)
- ✅ Pricing rules fetched once, not per-seat
- ✅ Coupon fetched once, not per-seat
- ✅ Async PubSub (fire-and-forget, no blocking)
- ✅ Async Oban job (don't wait for confirmation)

---

## 10. Security & Authorization

### Ash Policies (To Be Implemented)

```elixir
# lib/voelgoedevents/policies/checkout_policy.ex

defmodule Voelgoedevents.Policies.CheckoutPolicy do
  use Ash.Policy

  authorization do
    # Only authenticated users
    authorize_if :user_authenticated
    
    # User can only checkout their own holds
    authorize_if :user_owns_holds
    
    # Event must be published
    authorize_if :event_published
    
    # User's org must own event
    authorize_if :organization_matches
    
    # Rate limit: 1 checkout per user per event per 5 sec (prevent rapid retry abuse)
    authorize_if :rate_limit_not_exceeded
    
    # Deny all other access
    forbid_if :not_authenticated
  end
end
```

### Input Validation

- **Promo code:** String validation, parameterized query (no SQL injection)
- **Seat IDs:** UUID format validation required
- **Totals:** Never trust client—always calculate server-side
- **Request size:** Limit `held_seat_ids` to reasonable max (e.g., 1000 seats)

### Sensitive Data Handling

- **Expose:** Pricing breakdown (item prices, fees, taxes) — customer transparency
- **Log:** Full pricing in audit trail (compliance requirement)
- **Compute:** Server-side only (no client-calculated prices)
- **Protect:** Other users' carts/holds (always filter by user_id + org_id)

---

## 11. Multi-Tenancy & Domain Integration

### Involved Ash Domains

| Domain | Resources | Role in Workflow |
|--------|-----------|------------------|
| **Accounts** | User, Organization, Membership | Validates authentication + org context |
| **Events** | Event | Verifies event published + owns event |
| **Seating** | SeatHold, Seat, Layout | Validates held seats exist + not expired |
| **Ticketing** | Checkout, CheckoutItem, PricingRule, Coupon | Creates checkout session + applies pricing |
| **Payments** | Transaction, LedgerAccount | Prepares accounting entries (not executed here) |

### References to Domain Docs

- `docs/domain/tenancy_accounts.md` — User + Org + Membership rules
- `docs/domain/events_venues.md` — Event lifecycle, publish requirements
- `docs/domain/seating.md` — SeatHold state machine + expiry rules
- `docs/domain/ticketing_pricing.md` — PricingRule + Coupon structure
- `docs/domain/payments_ledger.md` — LedgerAccount setup (not used here, but context)
- `docs/architecture/02_multi_tenancy.md` — Organization isolation patterns

---

## 12. Future Implementation Notes

### Ash Resources & Actions (To Be Created)

**1. Checkout Resource**
```
Module: Voelgoedevents.Ash.Resources.Ticketing.Checkout
File: lib/voelgoedevents/ash/resources/ticketing/checkout.ex

Required attributes:
  - id (UUID, primary key)
  - user_id, event_id, organization_id
  - status (:started, :awaiting_payment, :completed, :abandoned, :failed)
  - subtotal_cents, discount_cents, platform_fee_cents, payment_fee_cents, tax_cents, total_cents
  - coupon_code (optional)
  - expires_at, completed_at
  - created_at, updated_at

Required actions:
  - :start_checkout (create with validations)
  - :complete (transition to :completed)
  - :abandon (transition to :abandoned)

Multitenancy:
  - strategy: :attribute
  - attribute: :organization_id
```

**2. CheckoutItem Resource**
```
Module: Voelgoedevents.Ash.Resources.Ticketing.CheckoutItem
File: lib/voelgoedevents/ash/resources/ticketing/checkout_item.ex

Required attributes:
  - id (UUID, primary key)
  - checkout_id, seat_hold_id, seat_id
  - price_cents

Required actions:
  - :create (with validation: seat_hold is active)

Relationships:
  - belongs_to :checkout
  - belongs_to :seat_hold
```

**3. PricingRule Resource**
```
Module: Voelgoedevents.Ash.Resources.Ticketing.PricingRule
File: lib/voelgoedevents/ash/resources/ticketing/pricing_rule.ex

Expected attributes:
  - id, event_id, block_id
  - price_cents, currency
  - tier_name
  - early_bird_discount_percent, group_discount_threshold
  - status (:active, :archived)
  - valid_from, valid_until

Multitenancy:
  - Via event (event.organization_id)
```

**4. Coupon Resource**
```
Module: Voelgoedevents.Ash.Resources.Ticketing.Coupon
File: lib/voelgoedevents/ash/resources/ticketing/coupon.ex

Expected attributes:
  - id, event_id, organization_id, code
  - discount_type (:percentage, :fixed_cents)
  - discount_value, max_discount_cents
  - valid_from, valid_until
  - max_uses, uses_count
  - status (:active, :paused, :expired, :archived)
  - one_use_per_user (boolean)

Multitenancy:
  - strategy: :attribute
  - attribute: :organization_id
```

### Workflow Orchestration (High-Level)

```elixir
# lib/voelgoedevents/workflows/checkout/start_checkout.ex

defmodule Voelgoedevents.Workflows.Checkout.StartCheckout do
  def run(held_seat_ids, promo_code, user_id, org_id) do
    with {:ok, holds} <- validate_holds(held_seat_ids, user_id, org_id),
         {:ok, event} <- verify_event(holds, user_id, org_id),
         {:ok, pricing} <- calculate_pricing(holds, event, promo_code, org_id),
         {:ok, checkout} <- create_checkout(pricing, user_id, event.id, org_id),
         {:ok, items} <- create_checkout_items(checkout, holds),
         :ok <- populate_cache(checkout, items, org_id),
         :ok <- schedule_cleanup_job(checkout, org_id),
         :ok <- emit_domain_event(checkout, holds),
         :ok <- log_audit_entry(checkout, user_id, org_id)
    do
      {:ok, checkout}
    else
      error -> {:error, error}
    end
  end
  
  # Private helpers...
end
```

### Controller Integration (High-Level)

```elixir
# lib/voelgoedevents_web/controllers/checkout_controller.ex

defmodule VoelgoedeventsWeb.CheckoutController do
  def create(conn, params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    held_seat_ids = params["held_seat_ids"]
    promo_code = params["promo_code"]
    
    case Voelgoedevents.Workflows.Checkout.StartCheckout.run(
      held_seat_ids,
      promo_code,
      user_id,
      org_id
    ) do
      {:ok, checkout} ->
        conn
        |> put_status(200)
        |> json(render_checkout_response(checkout))
      
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: reason})
    end
  end
end
```

### Testing Strategy

- **Unit tests:** Test each step in isolation (hold validation, pricing calc, etc.)
- **Integration tests:** Full workflow with mocked Ash resources
- **Multitenancy tests:** Verify org isolation (no cross-tenant data leakage)
- **Edge case tests:** Expired holds, invalid coupons, zero pricing, etc.

---

## 13. Related Workflows & Dependencies

### Upstream Dependency
- **`reserve_seat.md`** — Creates SeatHold records consumed by this workflow
- Workflow: User selects seat → SeatHold created (5-min TTL)
- Dependency: Cannot start checkout without active holds

### Downstream Dependency
- **`complete_checkout.md`** — Processes payment + issues tickets
- Workflow: User pays → Checkout transitions to :completed → Tickets created
- Dependency: Checkout session must exist + not expired

### Related Cleanup
- **`release_seat.md`** — Releases expired holds
- Triggered: By Oban job if checkout abandoned (Step 23)
- Impact: SeatHolds transition from :held → :available

### Related Analytics
- **`funnel_builder.md`** — Tracks conversion funnel (select → checkout → payment → complete)
- Consumes: CheckoutStarted event from this workflow
- Tracks: Abandonment rate, time-to-checkout, etc.

---

## 14. Success Criteria & Acceptance Tests

### Functional Requirements (Must Have)
- [ ] User can initiate checkout with active held seats
- [ ] Pricing calculated correctly (base + fees + taxes)
- [ ] Promo codes applied correctly (discount capped, not exceeding subtotal)
- [ ] Checkout record persisted to Postgres
- [ ] CheckoutItem records created for each seat
- [ ] Redis cache populated with full state
- [ ] Oban job scheduled for +15 min cleanup
- [ ] Domain event emitted
- [ ] Audit log entry recorded
- [ ] 15-minute expiry enforced (checkout expires, holds released)

### Performance Requirements (Should Have)
- [ ] Checkout response < 500ms (p95)
- [ ] Redis cache < 100ms writes
- [ ] Database transaction < 200ms
- [ ] Pricing calculation < 100ms (even with 100 seats)

### Security Requirements (Must Have)
- [ ] No cross-tenant data leakage (org_id filtering verified)
- [ ] User can only checkout own holds (user_id filtering verified)
- [ ] Pricing calculated server-side only (client cannot tamper)
- [ ] Rate limiting prevents rapid retry abuse

### Edge Cases (Must Handle)
- [ ] Hold expires between step 4 and step 18 (detected + error)
- [ ] Promo code invalid (either error or silently skip)
- [ ] Event published between request + execution (allowed, acceptable race)
- [ ] Event capacity changed (reject if block pricing changed)
- [ ] Redis down during cache write (fallback to DB-only session)

---

**END OF START CHECKOUT WORKFLOW SPECIFICATION**