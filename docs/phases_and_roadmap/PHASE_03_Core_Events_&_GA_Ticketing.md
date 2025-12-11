## 🎟️ PHASE 3: Core Events & GA Ticketing

**Goal:** Implement Event, Venue, TicketType resources and basic inventory-based ticketing  
**Duration:** 2 weeks  
**Deliverables:** Event CRUD, GA ticket sales, basic seat hold/release workflows  
**Dependencies:** Completes Phase 2

---

### Phase 3.1: Venue & Gate Resources

#### Sub-Phase 3.1.1: Create Venue Resource

**Task:** Define Venue resource with name, address, capacity, timezone  
**Objective:** Establish physical location context for events  
**Output:**  
- `lib/voelgoedevents/ash/resources/venues/venue.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_venues.exs`  
**Note:**  
- Include `organization_id` for multi-tenancy (Appendix B enforcement)
- Apply policies: only org members can create venues
- Reference `/docs/domain/events_venues.md`
- Attributes: `id`, `organization_id`, `name`, `address`, `city`, `country`, `postal_code`, `timezone`, `capacity`, `settings`, `status`, timestamps

---

#### Sub-Phase 3.1.2: Create Gate Resource

**Task:** Define Gate resource linking to Venue with access control settings  
**Objective:** Support multi-gate scanning and occupancy tracking  
**Output:**  
- `lib/voelgoedevents/ash/resources/venues/gate.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_gates.exs`  
**Note:**  
- Each gate has unique code (e.g., "GATE_A", "MAIN_ENTRANCE")
- Used by scanning devices for entry validation
- Attributes: `id`, `venue_id`, `organization_id`, `gate_code`, `name`, `status` (`:open`, `:closed`), `capacity`, `settings`, timestamps

---

### Phase 3.2: Event Resource

#### Sub-Phase 3.2.1: Create Event Resource with State Machine

**Task:** Define Event resource with status state machine  
**Objective:** Enable event lifecycle management and publishing workflow  
**Output:**  
- `lib/voelgoedevents/ash/resources/events/event.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_events.exs`  
**Note:**  
- Use `AshStateMachine` extension for status transitions
- Apply policies: only org admins can publish events
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache published events in Redis (TTL: 1 hour)
- Reference `/docs/domain/events_venues.md`
- Attributes: `id`, `organization_id`, `venue_id`, `name`, `description`, `status`, `start_at`, `end_at`, `sale_start_at`, `sale_end_at`, `capacity`, `settings`, timestamps

**States (canonical):**

- `:draft`
- `:published`
- `:live`
- `:ended`
- `:cancelled`
- `:postponed`
- `:archived`

**State Behaviour Table:**

| status      | can_sell_tickets?                                              | can_scan_tickets?                                                                                           | visible_publicly?                                    | notes                                        |
|-------------|----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|----------------------------------------------|
| `:draft`    | no (only internal test transactions in dev tools)             | no (only internal/dev test tools, not counted as real scans)                                               | no                                                  | Work-in-progress setup                       |
| `:published`| yes (if within `sale_start_at..sale_end_at`)                  | no real scans; only test scans allowed and must not count as real scans                                    | yes                                                 | Publicly listed, not yet "live"              |
| `:live`     | yes (if within `sale_start_at..sale_end_at`)                  | yes – real scans allowed, but only within `[start_at, end_at]` (plus small configurable grace window)      | yes                                                 | Event in progress                            |
| `:ended`    | no                                                             | no                                                                                                          | no on storefront; yes in organiser/admin dashboards | Finished; read-only reporting                |
| `:cancelled`| no (sales stop immediately)                                   | no                                                                                                          | no on storefront; visible in organiser/admin UI     | Cancelled; refunds handled by later phases   |
| `:postponed`| if no new date: no; if `rescheduled_at` set: yes (sale window)| only if `rescheduled_at` set **and** current time in that new event date window (same rules as `:live`)    | yes, with strong "postponed/rescheduled" messaging  | Tickets remain valid but date changed        |
| `:archived` | no                                                             | no                                                                                                          | no (only via reporting/history screens)             | Long-term storage / housekeeping             |

**Additional fields for postponement & recurrence:**

- `replaced_by_event_id` (nullable) – for postponed/duplicated events pointing to the replacement event.
- `recurrence_group_id` (nullable) – groups recurring runs of the "same" event series (e.g. Passievol 2025, 2026, 2027).
- `rescheduled_at` (nullable datetime) – when `status == :postponed`, this holds the new date/time if known.
- `postponement_reason` (string/enum, optional) – reason code or message (weather, restrictions, low sales, etc.).

**Derived Status:**

"On sale" is **not** a status state; it is a derived computation:

```
on_sale? = status in [:published, :live, :postponed] AND now in sale_start_at..sale_end_at
```

---

### Phase 3.3: TicketType Resource (GA)

#### Sub-Phase 3.3.1: Create TicketType Resource

