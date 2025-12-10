## 💳 PHASE 4: Orders, Payments & Ticket Issuance

**Goal:** Full payment processing, order management, QR ticket generation  
**Duration:** 2.5 weeks  
**Deliverables:** Transaction, Order, Ticket resources; payment webhooks; PDF generation  
**Dependencies:** Completes Phase 3

---

### Phase 4.1: Transaction Resource

#### Sub-Phase 4.1.1: Create Transaction Resource with State Machine

**Task:** Define Transaction resource tracking payment lifecycle  
**Objective:** Enable atomic payment state management  
**Output:**  
- `lib/voelgoedevents/ash/resources/payments/transaction.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_transactions.exs`  
**Note:**  
- Use `AshStateMachine` for status transitions
- States: `:initiated`, `:pending`, `:succeeded`, `:failed`, `:refunded`
- Store `provider` (`:paystack`, `:yoco`) and `provider_transaction_id`
- Apply policies: users can only view their own transactions
- Reference `/docs/domain/payments_ledger.md`
- Attributes: `id`, `organization_id`, `user_id`, `order_id`, `provider`, `provider_transaction_id`, `amount`, `currency`, `status`, `metadata`, timestamps

---

### Phase 4.2: Order Resource

#### Sub-Phase 4.2.1: Create Order Resource

**Task:** Define Order resource linking user, event, tickets, transaction  
**Objective:** Group tickets into a single purchase with fulfillment status  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/order.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_orders.exs`  
**Note:**  
- Status: `:pending`, `:paid`, `:fulfilled`, `:cancelled`, `:refunded`
- Apply policies: users can view their own orders
- Attributes: `id`, `organization_id`, `user_id`, `event_id`, `status`, `total_amount`, `currency`, `payment_status`, `fulfillment_status`, `notes`, timestamps
- Relationships: `has_many :tickets`, `has_one :transaction`

---

### Phase 4.3: Ticket Resource

#### Sub-Phase 4.3.1: Create Ticket Resource with State Machine

**Task:** Define Ticket resource (individual ticket instance) with QR code and status  
**Objective:** Enable ticket scanning and validation  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/ticket.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_tickets.exs`  
**Note:**  
- Use `AshStateMachine` for status transitions
- States: `:active`, `:scanned`, `:used`, `:voided`, `:refunded`
- Generate unique `ticket_code` (16-char base62, e.g., "3KQR-7F92-4M1X")
- QR payload: signed JWT with `{ticket_id, org_id, event_id, signature}`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache recently scanned tickets in ETS (5-min dedup window)
- Reference `/docs/workflows/process_scan.md` for QR validation specification
- Attributes: `id`, `order_id`, `ticket_type_id`, `event_id`, `organization_id`, `user_id`, `ticket_code` (unique), `qr_payload`, `status`, `scanned_at`, `last_gate_id`, `scan_count`, `seat_id` (nullable, for Phase 8), timestamps

---

### Phase 4.4: Complete Checkout Workflow

#### Sub-Phase 4.4.1: Implement Complete Checkout Workflow

**Task:** Create full checkout workflow from holds to paid tickets  
**Objective:** Atomic transaction handling with payment provider integration  
**Output:** `lib/voelgoedevents/workflows/checkout/complete_checkout.ex`  
**Note:**  
- Reference `/docs/workflows/complete_checkout.md` for full specification (do NOT duplicate steps)
- Workflow is transactional (all-or-nothing)
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) for cache invalidation
- Integrates with Phase 6 ledger entry creation
- Steps (high-level):
  1. Validate active holds (not expired)
  2. Initiate payment with provider (Paystack/Yoco)
  3. Create Order + Transaction records
  4. On success: convert holds → tickets, update inventory, create ledger entries
  5. On failure: release holds, cancel order

---

### Phase 4.5: Payment Provider Integration

#### Sub-Phase 4.5.1: Create Payment Provider Abstraction

**Task:** Create payment provider interface and Paystack/Yoco implementations  
**Objective:** Support multiple payment providers with unified interface  
**Output:**  
- `lib/voelgoedevents/payments/provider.ex` (behavior)
- `lib/voelgoedevents/payments/providers/paystack.ex`
- `lib/voelgoedevents/payments/providers/yoco.ex`  
**Note:**  
- Behavior defines: `initiate_payment/2`, `verify_payment/2`, `refund_payment/2`
- Store provider credentials in config (environment variables)
- Handle webhooks for payment confirmation
- Reference `/docs/domain/payments_ledger.md` for provider integration patterns

---

### Phase 4.6: QR Code & PDF Generation

#### Sub-Phase 4.6.1: Implement QR Code Generation

**Task:** Generate signed QR codes for tickets  
**Objective:** Enable secure, offline-verifiable ticket validation  
**Output:** `lib/voelgoedevents/ticketing/qr_generator.ex`  
**Note:**  
- QR payload: signed JWT with `{ticket_id, org_id, event_id, issued_at, signature}`
- Use Phoenix.Token for signing (secret key from config)
- TTL: Event end time + 7 days
- Reference `/docs/workflows/process_scan.md` for QR validation specification

---

#### Sub-Phase 4.6.2: Implement PDF Ticket Generation

**Task:** Generate PDF tickets with QR codes using Oban background job  
**Objective:** Provide downloadable, printable tickets to customers  
**Output:**  
- `lib/voelgoedevents/queues/worker_generate_pdf.ex`
- `lib/voelgoedevents/ticketing/pdf_generator.ex`  
**Note:**  
- Use `pdf_generator` or `wkhtmltopdf` for PDF rendering
- Store PDFs in S3-compatible storage or local filesystem
- Queue PDF generation in Oban `:default` queue
- Reference `/docs/architecture/06_jobs_and_async.md` for Oban patterns

---