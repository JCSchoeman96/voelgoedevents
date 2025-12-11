<!-- docs/domain/ticketing_pricing.md -->

# Domain: Ticketing & Pricing

## 1. Overview & Purpose

The **Ticketing & Pricing** domain manages ticket types, inventory tracking, seat holds, and pricing rules. In **Phase 3**, this domain focuses exclusively on **GA (General Admission) ticketing** using quantity-based inventory. Later phases will extend this to support seating-aware ticketing and advanced pricing models.

**Phase 3 Core Responsibilities**:

- TicketType resource management (GA only in Phase 3)
- GA inventory tracking (quantity-based: total, sold, held)
- SeatHold lifecycle and release (15-minute TTL)
- Basic coupon management (codes, usage limits)
- Caching and concurrency protection

**Out of Scope (Phase 3)**:

- Seating-aware ticketing (Phase 8)
- Entitlement modes, multi-day passes, re-entry rules (Phase 4+)
- Complex pricing rules (tiered, demand-based, capacity-based) — Phase 4+
- Bundles, add-ons, passes (Phase 4+)
- Payment processing (Payments & Ledger domain)
- QR code generation/validation (Scanning & Devices domain)

---

## 2. Phase 3 Focus Box

**PHASE 3 SCOPE: GA TICKETING ONLY**

This domain specification covers General Admission (quantity-based) ticketing exclusively in Phase 3. Seating-aware ticketing, per-seat pricing, and advanced entitlement modes are **explicitly deferred to Phase 8** (see `/docs/domain/seating.md` and future Phase 8 planning docs).

TicketType in Phase 3 is designed to be forward-compatible with future seating resources; no hard-coded assumptions prevent later bridging to seat structures.

---

## 3. Scope & Responsibility (Canonical)

### In Scope (Phase 3)

1. **TicketType** – GA (quantity-based) ticket definitions.
2. **SeatHold** – Temporary reservations (15-minute TTL) to prevent overselling.
3. **Basic Coupons** – Discount codes with usage tracking.
4. **Inventory Tracking** – GA quantity: total, sold, held.
5. **Caching & Concurrency** – ETS + Redis for fast access and distributed locking.

### Out of Scope (Phase 3)

- **Seating layouts, per-seat pricing** – belongs to Seating domain (Phase 8).
- **Entitlement modes** (re-entry, daily limits, multi-day passes) – Phase 4+.
- **Bundles, add-ons, passes** – Phase 4+.
- **Complex pricing models** (tiered, demand-based, capacity-based) – Phase 4+.
- **Event lifecycle or visibility** – belongs to Events & Venues domain.
- **Financial settlement, PSP details, refunds** – belongs to Payments & Ledger domain.

---

## 4. Core Resources

### 4.1 TicketType (GA Only, Phase 3)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.TicketType`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`  
**Phase**: Phase 3  

**Responsibility**: Define available GA (quantity-based) ticket types for an event.

**Fields (Phase 3)**:

- `id` (UUID)
- `event_id` (UUID) – associated event
- `organization_id` (UUID) – multi-tenancy scoping
- `name` (string) – e.g., "Early Bird", "General Admission"
- `description` (text, nullable)
- `price` (Decimal) – price in primary currency
- `currency` (atom, default `:ZAR`) – for now fixed to ZAR
- `total_quantity` (integer) – total available tickets
- `sold_count` (integer, default 0) – already sold
- `held_count` (integer, default 0) – currently held in SeatHolds
- `sale_start_at` (datetime, nullable) – when sales begin
- `sale_end_at` (datetime, nullable) – when sales end
- `status` (atom: `:available`, `:sold_out`, `:hidden`) – visibility/availability status
- `settings` (JSONB, optional) – e.g. `{"early_bird": true, "internal_only": false}`
- timestamps (`inserted_at`, `updated_at`)

**Derived Calculations** (read-time logic, NOT denormalized fields):

```
available_quantity = total_quantity - sold_count - held_count
```

**Behaviour**:

A ticket can be sold **only if all of the following are true**:

1. `Event.can_sell_tickets? == true` (derived from Event status + sale window; see `/docs/domain/events_venues.md`)
2. `TicketType.status == :available`
3. `available_quantity > 0`

**Important**: TicketType never overrides Event lifecycle. If an Event moves to `:cancelled`, no TicketType can be sold regardless of its status.

**On Sale (Derived, Not a TicketType Status)**:

