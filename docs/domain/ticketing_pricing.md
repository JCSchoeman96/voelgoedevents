# Domain: Ticketing & Pricing

## Overview & Purpose

The **Ticketing & Pricing** domain manages all aspects of ticket types, inventory, pricing rules, promotions, and seat holds. This domain ensures that events can flexibly offer GA (General Admission) and seated tickets, apply complex pricing logic, handle refunds correctly with the Payments & Ledger domain, and prevent overselling under high-concurrency conditions (flash sales, large events).

**Core Responsibilities**:

- Ticket type and variant management (GA, seated, passes, add-ons, bundles).
- Inventory tracking (GA capacity, seating allocation, stock management).
- Pricing rules evaluation (early-bird, time-window, capacity-based, dynamic).
- Coupon and promotion management.
- Seat hold lifecycle and release.
- **Ticket entitlement models** (re-entry rules, daily limits, multi-day passes).
- **Tenant-level policy configuration** (SuperAdmin controls).

**Out of Scope**:

- Payment authorization/capture (Payments & Ledger domain).
- QR code generation, scanning validation (Scanning & Devices, Ticket Identity docs).
- Refund ledger reversal (Payments & Ledger domain).

---

## Scope & Boundaries

### In Scope

1. TicketType resource (GA, seated, passes, add-ons, bundles).
2. PricingRule evaluation (tiered, time-based, capacity-based, bundle-based, donation-based).
3. Coupon management (codes, usage limits, per-customer caps).
4. Inventory tracking (GA remaining quantity, seating allocation, cross-zone blending).
5. Seat holds and releases (5-10 minute TTL, oversell protection).
6. **Ticket entitlement modes** (single_entry, unlimited_reentry, limited_reentry_per_day, multi-day passes).
7. **TicketingPolicy resource** (SuperAdmin per-tenant controls).
8. Refund eligibility rules (integration with Payments domain).
9. Performance caching (ETS, Redis, Postgres).

### Out of Scope

- External payment processing (delegated to Payments & Ledger).
- QR code signing, validation (delegated to Ticket Identity architecture).
- Scanning access control (delegated to Scanning domain).
- Seating plan builder UI (delegated to Phase 8 Seating domain).

---

## Personas & Use Cases

### 1. Event Organiser

- Create ticket types (GA, VIP, standing, multi-day passes).
- Set prices and pricing rules (early-bird, capacity-based discounts).
- Create and manage promotional codes.
- View inventory and sell-through analytics.
- Issue refunds and understand refund fee impact.

### 2. SuperAdmin / Platform Operator

- Configure which ticket types are allowed per organisation.
- Set min/max ticket prices per organisation.
- Enable/disable specific entitlement modes (re-entry, daily limits).
- Control donation availability per organisation.
- Restrict fee models (client pays, organiser absorbs, split).
- Set payout rules per organisation.

### 3. Customer / Event Attendee

- Purchase single or multiple tickets.
- Apply promotional codes.
- Choose ticket variants (GA, VIP, seating, add-ons).
- View ticket entitlements (allowed entries, valid dates).
- Process refunds (if eligible).

### 4. Finance / Accounting

- Understand fee interaction: platform fees, processor fees, refund fees.
- Reconcile refund ledger impact.
- Understand refund eligibility by ticket type.

---

## Core Resources

### 1. TicketType (Ticket Definitions)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.TicketType`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`  
**Phase Introduced**: Phase 3

