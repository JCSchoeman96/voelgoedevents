# Workflow: Complete Checkout

**From payment processor confirmation to finalized ticket issuance and double-entry accounting**

---

## 1. Purpose & Overview

**Complete Checkout** is the terminal workflow in the ticket sales funnel. It receives payment confirmation from a payment processor (Stripe, PayPal), validates the checkout session, atomically:

- Converts held seats to sold seats
- Issues tickets with unique codes
- Records double-entry accounting
- Schedules async jobs (QR generation, email confirmation, analytics)
- Broadcasts real-time occupancy updates

**Why it matters:**

- **Prevents double-selling:** Atomic transaction ensures seats aren't sold twice
- **Financial compliance:** Immutable double-entry accounting for tax/audit trails
- **Ticket security:** Unique codes prevent forgery; QR codes enable scanning
- **Real-time occupancy:** Dashboards update immediately (held → sold)
- **Customer communication:** Async email + QR codes sent without blocking webhook
- **Fraud prevention:** Webhook signature validation + idempotency prevent spoofing + double-charging

---

## 2. High-Level Flow

```
Payment Processor Webhook (Stripe/PayPal/etc)
  ↓
  [POST /webhooks/payments/{provider}]
  ↓
Signature validation (prevent spoofing)
  ↓
Idempotency check (prevent double-processing)
  ↓
Fetch & validate checkout session
  ↓
Verify seat holds still active (not expired)
  ↓
ATOMIC TRANSACTION:
  ├─ Create Ticket records (one per seat)
  ├─ Convert SeatHold status → :converted
  ├─ Update Seat status → :sold
  ├─ Record double-entry accounting (LedgerEntry)
  └─ Mark Checkout → :completed
  ↓
Cache invalidation (Redis ETS):
  ├─ Clear checkout cache
  ├─ Clear occupancy cache (will recompute)
  └─ Clear seat hold registry
  ↓
Schedule background jobs:
  ├─ GenerateQRCodeJob (one per ticket)
  ├─ SendConfirmationEmailJob
  └─ RecordAnalyticsEventJob
  ↓
Broadcast PubSub occupancy change
  ↓
Write audit log
  ↓
Return HTTP 200 OK (webhook ack)
```

---

## 3. Preconditions (Must Be True Before Starting)

### Webhook & Payment Verification
- ✅ Webhook request has valid signature (cryptographically verified with PSP secret)
- ✅ Webhook payload includes payment status = "succeeded" or "completed"
- ✅ Webhook includes checkout_id, event_id, organization_id in metadata
- ✅ Webhook idempotency key (provider event ID) not processed before
- ✅ Payment amount matches checkout total (exact cents match)

### Checkout Session Validation
- ✅ Checkout session exists in database
- ✅ Checkout status is `:started` (not already completed or abandoned)
- ✅ Checkout has not expired (expires_at > DateTime.utc_now())
- ✅ Checkout belongs to organization (org_id isolation)
- ✅ All checkout items reference valid seats

### Seat Hold Validation
- ✅ All SeatHold records referenced by checkout still exist
- ✅ All holds are in `:active` status (not expired or already converted)
- ✅ All holds have not passed held_until timestamp
- ✅ No duplicate holds for same seat

### Seat Validation
- ✅ All Seat records are in `:held` status (not sold/available/blocked)
- ✅ Seat's seat_hold_id references current hold (denormalized link)
- ✅ Each seat belongs to event + organization being checked out

### System Prerequisites
- ✅ PostgreSQL database connection available
- ✅ Redis cache available (or graceful fallback mode enabled)
- ✅ Oban job queue accepting new jobs
- ✅ PubSub messaging operational
- ✅ Ledger accounts configured for event (revenue, cash, fees, tax accounts)
- ✅ Payment processor webhook secret configured
- ✅ Multi-tenancy context (organization_id) extracted and validated

---

## 4. Postconditions (What Is True After Success)

### Persistent State (PostgreSQL)

✅ **Ticket Records Created** (one per seat):
```
{
  id: UUID (newly generated),
  seat_id: UUID,
  event_id: UUID,
  organization_id: UUID,
  user_id: UUID,
  checkout_id: UUID,
  status: :active,
  ticket_code: "3KQR-7F92-4M1X" (base62-encoded unique),
  qr_code_url: nil (will be populated by QR job),
  payment_reference: "{stripe_event_id}",
  purchased_at: DateTime.utc_now(),
  created_at: DateTime.utc_now(),
  updated_at: DateTime.utc_now()
}
```

✅ **SeatHold Records Updated**:
```
status: :active → :converted
converted_at: DateTime.utc_now()
(all other fields unchanged)
```

✅ **Seat Records Updated** (with optimistic lock):
```
status: :held → :sold
ticket_id: {newly created ticket UUID}
sold_at: DateTime.utc_now()
held_until: cleared (NULL)
locked_at: cleared (NULL)
seat_hold_id: cleared (NULL)
version: incremented by 1
```

✅ **LedgerEntry Records Created** (double-entry accounting):
```
Multiple entries recording:
  - Debit: Cash account (asset increase)
  - Credit: Event Revenue account (revenue increase)
  - Credit: Platform Fee account (fee component)
  - Credit/Debit: Tax Payable account (if applicable)
  - Debit/Credit: Discount account (if coupon applied)

All entries:
  - organization_id: scoped to tenant
  - reference_type: :Checkout
  - reference_id: checkout_id
  - created_at: DateTime.utc_now()
  - immutable once recorded
```

✅ **Checkout Record Updated**:
```
status: :started → :completed
completed_at: DateTime.utc_now()
payment_reference: "{stripe_event_id}"
(all other fields unchanged)
```

### Cache Layers (Invalidated)

✅ **Redis (Warm Cache)**:
- Key `voelgoed:org:{org_id}:checkout:{checkout_id}` → DELETED
- Key `voelgoed:org:{org_id}:event:{event_id}:occupancy` → DELETED
- Key `voelgoed:org:{org_id}:event:{event_id}:seat_holds` → DELETED
- All propagated to cluster via replication

✅ **ETS (Hot Cache)**:
- Checkout session entry deleted (if present)
- Occupancy cache entry deleted
- Seat hold entries deleted for each seat

### Background Jobs (Scheduled)

