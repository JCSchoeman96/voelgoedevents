<!-- docs/domain/seating.md -->

# Seating Domain

## 1. Scope & Responsibility

The Seating domain owns:

- Seat maps/layouts for venues and events.
- Sections, rows, seats, zones.
- Mapping between abstract seat identifiers and logical capacity.
- Integration with ticketing for seat-based inventory.

It is responsible for:

- Accurate representation of physical layout.
- Grouping (e.g. sections, zones, tiers).
- Providing fast seat availability state to Ticketing & Scanning.

Out of scope:

- Pricing logic (Ticketing & Pricing).
- Payment flow (Payments & Ledger).

---

## 2. Core Resources

**Layout**

- Fields:
  - `id`
  - `organization_id`
  - `venue_id`
  - `name`
  - `version`
  - `config` JSONB (sections, rows, seats, coordinates)
  - `status` (draft, active, deprecated)
- Invariants:
  - A layout belongs to one organization and one venue.
  - `config` must be valid (no overlapping seat IDs, structural checks).

**Section / Zone**

- Can be explicitly modeled or represented inside `config`.
- Represents logical grouping: e.g. VIP, General, Balcony.

**Seat**

- Usually represented as:
  - Unique `seat_id` per layout.
  - Attributes: row, number, section, type (standard, wheelchair, companion).
- Invariants:
  - Each `seat_id` is unique within a layout.
  - Must map deterministically to a “location” in the venue.

**SeatGroup (Optional)**

- For group bookings / tables / blocks.

---

## 3. Key Invariants

- A layout cannot be modified while actively used for on_sale events, except via safe migrations.
- Seat IDs are stable for the duration of an event; changing them post-sale must be avoided.
- Seat count determines maximum seated capacity for that event.

---

## 4. Performance & Caching Strategy

Data temperature:

- **Hot (ETS/Cachex + Redis):**
  - Seat availability per event/layout (free/held/sold).
  - This must be extremely fast and up-to-date.
- **Warm (Redis):**
  - Seat map structure for an event (sections, rows, coordinates).
- **Cold (Postgres):**
  - Canonical layout definition and config.

Strategy:

- Store seat map structure as JSON in Redis for quick read by LiveView and SvelteKit:
  - TTL: long (e.g. 24h) since layout changes infrequently.
- Store availability as:
  - **Bitmaps** (Redis `SETBIT`) or hashes keyed by seat_id:
    - This is the hot-path for availability checks.

---

## 5. Redis Structures

- Seat map structure:
  - `seating:layout:{layout_id}` → Redis **hash** or JSON blob:
    - Fields: `config`, `metadata`, `version`.
- Event-specific seat availability:
  - `seating:availability:{event_id}` → Redis **bitmap** (SETBIT) or **hash**:
    - Key: seat index or `seat_id`.
    - Value: state (0 = free, 1 = held, 2 = sold or separate bitmaps).
- Seat holds (see Ticketing domain for hold registry):
  - Usually a ZSET in Ticketing; seating should query or be updated by it.

---

## 6. Indexing & Query Patterns

In Postgres:

- `layouts`:
  - Index on `organization_id`.
  - Index on `(venue_id, status)`.
- `layout_versions` (if versioned separately):
  - Composite index `(layout_id, version)`.

Patterns:

- Fetch layout config for event:
  - Determine `layout_id` for event.
  - Get config from Redis → fallback to Postgres.
- Translate between `seat_id` and UI coordinates:
  - Entirely in seating config (client uses JSON schema).

---

## 7. PubSub & Real-time

Topics:

- `seating:event:{event_id}`:
  - Broadcast changes to seat availability (for dashboards & LiveView updates).
- `seating:layout:{layout_id}`:
  - Broadcast layout activation/deprecation.

Usage:

- Live seat map in checkout:
  - Subscribes to `seating:event:{event_id}` and updates via LiveView push.
- Admin tooling for layout editing:
  - Subscribes to updates for current layout.

---

## 8. Error & Edge Cases

- Layout changes after sales:
  - Must be either forbidden or handled via migration workflows.
- Overlapping or duplicate seats in config:
  - Must be caught at validation time.
- Event without a seating layout:
  - No seated inventory, only GA allowed.

---

## 9. Interactions with Other Domains

- **Ticketing & Pricing**:
  - Uses seat IDs and layout to create seat-specific ticket inventory.
- **Scanning & Devices**:
  - May use section/zone info for operational displays.
- **Reporting & Analytics**:
  - Uses seating data for occupancy and heatmaps.

---

## 10. Testing & Observability

- Tests:
  - Layout validation (no overlapping seats, correct counts).
  - Availability changes push correct updates to Redis and PubSub.
- Observability:
  - Telemetry on layout loading time and availability update latency.

---

## 11. Open Questions / Future Extensions

- Visual editor complexity (WebGL/Canvas vs simple SVG/HTML).
- Dynamic reconfiguration of sections during an event (usually no).
- Support for flexible seating / partial GA zones combined with seating.
