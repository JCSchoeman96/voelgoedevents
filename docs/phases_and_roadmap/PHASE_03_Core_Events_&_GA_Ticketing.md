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
- States: `:draft`, `:published`, `:live`, `:ended`, `:archived`
- Transitions: `:draft` → `:published` (admin), `:published` → `:live` (auto/manual), `:live` → `:ended` (auto/manual), `:ended` → `:archived` (admin)
- Apply policies: only org admins can publish events
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache published events in Redis (TTL: 1 hour)
- Reference `/docs/domain/events_venues.md`
- Attributes: `id`, `organization_id`, `venue_id`, `name`, `description`, `status`, `start_time`, `end_time`, `sale_start`, `sale_end`, `capacity`, `settings`, timestamps

---

### Phase 3.3: TicketType Resource (GA)

#### Sub-Phase 3.3.1: Create TicketType Resource

**Task:** Define TicketType resource for GA (General Admission) tickets  
**Objective:** Support inventory-based ticket sales with pricing and availability  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_ticket_types.exs`  
**Note:**  
- GA only in Phase 3 (seated ticketing in Phase 8)
- Inventory tracking: `total_quantity`, `sold_count`, `held_count`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — ETS + Redis counters
- Reference `/docs/domain/ticketing_pricing.md`
- Attributes: `id`, `event_id`, `organization_id`, `name`, `description`, `price` (Decimal), `currency` (`:ZAR`), `total_quantity`, `sold_count` (default: 0), `held_count` (default: 0), `sale_start`, `sale_end`, `status` (`:available`, `:sold_out`, `:hidden`), `settings`, timestamps
- Calculations: `available_quantity = total_quantity - sold_count - held_count`

---

### Phase 3.4: Seat Hold & Release Workflows

#### Sub-Phase 3.4.1: Create SeatHold Resource (for GA)

**Task:** Define SeatHold resource to track temporary reservations (5-minute TTL)  
**Objective:** Prevent overselling during checkout process  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/seat_hold.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_seat_holds.exs`  
**Note:**  
- TTL: 5 minutes (300 seconds)
- Status: `:active`, `:expired`, `:converted`, `:cancelled`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C):
  - Store in Redis ZSET for expiry tracking (key: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`)
  - Mirror in ETS for per-node fast lookup
- Reference `/docs/workflows/reserve_seat.md` for full workflow specification
- Attributes: `id`, `ticket_type_id`, `event_id`, `user_id`, `organization_id`, `quantity`, `status`, `held_until`, `source` (`:web`, `:scanner`), `notes`, timestamps

---

#### Sub-Phase 3.4.2: Implement Reserve Workflow (GA)

**Task:** Create workflow to hold GA tickets with optimistic lock and cache population  
**Objective:** Atomic hold creation with Redis/ETS sync  
**Output:** `lib/voelgoedevents/workflows/ticketing/reserve_ga_tickets.ex`  
**Note:**  
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — do NOT re-describe caching logic
- Use DLM for critical section: `"hold:ticket_type:#{ticket_type_id}"`
- Reference `/docs/workflows/reserve_seat.md` for full specification
- Validate available quantity (optimistic lock on `TicketType.version`)
- Schedule Oban cleanup job (5 min TTL)
- Broadcast PubSub occupancy update

---

#### Sub-Phase 3.4.3: Implement Release Workflow (GA)

**Task:** Create workflow to release expired or cancelled holds  
**Objective:** Restore inventory and clean up caches  
**Output:** `lib/voelgoedevents/workflows/ticketing/release_ga_tickets.ex`  
**Note:**  
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

---