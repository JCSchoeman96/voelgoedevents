<!-- docs/domain/ticketing_pricing.md -->

# Ticketing & Pricing Domain

## 1. Scope & Responsibility

The Ticketing & Pricing domain owns:

- Ticket types and variants (GA vs seated, tiers, bundles).
- Inventory model (how many tickets/which seats exist to sell).
- Price rules and promotions (time-based, capacity-based, coupon-based).
- Seat holds and release logic.
- Ensuring **no overselling**, even under flash-sale traffic.

Out of scope:

- Payment authorization/capture (Payments & Ledger).
- Actual QR details and scanning (Scanning & Devices, Ticket Identity architecture doc).

---

## 2. Core Resources

**TicketType**

- Fields:
  - `id`
  - `event_id`
  - `organization_id`
  - `name`
  - `description`
  - `kind` (ga, seat, package, add_on)
  - `base_price`
  - `currency`
  - `status` (draft, on_sale, paused, closed)
  - `max_per_order`, `min_per_order`
  - `capacity` or `linked_seating` (depending on GA vs seated)
- Invariants:
  - `status` + event status dictate sellability.
  - GA capacity must not exceed event/venue capacity.

**PriceRule**

- Fields (conceptual):
  - `id`
  - `ticket_type_id`
  - `rule_type` (early_bird, time_window, capacity_threshold, promo_code, etc.)
  - `conditions` JSONB
  - `adjustment` (fixed/percentage)
- Invariants:
  - Rules should be deterministic and orderable for evaluation.

**Coupon / Promotion**

- Fields:
  - `id`
  - `organization_id`
  - `code`
  - `applies_to` (events, ticket types)
  - `max_uses`, `per_customer_limit`
- Invariants:
  - Coupon usage must be concurrency-safe to avoid exceeding `max_uses`.

**Inventory / SeatAllocation**

- For GA:
  - `remaining_quantity` (or derived from sold + reserved).
- For seated:
  - Linked to `seat_id` from Seating domain.

---

## 3. Seat Holds & Oversell Protection

Seat holds are critical:

- When a customer starts checkout:
  - Eligible seats are **held** for a short window (e.g. 5–10 minutes).
  - If payment fails / times out, seats are released.
- Holds must be:

  - Stored in Redis (ZSET) for fast expiry handling.
  - Mirrored in ETS or process state for ultra-fast logic.

Invariants:

- A seat cannot be:
  - Held by two different carts at the same time.
  - Sold while held by another customer.
- GA inventory cannot go below zero.

---

## 4. Performance & Caching Strategy

Data temperature:

- **Hot (ETS/GenServer + Cachex):**
  - Current inventory snapshots for GA ticket types.
  - Current seat hold status for active checkouts.
  - Frequently evaluated price rules for “hot” events.
- **Warm (Redis):**
  - Seat holds registry (ZSETs per event).
  - Aggregate counts (sold, reserved, available).
  - Coupon usage counters.
- **Cold (Postgres):**
  - Canonical ticket types, price rules, coupons, and sold tickets.

TTL guidelines:

- Seat holds:
  - Expire automatically via ZSET timestamps; effective TTL equals hold duration.
- Price rule caches:
  - Short TTL (e.g. 30–120 seconds) for computed effective price schedule for an event.

---

## 5. Redis Structures

- Seat holds:
  - `ticketing:holds:event:{event_id}` → Redis **ZSET**
    - Member: `seat_id` or composite key including cart id.
    - Score: `expires_at` timestamp.
- GA inventory counters:
  - `ticketing:inventory:ga:{ticket_type_id}` → Redis **hash** or simple **string**:
    - Fields: `available`, `sold`, `held`.
- Coupon usage:
  - `ticketing:coupon_uses:{coupon_id}` → Redis **counter** (INCR).
- Pricing cache:
  - `ticketing:pricing:effective:{ticket_type_id}` → Redis **hash** or JSON:
    - Stores precomputed current price and next thresholds.

---

## 6. Indexing & Query Patterns

Critical indexes:

- `ticket_types`:
  - Index on `event_id`.
  - Index on `(event_id, status)`.
- `tickets` (sold instances):
  - Index on `(event_id, status)`.
  - Index on `(user_id)` for customer history.
- `price_rules`:
  - Index on `ticket_type_id`.

Patterns:

- Most reads:
  - From ETS/Redis for availability and prices.
- Writes:
  - Go through a GenServer or transactional logic:
    - Reserve inventory → create ticket records.

---

## 7. PubSub & Real-time

Topics:

- `ticketing:event:{event_id}`:
  - Sales updates, sell-out signals, pricing changes.
- `ticketing:ticket_type:{ticket_type_id}`:
  - Per-type updates for dashboards.

Usage:

- Sales dashboards subscribe for real-time counters.
- Checkout flows subscribe to detect when a selection becomes invalid (sold out).

---

## 8. Error & Edge Cases

- Race conditions:
  - Two users attempting same seat or last GA units:
    - Must rely on Redis + DB transaction to ensure only one succeeds.
- Expired holds:
  - Checkout attempt with expired hold must fail gracefully.
- Price changes mid-checkout:
  - Decide policy:
    - Lock price at cart creation
    - Or re-evaluate at payment step.

---

## 9. Interactions with Other Domains

- **Seating**:
  - Uses seat IDs and maps them to actual physical seats.
- **Payments & Ledger**:
  - Ticketing triggers charges and ledger entries.
- **Scanning & Devices**:
  - Ticket identity + entitlement used at scanning time.
- **Analytics & Reporting**:
  - Uses ticket sales, revenue, and conversion metrics.

---

## 10. Testing & Observability

- Tests:
  - High-concurrency tests for GA and seated oversell protection.
  - Seat-hold timeout behavior.
- Observability:
  - Metrics: hold count, conversion rate from hold → sale, oversell incidents (must be zero).
  - Logs with `event_id`, `ticket_type_id`, `seat_id`.

---

## 11. Open Questions / Future Extensions

- Dynamic pricing (based on demand).
- Cross-event bundles and passes.
- Transfer/Resale rules (ownership changes).