**Responsibility**: Define available ticket types for an event.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID) — multi-tenancy
- `event_id` (UUID) — associated event
- `name` (string) — e.g., "VIP", "General Admission", "3-Day Pass"
- `description` (string, nullable)
- `kind` (atom: `:ga`, `:seated`, `:pass`, `:addon`, `:bundle`)
- `base_price_cents` (integer) — starting price before rules
- `currency` (string, default `"ZAR"`)
- `status` (atom: `:draft`, `:on_sale`, `:paused`, `:closed`)
- `total_capacity` (integer, nullable) — for GA tickets
- `sold_count` (integer, default 0)
- `held_count` (integer, default 0)
- `max_per_order` (integer, nullable) — e.g., 5 tickets max per order
- `min_per_order` (integer, default 1)
- `refundable` (boolean, default true)
- `entitlement_mode` (atom: `:single_entry`, `:unlimited_reentry`, `:limited_reentry_per_day`, `:single_entry_per_day`, `:unlimited_multi_day`)
- `max_daily_entries` (integer, nullable) — for `:limited_reentry_per_day`
- `max_total_entries` (integer, nullable) — for `:limited_reentry_per_day` across full event
- `valid_days` (array of atoms, nullable) — for multi-day: `[:monday, :tuesday, ...]` or range
- `entry_reset_strategy` (atom: `:calendar_day`, `:sliding_24h`, `:event_day`) — how resets work
- `created_at`, `updated_at`

**Calculations**:

- `available_quantity`: `total_capacity - sold_count - held_count` (for GA)

**Invariants**:

- MUST match event status (if event not published, cannot sell).
- For GA: `total_capacity` MUST NOT exceed venue capacity.
- For seated: linked via seating domain.
- Entitlement mode MUST be allowed per TicketingPolicy for org.
- `refundable` status MUST align with PaymentPolicy refund fee logic.
- **Entitlement Price Interaction**:
  - `effective_price` MUST NOT vary based on number of entries used.
  - Pricing rules MUST NOT contradict entitlement rules (e.g. cannot offer "one entry per day" if the ticket is sold as a single-day ticket).
  - Multi-day tickets MUST specify either `valid_dates` or `event_day_indices`.

---

### 2. PricingRule (Dynamic Price Evaluation)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.PricingRule`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/pricing_rule.ex`  
**Phase Introduced**: Phase 3

**Responsibility**: Define pricing adjustments based on conditions.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `ticket_type_id` (UUID)
- `rule_type` (atom: `:fixed`, `:tiered`, `:early_bird`, `:capacity_based`, `:time_window`, `:demand_based`, `:addon_based`, `:bundle_based`, `:donation_based`, `:override`)
- `priority` (integer) — lower priority evaluates first
- `conditions` (JSONB) — rule-specific conditions
  - Early-bird: `{ "ends_at": "2025-02-15" }`
  - Tiered: `{ "thresholds": [{ "min_qty": 0, "max_qty": 50, "discount_percent": 10 }] }`
  - Time-window: `{ "starts_at": "...", "ends_at": "..." }`
  - Capacity-based: `{ "sold_threshold": 50, "discount_percent": 5 }`
  - Demand-based: `{ "occupancy_percent": 75, "price_increase_percent": 15 }`
- `adjustment_type` (atom: `:fixed`, `:percentage`)
- `adjustment_value` (decimal) — ZAR or %
- `max_discount_cents` (integer, nullable) — cap on discount
- `status` (atom: `:active`, `:inactive`)
- `created_at`, `updated_at`

**Calculations**:

- **Effective Price**: Evaluate all active rules in priority order, apply adjustments (stacking or override).

**Invariants**:

- Rules MUST be deterministic and orderable.
- MUST NOT allow rules that contradict entitlement model (e.g., dynamic pricing on refundable pass).
- Rules MUST be evaluated at checkout time and **price locked** in cart.

#### Manual Override Rule (`rule_type: :override`)

A price override rule allows an administrator or organiser to directly set the effective ticket price
for a defined time window, bypassing all other pricing rules.

**Fields**:

- `override_price_cents` (required)
- `starts_at` (optional)
- `ends_at` (optional)

**Behavior**:

- When active, the override price MUST supersede all other price rules:
  - fixed price
  - tiered/early-bird
  - capacity thresholds
  - time-window adjustments
  - dynamic pricing
- If multiple override rules exist, the highest-priority (earliest created or explicit priority field) MUST win.
- If the override window expires, the pricing engine MUST automatically revert to the next active rule.

**Invariants**:

- Override rules MUST NOT violate min/max price constraints defined in TicketingPolicy.
- Override rules MUST be auditable through the platform auditing system.

---

### 3. Coupon (Promotional Codes)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.Coupon`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/coupon.ex`  
**Phase Introduced**: Phase 3

