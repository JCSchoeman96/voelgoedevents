# Domain: Seating

## Overview & Purpose

The **Seating** domain manages all aspects of physical and logical venue seating: layouts, zones, individual seats, accessibility features, multi-day seat assignments, and real-time seat availability state. This domain ensures accurate venue representation, prevents double-booking through distributed locking, and integrates tightly with Ticketing (seat-based inventory), Payments (pricing zones), and Scanning (entry validation).

**Core Responsibilities**:

- Venue layout and seating configuration (Layout, Zones, Seats).
- Seat identity stability and layout versioning.
- Zone classification: reserved seating, GA (seated/standing), VIP, accessibility.
- Real-time seat availability (available, held, sold, blocked).
- Accessibility seat types (standard, wheelchair, companion).
- Multi-day seat assignment and validity across event days.
- VIP and membership-restricted zone access control.
- Seat hold registry integration (coordinated with Ticketing domain).
- Performance caching (ETS, Redis, PostgreSQL).
- Layout migration and version control (when seats are modified post-sale).

**Out of Scope**:

- Pricing logic (delegated to Ticketing & Pricing domain).
- Payment processing (delegated to Payments & Ledger domain).
- QR code scanning and gate validation (delegated to Scanning domain).
- Figma import or visual seating plan editor UI (Phase 9, not Phase 8).

---

## Scope & Boundaries

### In Scope

1. **Layout & Version Management**: VenueLayout (canonical) and EventLayout (shallow copy with overrides).
2. **Zones**: Logical groupings with type (reserved_seating, ga_seated, ga_standing, vip_reserved, vip_standing).
3. **Zone Access Control**: Public, membership_tier, role_based, whitelist modes for VIP/restricted zones.
4. **Seats**: Individual seats with stable seat_id, physical position, category (standard, wheelchair, companion).
5. **Accessibility Rules**: Wheelchair + companion pairing, soft-reservation, occupancy-based release thresholds.
6. **Seat Holds & Inventory**: Integration with Ticketing's SeatHold registry; observed via Redis/ETS.
7. **Multi-Day Seating**: Stable seat assignment across multiple event days.
8. **Hybrid Events**: Mixed reserved seating + GA zones (seated or standing).
9. **Orphan Seat Avoidance**: Algorithmic preference for contiguous seat clusters, grouping logic.
10. **Group Bookings**: Support for N-seat reservations with adjacency hints.
11. **SeatingPolicy**: Tenant-level SuperAdmin configuration and event-level overrides.
12. **Performance & Caching**: Hot (ETS), Warm (Redis), Cold (PostgreSQL) layers.

### Out of Scope

- External payment processing (Payments & Ledger domain).
- QR code generation, signing, validation (Scanning domain, Ticket Identity).
- Scanning gate operations and device control (Scanning domain).
- Figma/import tooling (Phase 9+, not Phase 8).
- Highly dynamic session-based seating or flexible reconfiguration during events (future enhancement).

---

## Seat Identity & Layout Inheritance Model

### Seat Identity

**Fundamental Principle**: Each seat is identified by a **stable, venue-level `seat_id`** that is unique within a layout and valid for the entire event duration (including multi-day events).

- Seat position (section, row, number, coordinates) is defined in the venue **Layout** resource.
- Seat IDs MUST NOT change during an event, even across multiple days.
- A seat's physical position and metadata are immutable once events reference that layout version.

### Layout Hierarchy

**VenueLayout** (Canonical):

- Owned by a **Venue** (which belongs to an **Organisation**).
- Contains all possible sections, rows, and seats for that venue.
- Immutable after creation (mutations create new versions).
- Stored in PostgreSQL + Redis JSON cache.

**EventLayout** (Event-Specific Overlay):

- Reference to a **VenueLayout** with event-specific overrides:
  - Enabled/disabled zones (e.g., disable VIP zone for budget event).
  - Blocked seats (e.g., emergency exit, structural obstruction).
  - Zone type remapping (e.g., zone becomes standing-only for festival).
  - Pricing zone assignment (which zones get which PricingRule).
- **Shallow copy model**: EventLayout does NOT replicate seat data; it references VenueLayout + stores deltas.
- Each Event MUST reference a specific `(layout_id, layout_version)` pair.
- Once tickets are sold for an event, the layout version is **frozen**.

### Layout Versioning & Migration

**Invariants**:

- A VenueLayout CAN be modified (creating new version) ONLY if no on-sale/live events reference it.
- Once an event has sold tickets, you MUST NOT mutate its layout in-place.
- If layout changes are needed post-sale (e.g., seat relocations):
  - Create a **new layout version**.
  - Implement a **migration workflow** (Phase 8+ advanced feature) to relocate existing ticket holders.
  - Update Event to reference new layout version.
  - Both old and new layouts preserved for audit trail.

---

## Zones, GA, Standing & VIP Model

### Zone Concept & Types

A **Zone** is a logical grouping of seats or capacity within a Layout. Each zone has:

- **zone_id** (UUID): Unique within layout.
- **zone_type** (enum):
  - `:reserved_seating` — Physical seats, reserved per booking.
  - `:ga_seated` — GA capacity with flexible seat assignment per entry.
  - `:ga_standing` — Standing room only, capacity-based, no individual seats.
  - `:vip_reserved` — Reserved seats + membership/role restrictions.
  - `:vip_standing` — VIP standing area + access control.
- **capacity** (integer): Total seats/spots in this zone.
- **access_mode** (enum):
  - `:public` — Anyone can book/enter.
  - `:membership_tier` — Only users with specific membership tier.
  - `:role_based` — Only users with specific role (admin, organizer, etc.).
  - `:whitelist` — Only whitelisted users (future, Phase 8+).
- **availability_status** (derived): Calculated from held + sold counts.
- **metadata** (JSONB): Zone-specific config (row count, seat numbering scheme, accessibility features, etc.).

### Seat Assignment by Zone Type