The concept of "on sale" is a **derived computation combining Event and TicketType**:

```
ticket_on_sale? = Event.on_sale? 
                  AND TicketType.status == :available
                  AND now in [TicketType.sale_start_at, TicketType.sale_end_at]
                  AND available_quantity > 0
```

**Forward Compatibility (Phase 8+)**:

In Phase 3, TicketType is GA-only and does not reference seating constructs. Future phases may:

- Introduce a `kind` field (`:ga` | `:seated`) to distinguish GA from seated tickets.
- Link TicketType to seating constructs via a bridge resource (e.g., `TicketTypeSeatBlock` or `TicketTypeSeatCategory`).
- Add per-seat pricing overrides.

**None of these extensions are implemented in Phase 3**, but the schema must not hard-code anything that prevents them later.

---

### 4.2 SeatHold (GA Holds, Phase 3)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.SeatHold`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/seat_hold.ex`  
**Phase**: Phase 3  

**Responsibility**: Track temporary reservations (holds) to prevent overselling during checkout.

**Fields**:

- `id` (UUID)
- `ticket_type_id` (UUID) – the TicketType being held
- `event_id` (UUID) – denormalized from TicketType for fast queries
- `organization_id` (UUID) – multi-tenancy scoping
- `user_id` (UUID, nullable) – for guest flows or later auth
- `quantity` (integer) – number of tickets held
- `status` (atom: `:active`, `:expired`, `:converted`, `:cancelled`)
- `held_until` (datetime, NOT nullable while status == `:active`) – when this hold expires
- `source` (atom: `:web`, `:scanner`, `:backoffice`, optional) – origin of the hold
- `notes` (text, optional) – audit trail info
- timestamps (`inserted_at`, `updated_at`)

**TTL and Lifecycle** (GLOBALLY STANDARD):

- **Global TTL**: 15 minutes (900 seconds), **no per-event override in Phase 3**
- `held_until = inserted_at + 15 minutes`
- At or after `held_until`, SeatHold **must** move to `:expired` and its quantity returned to available inventory
- Status `:expired` includes both:
  - Natural TTL expiry
  - Forced expiry due to Event status change (`:cancelled` or `:postponed` without rescheduled_at)

**Event Status Interaction** (Must follow `/docs/domain/events_venues.md`):

- **When Event moves to `:cancelled`**:
  - All `:active` SeatHolds for that event **MUST** be immediately released (moved to `:expired`).
  - `TicketType.held_count` is decremented.
  - No new SeatHolds or checkouts may be created while event is `:cancelled`.

- **When Event moves to `:postponed` without `rescheduled_at`**:
  - Existing `:active` SeatHolds remain in the database but are functionally **suspended** (checkout cannot proceed).
  - No new SeatHolds or checkouts are allowed until `rescheduled_at` is set.

- **When Event moves to `:postponed` with `rescheduled_at` set**:
  - SeatHolds and checkouts resume as normal within the new event window.

**Caching & Storage Patterns**:

- **Redis ZSET** for expiry tracking:
  - Key: `ticketing:holds:org:{org_id}:event:{event_id}`
  - Score: `held_until` (epoch timestamp)
  - Value: `seat_hold_id`
  - Used by cleanup worker to scan for expired holds efficiently

- **ETS mirror** per node:
  - For fast per-node lookup before Redis query
  - Invalidated when hold expires or converts

- Must match patterns in `/docs/architecture/03_caching_and_realtime.md`

**Oban Cleanup Worker** (Existing Module):

- Module: `Voelgoedevents.Queues.WorkerCleanupHolds` (do NOT invent new job paths)
- Triggered at `held_until + 10 seconds` (small grace window)
- Actions:
  - Scan Redis ZSET for expired holds
  - Mark SeatHolds as `:expired`
  - Decrement `TicketType.held_count`
  - Update Redis/ETS counters (write-through pattern per Appendix C)
  - Emit PubSub notification: `ticketing:event:{event_id}` with hold expiry details

---

### 4.3 Coupon (Basic, Phase 3)

**Module**: `Voelgoedevents.Ash.Resources.Ticketing.Coupon`  
**File**: `lib/voelgoedevents/ash/resources/ticketing/coupon.ex`  
**Phase**: Phase 3  

**Responsibility**: Track discount codes and their usage.

**Fields**:

- `id` (UUID)
- `organization_id` (UUID) – coupon scoped to org; no cross-org usage
- `event_id` (UUID, nullable) – if set, coupon applies only to this event
- `code` (string, unique per org) – the discount code
- `discount_type` (atom: `:fixed_amount` | `:percent`)
- `amount` (Decimal) – fixed discount amount (if `:fixed_amount`)
- `percent` (Decimal, 0-100) – discount percentage (if `:percent`)
- `max_uses` (integer, nullable) – global max uses across all customers
- `max_uses_per_user` (integer, nullable) – max per customer
- `valid_from` (datetime, nullable)
- `valid_until` (datetime, nullable)
- `is_active` (boolean, default true)
- `notes` (text, optional)
- timestamps (`inserted_at`, `updated_at`)

**Behaviour**:

- Coupon must be checked at checkout time against Event and TicketType rules.
- A coupon is valid only if:
  - `is_active == true`
  - Current datetime is within `[valid_from, valid_until]`
  - `event_id` is null OR matches the checkout event
  - `max_uses` has not been exhausted (global)
  - User's coupon use count < `max_uses_per_user` (user-scoped)
- **Multi-tenancy**: All coupons are scoped by `organization_id`. No coupon may apply across organizations.

---

## 5. Pricing & Coupons (Phase 3: Simple)

**Phase 3 Pricing Strategy**:

- **Base Price**: Fixed price on TicketType.price
- **Optional Discount**: Single coupon applied at checkout (no multi-coupon stacking in Phase 3)
- **Effective Price Calculation** (at checkout):
  ```
  discount = coupon ? apply_discount(base_price, coupon) : 0
  effective_price = base_price - discount
  ```

**Caching**:

- Effective pricing is computed at read-time, not stored.
- Cache pricing lookups for performance:
  - **ETS key**: `pricing:effective:{org_id}:{ticket_type_id}`
  - **Redis warm layer**: For recomputation across nodes (see `/docs/architecture/03_caching_and_realtime.md`)
  - TTL: 30 minutes

**Phase 4+**:

Complex pricing models (tiered, volume-based, capacity-based, dynamic) will be introduced later. Phase 3 must not hard-code pricing logic in a way that blocks future models.

---

## 6. Interaction with Events & Venues (CRITICAL)

**Do NOT introduce a separate Event state machine in Ticketing.** Instead:

- **Canonical Event States**: Defined in `/docs/domain/events_venues.md`
- **Ticketing Rules**: Pure consequences of Event status and sale windows

**Event Status Impact on Ticketing**:

| Event Status | Ticket Sales Allowed? | Notes |
|--------------|----------------------|-------|
| `:draft` | no | Internal/dev only |
| `:published` | yes (if within sale window) | Publicly listed |
| `:live` | yes (if within sale window) | Event in progress |
| `:ended` | no | Finished; read-only |
| `:cancelled` | no (stops immediately) | All holds released |
| `:postponed` (no rescheduled_at) | no | No holds until rescheduled |
| `:postponed` (with rescheduled_at) | yes (if within new window) | Sales resume |
| `:archived` | no | Historical only |

**PubSub Listening**:

Ticketing domain listens to:

- Topic: `events:event:{event_id}`
  - On `:cancelled` → Release all `:active` SeatHolds for that event
  - On `:postponed` (no rescheduled_at) → Suspend new holds/checkouts
  - On `:postponed` (rescheduled_at set) → Resume holds/checkouts
- Publish reactions to `ticketing:event:{event_id}` for downstream consumers (checkout, scanning)

---

## 7. Multi-Tenancy & RBAC (Phase 3)

**Multi-Tenancy Enforcement**:

- All TicketType, SeatHold, and Coupon entities **must** be scoped by `organization_id`
- No TicketType, pricing rule, or coupon may apply across organizations
- Queries must always filter by org_id to prevent cross-tenant leakage

**RBAC Capabilities** (align with `/docs/domain/rbac_and_platform_access.md`):

| Role | Manage TicketTypes | Manage Coupons/Pricing | View Revenue Reports | Trigger Refunds | Touch Ledger/Settlement |
|------|-------------------|------------------------|----------------------|-----------------|-------------------------|
| `:owner` | yes | yes | yes | (Phase 4+) | (Phase 4+) |
| `:admin` | yes | yes | yes | (Phase 4+) | (Phase 4+) |
| `:staff` | yes (bounded) | yes (bounded) | yes | no | no |
| `:scanner_only` | no | no | no | no | no |
| Platform `super_admin` | yes (audit logged) | yes (audit logged) | yes | (Phase 4+) | (Phase 4+) |
| Platform `tenant_manager` | yes (with tenant consent & audit) | yes (with tenant consent & audit) | yes (support) | **no** | **no** |