**Responsibility**: Manage discount codes.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `code` (string, unique per org) — e.g., "EARLY20"
- `applies_to` (atom: `:all_events`, `:specific_events`, `:specific_ticket_types`)
- `applies_to_ids` (array of UUIDs, nullable) — event or ticket type IDs
- `discount_type` (atom: `:fixed`, `:percentage`)
- `discount_value` (decimal) — ZAR or %
- `max_discount_cents` (integer, nullable) — cap discount
- `max_uses` (integer, nullable) — global limit
- `per_customer_limit` (integer, default 1) — can use once per customer
- `valid_from` (datetime)
- `valid_until` (datetime)
- `status` (atom: `:active`, `:inactive`, `:archived`)
- `multi_coupon_allowed` (boolean, default false) — can combine with other coupons
- `created_at`, `updated_at`

**Tracking**:

- `coupon_uses` table (or JSONB array in coupon) tracking:
  - `user_id`, `order_id`, `created_at`

**Invariants**:

- Coupon usage MUST be concurrency-safe (prevent exceeding `max_uses`).
- Usage MUST be validated at checkout.
- Code MUST be unique per organisation.

---

### 4. SeatHold (Temporary Reservation)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.SeatHold`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/seat_hold.ex`  
**Phase Introduced**: Phase 3

**Responsibility**: Track 5-10 minute temporary holds during checkout.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `event_id` (UUID)
- `ticket_type_id` (UUID)
- `user_id` (UUID) — who is holding
- `quantity` (integer) — for GA
- `seat_ids` (array of UUIDs, nullable) — for seated tickets
- `status` (atom: `:active`, `:expired`, `:converted`, `:cancelled`)
- `held_until` (datetime) — expiry
- `source` (atom: `:web`, `:scanner`, `:api`)
- `created_at`

**Storage**:

- **Redis ZSET**: `ticketing:holds:event:{event_id}`
  - Member: `{seat_id}` or `{ticket_type_id}:{hold_id}`
  - Score: `held_until` timestamp (auto-expire via ZSET operations)
- **ETS**: per-node fast lookup (mirrors Redis)
- **PostgreSQL**: durable record for audit & recovery

**Invariants**:

- A seat CANNOT be held by two carts simultaneously.
- Holds MUST NOT exceed available inventory.
- Expired holds MUST be released automatically via Oban cleanup job.

---

### 5. Ticket (Sold Instance)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.Ticket`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/ticket.ex`  
**Phase Introduced**: Phase 4

**Responsibility**: Individual ticket instance with state machine.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `order_id` (UUID)
- `ticket_type_id` (UUID)
- `event_id` (UUID)
- `user_id` (UUID) — who owns this ticket
- `ticket_code` (string, unique) — 16-char base62
- `qr_payload` (string) — signed JWT for scanning
- `status` (atom: `:active`, `:scanned`, `:used`, `:voided`, `:refunded`)
- `entry_count` (integer, default 0) — for re-entry tracking
- `last_entry_date` (date, nullable) — last time entered
- `last_exit_at` (datetime, nullable) — last exit scan
- `scanned_at` (datetime, nullable)
- `refunded_at` (datetime, nullable)
- `seat_id` (UUID, nullable) — for Phase 8 seating
- `created_at`, `updated_at`

**State Machine** (Ash.StateMachine):

- `:active` → `:scanned` (first scan)
- `:scanned` → `:used` (after allowed entries)
- Any → `:voided` (admin/system)
- Any → `:refunded` (refund processed)

**Entitlement Enforcement**:

- At scan time, check entitlement mode:
  - `:single_entry`: Can scan once.
  - `:unlimited_reentry`: Can scan unlimited times.
  - `:limited_reentry_per_day`: Max X entries per calendar/sliding day.
  - `:single_entry_per_day`: One entry per day.
  - `:unlimited_multi_day`: Unlimited on valid days.

---

### 6. TicketingPolicy (SuperAdmin Tenant Controls)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.TicketingPolicy`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/ticketing_policy.ex`  
**Phase Introduced**: Phase 3