**Task:** Define TicketType resource for GA (General Admission) tickets  
**Objective:** Support inventory-based ticket sales with pricing and availability  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_ticket_types.exs`  
**Note:**  
- **Phase 3 TicketType represents GA products only** (quantity-based, no seat references yet).
- Inventory tracking: `total_quantity`, `sold_count`, `held_count`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — ETS + Redis counters
- Reference `/docs/domain/ticketing_pricing.md`
- Attributes: `id`, `event_id`, `organization_id`, `name`, `description`, `price` (Decimal), `currency` (`:ZAR`), `total_quantity`, `sold_count` (default: 0), `held_count` (default: 0), `sale_start_at`, `sale_end_at`, `status` (`:available`, `:sold_out`, `:hidden`), `settings`, timestamps
- Calculations: `available_quantity = total_quantity - sold_count - held_count`

**Design Constraint – Future Seating Compatibility:**

TicketType must be designed and implemented to remain compatible with future seating resources (SeatingPlan, Section, Block, Seat) and a bridge resource (e.g. TicketTypeSeatBlock or TicketTypeSeatCategory). **Phase 3 must not hard-code anything that prevents later linking TicketType to seat structures.** Phase 8 will extend ticketing to support assigned seats via this bridge resource; the TicketType schema laid in Phase 3 must anticipate this evolution without implementing it.

---

### Phase 3.4: Seat Hold & Release Workflows

#### Sub-Phase 3.4.1: Create SeatHold Resource (for GA)

**Task:** Define SeatHold resource to track temporary reservations (15-minute TTL)  
**Objective:** Prevent overselling during checkout process  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/seat_hold.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_seat_holds.exs`  
**Note:**  
- **TTL: 15 minutes (900 seconds), globally standard** (no per-event override in Phase 3)
- Status: `:active`, `:expired`, `:converted`, `:cancelled`
  - `:expired` includes both natural TTL expiry and forced expiry due to Event.cancelled or Event.postponed (no new date)
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C):
  - Store in Redis ZSET for expiry tracking (key: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`)
  - Mirror in ETS for per-node fast lookup
- Reference `/docs/workflows/reserve_seat.md` for full workflow specification
- Attributes: `id`, `ticket_type_id`, `event_id`, `user_id`, `organization_id`, `quantity`, `status`, `held_until`, `source` (`:web`, `:scanner`), `notes`, timestamps

**Behaviour Rules – Event Status Changes:**

- **When the related Event moves to `:cancelled`:**
  - All `:active` SeatHolds for that event **MUST** be expired immediately (via release/cleanup workflow).
  - No new SeatHolds or checkouts may be created for that event.

- **When the related Event moves to `:postponed`:**
  - If `rescheduled_at` is **nil** (no new date yet): existing SeatHolds remain, but **no new** SeatHolds or checkouts are allowed.
  - If `rescheduled_at` is set (event rescheduled): SeatHolds and checkouts are allowed again as normal, but UI must show "postponed/rescheduled" messaging.

---

#### Sub-Phase 3.4.2: Implement Reserve Workflow (GA)

**Task:** Create workflow to hold GA tickets with optimistic lock and cache population  
**Objective:** Atomic hold creation with Redis/ETS sync  
**Output:** `lib/voelgoedevents/workflows/ticketing/reserve_seat.ex` (module: `Voelgoedevents.Workflows.Ticketing.ReserveSeat`)  
**Note:**  
- **Phase 3 scope:** This workflow only handles GA (quantity-based) tickets. Phase 8 will extend this same workflow to support seated tickets via the Seating engine.
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — do NOT re-describe caching logic
- Use DLM for critical section: `"hold:ticket_type:#{ticket_type_id}"`
- Reference `/docs/workflows/reserve_seat.md` for full specification
- Validate available quantity (optimistic lock on `TicketType.version`)
- Schedule Oban cleanup job (15 min TTL)
- Broadcast PubSub occupancy update

---

#### Sub-Phase 3.4.3: Implement Release Workflow (GA)

**Task:** Create workflow to release expired or cancelled holds  
**Objective:** Restore inventory and clean up caches  
**Output:** `lib/voelgoedevents/workflows/ticketing/release_seat.ex` (module: `Voelgoedevents.Workflows.Ticketing.ReleaseSeat`)  
**Note:**  
- **Phase 3 scope:** This workflow only handles GA (quantity-based) tickets. Phase 8 will extend this same workflow to support seated tickets via the Seating engine.
- Triggered by Oban job at `held_until + 10s`
- Decrement `TicketType.held_count`
- Clear Redis + ETS entries (Appendix C write-through pattern)
- Reference `/docs/workflows/release_seat.md` for full specification

---

### Phase 3.5: Basic Checkout Flow (Simplified)

#### Sub-Phase 3.5.1: Create Checkout Session Workflow (Stub)

**Task:** Create minimal checkout workflow for Phase 3 (no payment yet)  
**Objective:** Convert holds to "reserved" state (payment in Phase 4)  
**Output:** `lib/voelgoedevents/workflows/checkout/start_checkout.ex`  
**Note:**  
- Phase 3: Validates holds, creates placeholder order
- Phase 4: Adds payment integration
- Reference `/docs/workflows/start_checkout.md` for full specification

**Behaviour Under Cancelled/Postponed Events:**

- **StartCheckout MUST hard-fail if:**
  - `Event.status == :cancelled`
  - `Event.status == :postponed` AND `rescheduled_at` is nil (no new date yet)

- **StartCheckout MAY proceed if:**
  - `Event.status in [:published, :live, :postponed]` AND `rescheduled_at` is set AND within sale window

This ensures Phase 3 cannot accidentally allow checkout for cancelled or date-unknown postponed events.

---

## RBAC & Audit for Event Cancel/Postpone

**Roles & Permissions:**

- **Tenant roles:**
  - `:owner` and `:admin` may cancel or postpone events.
  - `:staff` cannot cancel or postpone by default.

- **Platform:**
  - Platform `super_admin` may always cancel/postpone any event (e.g., safety, abuse, legal reasons).
  - `tenant_manager` may cancel/postpone only when a tenant explicitly authorizes it, and this must be logged.

**Audit & Compliance:**

- All cancel/postpone actions **MUST** be auditable (see `/docs/rbac_and_platform_access.md` for detailed policy semantics):
  - Include `reason` (text/enum).
  - Include `tenant_approval_reference` (for `tenant_manager` actions).
  - Log actor identity, timestamp, and affected event ID.

**Note:** Full RBAC policy semantics are defined in `/docs/rbac_and_platform_access.md`; this section is a cross-link and behavioural summary only.

---