**tenant_manager Constraints** (Platform-Level Support Role):

- `tenant_manager` may adjust TicketTypes and Coupons **only**:
  - with explicit tenant approval, and
  - when providing:
    - `reason` (text: why the change is needed)
    - `tenant_approval_reference` (email, ticket ID, signed agreement, etc.)
  - All such changes **MUST** be logged via the Auditable/AuditLog mechanism
  
- `tenant_manager` may **NOT**:
  - issue refunds
  - touch ledger balances or settlement configuration
  - change payment method or payout rules
  - modify TicketType prices/coupons without documented tenant consent

This pattern mirrors Event cancel/postpone permissions in `/docs/domain/events_venues.md` and prevents silent, untraceable platform meddling.

**Audit Requirements**:

- All TicketType creation/update/delete must be logged with actor, timestamp, and changes
- All coupon creation and usage must be auditable (especially application at checkout)
- All platform-level overrides (super_admin, tenant_manager) must include reason and tenant consent reference

---

## 8. Redis Structures & Caching

**ETS + Redis Layers** (per `/docs/architecture/03_caching_and_realtime.md`):

### SeatHold Expiry Tracking

**Redis ZSET**:
```
Key: ticketing:holds:org:{org_id}:event:{event_id}
Score: held_until (epoch timestamp)
Value: seat_hold_id
TTL: Match SeatHold TTL (15 minutes)
```

Used by cleanup worker to efficiently identify expired holds without scanning all records.

### TicketType Inventory Summary

**Redis Hash**:
```
Key: ticketing:inventory:{ticket_type_id}
Fields: total_quantity, sold_count, held_count, status, last_updated
TTL: 5 minutes (recalculated frequently due to volatile holds)
```

Used by checkout/cart flows for real-time availability checks.

### Effective Pricing Cache

**Redis Hash**:
```
Key: pricing:effective:{org_id}:{ticket_type_id}
Fields: base_price, currency, effective_price, coupon_applied, last_updated
TTL: 30 minutes
```

Invalidated on TicketType or Coupon change.

---

## 9. Indexing & Query Patterns

**Critical Indexes on `ticket_types`**:

- `organization_id`
- `event_id`
- `(organization_id, event_id)`
- `(organization_id, status)`

**Critical Indexes on `seat_holds`**:

- `organization_id`
- `event_id`
- `ticket_type_id`
- `user_id`
- `status`
- `(event_id, status, held_until)` – for expiry scans

**Critical Indexes on `coupons`**:

- `organization_id`
- `event_id`
- `code` (unique per org)

**Common Queries**:

- List TicketTypes for an event (with inventory): `WHERE event_id = ? AND status != :hidden`
- Get active holds for an event: `WHERE event_id = ? AND status = :active AND held_until > now()`
- Validate coupon at checkout: `WHERE code = ? AND organization_id = ? AND is_active = true`

---

## 10. Interactions with Other Domains

### Events & Venues

- **Dependency**: TicketType.event_id must reference a valid Event
- **Constraint**: Ticket sales allowed only if Event.can_sell_tickets? == true
- **PubSub**: Listen to event status changes to update hold behaviour

### Seating Domain (Phase 8)

- **Deferred**: TicketType will link to seating constructs via bridge resource in Phase 8
- **Constraint**: Phase 3 must NOT hard-code seat-specific logic
- **Design Pattern**: Bridge resource (e.g., TicketTypeSeatBlock) will map TicketType to Seat inventory later

### Payments & Ledger

- **Dependency**: Order creation requires TicketType validation (inventory, price, eligibility)
- **Refund Integration**: Determined by Coupon.refundable flag (Phase 4+)

### Scanning & Devices

- **Dependency**: Ticket scanning uses **Ticket status** (and Event status) to validate eligibility
- **SeatHold**: Is a checkout-time construct only and is **never consulted at scan time**
- **Entitlement**: In Phase 3, all scans are `:single_entry` (no re-entry logic yet)

### Reporting & Analytics

- **Feeds**: Ticket sales and hold creation/expiry feed FunnelSnapshot
- **Dimension**: Event + TicketType is primary breakdown

---

## 11. Performance & Observability

### Tests (Phase 3 Must Cover)