**Reserved Seating Zones** (`:reserved_seating`, `:vip_reserved`):

- Each seat has a fixed `seat_id`, row, number, coordinates.
- On booking: Customer selects specific seat_id → SeatHold created → Ticket assigned to that seat_id.
- Multi-day: Same seat_id valid across all days ticket is valid for.

**GA Seated Zones** (`:ga_seated`):

- Zone has total capacity (e.g., 500 seats) but NO individual seat objects.
- On booking: System or customer doesn't select specific seat; just allocates capacity.
- On entry (scanning): Assigner device can assign a physical seat from available pool in GA zone, OR just validates capacity.
- Multi-day: Seat assignment per entry, not fixed across days (unless event-level config specifies).

**Standing Zones** (`:ga_standing`, `:vip_standing`):

- Pure capacity-based (no seats).
- Booking: Customer reserves X capacity units.
- Entry: Gate validates occupancy count, increments live attendee count.
- No seat_id assignments.

### VIP & Membership-Restricted Zones

**Access Control Integration**:

1. **Zone-Level Configuration**:

   - Zone `access_mode` and `membership_tier` (if applicable).
   - Example: VIP zone with `access_mode: :membership_tier, membership_tier: "voelgoed_vriendinne"`.

2. **Booking Validation**:

   - When user attempts to book/hold seat in restricted zone:
     - Check `access_mode`:
       - `:public` → Allow all.
       - `:membership_tier` → Verify user has membership tier via Accounts domain.
       - `:role_based` → Verify user has role via Ash Policy.
   - If unauthorized → Reject with 403 error.

3. **Ash Policy Integration**:

   - SeatingPolicy resource defines which access_modes are enabled per tenant.
   - Domain event authorizes actions: `authorize_if (user_has_membership_for_zone)`.
   - Example policy:
     ```
     authorize if access_mode == :public
     authorize if (access_mode == :membership_tier AND user.membership_tier == zone.membership_tier)
     authorize if (access_mode == :role_based AND user.role in zone.allowed_roles)
     forbid if not_authenticated
     ```

4. **Multi-Ticket Booking for Friends**:
   - If a Voelgoed Vriendinne member books for 3 friends in a VIP zone:
     - All 3 friends MUST either:
       - Also be Vriendinne members, OR
       - Be explicitly added to a whitelist.
   - Scanning validates each ticket's associated membership at entry time.
   - Field on Ticket: `associated_membership_id` (optional, links ticket to membership record).

---

## Accessibility & Companion Seat Model

### Seat Categories

Each Seat has a **category** (atom):

- `:standard` — Regular seat, no special accommodation.
- `:wheelchair` — Wheelchair-accessible seat.
- `:companion` — Companion seat (logically paired with a wheelchair seat).
- `:restricted_view` (optional) — Obstructed view, lower price tier.
- `:aisle` (optional) — Aisle seat, no adjacent seat on one side.

### Wheelchair + Companion Pairing

**Rules**:

1. A wheelchair seat CAN be booked alone (no forced companion purchase).
2. Each wheelchair seat has logically paired companion seat(s) — typically:
   - One directly adjacent (if adjacent exists).
   - Or designated in layout metadata.
3. When wheelchair seat is booked (SeatHold created):
   - Paired companion seat(s) are **soft-reserved** (not bookable by general public).
   - Soft-reserve persists until zone occupancy reaches high threshold (configurable, default 80–90%).
4. Once threshold reached:
   - Unclaimed companion seats are **released to general pool** (any customer can now book).
   - Soft-reservation lifted via SeatingPolicy rule.

### Configuration in SeatingPolicy & Event Config

**SeatingPolicy Fields**:

- `enforce_accessibility_rules` (boolean, default true) — Enable companion soft-reserve.
- `companion_release_occupancy_threshold` (integer, default 85) — Occupancy % when companion seats released.
- `max_wheelchair_seats_per_booking` (integer, default 1) — Prevent abuse.
- `accessibility_audit_enabled` (boolean, default true) — Log all accessibility bookings.

**Event-Level Overrides**:

- Event can override SeatingPolicy defaults via EventLayout metadata.
- Example: `seating_config: { enforce_accessibility_rules: false }` for small/simple events.

### Data Representation

**Option A: Companion Seat Metadata**

- Seat resource has field `companion_seat_id` (UUID, nullable).
- Wheelchair seat → companion_seat_id = adjacent seat.
- Companion seat → companion_of_seat_id = paired wheelchair seat.

**Option B: SeatGroup Resource** (recommended for Phase 8+)

- New resource `SeatGroup` groups logically related seats.
- Seats belong to a SeatGroup via `seat_group_id`.
- SeatGroup has `group_type: :wheelchair_pair, :family_block, :vip_table`.
- Soft-reserve logic operates on group level.

### UI & Scanning Integration

**Checkout/Selection UI**:

- When user selects wheelchair seat, UI optionally displays and suggests companion seat.
- System shows companion pricing (if discounted) and highlights soft-reserve status.
- Accessibility details displayed: "This seat is wheelchair accessible. A companion seat (Row A, Seat 43) is reserved for you."

**Scanner Device**:

- When wheelchair ticket scanned, device notes accessibility flag.
- Staff can see: "Wheelchair ticket, companion reserved."
- On-gate UI prompts: "Please ensure companion is accompanied."

---

## Multi-Day & Multi-Session Seating

### Seat Assignment for Multi-Day Events

**Fundamental Rule**: For reserved seating in multi-day events, seat assignment is **stable for the entire event duration**.

**Definition**:

- A seat assignment (Ticket → Seat) is valid for **all days the ticket is valid** for that event.
- Example: 3-day festival pass (Fri–Sun) → Same seat reserved for all 3 days.
- Entry on each day: Same seat_id scanned, ticket increments entry counter.

**Scanning Behavior**:

- Day 1: User scans ticket → Seat marked occupied for Day 1.
- Day 2: Same user scans same ticket → Seat marked occupied for Day 2.
- No separate "per-day" seat objects; same ticket + seat_id tracked across days.

### GA Zones in Multi-Day Events

**Reserved Seating + GA Mixed**:

- Reserved seats: Stable as above.
- GA zones: Capacity-based, NO per-seat assignment.
  - Booking: Customer reserves N capacity in GA zone (not specific seats).
  - Scanning: Capacity validated per day (live occupancy count).
  - No seat_id tracked for GA.

**Multi-Day Pass + GA Ticket**:

- If ticket is multi-day, each day's entry validated against entitlement cap.
- Example: `:limited_reentry_per_day` pass → Max 1 entry per day.
- Scanning validates: `entry_count_today < max_daily_entries` from TicketType.

### Sessions (Future, Not Phase 8)

**Out of Scope for Phase 8**: Session-based seating (matinee vs. evening showings with different seat assignments) is deferred to Phase 8+ enhancement.

- Implementation would require per-session seat status tracking.
- Would complicate layout and availability caching significantly.
- Mark in roadmap for future consideration.

---

## No Orphan Seats & Group/Adjacency Rules

### Orphan Seat Definition

An **orphan seat** is an available seat that is isolated (not adjacent to other available seats) after a booking.

**Example**:

```
Before: [ A1(av) A2(av) A3(av) A4(av) A5(av) ]
User books: A2, A4
After:  [ A1(av) A2(X)  A3(av) A4(X)  A5(av) ]
Result: A1 and A3 are orphaned (isolated, hard to sell later)
```

### Avoidance Strategy

**Algorithmic Preference**:

1. When allocating seats, prefer contiguous blocks.
2. If contiguous block unavailable, find best-available cluster (minimize orphan creation).
3. MUST NOT create orphans if other options exist.
4. **Exceptions** (allow orphans in these cases):
   - Row is >90% sold (almost no availability left).
   - Only single seats remain in row (all are inherently orphans).
   - User specifically requests non-adjacent seats (rare).

**No Orphan Logic Example**:

```elixir
# Request: 2 adjacent seats in Row A (seats 1-10)
# Availability: 1(av) 2(X) 3(av) 4(av) 5(X) 6(av) 7(av) 8(av) 9(X) 10(av)

# Preferred allocation: Seats 6-7 (contiguous, no orphans created)
# NOT seats 1+6 (would orphan seat 10, isolate seats 3-4)
# NOT seats 3+8 (would orphan seats 1, 10)
```

### Group Booking & Adjacency

**Group Booking**:

- Customer requests N seats (e.g., party of 5).
- System SHOULD try to find N contiguous seats in same row/section.
- If contiguous not available:
  - Fall back to best-available cluster (e.g., 4 together + 1 nearby).
  - Clearly communicate to customer: "4 seats together in Row A, 1 seat in Row B (3 rows back)."

**Seating Policy Configuration**:

- `group_adjacency_strict` (boolean, default false) → Require contiguity or reject?
- `max_group_split` (integer, default 2 rows) → Max distance between group clusters?
- `prefer_clustering_over_selection` (boolean) → System chooses seats vs. customer selects?

---

## Hybrid Seating Model (Reserved + GA + Standing)

### Mixed Capacity Event Example

**Festival Layout**:

- **Section A** (`:reserved_seating`) → 200 fixed seats, $80/ticket.
- **Section B** (`:ga_seated`) → 300 GA capacity, flexible seat per entry, $60/ticket.
- **Pit** (`:ga_standing`) → 400 standing capacity, pure occupancy, $40/ticket.
- **VIP Lounge** (`:vip_reserved`) → 50 seats, $200/ticket, Vriendinne-only.

**Total Event Capacity**: 950 (500 seated + 400 standing).

### Capacity Calculation

**Reserved Seating**:

- Capacity = count(Seats in zone).
- Available = Capacity - sold_count - held_count (via Ticketing domain).

**GA Seated**:

- Capacity = zone.capacity integer.
- Available = Capacity - sold_count - held_count.
- No per-seat tracking.

**GA Standing / VIP Standing**:

- Capacity = zone.capacity integer.
- Available = Capacity - sold_count - held_count.
- Live occupancy tracked via Scanning (entry/exit counts).

### Mixed Capacity Interactions

**Inventory Pools**:

- Each zone has independent capacity (no cross-pool blending in MVP).
- Example: Section A fully sold does NOT make Section B cheaper or free.
- (Future Phase 8+: dynamic re-pricing based on total event occupancy.)

**Total Event Occupancy**:

- Calculated as sum across all zones: `live_attendance = sum(zone.occupancy)`.
- Used for dashboards, analytics, venue management.

---

## Resources & Relationships (Ash-Oriented)

### Resource: Layout

**Module**: `Voelgoedevents.Ash.Resources.Seating.Layout`  
**File**: `lib/voelgoedevents/ash/resources/seating/layout.ex`  
**Phase Introduced**: Phase 8

**Responsibility**: Define venue seating configuration.

**Key Fields**:

- `id` (UUID, primary key)
- `organization_id` (UUID) — multi-tenancy
- `venue_id` (UUID) — associated venue
- `name` (string) — e.g., "Main Hall 2025"
- `description` (string, nullable)
- `version` (integer) — auto-incrementing for schema evolution
- `total_capacity` (integer) — sum of all zones
- `config` (JSONB) — nested structure:
  ```json
  {
    "zones": [
      {
        "zone_id": "uuid-section-a",
        "zone_type": "reserved_seating",
        "name": "Orchestra",
        "capacity": 200,
        "access_mode": "public",
        "seats": [
          {
            "seat_id": "uuid-a-1-1",
            "row": "A",
            "number": 1,
            "category": "standard",
            "coordinates": { "x": 10, "y": 50 }
          }
        ]
      }
    ]
  }
  ```