**Responsibility**: Tenant-level configuration of ticketing and pricing behaviour.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `enabled_ticket_kinds` (array of atoms, default all) — which types allowed
- `enabled_entitlement_modes` (array of atoms, default all) — `:single_entry`, `:unlimited_reentry`, etc.
- `allowed_pricing_models` (array of atoms, default all) — `:fixed`, `:tiered`, `:early_bird`, etc.
- `allowed_discount_types` (array of atoms) — `:fixed`, `:percentage`, `:addon`, `:bundle`
- `allow_coupons` (boolean, default true)
- `allow_multi_coupon` (boolean, default false)
- `min_ticket_price_cents` (integer, nullable)
- `max_ticket_price_cents` (integer, nullable)
- `allow_addons` (boolean, default true)
- `allow_bundles` (boolean, default true)
- `allow_passes` (boolean, default true)
- `allow_donations` (boolean, default false) — for free/NPO events
- `refund_enabled` (boolean, default true)
- `refund_platform_fee_on_refund` (boolean, default false) — non-refundable fees
- `checkout_grace_period_minutes` (integer, default 15) — seat hold TTL
- `max_seats_per_order` (integer, default 10)
- `created_at`, `updated_at`

#### Seat Hold Configuration

The following fields define the tenant-level defaults for seat holds and GA inventory reservations.
These values SHOULD be overridden by event-level configuration where required.

- `seat_hold_ttl_minutes`

  - The number of minutes a GA or seated hold remains valid before automatic expiry.
  - Default: 10 minutes.

- `seat_hold_expiry_strategy`

  - How expired holds are processed.
  - Allowed: `:lazy_cleanup` (on access), `:strict_cleanup` (via Oban job), `:immediate_release` (aggressive).
  - Default: `:strict_cleanup`.

- `max_holds_per_user`

  - Maximum number of active holds per user/session/cart across all events.
  - Prevents abuse where a single user locks too many seats.

- `max_holds_per_ip`
  - Maximum holds allowed per IP to prevent automated scalping behavior.

**Invariants**:

- All holds MUST be stored in Redis ZSET with expiry timestamps.
- A hold MAY NOT exist past its TTL unless overridden by admin tooling.

**Enforcement**:

- Applied during:
  - TicketType creation (validate `kind` and `entitlement_mode` allowed).
  - PricingRule creation (validate `rule_type` allowed).
  - Coupon creation (validate allowed).
  - Checkout (validate refund eligibility).

---

### 7. PassBundle (Multi-Day / Package Tickets)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.PassBundle`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/pass_bundle.ex`  
**Phase Introduced**: Phase 4

**Responsibility**: Represent passes and bundles (e.g., "3-Day Weekend Pass").

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `event_id` (UUID)
- `name` (string) — e.g., "3-Day Festival Pass"
- `description` (string, nullable)
- `type` (atom: `:multi_day_pass`, `:family_pack`, `:vip_bundle`, `:camping_addon`)
- `bundle_ticket_type_ids` (array of UUIDs) — constituent ticket types
- `bundle_price_cents` (integer) — total price (may be less than sum)
- `valid_dates` (array of dates) — which days are valid
- `entry_rules` (JSONB) — entry limits per day, resets, etc.
- `refund_rules` (JSONB) — partial refund rules
- `status` (atom: `:draft`, `:on_sale`, `:closed`)
- `created_at`, `updated_at`

**Invariants**:

- Bundle price SHOULD be less than or equal to sum of component prices.
- Refund eligibility depends on how many days/items used.

---

### 8. AddOn (Optional Extras)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.AddOn`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/addon.ex`  
**Phase Introduced**: Phase 4

**Responsibility**: Optional extras (parking, camping, merchandise).

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `event_id` (UUID)
- `name` (string) — e.g., "Parking Pass"
- `price_cents` (integer)
- `max_per_order` (integer, nullable)
- `inventory_available` (integer, nullable) — can be limited
- `status` (atom: `:available`, `:sold_out`, `:discontinued`)
- `created_at`, `updated_at`

**Integration**:

- AddOns selected during checkout, added to order line items.
- Price locked in order.

---

## Ticket Entitlement & Check-In Rules

### Overview