- **Inventory Protection**:
  - Cannot oversell (available_quantity must remain >= 0)
  - sold_count + held_count <= total_quantity always

- **SeatHold Lifecycle**:
  - Hold expires after exactly 15 minutes
  - Expiry releases quantity back to available
  - Cleanup worker processes expirations correctly

- **Event Status Transitions**:
  - `:cancelled` event releases all active holds
  - `:postponed` (no rescheduled_at) suspends new holds
  - `:postponed` (with rescheduled_at) resumes holds

- **Multi-Tenant Isolation**:
  - Cannot access another org's TicketTypes, SeatHolds, or Coupons
  - Coupon never applies across orgs

- **Coupon Validation**:
  - Invalid coupons rejected (expired, max uses reached, inactive)
  - Per-user limits enforced correctly

### Observability: Telemetry Events

Emit structured telemetry with these standard fields:

- `organization_id`
- `event_id`
- `ticket_type_id`
- `user_id` (if applicable)
- `timestamp`

**Events to Track**:

1. **Ticket Sold**
   - Fields: quantity, price, coupon_code, effective_price
   - Used for: Revenue tracking, discount analysis

2. **Hold Created**
   - Fields: quantity, source (web/scanner/backoffice)
   - Used for: Conversion funnel, hold analysis

3. **Hold Expired**
   - Fields: quantity, reason (natural TTL vs event cancelled/postponed)
   - Used for: Cart abandonment metrics, inventory volatility

4. **Hold Converted** (to ticket)
   - Fields: quantity, conversion_time_seconds
   - Used for: Checkout conversion rates

5. **Inventory Recalculated**
   - Fields: total_quantity, sold_count, held_count, available_quantity
   - Used for: Inventory health monitoring

6. **Coupon Applied**
   - Fields: coupon_code, discount_type, discount_amount
   - Used for: Pricing analytics, discount effectiveness

7. **TicketType Status Changed**
   - Fields: old_status, new_status, reason
   - Used for: Audit, sales pattern analysis

### Logs

- Log all TicketType CRUD operations with actor, timestamp, and changes
- Log hold creation/expiry/conversion with reason
- Log coupon application attempts (valid and invalid)
- Log refund eligibility checks and outcomes

---

## 12. Edge Cases & Error Handling

- **Concurrent holds on same TicketType**:
  - Use distributed lock (DLM) during hold creation: `lock:ticket_type:{ticket_type_id}`
  - Prevents double-booking via optimistic lock on version field

- **Event cancelled mid-hold**:
  - SeatHold release triggered via PubSub notification
  - If release fails, manual intervention queue flagged for admin

- **Hold expiry race**:
  - Worker checks `held_until` at invocation time; if already released, skip
  - Idempotent release logic ensures no double-decrement

- **Coupon exhausted at checkout**:
  - Validate max_uses BEFORE checkout creation
  - If exhausted between validation and checkout, checkout fails with clear message

---

## 13. Future Extensions (Phase 4+)

**Not in Phase 3 Scope**:

- Complex pricing models (tiered, capacity-based, demand-based, add-on-based, bundle-based)
- Multi-coupon stacking
- Advanced entitlement modes (re-entry, daily limits, multi-day passes)
- Passes, bundles, add-ons
- TicketingPolicy resource (tenant-level configuration)
- Seated tickets and per-seat pricing
- Donation subsystem
- Refund policy enforcement

These will be introduced in later phases with clear TOON prompts and phase documentation.

---

## 14. Document Status

**Version**: 3.1 (Phase 3 Canonical + RBAC & Scanning Updates)  
**Last Updated**: December 11, 2025  
**Status**: Phase 3 Specification – GA Ticketing Only  
**Next Review**: After Phase 3 implementation, before Phase 4 planning  

---

## 15. References

- `/docs/PHASE_03_Core_Events_&_GA_Ticketing.md` – Phase 3 implementation roadmap
- `/docs/domain/events_venues.md` – Event lifecycle and state machine (canonical)
- `/docs/domain/rbac_and_platform_access.md` – RBAC policies and capabilities
- `/docs/architecture/02_multi_tenancy.md` – Multi-tenancy enforcement patterns
- `/docs/architecture/03_caching_and_realtime.md` – ETS + Redis caching patterns
- `/docs/architecture/05_eventing_model.md` – PubSub topics and event patterns
- `/docs/architecture/06_jobs_and_async.md` – Oban job patterns

---