- `status` (atom: `:draft`, `:active`, `:archived`)
- `created_at`, `updated_at`

**Invariants**:

- Layout belongs to exactly one organization and one venue.
- `config` MUST be structurally valid (no overlapping seat IDs, no cycles, etc.).
- Seat IDs MUST be unique within layout.
- Total capacity MUST match sum of zone capacities.

### Resource: Zone

**Module**: `Voelgoedevents.Ash.Resources.Seating.Zone`  
**File**: `lib/voelgoedevents/ash/resources/seating/zone.ex`  
**Phase Introduced**: Phase 8

**Responsibility**: Logical grouping of seats/capacity with access control.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `layout_id` (UUID) — parent layout
- `zone_type` (atom: `:reserved_seating`, `:ga_seated`, `:ga_standing`, `:vip_reserved`, `:vip_standing`)
- `name` (string) — e.g., "VIP Lounge"
- `capacity` (integer)
- `access_mode` (atom: `:public`, `:membership_tier`, `:role_based`, `:whitelist`)
- `membership_tier` (string, nullable) — for `:membership_tier` access_mode
- `allowed_roles` (array of strings, nullable) — for `:role_based` access_mode
- `metadata` (JSONB) — zone-specific config (row count, accessibility, etc.)
- `created_at`, `updated_at`

**Invariants**:

- Zone belongs to exactly one layout and one organization.
- If `access_mode: :membership_tier`, `membership_tier` MUST be non-null.
- If `access_mode: :role_based`, `allowed_roles` MUST be non-empty.
- `capacity` MUST be > 0.

### Resource: Seat

**Module**: `Voelgoedevents.Ash.Resources.Seating.Seat`  
**File**: `lib/voelgoedevents/ash/resources/seating/seat.ex`  
**Phase Introduced**: Phase 8

**Responsibility**: Individual physical seat (reserved zones only).

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `seat_id` (string, unique per layout) — stable identifier, e.g., "A-1"
- `zone_id` (UUID) — parent zone
- `layout_id` (UUID) — parent layout
- `row` (string) — e.g., "A"
- `number` (integer) — e.g., 1
- `category` (atom: `:standard`, `:wheelchair`, `:companion`, `:restricted_view`, `:aisle`)
- `companion_seat_id` (UUID, nullable) — paired wheelchair seat
- `status` (atom: `:available`, `:held`, `:sold`, `:blocked`)
- `held_until` (datetime, nullable) — expiry of current hold
- `seat_hold_id` (UUID, nullable) — reference to active SeatHold
- `version` (integer) — optimistic lock counter
- `created_at`, `updated_at`

**Invariants**:

- Seat belongs to exactly one layout and one zone.
- `seat_id` MUST be unique within layout.
- `:wheelchair` seats SHOULD have a `companion_seat_id`.
- `:companion` seats SHOULD reference their paired wheelchair seat via `companion_seat_id`.
- `status` state machine enforced by Ash StateMachine.

### Resource: SeatGroup (Optional, Recommended)

**Module**: `Voelgoedevents.Ash.Resources.Seating.SeatGroup`  
**File**: `lib/voelgoedevents/ash/resources/seating/seat_group.ex`  
**Phase Introduced**: Phase 8+ (Nice-to-Have for MVP)

**Responsibility**: Group logically related seats (wheelchair pairs, family blocks, VIP tables).

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `layout_id` (UUID)
- `group_type` (atom: `:wheelchair_pair`, `:family_block`, `:vip_table`, `:reserved_block`)
- `seat_ids` (array of UUIDs) — seats in group
- `metadata` (JSONB) — group-specific config
- `created_at`, `updated_at`

**Invariants**:

- All seats in group MUST be in same layout.
- All seats in group MUST be in same zone.

### Resource: SeatingPolicy

**Module**: `Voelgoedevents.Ash.Resources.Seating.SeatingPolicy`  
**File**: `lib/voelgoedevents/ash/resources/seating/seating_policy.ex`  
**Phase Introduced**: Phase 8

**Responsibility**: Tenant-level SuperAdmin controls for seating behaviour.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `allow_reserved_seating` (boolean, default true)
- `allow_ga_seating` (boolean, default true)
- `allow_hybrid_ga_reserved` (boolean, default true)
- `allow_vip_zones` (boolean, default false)
- `enforce_accessibility_rules` (boolean, default true)
- `companion_release_occupancy_threshold` (integer, default 85) — % occupancy
- `max_wheelchair_seats_per_booking` (integer, default 1)
- `accessibility_audit_enabled` (boolean, default true)
- `max_seats_per_booking` (integer, default 10)
- `orphan_avoidance_strict` (boolean, default true) — Reject orders that create orphans?
- `group_adjacency_strict` (boolean, default false) — Require contiguity for groups?
- `default_hold_ttl_minutes` (integer, default 10) — Per-event override-able
- `max_holds_per_user` (integer, nullable) — Coordination with TicketingPolicy
- `max_holds_per_ip` (integer, nullable) — Fraud prevention
- `created_at`, `updated_at`

**Enforcement**:

- Applied during:
  - Zone creation (validate access_mode allowed).
  - Seat category creation (validate wheelchair/companion rules allowed).
  - Event-level seating config (validate overrides permitted).
  - Booking/hold operations (validate capacity, adjacency rules).

### Resource: EventLayout (Event-Specific Overlay)

**Module**: `Voelgoedevents.Ash.Resources.Seating.EventLayout`  
**File**: `lib/voelgoedevents/ash/resources/seating/event_layout.ex`  
**Phase Introduced**: Phase 8