✅ **Oban Jobs**:
- `GenerateQRCodeJob`: One job per ticket
  - Will: Encode ticket_code → QR image → Upload to S3 → Update Ticket.qr_code_url
  - Max attempts: 5
  - Queue: `:default` (high priority, doesn't block webhook)

- `SendConfirmationEmailJob`: One job per checkout
  - Will: Fetch ticket codes → Render email template → Send via email provider
  - Max attempts: 3
  - Queue: `:default`

- `RecordAnalyticsEventJob`: One job per checkout
  - Will: Extract dimensions → Update materialized views → Log to analytics warehouse
  - Max attempts: 1 (non-critical)
  - Queue: `:analytics`

### Notifications & Audit

✅ **PubSub Broadcast**:
```
Topic: occupancy:{org_id}:{event_id}
Message: {
  event: :seats_sold,
  seat_ids: [UUID, UUID, ...],
  ticket_count: N,
  total_available: count,
  total_held: count,
  total_sold: count + N,
  timestamp: ISO8601
}
```
- Subscribers: Admin dashboards, analytics workers, real-time occupancy displays

✅ **Audit Log Entry**:
```
{
  organization_id: org_id,
  user_id: checkout.user_id,
  action: :checkout_completed,
  entity_type: :Checkout,
  entity_id: checkout_id,
  changes: {
    status: :completed,
    total_cents: N,
    seat_count: N,
    ticket_ids: [UUID, ...],
    payment_reference: "{stripe_event_id}"
  },
  metadata: {
    payment_processor: :stripe,
    webhook_event_id: "{stripe_event_id}",
    tickets_created: N,
    accounting_entries: N
  },
  timestamp: DateTime.utc_now()
}
```

### API Response (Webhook Acknowledgment)

✅ **HTTP 200 OK**:
```json
{
  "status": "ok",
  "checkout_id": "uuid-...",
  "ticket_count": N,
  "message": "Checkout completed, tickets issued"
}
```
- Status 200: Signal to PSP "don't retry, we processed this"
- Idempotency guaranteed: Subsequent calls with same webhook ID return same result (cached)

### Failure Cases (Guaranteed NOT to happen on error)

❌ On **ANY error**, these are guaranteed NOT to happen:
- ✅ No partial ticket creation (transaction atomic)
- ✅ No seats stranded in :held state (rollback if error)
- ✅ No double-entry violation (balanced journal)
- ✅ No cache corruption (all-or-nothing invalidation)
- ✅ No jobs scheduled for incomplete transactions
- ✅ No customer emails sent for failed checkouts
- ✅ Checkout remains in :started state (can retry or release)

---

## 5. Detailed Step-by-Step Workflow (Happy Path)

### Phase 1: Webhook Reception & Cryptographic Validation

**Step 1: Payment Processor Sends Webhook**

```
POST /webhooks/payments/stripe
Content-Type: application/json
Stripe-Signature: t=1732619400,v1=signature_hash_abcd...

{
  "id": "evt_1A1A1A1A1A1A1A1A",
  "type": "charge.succeeded",
  "created": 1732619400,
  "data": {
    "object": {
      "id": "ch_1A1A1A1A1A1A1A1A",
      "amount": 106000,
      "currency": "zar",
      "status": "succeeded",
      "paid": true,
      "metadata": {
        "checkout_id": "uuid-checkout-xyz",
        "organization_id": "uuid-org-123",
        "event_id": "uuid-event-456"
      }
    }
  }
}
```

**Step 2: Extract Raw Request Body (Before Any Parsing)**

```
Action: Store raw HTTP body (before JSON parsing)
Reason: Stripe signature validation uses exact raw bytes
        (any whitespace differences cause HMAC mismatch)
```

**Step 3: Validate Webhook Signature Cryptographically**

```
Process:
  1. Extract from header: t={timestamp}, v1={provided_hash}
  2. Compute: HMAC-SHA256(webhook_secret, raw_body)
  3. Compare computed hash with provided hash
  4. If mismatch: REJECT (could be spoofed)
  5. If match: ACCEPT (cryptographically verified from Stripe)
```

**Step 4: Validate Webhook Timestamp (Prevent Replay Attacks)**

```
Process:
  1. Parse timestamp from header: t=1732619400
  2. Compare with current time: now = DateTime.utc_now()
  3. If |now - timestamp| > 300 seconds (5 min buffer):
     - REJECT (webhook too old, possible replay)
  4. If within 5 min: ACCEPT (fresh webhook)
```

**Step 5: Parse Webhook Payload**

```
Extract:
  - payment_id: evt_1A1A1A1A1A1A1A1A (from "id" field)
  - payment_status: "succeeded" (from "status" field)
  - payment_amount_cents: 106000 (from "amount" field)
  - payment_reference: evt_1A1A1A1A1A1A1A1A (Stripe event ID)
  - metadata: {checkout_id, organization_id, event_id}
  
Validate:
  - payment_status must be "succeeded" (not pending/failed)
  - amount must be > 0
  - metadata.checkout_id must be non-empty UUID format
  - metadata.organization_id must be non-empty UUID format
  - metadata.event_id must be non-empty UUID format
```

---

### Phase 2: Idempotency & Webhook Deduplication

**Step 6: Check Webhook Idempotency (Prevent Double-Processing)**

```
Process:
  1. Use webhook event ID as idempotency key:
     idempotency_key = "webhook:payment:#{payment_reference}"
  
  2. Query cache (try in order):
     - ETS lookup (per-node, fastest)
     - Redis lookup (cluster-wide)
  
  3. If found:
     - Status = :processing → webhook already in flight, wait/retry
     - Status = :completed → webhook already processed, return cached result
     - Status = :failed → webhook failed, return error (don't retry)
  
  4. If NOT found:
     - Status = :not_seen → First time, proceed to checkout validation
     - Mark in cache: idempotency_key = :processing
     - TTL: 24 hours (keep record for audit)

Purpose: If Stripe retries webhook (network hiccup), we don't:
  - Create duplicate tickets
  - Double-charge ledger
  - Send duplicate emails
```

---

### Phase 3: Checkout Session Validation

**Step 7: Fetch Checkout from Cache (Then Database)**

```
Cache lookup strategy:
  1. Try Redis (warm cache): redis_key = voelgoed:org:{org_id}:checkout:{checkout_id}
     - If hit: Deserialize, proceed to Step 8
     - If miss: Continue to step 2
  
  2. Query PostgreSQL:
     {:ok, checkout} = Ash.get(Checkout, checkout_id,
       filter: [organization_id: org_id])
     
     (Multi-tenancy filter: organization_id prevents cross-tenant leaks)
  
  3. Cache result: Store in Redis (TTL: 15 minutes)
  
  4. If not found: {:error, :checkout_not_found}

Extracted fields:
  - checkout.status (must be :started)
  - checkout.expires_at (must be > now)
  - checkout.total_cents (must match payment_amount_cents)
  - checkout.user_id (for audit trail)
  - checkout.discount_cents (for accounting)
  - checkout.platform_fee_cents (for accounting)
  - checkout.tax_cents (for tax reporting)
```

**Step 8: Verify Checkout Status is :started (Not Already Completed)**

```
Check: checkout.status == :started
If false: {:error, :checkout_not_started, %{current_status: checkout.status}}

Why: Checkout can transition to:
  - :completed (payment success) — can't retry
  - :abandoned (user cancelled) — can't retry
  - :failed (payment declined) — can retry with new payment

If user paid twice, second webhook finds checkout in :completed state
→ Idempotent: Return cached result from first completion
```

**Step 9: Verify Checkout Has Not Expired**

```
Check: checkout.expires_at > DateTime.utc_now()
If false: {:error, :checkout_expired, %{expired_at: checkout.expires_at}}

Why: Checkout sessions are time-limited (typically 15 minutes)
     If customer doesn't pay within window, seats are released back
     Payment after expiry should be rejected (user should re-checkout)
```

**Step 10: Verify Payment Amount Matches Checkout Total**

```
Check: payment_amount_cents == checkout.total_cents
If false: {:error, :amount_mismatch, %{
  expected_cents: checkout.total_cents,
  received_cents: payment_amount_cents
}}

Why: Fraud detection
     - Customer might manipulate amount in payment form
     - Payment processor might record different amount
     - Mismatch signals potential fraud → alert fraud team
```

---

### Phase 4: Seat Hold Validation

**Step 11: Fetch All Seat Holds Referenced by Checkout**

```
Process:
  1. Query checkout items (line items):
     {:ok, items} = Ash.read(CheckoutItem,
       filter: [checkout_id: checkout_id])
  
  2. Extract hold IDs from items:
     hold_ids = items |> Enum.map(& &1.seat_hold_id)
  
  3. Fetch holds:
     {:ok, holds} = Ash.read(SeatHold,
       filter: [
         id: {:in, hold_ids},
         organization_id: org_id
       ])
  
  4. Verify count matches:
     unless length(holds) == length(items) do
       {:error, :missing_holds, %{expected: length(items), found: length(holds)}}
     end

Purpose: Ensure all seats user selected are still reserved
```

**Step 12: Verify All Holds Are :active (Not Expired/Converted)**

```
Process:
  1. Check each hold:
     for hold <- holds do
       unless hold.status == :active do
         {:error, :hold_not_active, %{
           hold_id: hold.id,
           status: hold.status
         }}
       end
     end
  
  2. Why this matters:
     - :expired → Hold auto-released 5 min after reservation (TTL)
     - :converted → Already converted to ticket by another payment
     - :cancelled → User or system cancelled explicitly
  
  3. Recovery: Ask user to re-select seats (they may be taken)

Timing: This check happens ~5 minutes after user clicked "reserve"
        Most holds are still valid, but occasional expirations happen
```

**Step 13: Verify All Holds Have Not Passed Expiry Time**

```
Process:
  now = DateTime.utc_now()
  
  expired_holds = holds
    |> Enum.filter(fn h -> h.held_until <= now end)
  
  if not Enum.empty?(expired_holds) do
    {:error, :holds_expired, %{
      count: length(expired_holds),
      hold_ids: Enum.map(expired_holds, & &1.id)
    }}
  end

Why separate check:
  - Previous check saw status = :active
  - But time may have passed between check + TTL cleanup job running
  - This check catches edge case: hold still :active but time expired
```

---

### Phase 5: Seat Validation

**Step 14: Fetch All Seats Being Purchased**

```
Process:
  1. Extract seat IDs from checkout items:
     seat_ids = items |> Enum.map(& &1.seat_id)
  
  2. Fetch seats:
     {:ok, seats} = Ash.read(Seat,
       filter: [
         id: {:in, seat_ids},
         event_id: event_id,
         organization_id: org_id,
         status: :held  # Only held seats can be sold
       ])
  
  3. Verify count:
     unless length(seats) == length(items) do
       {:error, :seats_not_held}
     end

Purpose: Verify seats still in held state (not sold by another customer)
```

**Step 15: Verify Seat-Hold Cross-Reference (Denormalized Link)**

```
Process:
  for {item, seat} <- Enum.zip(items, seats) do
    unless seat.seat_hold_id == item.seat_hold_id do
      {:error, :seat_hold_mismatch, %{
        seat_id: seat.id,
        expected_hold: item.seat_hold_id,
        actual_hold: seat.seat_hold_id
      }}
    end
  end

Why:
  - Seats and holds have denormalized foreign key reference
  - Verify consistency (data integrity check)
  - Detects: Another process changed seat_hold_id (shouldn't happen)
```

---

### Phase 6: Accounting Setup (Fetch Ledger Accounts)

**Step 16: Fetch Required Ledger Accounts**

```
Process:
  1. Fetch chart of accounts for organization:
     {:ok, cash_account} = get_ledger_account(:cash, org_id)
     {:ok, revenue_account} = get_ledger_account(:event_revenue, org_id, event_id)
     {:ok, platform_fee_account} = get_ledger_account(:platform_fee, org_id)
     {:ok, tax_payable_account} = get_ledger_account(:sales_tax_payable, org_id)
     
     if checkout.discount_cents > 0 do
       {:ok, discount_account} = get_ledger_account(:discount_expense, org_id)
     end
  
  2. Verify all exist:
     if nil?(cash_account) or nil?(revenue_account) do
       {:error, :missing_ledger_accounts, %{
         missing: ["cash_account", "revenue_account"]
       }}
     end

Why: Before transaction starts, verify accounts exist
     Prevents partial transaction + double-entry violation
     (Missing account = accounting becomes unbalanced)

Reference: docs/domain/payments_ledger.md for chart of accounts structure
```

---

### Phase 7: Atomic Transaction (All-or-Nothing)

**Step 17: Begin Database Transaction**

```
Result = Ash.Repo.transaction(fn ->
  # Steps 18-22 execute ATOMICALLY within this transaction
  # If any error occurs, entire transaction rolls back
  # Either ALL succeed or ALL fail (no partial state)
end)

case Result do
  {:ok, {tickets, holds, seats, entries, checkout}} ->
    continue_to_phase_8(...)
  
  {:error, :optimistic_lock_failed} ->
    # One of seats.version changed (concurrent update)
    # Retry entire workflow with updated version
    {:error, :seat_concurrency_conflict}
  
  {:error, reason} ->
    # Any other error: entire transaction rolls back
    {:error, :transaction_failed, reason}
end
```

**Step 18: Create Ticket Records (Within Transaction)**

```
Process:
  1. Generate unique ticket code for each seat:
     ticket_code = Base62.encode(SecureRandom.uuid()) 
     # Example: "3KQR-7F92-4M1X"
  
  2. Create Ticket resource (per seat):
     tickets = for item <- items do
       {:ok, ticket} = Ash.create(Ticket, %{
         "seat_id" => item.seat_id,
         "event_id" => event_id,
         "organization_id" => org_id,
         "user_id" => checkout.user_id,
         "checkout_id" => checkout_id,
         "status" => :active,
         "ticket_code" => ticket_code,
         "payment_reference" => payment_reference,
         "purchased_at" => DateTime.utc_now()
       }, authorize?: false)
       ticket
     end
  
  3. Verify all created:
     unless length(tickets) == length(items) do
       raise "Ticket creation incomplete"
     end

Purpose:
  - One ticket per purchased seat
  - ticket_code: Unique identifier for scanning/verification
  - status: :active (usable, not yet scanned or voided)
  - payment_reference: Links to payment processor for audit
```

**Step 19: Convert SeatHold Status to :converted (Within Transaction)**

```
Process:
  for hold <- holds do
    {:ok, _} = Ash.update(hold, :convert_to_ticket, %{
      "status" => :converted,
      "converted_at" => DateTime.utc_now()
    }, authorize?: false)
  end

Purpose:
  - Mark hold as no longer active (released from circulation)
  - status: :active → :converted (immutable state transition)
  - Timestamp: When hold became a paid ticket
  - Prevent: Cleanup job from releasing hold (it sees :converted, skips)
```

**Step 20: Update Seat Status to :sold (Within Transaction, with Optimistic Lock)**

```
Process:
  for seat <- seats do
    # Fetch current version (already done in Step 15)
    current_version = seat.version
    new_version = current_version + 1
    
    # Find associated ticket
    ticket = Enum.find(tickets, fn t -> t.seat_id == seat.id end)
    
    # Update with optimistic lock
    {:ok, updated_seat} = Ash.update(seat, :sell, %{
      "ticket_id" => ticket.id,
      "status" => :sold,
      "sold_at" => DateTime.utc_now(),
      "held_until" => nil,
      "locked_at" => nil,
      "seat_hold_id" => nil,
      "version" => new_version
    }, authorize?: false)
    
    # SQL executed (with version check):
    # UPDATE seats
    # SET ticket_id = :ticket_id,
    #     status = 'sold',
    #     sold_at = :now,
    #     held_until = NULL,
    #     locked_at = NULL,
    #     seat_hold_id = NULL,
    #     version = :new_version
    # WHERE id = :seat_id
    #   AND version = :current_version
    #   AND organization_id = :org_id
    # RETURNING *;
    #
    # If version != current_version: Transaction ROLLS BACK entirely
  end

Purpose:
  - Optimistic lock prevents race condition (two buyers for same seat)
  - If concurrent buyer also purchased seat, their transaction arrived first
  - Our version check fails, we retry (max 3 attempts with backoff)
  - Ticket remains held, customer can select different seat
```

**Step 21: Record Double-Entry Accounting (Within Transaction)**

```
Process: Create LedgerEntry records (balanced journal)

  1. ENTRY 1: Cash In (Debit Cash, Credit Revenue)
     {:ok, entry1} = Ash.create(LedgerEntry, %{
       "account_debit_id" => cash_account.id,
       "account_credit_id" => revenue_account.id,
       "amount_cents" => checkout.subtotal_cents,
       "description" => "Payment: #{length(seats)} seats, event #{event_id}",
       "reference_type" => :Checkout,
       "reference_id" => checkout_id,
       "organization_id" => org_id
     })
     # Journal: DR Cash | CR Revenue = subtotal

  2. ENTRY 2: Platform Fee (Debit Platform Fee, Credit Cash)
     {:ok, entry2} = Ash.create(LedgerEntry, %{
       "account_debit_id" => platform_fee_account.id,
       "account_credit_id" => cash_account.id,
       "amount_cents" => checkout.platform_fee_cents,
       "description" => "Platform fee (2.5%)",
       "reference_type" => :Checkout,
       "reference_id" => checkout_id,
       "organization_id" => org_id
     })
     # Journal: DR Platform Fee | CR Cash = fee

  3. ENTRY 3: Sales Tax (Debit Revenue, Credit Tax Payable)
     if checkout.tax_cents > 0 do
       {:ok, entry3} = Ash.create(LedgerEntry, %{
         "account_debit_id" => revenue_account.id,
         "account_credit_id" => tax_payable_account.id,
         "amount_cents" => checkout.tax_cents,
         "description" => "Sales tax payable",
         "reference_type" => :Checkout,
         "reference_id" => checkout_id,
         "organization_id" => org_id
       })
       # Journal: DR Revenue Expense | CR Tax Payable = tax
     end

  4. ENTRY 4: Discount (If Coupon Applied)
     if checkout.discount_cents > 0 do
       {:ok, entry4} = Ash.create(LedgerEntry, %{
         "account_debit_id" => discount_account.id,
         "account_credit_id" => revenue_account.id,
         "amount_cents" => checkout.discount_cents,
         "description" => "Discount: #{checkout.coupon_code}",
         "reference_type" => :Checkout,
         "reference_id" => checkout_id,
         "organization_id" => org_id
       })
       # Journal: DR Discount Expense | CR Revenue = discount
     end

Accounting Principle:
  - Double-entry: Every debit has a credit (sum to zero)
  - No single-entry accounting (prevents fraud/manipulation)
  - All entries linked to checkout_id (audit trail)
  - Immutable once recorded (append-only)
  - Multi-tenant: All scoped by organization_id
```

**Step 22: Mark Checkout as :completed (Within Transaction)**

```
Process:
  {:ok, completed_checkout} = Ash.update(checkout, :complete, %{
    "status" => :completed,
    "completed_at" => DateTime.utc_now(),
    "payment_reference" => payment_reference
  }, authorize?: false)

Status transition:
  :started → :completed

Idempotency:
  - If webhook retried, checkout already :completed
  - Step 8 check will catch this, return cached result
```

**Step 23: Commit Transaction**

```
Transaction automatically commits if no errors raised
All records now durable in PostgreSQL

Log entry:
  "Checkout completed atomically: checkout_id=..., payment_reference=..., tickets_issued=N"
```

---

### Phase 8: Cache Invalidation (Post-Transaction)

**Step 24: Invalidate Redis Cache Entries**

```
Process (after transaction committed):

  1. Invalidate checkout cache:
     redis_key = "voelgoed:org:#{org_id}:checkout:#{checkout_id}"
     Redix.command!(:redis, ["DEL", redis_key])
     # Prevents: New webhook with same checkout_id getting stale session
  
  2. Invalidate occupancy cache (will be recomputed on next query):
     occupancy_key = "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"
     Redix.command!(:redis, ["DEL", occupancy_key])
     # Next occupancy query: fresh count from DB
  
  3. Invalidate seat hold registry:
     holds_key = "voelgoed:org:#{org_id}:event:#{event_id}:seat_holds"
     Redix.command!(:redis, ["DEL", holds_key])
     # Prevents: Cache showing holds that are now converted

Order matters: Database changes first, THEN cache cleared
               (Never cache-clear before DB commit)
```

**Step 25: Invalidate ETS Cache Entries (Per-Node)**

```
Process (per-node, parallel):

  1. Delete checkout session:
     :ets.delete(:checkout_sessions, {org_id, checkout_id})
  
  2. Delete occupancy cache:
     :ets.delete(:occupancy_cache, {org_id, event_id})
  
  3. Delete seat hold entries:
     for hold <- holds do
       :ets.delete(:seat_holds_hot, {org_id, hold.seat_id})
     end

Purpose: Clear hot cache on this node
         Other nodes will eventually evict via TTL
         No need for coordination
```

---

### Phase 9: Background Jobs (Non-Blocking)

**Step 26: Schedule QR Code Generation Job**

```
Process:
  for ticket <- tickets do
    %{
      "ticket_id" => ticket.id,
      "ticket_code" => ticket.ticket_code,
      "event_id" => event_id,
      "organization_id" => org_id
    }
    |> Voelgoedevents.Queues.WorkerGenerateQRCode.new()
    |> Oban.insert()
  end

Job Definition (async worker):
  - Module: Voelgoedevents.Queues.WorkerGenerateQRCode
  - File: lib/voelgoedevents/queues/worker_generate_qr_code.ex
  - Responsibility:
    1. Fetch Ticket record
    2. Generate QR code image (encode ticket_code as QR data)
    3. Upload to S3 / CDN (e.g., Cloudinary, AWS S3)
    4. Update Ticket.qr_code_url with CDN URL
    5. Mark Ticket.qr_generated_at timestamp
  - Max retries: 5 (with exponential backoff)
  - Max runtime: 30 seconds
  - On failure: Log error, retry later (fallback: ticket issued but without QR)

Why async:
  - Webhook response returned immediately (don't block payment processor)
  - QR generation is I/O-heavy (network upload)
  - Email can be sent without QR (fallback: email includes ticket code)
```

**Step 27: Schedule Confirmation Email Job**

```
Process:
  %{
    "checkout_id" => checkout_id,
    "user_id" => checkout.user_id,
    "user_email" => user.email,
    "event_id" => event_id,
    "organization_id" => org_id,
    "ticket_ids" => Enum.map(tickets, & &1.id),
    "total_cents" => checkout.total_cents
  }
  |> Voelgoedevents.Queues.WorkerSendConfirmationEmail.new()
  |> Oban.insert()

Job Definition (async worker):
  - Module: Voelgoedevents.Queues.WorkerSendConfirmationEmail
  - File: lib/voelgoedevents/queues/worker_send_confirmation_email.ex
  - Responsibility:
    1. Fetch Ticket records (with QR code URLs, if ready)
    2. Fetch Event details (name, date, location)
    3. Render email template (HTML + text)
    4. Send via email provider (SendGrid, Mailgun, SMTP)
    5. Log email sent timestamp
  - Max retries: 3 (with exponential backoff)
  - Max runtime: 20 seconds
  - On failure: Retry later (customer can check email page or resend manually)

Email content includes:
  - Order confirmation (ticket codes)
  - QR codes (if ready) or instruction to download later
  - Event details (date, time, location, instructions)
  - Refund/cancellation policy
  - Support contact
```

**Step 28: Schedule Analytics Event Job**

```
Process:
  %{
    "event_type" => :purchase_completed,
    "organization_id" => org_id,
    "event_id" => event_id,
    "user_id" => checkout.user_id,
    "checkout_id" => checkout_id,
    "total_cents" => checkout.total_cents,
    "seat_count" => length(tickets),
    "coupon_code" => checkout.coupon_code || nil,
    "timestamp" => DateTime.utc_now()
  }
  |> Voelgoedevents.Queues.WorkerRecordAnalyticsEvent.new()
  |> Oban.insert()

Job Definition (async worker):
  - Module: Voelgoedevents.Queues.WorkerRecordAnalyticsEvent
  - File: lib/voelgoedevents/queues/worker_record_analytics_event.ex
  - Responsibility:
    1. Extract dimensions (event, user, coupon, revenue)
    2. Increment materialized view counters (purchase count, revenue)
    3. Log to analytics warehouse (Google Analytics, Mixpanel, custom DB)
    4. Update funnel metrics (reserve → checkout → purchase)
  - Max retries: 1 (non-critical, don't over-retry)
  - Max runtime: 10 seconds
  - On failure: Continue (don't block checkout completion)

Analytics captured:
  - Funnel stage: Purchase
  - Revenue: total_cents
  - Conversion time: time from checkout creation to completion
  - Coupon effectiveness: Did discount help close sale?
```

**Step 29: Emit Domain Event**

```
Event: Voelgoedevents.Domain.Events.CheckoutCompleted

Payload:
  checkout_id: UUID,
  user_id: UUID,
  event_id: UUID,
  organization_id: UUID,
  total_cents: integer,
  seat_count: integer,
  ticket_ids: [UUID, ...],
  payment_reference: string,
  timestamp: DateTime

Consumers:
  - CRM system: Update customer record (purchase history)
  - Loyalty system: Award points (if applicable)
  - Reporting: Aggregate for dashboard
  - Notifications: Trigger SMS/push notifications
```

---

### Phase 10: Real-Time Notifications

**Step 30: Broadcast PubSub Occupancy Update**

```
Process:
  topic = "occupancy:#{org_id}:#{event_id}"
  
  message = %{
    event: :seats_sold,
    seat_ids: Enum.map(tickets, & &1.seat_id),
    ticket_count: length(tickets),
    released_at: DateTime.utc_now(),
    
    # Optional: recalculate fresh occupancy
    occupancy: %{
      total_available: calculate_available(event_id, org_id),
      total_held: calculate_held(event_id, org_id),
      total_sold: calculate_sold(event_id, org_id),
      percent_available: ...,
      percent_held: ...,
      percent_sold: ...
    },
    
    timestamp: DateTime.to_iso8601(DateTime.utc_now())
  }
  
  Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, topic, message)

Subscribers:
  - Admin dashboard (LiveView): Display real-time occupancy bar
  - Analytics worker: Track occupancy over time
  - Client-side JS: Update available seat count for other users
  - Notification system: Send alerts if occupancy > 90%
```

---

### Phase 11: Audit & Webhook Acknowledgment

**Step 31: Write Audit Log Entry**

```
Entry:
  {
    organization_id: org_id,
    user_id: checkout.user_id,
    action: :checkout_completed,
    entity_type: :Checkout,
    entity_id: checkout_id,
    
    changes: %{
      status: {from: :started, to: :completed},
      total_cents: checkout.total_cents,
      seat_count: length(tickets),
      ticket_ids: Enum.map(tickets, & &1.id),
      payment_reference: payment_reference,
      platform_fee_cents: checkout.platform_fee_cents,
      tax_cents: checkout.tax_cents,
      discount_cents: checkout.discount_cents
    },
    
    metadata: %{
      payment_processor: :stripe,
      webhook_event_id: payment_reference,
      tickets_created: length(tickets),
      ledger_entries: entry_count,
      cache_invalidated: true,
      jobs_scheduled: 3
    },
    
    timestamp: DateTime.utc_now()
  }
  |> Ash.create!(AuditLog)

Purpose:
  - Compliance: Non-repudiation (proof of transaction)
  - Support: Troubleshooting (what happened when)
  - Analytics: Trend analysis (purchase patterns)
  - Fraud: Historical record for investigation
```

**Step 32: Mark Webhook as Processed (Update Idempotency Cache)**

```
Process:
  idempotency_key = "webhook:payment:#{payment_reference}"
  
  # Update cache: mark as completed
  :ets.insert(:webhook_cache, {idempotency_key, {:completed, result}})
  
  # Store result: cached response for retries
  # TTL: 24 hours (keep for audit trail)

Purpose:
  - If webhook retried 1 minute later: Return cached result immediately
  - If webhook retried 1 hour later: Return cached result
  - Only one "real" processing happens, rest are served from cache
```

**Step 33: Return HTTP 200 OK (Webhook Acknowledgment)**

```
Response:
  HTTP/1.1 200 OK
  Content-Type: application/json
  
  {
    "status": "ok",
    "message": "Checkout completed successfully",
    "checkout_id": checkout_id,
    "ticket_count": length(tickets),
    "payment_reference": payment_reference
  }

HTTP Status Semantics:
  - 200 OK: "Successfully processed, don't retry"
  - 4xx: "Bad request, won't fix, don't retry"
  - 5xx: "Transient error, retry later"

Stripe behavior:
  - Receives 200: Stops retrying
  - Receives 5xx: Retries up to 7 times (exponential backoff)
  - Timeout: Treats as 5xx, retries
```

---

### Phase 12: Client-Side Confirmation (Polling)

**Step 34: Client Polls for Ticket Confirmation**

```javascript
// Browser: Svelte component or vanilla JS

let ticketsReady = false;

onMount(() => {
  // Poll endpoint to check if tickets ready
  const pollInterval = setInterval(async () => {
    const response = await fetch(`/api/tickets?checkout_id=${checkoutId}`);
    
    if (response.ok) {
      const tickets = await response.json();
      ticketsReady = true;
      clearInterval(pollInterval);
      
      // Display:
      // - "Order Confirmed!"
      // - Ticket codes (e.g., "3KQR-7F92-4M1X")
      // - QR codes (once generated)
      // - Download / Print options
      // - Add to Calendar
    }
  }, 2000); // Poll every 2 seconds
  
  // Timeout: Stop polling after 5 minutes
  setTimeout(() => clearInterval(pollInterval), 300000);
});

// Fallback:
// - If polling times out, show "Check your email"
// - Customer can check email page to download tickets later
```

---

## 6. Edge Cases & Failure Modes

| Edge Case | Cause | Prevention | Recovery |
|-----------|-------|-----------|----------|
| **Duplicate webhook** | Payment processor retries | Idempotency key check (webhook event ID) | Return cached result, skip reprocessing |
| **Webhook out of order** | Provider sends events out of sequence | State validation (checkout.status == :started) | Reject, return 5xx (retry signal) |
| **Checkout expired** | User took > 15 min at payment screen | Verify expires_at > now | Return 400 (no-retry), user re-selects |
| **Seat hold expired** | Hold TTL (5 min) passed during payment | Re-verify holds.held_until | Return 400 (no-retry), user re-selects |
| **Seat already sold** | Another user purchased same seat concurrently | Optimistic lock (Seat.version) | Transaction rolls back, retry (max 3x) |
| **Amount mismatch** | Webhook has wrong amount vs checkout | Verify payment_amount_cents == checkout.total_cents | Return 400 (no-retry), alert fraud team |
| **Missing ledger accounts** | Chart of accounts not configured for org | Validate accounts exist before transaction | Return 500 (retry), alert accounting team |
| **QR generation fails** | S3 upload fails, encoding error | Oban job retry (5 times) | Email still sent, ticket still valid, QR generated later |
| **Email delivery fails** | SMTP server down | Oban job retry (3 times) | Ticket still created, email retried, customer can resend |
| **Invalid webhook signature** | Spoofed webhook from attacker | HMAC-SHA256 validation | Reject with 400, log security alert |
| **Webhook too old (replay)** | Webhook timestamp > 5 min old | Timestamp validation | Reject with 400, don't process |
| **Concurrent payment** | Two payments for same user (double-tap) | Webhook idempotency + database unique constraint | First transaction succeeds, second gets cached result |
| **Database connection lost** | PostgreSQL unavailable | Connection pooling + failover | Return 500 (retry), Oban queues job for later |
| **Redis unavailable** | Cache cluster down | Graceful fallback (proceed with DB only) | Warn in logs, don't block checkout (cache is optional) |
| **Transaction timeout** | Very large transaction (many seats) | Database connection pool tuning | Retry with exponential backoff |
| **PubSub broadcast fails** | Message broker down | Async fire-and-forget (don't block response) | Log warning, occupancy updates manually on next query |

---

## 7. Idempotency & Webhook Handling

### Idempotency Guarantees

```
Webhook sent from Stripe: evt_1A1A1A1A1A1A1A1A
  ↓
First processing:
  - Create tickets
  - Convert holds
  - Record accounting
  - Mark checkout :completed
  - Return 200 + cached result

Stripe retries (network hiccup):
  - Idempotency key: evt_1A1A1A1A1A1A1A1A
  - Cache lookup: Found, status = :completed
  - Return cached 200 response (same as first call)
  - NO new tickets created
  - NO double ledger entries
  - NO duplicate emails

Result: Exactly once semantics guaranteed
```

### Idempotency Key Management

```
Key: webhook:payment:{payment_reference}
     (e.g., "webhook:payment:evt_1A1A1A1A1A1A1A1A")

Value: {
  status: :processing | :completed | :failed,
  result: {...},  // cached response
  timestamp: DateTime,
  attempts: N
}

TTL: 24 hours
  - Prevents double-processing within 24 hour window
  - After 24 hours: key expires, old webhook reprocessed if seen again
  - (Stripe only retries for ~24 hours anyway)

Storage: ETS + Redis
  - ETS: per-node, < 1ms lookups
  - Redis: cluster-wide, replication for HA
```

---

## 8. Multi-Tenancy & Security

### Organization Isolation (CRITICAL)

**Rule 1: Extract org_id from Webhook Metadata**

```elixir
# ✅ CORRECT
org_id = webhook_payload.data.object.metadata.organization_id

# ❌ WRONG
org_id = params["organization_id"]  # User can spoof!
org_id = conn.path_params["org_id"]  # Not in webhook body
```

**Rule 2: All Database Queries Include org_id Filter**

```elixir
# ✅ CORRECT
Ash.get(Checkout, checkout_id,
  filter: [organization_id: org_id, ...])

# ❌ WRONG
Ash.get(Checkout, checkout_id)  # Missing org filter!
```

**Rule 3: Multi-Tenancy at Resource Level**

```elixir
# All resources declare tenancy strategy
multitenancy do
  strategy :attribute
  attribute :organization_id  # Partition by org
end

# Ash automatically enforces filter in all queries
```

**Rule 4: Audit Logging Includes org_id**

```elixir
# ✅ REQUIRED
Ash.create!(AuditLog, %{
  "organization_id" => org_id,  # ← ALWAYS
  "user_id" => user_id,
  "action" => :checkout_completed,
  ...
})
```

### Webhook Security

**Signature Validation (Non-Negotiable)**

```
Process:
  1. Receive raw HTTP body (before any parsing)
  2. Extract Stripe-Signature header
  3. Compute: HMAC-SHA256(webhook_secret, raw_body)
  4. Compare with provided signature
  5. If mismatch: REJECT (return 400)
  6. If match: ACCEPT (cryptographically verified)

Why:
  - Prevents man-in-the-middle attack
  - Prevents webhook spoofing
  - Only Stripe (with secret) can create valid signatures

Secret management:
  - Store in environment variables (not in code)
  - Rotate occasionally
  - Never log or expose
```

**Timestamp Validation (Replay Prevention)**

```
Process:
  1. Extract timestamp from Stripe-Signature header
  2. Verify: |current_time - signature_time| < 300 seconds
  3. If too old: REJECT (possible replay attack)

Why:
  - Prevents attacker replaying old webhooks
  - 5-minute window allows for clock skew
```

### Sensitive Data Handling

- **Don't expose:** Payment card numbers, customer SSN, full transaction amounts to unauthorized users
- **Do expose:** Ticket codes, event details, receipt summary, tax amounts
- **Log:** Payment reference, amount, event ID (for audit)
- **Secure:** All accounting entries immutable once recorded

---

## 9. Performance & Consistency

### Atomic Transaction Guarantees

```
Scenario: Two concurrent customers buying last 2 seats

Customer A's transaction:
  BEGIN TRANSACTION
  Check: seat_1.version = 1
  UPDATE seat_1 SET version = 2 WHERE version = 1  ✓ SUCCEEDS

Customer B's transaction:
  BEGIN TRANSACTION
  Check: seat_2.version = 1
  UPDATE seat_2 SET version = 2 WHERE version = 1  ✓ SUCCEEDS

Both transactions commit:
  - Customer A gets seat_1
  - Customer B gets seat_2
  - No double-selling

Scenario: One customer tries to buy same seat twice

Transaction 1:
  UPDATE seat_1 SET version = 2 WHERE version = 1  ✓ SUCCEEDS

Transaction 2 (concurrent):
  UPDATE seat_1 SET version = 2 WHERE version = 1  ✗ FAILS
  (version is already 2)
  
  Entire transaction rolls back:
    - No second ticket created
    - Seat remains sold (to first customer)
    - Second customer asked to select different seat
```

### Three-Tier Caching Strategy

**Hot Layer: ETS (Per-Node, < 1ms)**
```
Tables:
  - :webhook_cache (idempotency tracking)
  - :checkout_sessions (session cache)
  - :occupancy_cache (computed counts)

TTL: 15-24 hours
Use case: Fast idempotency checks, avoid database hits
```

**Warm Layer: Redis (Cluster-Wide, < 10ms)**
```
Keys:
  - voelgoed:org:{org_id}:checkout:{checkout_id}
  - voelgoed:org:{org_id}:event:{event_id}:occupancy

TTL: 15 minutes (auto-expire)
Use case: Cross-node consistency, warm startup
```

**Cold Layer: PostgreSQL (Durable, 5-50ms)**
```
Tables: checkouts, tickets, ledger_entries, seats
Use case: Source of truth, audit trail, analytics
```

### Performance Targets

| Operation | Latency | Notes |
|-----------|---------|-------|
| Webhook signature validation | < 10ms | Crypto operation |
| Idempotency check (ETS hit) | < 1ms | Hash lookup |
| Checkout fetch (Redis hit) | < 10ms | Network latency |
| Seat hold verification | 5-20ms | Index scan, verify holds |
| Atomic transaction | 50-200ms | Depends on seat count |
| Cache invalidation | 5-20ms | Batch Redis commands |
| Job scheduling (Oban) | < 10ms | Queue insert |
| Total webhook response | 100-300ms | Typical end-to-end |

---

## 10. Implementation Targets

### Ash Resources & Actions

**1. Ticket Resource (:create action)**

```
Module: Voelgoedevents.Ash.Resources.Ticketing.Ticket
File: lib/voelgoedevents/ash/resources/ticketing/ticket.ex

Actions:
  :create
    - Arguments: seat_id, event_id, user_id, checkout_id, status, ticket_code
    - Changes: Set attributes as provided
    - Validations:
      - :ticket_code_unique (no duplicates)
      - :seat_exists (foreign key validation)
      - :organization_matches (multi-tenancy)

  :scan (future workflow)
    - Mark ticket as :scanned
    - Record scanned_at timestamp
```

**2. SeatHold Resource (:convert_to_ticket action)**

```
Module: Voelgoedevents.Ash.Resources.Seating.SeatHold
File: lib/voelgoedevents/ash/resources/seating/seat_hold.ex

Actions:
  :convert_to_ticket
    - Arguments: (none)
    - Changes:
      - Set status → :converted
      - Set converted_at → DateTime.utc_now()
    - Validations:
      - :status_active (only :active holds can convert)
```

**3. Seat Resource (:sell action)**

```
Module: Voelgoedevents.Ash.Resources.Seating.Seat
File: lib/voelgoedevents/ash/resources/seating/seat.ex

Actions:
  :sell
    - Arguments: ticket_id
    - Changes:
      - Set status → :sold
      - Set ticket_id → provided value
      - Set sold_at → DateTime.utc_now()
      - Clear held_until, locked_at, seat_hold_id
      - Increment version (optimistic lock)
    - Validations:
      - :status_held (only :held seats can be sold)
      - :version_matches (optimistic lock guard)
```

**4. Checkout Resource (:complete action)**

```
Module: Voelgoedevents.Ash.Resources.Ticketing.Checkout
File: lib/voelgoedevents/ash/resources/ticketing/checkout.ex

Actions:
  :complete
    - Arguments: payment_reference
    - Changes:
      - Set status → :completed
      - Set completed_at → DateTime.utc_now()
      - Set payment_reference → provided value
    - Validations:
      - :status_started (only :started checkouts can complete)
      - :not_expired (expires_at > now)
```

**5. LedgerEntry Resource (:create action)**

```
Module: Voelgoedevents.Ash.Resources.Payments.LedgerEntry
File: lib/voelgoedevents/ash/resources/payments/ledger_entry.ex

Actions:
  :create
    - Arguments: account_debit_id, account_credit_id, amount_cents, description
    - Changes: Set attributes as provided
    - Validations:
      - :accounts_exist (both accounts exist + belong to org)
      - :amount_positive (amount > 0)
      - :organization_matches (multi-tenancy)
      - :balanced (for batch operations, debits == credits)
```

### Phoenix Controllers & Endpoints

**Webhook Endpoint**

```
POST /webhooks/payments/stripe
  - No authentication (payment processor pushes)
  - Validates webhook signature (HMAC-SHA256)
  - Checks idempotency (webhook event ID)
  - Calls complete_checkout workflow
  - Returns 200 OK or appropriate error code
```

### Oban Workers

```
WorkerGenerateQRCode:
  - Module: Voelgoedevents.Queues.WorkerGenerateQRCode
  - File: lib/voelgoedevents/queues/worker_generate_qr_code.ex
  - Queue: :default (high priority)
  - Max retries: 5

WorkerSendConfirmationEmail:
  - Module: Voelgoedevents.Queues.WorkerSendConfirmationEmail
  - File: lib/voelgoedevents/queues/worker_send_confirmation_email.ex
  - Queue: :default (high priority)
  - Max retries: 3

WorkerRecordAnalyticsEvent:
  - Module: Voelgoedevents.Queues.WorkerRecordAnalyticsEvent
  - File: lib/voelgoedevents/queues/worker_record_analytics_event.ex
  - Queue: :analytics (lower priority)
  - Max retries: 1
```

---

## 11. Monitoring & Observability

### Key Metrics

```
1. Webhook success rate
   - Alert if < 95% (payment processor issues or our bugs)

2. Payment processing latency (p50, p95, p99)
   - Target: < 200ms (p95)
   - Alert if > 500ms

3. Idempotency cache hit rate
   - Track: % of webhooks served from cache (should be high if processor retries)

4. Ticket creation success rate
   - Alert if < 99% (data integrity issues)

5. Concurrent seat conflicts (optimistic lock failures + retries)
   - Monitor: Indicates seller pressure on popular events
   - Expected: < 1% of transactions

6. Oban job success rates (QR, email, analytics)
   - Alert if QR job > 5% failure
   - Alert if email job > 10% failure
```

### Alerts

```
- High webhook failure rate → Check payment processor status + logs
- High transaction latency → Database performance issue?
- Low idempotency cache hits → Processor not retrying (good) or bad implementation
- QR generation failures → S3/CDN issues?
- Email send failures → SMTP provider down?
```

---

## 12. Future Enhancements

- **Payment plans:** Multi-installment payments (split across dates)
- **Refund workflow:** Reverse ticket sales + accounting entries (double-entry reversal)
- **Resale marketplace:** Allow customers to resell tickets on platform
- **Group discounts:** Auto-apply bulk discount for 10+ seats
- **Waitlist promotion:** Auto-create tickets for waitlisted customers if inventory available
- **Subscription events:** Auto-renewal for recurring event series
- **Invoice generation:** PDF invoices for B2B customers
- **Tax compliance:** Auto-calculate VAT/GST by jurisdiction

---

**END OF COMPLETE CHECKOUT WORKFLOW**