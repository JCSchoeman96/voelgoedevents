# Payments & Ledger Domain

## 1. Scope & Responsibility

The Payments & Ledger domain owns:

- Payment initiation (checkout → payment attempt)
- Payment authorization, capture, refund flows
- Payout configuration per organization
- Ledger entries (immutable accounting events)
- Reconciliation rules & financial reporting base layer
- Chargeback handling workflows

It is responsible for:

- Correct tracking of money movement
- Guaranteeing that financial records are immutable and auditable
- Integrating with external PSPs (Stripe, Payfast, PayGate, etc.)
- Providing consistent financial views to Reporting

Out of scope:

- Ticket inventory management (Ticketing & Pricing)
- QR-based ticket identity (Scanning & Devices)
- Analytics transformation of revenue (Analytics & Funnels)

---

## 2. Core Resources

### **PaymentAttempt**

Represents a single customer payment interaction.

Fields:
- `id`
- `organization_id`
- `event_id`
- `ticket_order_id`
- `psp` (stripe, payfast, etc.)
- `psp_payment_id`
- `amount`, `currency`
- `status` (pending, authorized, captured, failed, refunded)
- `error_code` / `failure_reason`
- `created_at`, `updated_at`

Invariants:
- A PaymentAttempt must always map back to a **ticket order**.
- Only one successful (captured) payment per order.
- Status transitions must follow valid state machine rules.

---

### **LedgerEntry**

Immutable record of financial events.

Fields:
- `id`
- `organization_id`
- `event_id`
- `payment_attempt_id` (optional)
- `entry_type` (sale, fee, refund, chargeback, payout)
- `amount`
- `currency`
- `direction` (credit/debit)
- `metadata` JSONB
- `created_at`

Invariants:
- LedgerEntry is **immutable** once created.
- Entries must balance:
  - Sale = gross revenue
  - Fee = platform fees
  - Refund = negative sale
- All financial reports derive exclusively from LedgerEntry.

---

### **PayoutConfig**

Defines how money flows to event organizers.

Fields:
- `id`
- `organization_id`
- `psp_account_id`
- `bank_details`
- `settlement_schedule` (daily, weekly, event_end)
- `status` (active, disabled)

Invariants:
- Only one active payout config per organization at a time.

---

## 3. Key Invariants

- A payment can only be captured once.
- Refunds cannot exceed the total captured amount.
- Ledger must remain balanced across all entries.
- Payouts can only be scheduled for settled/captured transactions.
- All money-related mutations must be fully idempotent.

---

## 4. Performance & Caching Strategy

**Hot (ETS/Cachex):**
- PSP configuration cached per organization.
- Recent PaymentAttempts (5–30 min).

**Warm (Redis):**
- Payment status tracking:
  - `payment:{order_id}` → current state machine snapshot.
- Ledger aggregate caches:
  - Revenue totals
  - Refund totals
  - Fees totals

TTL: 10–60 minutes for aggregates.

**Cold (Postgres):**
- Canonical ledger.
- Payment attempts.
- Reconciliation history.

Cache invalidation:
- On payment status change → invalidate order + ledger aggregates.

---

## 5. Redis Structures

- `payments:status:{order_id}` → Redis **hash**
  - `payment_attempt_id`, `status`, `updated_at`
- `ledger:agg:event:{event_id}` → Redis **hash**
  - `revenue`, `refunds`, `fees`
- `ledger:agg:org:{organization_id}` → Redis **hash**

---

## 6. Indexing & Query Patterns

Indexes:
- `(organization_id, event_id)` on PaymentAttempt & LedgerEntry
- `(entry_type, created_at)` on LedgerEntry for fast reporting windows
- `psp_payment_id` unique for de-duplication

Patterns:
- Fetch payment status: Redis → fallback DB.
- Generate financial report: Redis aggregates → DB materialized view fallback.

---

## 7. PubSub & Real-time

Topics:
- `payments:order:{order_id}`
- `payments:organization:{org_id}`

Broadcasts:
- Payment completed
- Refund processed
- Chargeback received

---

## 8. Error & Edge Cases

- PSP returning duplicate webhooks → must be idempotent.
- Delayed payment confirmation → real-time status must converge via Redis.
- Chargebacks should retroactively create negative ledger entries.

---

## 9. Domain Interactions

- **Ticketing** — unlocks/sells inventory after successful payment.
- **Reporting** — consumes ledger for dashboards.
- **Integrations** — receives PSP events via webhooks.
- **Analytics** — uses ledger to populate revenue funnels.

---

## 10. Testing & Observability

Tests:
- State machine transitions.
- Idempotent webhook processing.
- Ledger balancing.

Telemetry:
- PSP latency
- Payment success rate
- Refund ratios

---

## 11. Open Questions

- Will payouts be automated or manual?
- Do we support multiple PSPs per organization?
- Bulk refunds (per event/session)?