Ticket entitlement defines HOW a ticket may be used during an event: single entry, re-entry, daily limits, multi-day access, etc.

### Supported Entitlement Modes

| Mode                       | Behavior                                 | Use Case                            | Reset                                |
| -------------------------- | ---------------------------------------- | ----------------------------------- | ------------------------------------ |
| `:single_entry`            | Can scan exactly once. Re-entry blocked. | Day-pass, one-time access           | N/A                                  |
| `:unlimited_reentry`       | Can scan unlimited times.                | Festival wristband, multi-venue     | N/A                                  |
| `:limited_reentry_per_day` | Max X entries per day (configurable).    | Multi-day festival with daily limit | Daily (calendar/sliding/event-based) |
| `:single_entry_per_day`    | Max 1 entry per day.                     | Gym membership, daily access        | Daily                                |
| `:unlimited_multi_day`     | Unlimited entries on specified days.     | 3-day festival, valid Fri-Sun       | Daily                                |

### Checkout Semantics

TicketingPolicy and TicketType MUST specify how a ticket interacts with checkout actions at event gates.

**Operational Rules**:

- **Exit Scan Required**

  - If `checkout_required_for_reentry` is TRUE, a ticket MUST perform an EXIT scan
    before performing the next valid ENTRY. This prevents infinite re-entry without explicit tracking.

- **Optional Checkout**

  - If `allow_checkout` is TRUE but `checkout_required_for_reentry` is FALSE:
    - A ticket MAY check out.
    - Re-entry is still allowed without performing an exit scan.
    - Used for events that want approximate but not enforced occupancy tracking.

- **No Checkout Allowed**

  - If `allow_checkout` is FALSE:
    - Devices MUST NOT offer a checkout option.
    - All "exit gate" scanning attempts MUST be rejected.

- **Daily Reset Interaction**

  - For entitlement modes that reset daily (e.g., single_entry_per_day):
    - Reset occurs at midnight or `event_day_start` as defined by event configuration.
    - Exits do NOT reset the entitlement window.

- **State Machine Requirements**
  - ENTRY increments `entries_used`.
  - EXIT sets `last_exit_at`.
  - Re-entry rules MUST verify both:
    1. Whether checkout was required
    2. Whether entitlement caps have been reached

These rules MUST be enforced by both the scanning API and the in-venue scanner devices.

---

## Pricing Models

### Supported Models

| Model              | Use Case                   | Conditions                          |
| ------------------ | -------------------------- | ----------------------------------- |
| **Fixed**          | Simple, static pricing     | Price does not change               |
| **Tiered**         | Volume discount            | `qty >= 50 → 10% off`               |
| **Early-Bird**     | Early purchase discount    | Before date X → ZAR 50 off          |
| **Capacity-Based** | Dynamic based on occupancy | `sold >= 50% → +5%`                 |
| **Time-Window**    | Limited-time offer         | `valid_from` to `valid_until`       |
| **Demand-Based**   | Surge pricing              | High occupancy → higher price       |
| **Addon-Based**    | Add-on bundling            | Parking + ticket = bundle price     |
| **Bundle-Based**   | Multi-ticket packages      | 3-Day pass < 3 × 1-Day              |
| **Donation-Based** | Free events with donations | Optional donation field             |
| **Override**       | Manual admin pricing       | Directly set price, bypassing rules |

### Pricing Evaluation Logic

**At Checkout**:

1. Start with base price.
2. Evaluate all active rules in priority order.
3. Apply adjustments (stack or override per rule config).
4. **Lock price** in order (immutable).
5. Calculate fees (platform, processor) per PaymentPolicy.

**Key Rules**:

- Prices MUST be evaluated and locked **before payment**.
- Prices MUST NOT change between cart and payment.
- Price cache TTL: 30-120 seconds (short, for rapid re-evaluation).

---

## Discount & Promotion Rules

### Coupon Application

**Multi-Coupon Mixing**:

- By default: ONE coupon per order.
- If `multi_coupon_allowed: true` on TicketingPolicy:
  - Multiple coupons can be stacked.
  - Applied in priority order.

**Per-Coupon Limits**:

- `max_uses`: Global limit (concurrency-safe via Redis INCR).
- `per_customer_limit`: Max times a customer can use.
- Usage validation at checkout.

**Cross-Event Promotions**:

- Coupon `applies_to: :all_events` applies to all org events.
- Coupon `applies_to: :specific_events` lists event IDs.

**Donation-Based Discount** (Free Events):

- If event is free and donation enabled:
  - Customer can donate any amount.
  - Donation amount does NOT affect ticket price (ticket is free).
  - Donation is separate ledger entry (4400-DONATION-REVENUE or liability).

---

## Inventory Management

### GA Inventory

**Tracking**:

- `total_capacity`: Fixed limit per ticket type.
- `sold_count`: Confirmed sales.
- `held_count`: Active seat holds (ZSET in Redis).
- `available_quantity` (derived): `total_capacity - sold_count - held_count`

**Cross-Zone Blending** (Phase 8+):

- If seating allows GA + reserved zones:
  - Total GA inventory = `total_capacity - reserved_allocated`.
  - Inventory "pools" across zones.

**Dynamic Release**:

- Inventory can be released time-based (e.g., release VIP-only section at T-7 days).
- Release is manual admin action or configured rule.

### Seating Inventory (Phase 8)

- Linked to Seat resources (1:1).
- Seat status: `:available`, `:held`, `:sold`, `:blocked`.
- Cross-zone queries must account for price zone.

---

## Multi-Day & Multi-Event Validity

### Ticket Validity Model

**Date Ranges**:

- Single-day: Event date only.
- Multi-day: Specific date array (e.g., Friday, Saturday, Sunday).
- Cross-event: Not supported in MVP (future feature).

**Day-Indexed Access**:

- Each valid day = one entry (`:limited_reentry_per_day`).
- Reset strategy:
  - `:calendar_day`: Resets at midnight UTC or org timezone.
  - `:sliding_24h`: Resets 24h from first scan.
  - `:event_day`: Resets at event start time each day.

**QR Code Strategy**:

- **Single QR**: One stable QR for all days (regenerated on refund only).
- **Per-Day QR**: New QR generated each day (future, complex).

---

## Refund & Ledger Integration

### Refund Eligibility

**By Ticket Type**:

- TicketType field `refundable: true` (default).
- If `refundable: false` (e.g., special events): No refunds allowed.

**Platform Fee Handling**:

- Determined by PaymentPolicy `refund_platform_fee_on_refund`:
  - `false` (default): Platform fees non-refundable.
  - `true`: Platform fees refundable.

**Processor Fee Handling**:

- Determined by PaymentPolicy `processor_fee_type`:
  - `:non_refundable`: Customer absorbs processor fee.
  - `:refundable`: Refunded if PSP supports it.

### Refund Ledger Example

**Ticket Sale** (Client Pays All Fees):

```
Debit  1000-CASH                    1040 ZAR
Credit 2000-PAYABLE-ORGANIZER        950 ZAR (ZAR 1000 - ZAR 50 platform fee)
Credit 5000-PLATFORM-FEE              50 ZAR
Credit 5100-PROCESSOR-FEE             40 ZAR
```

**Refund** (Non-Refundable Platform Fee):

```
Debit  2000-PAYABLE-ORGANIZER        950 ZAR
Credit 5100-PROCESSOR-FEE             40 ZAR
Credit 1000-CASH                     990 ZAR (customer gets back ZAR 1000 − ZAR 50 platform fee)
```

(See payments_ledger.md for full details.)

---

## Seat Holds & Oversell Protection

### Hold Lifecycle

**Creation**:

1. User selects seats/tickets.
2. System creates SeatHold (status: `:active`, `held_until: now + 15 min`).
3. Inventory decremented (held_count incremented).
4. Hold stored in Redis ZSET + ETS for fast lookup.

**Expiry**:

1. Oban job runs every 30s, checks expired ZSET members.
2. Deletes from Redis ZSET.
3. Updates TicketType `held_count`.
4. Broadcasts PubSub event (occupancy updated).

**Conversion**:

1. Payment succeeds.
2. SeatHold status → `:converted`.
3. Seat holds released (held_count decremented).
4. Tickets created.