**Responsibility**: Event-specific seating overrides on top of VenueLayout.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `event_id` (UUID)
- `layout_id` (UUID) — reference to VenueLayout
- `layout_version` (integer) — frozen at event creation
- `overrides` (JSONB) — deltas:
  ```json
  {
    "blocked_seat_ids": ["uuid-a-10", "uuid-b-5"],
    "disabled_zones": ["uuid-vip-lounge"],
    "zone_overrides": {
      "uuid-section-b": {
        "access_mode": "membership_tier",
        "membership_tier": "special"
      }
    },
    "pricing_zones": {
      "uuid-section-a": { "pricing_rule_id": "uuid-rule-1" }
    }
  }
  ```
- `created_at`, `updated_at`

**Invariants**:

- EventLayout MUST reference an active VenueLayout.
- Once event has sold tickets, `layout_version` is immutable.

---

## Integration with Ticketing, Pricing & Holds

### Seat ↔ Ticketing Inventory Integration

**Seating Domain** (this domain):

- Manages Seat objects, status (available/held/sold/blocked).
- Manages SeatGroup (optional).

**Ticketing Domain** (adjacent domain):

- Manages SeatHold (5–10 minute temporary reservation).
- Manages Ticket (sold instance, linked to seat_id).
- Manages TicketType with `kind: :seated` (linked to layout zones).

**Data Flow**:

1. Customer selects seat_id → Calls Ticketing.reserve_seat() workflow.
2. Ticketing creates SeatHold in PostgreSQL + Redis ZSET (seating:holds:event:{event_id}).
3. Seating observes hold status in Redis, updates seat.status = :held (via cache invalidation).
4. Payment succeeds → Ticketing converts hold to Ticket.
5. Seating marks seat.status = :sold (irreversible for that event).

### Seat Hold & Availability State Machine

**Seat Status Transitions**:

```
available → held (SeatHold created)
  ├→ available (SeatHold expired or released)
  └→ sold (SeatHold converted to Ticket)

any state → blocked (admin action, structural issue)
any state → archived (layout version retired)
```

**Availability Cache**:

- **Hot** (ETS): Per-node in-memory, 1ms lookup.

  - Key: `org_{org_id}:seat:{seat_id}`
  - Value: `{status, held_until, version}`
  - TTL: 15 minutes.

- **Warm** (Redis): Cluster-wide, 10ms lookup.

  - ZSET: `voelgoed:org:{org_id}:event:{event_id}:seats:availability`
  - Score: `version` (increments on change).
  - Member: `{seat_id}:{status}:{held_until}` encoded.
  - String: `voelgoed:org:{org_id}:seat:{seat_id}:hold` → hold metadata.
  - TTL: 5–30 minutes.

- **Cold** (PostgreSQL): Authoritative.
  - Seat table with status, held_until, seat_hold_id.
  - Indexed on event_id, zone_id, status for fast queries.

**Transition Rules**:

- `available` → `held`: Only Ticketing.reserve_seat() can trigger (via Seating.hold_seat action).
- `held` → `available`: Ticketing.release_seat() or Oban cleanup job.
- `held` → `sold`: Ticketing.create_ticket() on payment success.
- Any → `blocked`: Admin action (via Ash policy).

**Invariant**: Seating MUST NOT duplicate hold management logic. It reads and reacts to Ticketing's hold registry; it does not author holds.

### Read-Only Hold Observation Pattern

**Design**:

- Seating queries Ticketing's SeatHold table or Redis hold registry **read-only**.
- Seating updates its own Seat.status and caches based on observed holds.
- All hold creation/expiry/conversion is Ticketing's responsibility.

**Implementation Sketch**:

```elixir
# Seating.query_seat_availability(event_id, seat_id)
# 1. Check ETS (hot)
# 2. Check Redis (warm)
# 3. Query Seat table + join SeatHold (cold)
# 4. Determine status based on:
#    - seat.status
#    - If held: check seat_hold.held_until > now?
#    - If held_until expired: refresh cache, update status
# 5. Return {status, metadata}
```

---

## VIP & Membership-Restricted Zones

### Access Control Integration Points

**Zone Configuration**:

- Zone resource has fields: `access_mode`, `membership_tier`, `allowed_roles`.

**Booking Validation** (Ash Policy):

```
authorize if access_mode == :public

authorize if (
  access_mode == :membership_tier AND
  user.membership_tier == zone.membership_tier AND
  user.membership_status == :active
)

authorize if (
  access_mode == :role_based AND
  user.role in zone.allowed_roles
)

forbid if not_authenticated
forbid if (access_mode == :membership_tier AND user.membership_tier != zone.membership_tier)
```

### Voelgoed Vriendinne Example

**Use Case**: Voelgoed Vriendinne members get exclusive access to VIP section.

**Setup**:

1. Create VIP Zone in Layout:

   - `zone_type: :vip_reserved`
   - `access_mode: :membership_tier`
   - `membership_tier: "voelgoed_vriendinne"`
   - Seats: 50 reserved seats.

2. Create SeatingPolicy rules (tenant-level):

   - `allow_vip_zones: true`
   - `enforce_accessibility_rules: true`

3. Create EventLayout for specific event:

   - Override zone if needed (e.g., disable VIP for budget event).
   - Or inherit defaults from VenueLayout.

4. When member books:

   - Calls Ticketing.reserve_seat(event_id, seat_id) with user context.
   - Ticketing validates user authorization against Seating zone via Ash policy.
   - Policy checks: `user.membership == "voelgoed_vriendinne"` → Allow.
   - SeatHold created.
   - Ticket eventually linked to Membership record.

5. At scanning:
   - Scanner reads ticket → checks `associated_membership_id`.
   - Verifies membership status still active.
   - If membership revoked/expired: Reject entry with message "Membership expired."

---

## SeatingPolicy & SuperAdmin Controls

### Tenant-Level Configuration

**SuperAdmin Configurable** (per organisation):

- Allowed seating types (reserved, GA, hybrid).
- VIP zone enablement.
- Accessibility rules enforcement (companion soft-reserve, release threshold).
- Orphan avoidance strategy (strict vs. best-effort).
- Group booking adjacency rules.
- Default seat hold TTL (can be per-event overridden).