**Cancellation**:

1. User abandons checkout.
2. System marks SeatHold `:cancelled`.
3. Releases inventory.

### Oversell Prevention

**Invariant**: `available_quantity >= 0` always.

**Implementation**:

1. **Optimistic Lock** on TicketType `version` field.
2. **Redis DLM** (Distributed Lock Manager) for critical section.
3. **ZSET Score** for hold expiry (atomic via Redis).

**Race Condition Example**:

- User A tries to hold last 5 GA tickets.
- User B tries to hold same 5 tickets.
- Only one succeeds (DLM ensures atomicity).

---

## Performance & Caching

### Data Temperature

| Layer    | Purpose                                                          | TTL        | Technology  |
| -------- | ---------------------------------------------------------------- | ---------- | ----------- |
| **Hot**  | Inventory snapshots, hold status, pricing cache                  | 30-120 sec | ETS, Cachex |
| **Warm** | Seat holds registry, coupon usage, aggregate counts              | 5-30 min   | Redis       |
| **Cold** | Canonical resources (ticket types, rules, coupons, sold tickets) | Permanent  | PostgreSQL  |

### Redis Structures

```
ticketing:holds:event:{event_id}
  → ZSET, member={ticket_type_id}:{hold_id}, score={expires_at}

ticketing:inventory:ga:{ticket_type_id}
  → HASH | STRING, fields={available, sold, held}

ticketing:coupon_uses:{coupon_id}
  → Counter (INCR)

ticketing:pricing:effective:{ticket_type_id}
  → HASH | JSON, fields={current_price, next_threshold, ...}
```

### Caching Invalidation

**Triggers**:

- Ticket sold → invalidate inventory, pricing cache.
- Seat hold created/expired → invalidate inventory.
- PricingRule updated → invalidate pricing cache.
- Coupon used → invalidate coupon usage counter.

**Method**:

- PubSub broadcast to all nodes.
- Oban job for async cleanup.
- TTL auto-expiry for eventual consistency.

---

## Testing & Observability

### Test Coverage

**High-Concurrency Tests**:

- Two users attempting last GA ticket → only one succeeds.
- Seat hold expiry with high rate of purchases.
- Coupon usage counter under concurrent updates.

**Refund Tests**:

- Non-refundable fee handling.
- Refundable fee handling.
- Partial refunds.

**Pricing Tests**:

- Rule evaluation order.
- Coupon application.
- Price locking at checkout.
- Override-rule price locking during seat hold TTL.

**Entitlement Tests**:

- Single-entry blocks second scan.
- Daily limit enforced.
- Multi-day pass valid only on specified days.
- Validate daily entitlement resets (midnight/event-day-based).
- Validate multi-day pass behavior across different days.
- Validate "single entry only" tickets reject re-entry.
- Validate "checkout required" mode enforces EXIT scan before re-entry.
- Validate "unlimited re-entry" mode correctly increments entry counters.
- Validate `max_daily_entries` and `max_total_entries` caps.
- Validate TicketingPolicy seat_hold_ttl and hold expiration correctness.

### Metrics & Alerts

| Metric                  | Target              | Alert                   |
| ----------------------- | ------------------- | ----------------------- |
| Oversell Incidents      | 0                   | Any > 0 = critical      |
| Hold-to-Sale Conversion | 40-60%              | < 30% = investigate     |
| Hold Expiry Rate        | Normal distribution | Spike = checkout issues |
| Coupon Usage vs. Max    | < max               | Any >= max = warn       |
| Price Cache Hit Rate    | 90%+                | < 80% = degradation     |

### Logs

- Log `organization_id`, `event_id`, `ticket_type_id`, `user_id` for all operations.
- Log rule evaluation details (which rules applied, effective price).
- Log hold creation/expiry/conversion.
- Log refund eligibility checks.

---

## Domain Interactions

### Seating Domain (Phase 8)

- TicketType `kind: :seated` links to Seating domain.
- Seat resource provides `seat_id`.
- Price zone mapping: Seat maps to PricingRule via zone.

### Payments & Ledger Domain