### Event-Level Overrides

**Event Organiser Can Override** (if SuperAdmin permits):

- Specific SeatingPolicy fields via EventLayout.metadata.
- Example:
  ```json
  {
    "seating_overrides": {
      "enforce_accessibility_rules": false,
      "orphan_avoidance_strict": false,
      "default_hold_ttl_minutes": 5
    }
  }
  ```

**Validation**:

- Ash Policy checks: Is this override permitted by SeatingPolicy?
- Example: If SuperAdmin set `enforce_accessibility_rules: true` as mandatory, organiser cannot override to false.

### Phase Allocation

**Phase 8**:

- Basic SeatingPolicy fields.
- Event-level overrides (simple case).
- VIP zone access control.
- Wheelchair + companion soft-reserve.

**Phase 8+ (Future)**:

- Dynamic occupancy-based pricing in Seating (complex interaction with Ticketing).
- Highly flexible reconfiguration mid-event (requires versioning overhaul).
- Session-based seating (matinee vs. evening).

---

## Caching & Redis Structures (Refined)

### Multi-Tenancy Scoping

**Critical Rule**: All Redis keys MUST include `org_{org_id}:` prefix to prevent cross-tenant collision.

```
voelgoed:org:{org_id}:layout:{layout_id}
voelgoed:org:{org_id}:event:{event_id}:seats:availability
voelgoed:org:{org_id}:seat:{seat_id}:hold
voelgoed:org:{org_id}:event:{event_id}:holds  (ZSET for Ticketing)
voelgoed:org:{org_id}:occupancy:{event_id}
```

### Layout JSON Cache

**Purpose**: Fast layout loading for checkout UI, admin dashboards.

**Structure**:

```
Key: voelgoed:org:{org_id}:layout:{layout_id}:config
Value: JSON — full layout config (zones, seats, coordinates)
TTL: 24 hours (layout changes infrequently)
Invalidation: On layout update via Ash action
```

**Rebuild on Cache Loss**:

```elixir
# Query Postgres
layout = Ash.read!(Layout, id: layout_id)
config_json = Jason.encode!(layout.config)
Redis.set(key, config_json, ex: 86400)
```

### Seat Availability Bitmap

**Purpose**: Ultra-fast availability checks (is seat X available?).

**Structure**:

```
Key: voelgoed:org:{org_id}:event:{event_id}:seats:bitmap
Data: Redis SETBIT or HASH
  - Option A (SETBIT): Bit index = hash(seat_id), value = 0 (available) or 1 (held/sold)
  - Option B (HASH): Field = seat_id, value = status (0=available, 1=held, 2=sold)
TTL: 5–30 minutes
Invalidation: On hold/sale via write-through pattern
```

**Lookup**:

```elixir
# O(1) bitmap lookup
getbit(voelgoed:org:{org_id}:event:{event_id}:seats:bitmap, seat_index)
# Returns 0 (available) or 1 (occupied)
```

### Seat Hold Registry (Ticketing Domain)

**Purpose**: Expiring holds for oversell prevention.

**Structure**:

```
Key: voelgoed:org:{org_id}:event:{event_id}:holds
Data: ZSET
  - Member: {seat_id}:{hold_id}:{user_id}:{held_until_iso}
  - Score: held_until (Unix timestamp) — enables efficient expiry scans
TTL: Automatic via sorted set score (elements with score < now)
```

**Cleanup**:

```elixir
# Oban job: every 30s, remove expired holds
Redix.command!(redis, ["ZREMRANGEBYSCORE", key, "-inf", "#{now_unix}"])
```

### Occupancy & Analytics Cache

**Purpose**: Live occupancy counts for dashboards.

**Structure**:

```
Key: voelgoed:org:{org_id}:occupancy:{event_id}
Data: HASH
  - available_count: integer
  - held_count: integer
  - sold_count: integer
  - live_attendees: integer (from scanning)
  - last_updated: timestamp
TTL: 1 minute (refreshed on significant changes)
```

### Consistency & Fallback

**Write-Through Pattern**:

1. Write to PostgreSQL (authoritative).
2. Invalidate ETS (per-node, immediate).
3. Invalidate Redis (cluster-wide, immediate).
4. Next read falls back to PostgreSQL, repopulates cache.

**Cache Loss Recovery**:

- If Redis fails, fall back to PostgreSQL queries (slower, but correct).
- Log cache misses for monitoring.
- Implement automatic cache rebuild job (Oban, runs every 5 min).

---

## Hybrid Seating Example: Festival Event

**Scenario**: 2-day music festival.

- **Day 1 & 2**: 1,000 capacity total.
- **Reserved Seating (Orchestra)**: 300 seats, $150/ticket, stable assignment.
- **GA Seated (Floor)**: 400 capacity, flexible, $100/ticket.
- **Pit (Standing)**: 300 capacity, standing room only, $80/ticket.
- **VIP Lounge (Reserved, Members-Only)**: 50 seats, $300/ticket.

**Inventory Calculation**:

- Orchestra: 300 available − held − sold.
- Floor GA: 400 available − held − sold.
- Pit Standing: 300 available − held − sold.
- VIP: 50 available − held − sold (+ membership check).
- **Total**: 1,050 seats/capacity.

**Ticket Types** (Ticketing domain):

- TicketType `orchestra_2day`: kind = `:seated`, entitlement = `:unlimited_multi_day`, valid_days = [Fri, Sat].
- TicketType `ga_floor_2day`: kind = `:ga`, entitlement = `:ga_seated`, valid_days = [Fri, Sat].
- TicketType `pit_standing_2day`: kind = `:ga`, entitlement = `:ga_standing`, valid_days = [Fri, Sat].
- TicketType `vip_2day`: kind = `:seated`, entitlement = `:unlimited_multi_day`, valid_days = [Fri, Sat].

**Booking Flow**:

1. User selects:
   - 2 orchestra seats (Row A, Seats 5-6) → stable for both days.
   - 1 GA floor → no specific seat, just capacity.
   - 1 pit standing → no specific seat, just capacity.
2. Ticketing.reserve_seat() creates 3 SeatHolds.
3. Seating updates Seat statuses and availability cache.
4. Checkout calculates pricing by zone (orchestra $150 × 2, floor $100, pit $80).
5. Payment succeeds → tickets created, seats marked :sold, GA capacity decremented.
6. Day 1 Entry: Scanner reads orchestra ticket, validates seat A5 (scanned), increments entry_count.
7. Day 2 Entry: Same orchestra ticket, same seat A5, increments entry_count again. GA floor ticket scanned, occupancy +1.

---

## Testing & Observability (Extended)

### Test Coverage Areas

**VIP/Membership Access**:

- User WITH membership successfully reserves VIP seat.
- User WITHOUT membership rejected when attempting VIP zone booking.
- Membership revocation post-booking → scanning rejects entry.

**Wheelchair & Companion Pairing**:

- Wheelchair seat booked → companion soft-reserved (hidden from listings).
- Event occupancy reaches 85% → companion released to general availability.
- User books wheelchair seat without companion → ticket issued successfully.
- Companion released after threshold → other user can now book companion seat.

**Hybrid GA + Reserved Events**:

- Reserved zone and GA zone coexist.
- Inventory independently tracked per zone.
- Total occupancy = sum across zones.

**Multi-Day Seating Stability**:

- Day 1: Ticket scanned, entry_count = 1, seat marked occupied.
- Day 2: Same ticket + seat scanned, entry_count = 2, seat marked occupied.
- Seat assignment unchanged across both days.

**Orphan Seat Avoidance**:

- Request 2 seats in row with [available, held, available, held, available] → System allocates to avoid orphans.
- Strict mode rejects allocation → User receives "No suitable seat pairs available."
- Best-effort mode returns non-contiguous → Clear messaging to customer.

**Rebuilding Seating Availability from PostgreSQL**:

- Corrupt Redis → Trigger rebuild job.
- Job queries all Seats + SeatHolds for event.
- Recalculates availability, repopulates caches.
- Verify correctness against PostgreSQL.

### Metrics & Alerts

| Metric                          | Target              | Alert Threshold                            |
| ------------------------------- | ------------------- | ------------------------------------------ |
| **Orphan Seat Ratio**           | < 5% per event      | > 10% = investigate availability algorithm |
| **VIP Zone Utilization**        | 60–90%              | < 40% or > 95% = unusual                   |
| **Accessibility Utilization**   | 1–3% (realistic)    | > 5% or = 0% = audit                       |
| **Layout Load Time**            | < 50ms p95          | > 200ms = Redis/cache issue                |
| **Redis Bitmap Update Latency** | < 20ms              | > 100ms = cluster degradation              |
| **Cache Hit Rate (Layout)**     | 95%+                | < 80% = cache eviction/invalidation issue  |
| **Hold-to-Sale Conversion**     | 40–60%              | < 25% or > 85% = unusual user behavior     |
| **Seat Hold Expiry Rate**       | Normal distribution | Spike = checkout UX issues                 |

### Observability & Logging

**Logs to Emit**:

- Seat hold creation: `org_id`, `event_id`, `seat_id`, `user_id`, `held_until`.
- Availability state changes: `org_id`, `event_id`, `seat_id`, `status_before`, `status_after`, `reason`.
- Layout version changes: `org_id`, `venue_id`, `layout_id`, `version_before`, `version_after`.
- Cache invalidation: `org_id`, `event_id`, `keys_invalidated`.
- Orphan seat allocation: `org_id`, `event_id`, `orphans_created`, `reason`.
- VIP zone access: `org_id`, `event_id`, `zone_id`, `user_id`, `access_granted` or `access_denied`, `reason`.
- Wheelchair booking: `org_id`, `event_id`, `seat_id`, `companion_seat_id`, `companion_soft_reserved` = true/false.

---

## MVP vs. Phase 8 & Future

### Phase 3/4: GA-Only Seating (MVP)

**In Scope**:

- Simple static layout JSON.
- GA capacity tracking (no individual seats).
- Basic availability state (free/held/sold).
- Redis bitmap for fast availability checks.

**Out of Scope**:

- Reserved seating, zones, seat objects.
- Accessibility features.
- VIP zones, membership access control.
- Orphan avoidance, group booking logic.
- Layout versioning, migrations.

### Phase 8: Full Seating Engine

**Additions**:

- All resource types: Layout, Zone, Seat, SeatGroup, SeatingPolicy, EventLayout.
- Reserved seating + GA hybrid.
- Zones with type and access control.
- Wheelchair + companion seat pairing & soft-reserve.
- Multi-day seat assignment stability.
- Orphan avoidance algorithm.
- Group booking & adjacency rules.
- VIP zones with membership/role access.
- Layout versioning & event-specific overrides.

### Phase 8+ (Future Enhancements)

- **Session-Based Seating**: Different seat assignments for matinee vs. evening showings.
- **Dynamic Re-Pricing**: Occupancy-based price adjustments per zone.
- **Figma Import**: Auto-generate layouts from Figma seating plans.
- **Flexible Reconfiguration**: Mid-event layout changes with ticket migration.
- **Advanced Group Logic**: Multi-row family packs, table reservations.
- **Accessibility Analytics**: Utilization trends, recommendation engine.

---

## Domain Interactions Summary

### Seating ↔ Ticketing & Pricing

- **Seating provides**: Seat objects, layout, zone capacity.
- **Ticketing provides**: SeatHold, Ticket, inventory tracking.
- **Integration**: Ticketing reserves seats; Seating tracks status. Hold state drives Seating availability.
- **Pricing domain**: Zone → PricingRule mapping (e.g., orchestra zone gets $150 rule).

### Seating ↔ Payments & Ledger