- Order → Transaction (payment processing).
- Refund → JournalEntry (ledger reversal).
- TicketType `refundable` flag + PaymentPolicy `refund_platform_fee` determine ledger impact.

### Scanning Domain

- Ticket entitlement mode governs re-entry behaviour.
- Scan workflow validates entry count against entitlement mode.
- Multi-day passes validate date of scan against valid_dates.

### Analytics Domain

- Ticket sales feed into FunnelSnapshot.
- Pricing rule effectiveness tracked (% discount applied).

---

## MVP vs. Future Phases

### Phase 3-4: Basic Ticketing & Pricing

**In Scope**:

- Simple TicketType (GA, basic seated).
- Fixed pricing + early-bird rule.
- Coupon codes (basic usage tracking).
- Seat holds (5 min TTL).
- Single-entry entitlement only.

**Out of Scope**:

- Advanced pricing models (demand-based, addon-based).
- Multi-coupon stacking.
- Complex entitlement modes (daily limits, multi-day passes).
- TicketingPolicy resource (assume defaults).
- Passes/bundles (simplified).

### Phase 8+: Advanced Ticketing

**Additions**:

- All pricing models (tiered, capacity-based, demand-based, addon-based, bundle-based, override).
- Multi-coupon stacking.
- All entitlement modes (daily limits, multi-day passes, unlimited re-entry).
- TicketingPolicy resource (full SuperAdmin control).
- Complex passes and bundles.
- Donation subsystem.
- Advanced inventory management (cross-zone blending, dynamic release).
- Full checkout semantics with exit scan tracking.

---

## New Resources to Register

The following resources MUST be added to `DOMAIN_MAP.md` and `ai_context_map.md`:

| Resource          | Module                                                   | File Path                                                        | Domain    | Phase | Notes                              |
| ----------------- | -------------------------------------------------------- | ---------------------------------------------------------------- | --------- | ----- | ---------------------------------- |
| `TicketingPolicy` | `Voelgoedevents.Ash.Resources.Ticketing.TicketingPolicy` | `lib/voelgoedevents/ash/resources/ticketing/ticketing_policy.ex` | Ticketing | 3     | SuperAdmin controls per tenant     |
| `PassBundle`      | `Voelgoedevents.Ash.Resources.Ticketing.PassBundle`      | `lib/voelgoedevents/ash/resources/ticketing/pass_bundle.ex`      | Ticketing | 4     | Multi-day passes, family packs     |
| `AddOn`           | `Voelgoedevents.Ash.Resources.Ticketing.AddOn`           | `lib/voelgoedevents/ash/resources/ticketing/addon.ex`            | Ticketing | 4     | Optional extras (parking, camping) |

---

## Document Status

**Version**: 2.1 (Extended, Finalized, and Edited)  
**Last Updated**: December 8, 2025  
**Status**: Canonical Specification for Phase 3, 4, and 8 Implementation — Phase-Ready  
**Next Review**: After Phase 4 completion (before Phase 8 seating integration)

---

## References

### Internal VoelgoedEvents Docs

- `MASTER_BLUEPRINT.md` — Section 4 (Domain Map), Section 7 (Workflows)
- `DOMAIN_MAP.md` — Section 4 (Ticketing & Pricing)
- `PROJECT_GUIDE.md` — Section 5.3 (Ticketing Resources)
- `payments_ledger.md` — Refund fee logic, ledger integration
- `start_checkout.md` — Pricing calculation workflow
- `complete_checkout.md` — Ticket issuance and inventory updates
- `VOELGOEDEVENTS_FINAL_ROADMAP.md` — Phase 3 (Core Events & GA Ticketing), Phase 4 (Orders & Payments), Phase 8 (Seating)
- `03_caching_and_realtime.md` — Cache layers, PubSub patterns
- `02_multi_tenancy.md` — Multi-tenant enforcement
- `05_eventing_model.md` — Domain event emission

### External References

- **Stripe Pricing & Billing**: https://stripe.com/billing/pricing
- **Event Ticketing Best Practices**: https://www.eventbrite.com/platform/solutions/
- **Capacity-Based Pricing**: https://en.wikipedia.org/wiki/Yield_management

---