- **Integration**: Seating does NOT interact directly with Payments domain.
- **Indirect**: Ticketing applies pricing rules (zone-based) for ledger entry.

### Seating ↔ Scanning

- **Seating provides**: Seat metadata for display (row, number, coordinates).
- **Scanning provides**: Entry validation, occupancy updates.
- **Integration**: Scanner reads seat_id from ticket, validates against Seating layout.

### Seating ↔ Accounts / Membership

- **Integration**: Verify user membership for VIP zone access.
- **Pattern**: Ash Policy checks user.membership_tier against zone.membership_tier.

### Seating ↔ Events

- **Integration**: Event references EventLayout which references VenueLayout.
- **Lifecycle**: Event creation selects layout + version. Once on-sale, layout version frozen.

---

## Error & Edge Cases

**Layout changes after sales**:

- **Prevention**: Mark layout as `:archived` if on-sale event references it. Forbid mutations.
- **Recovery**: Create new layout version, implement migration workflow.

**Overlapping/Duplicate seats in config**:

- **Prevention**: Validate layout.config at creation time. Ash validations check uniqueness of seat_ids.
- **Recovery**: Return validation error to admin. Editor rejects save.

**Event without seating layout**:

- **Behavior**: Event can have GA-only tickets (no layout reference). Seating domain not involved.
- **Constraint**: `TicketType.kind = :ga` does NOT require seat_ids.

**Cross-tenant data leakage**:

- **Prevention**: All Redis keys include `org_{org_id}:`. All queries filter by `organization_id`.
- **Monitoring**: Periodic audit queries checking for orphaned cross-org data.

**Hold expiry during checkout**:

- **Handling**: Seating query returns expired hold. Ticketing.start_checkout() rejects with "Hold expired."
- **Recovery**: User returns to seat selection, re-reserves.

**VIP membership revoked mid-event**:

- **Scanning**: Scanner checks membership status, rejects entry if revoked.
- **Ticket**: Ticket remains valid (pre-purchased), but venue can deny entry.
- **Audit**: Log revocation-related rejections.

**Wheelchair seat with no companion**:

- **Allowed**: Wheelchair seat can be booked solo.
- **Logic**: Soft-reserve only applies to PAIRED companion (if exists).

**Orphan avoidance logic fails (algorithm bug)**:

- **Fallback**: Allow booking, log as operational issue.
- **Admin Override**: SuperAdmin can manually release orphaned seats.

---

## Resources to Register in DOMAIN_MAP & ai_context_map

The following resources MUST be added to `DOMAIN_MAP.md` and `ai_context_map.md`:

| Resource        | Module                                               | File Path                                                    | Domain  | Phase | Notes                                                          |
| --------------- | ---------------------------------------------------- | ------------------------------------------------------------ | ------- | ----- | -------------------------------------------------------------- |
| `Layout`        | `Voelgoedevents.Ash.Resources.Seating.Layout`        | `lib/voelgoedevents/ash/resources/seating/layout.ex`         | Seating | 8     | Venue seating configuration, versioned                         |
| `Zone`          | `Voelgoedevents.Ash.Resources.Seating.Zone`          | `lib/voelgoedevents/ash/resources/seating/zone.ex`           | Seating | 8     | Logical groupings of seats with access control                 |
| `Seat`          | `Voelgoedevents.Ash.Resources.Seating.Seat`          | `lib/voelgoedevents/ash/resources/seating/seat.ex`           | Seating | 8     | Individual physical seat with state machine                    |
| `SeatGroup`     | `Voelgoedevents.Ash.Resources.Seating.SeatGroup`     | `lib/voelgoedevents/ash/resources/seating/seat_group.ex`     | Seating | 8+    | Groups of related seats (pairs, blocks, tables) — nice-to-have |
| `SeatingPolicy` | `Voelgoedevents.Ash.Resources.Seating.SeatingPolicy` | `lib/voelgoedevents/ash/resources/seating/seating_policy.ex` | Seating | 8     | SuperAdmin tenant-level seating configuration                  |
| `EventLayout`   | `Voelgoedevents.Ash.Resources.Seating.EventLayout`   | `lib/voelgoedevents/ash/resources/seating/event_layout.ex`   | Seating | 8     | Event-specific layout overrides & deltas                       |

---

## Document Status

**Version**: 3.0 (Fully Extended, Finalized, and Phase-Ready)  
**Last Updated**: December 8, 2025  
**Status**: Canonical Specification for Phase 8 Seating Engine Implementation  
**Next Review**: After Phase 8 completion (before Phase 9 UI builder)

---

## References

### Internal VoelgoedEvents Docs

- `MASTER_BLUEPRINT.md` — Section 3 (Seating & Scanning), Section 5 (Caching & Performance)
- `DOMAIN_MAP.md` — Section 5 (Seating & Scanning)
- `ticketing_pricing.md` — Seat-based inventory, hold integration
- `payments_ledger.md` — Pricing zone mapping, ledger interaction
- `reserve_seat.md` — Detailed hold creation workflow
- `release_seat.md` — Hold expiry and release workflow
- `start_checkout.md` — Pricing calculation with zone-based rules
- `VOELGOEDEVENTS_FINAL_ROADMAP.md` — Phase 8 (Seating Engine), Phase 9 (Seating UI)
- `02_multi_tenancy.md` — Multi-tenant isolation patterns, Ash policies
- `03_caching_and_realtime.md` — Three-tier caching model, Redis structures
- `AGENTS.md` — Development standards for resource creation
- `ai_context_map.md` — Resource registry, module naming conventions

### External References

- **Eventbrite Seating Model**: https://www.eventbrite.com/platform/solutions/seating/
- **Ticketmaster Accessibility**: https://www.ticketmaster.com/accessibility
- **Redis Sorted Sets**: https://redis.io/commands#sorted-set
- **Elixir/Ash State Machines**: https://ash-hq.org/docs/module/ash_state_machine

---
