<!-- docs/domain/events_venues.md -->

# Events & Venues Domain

## 1. Scope & Responsibility

The Events & Venues domain owns:

- Venues (physical or virtual locations)
- Events (per-organization event definitions)
- Event scheduling (start/end, gates, sessions)
- Basic event lifecycle state (draft, published, on_sale, sold_out, closed)

Out of scope:

- Seating layout logic (belongs to Seating)
- Pricing and ticket rules (belongs to Ticketing & Pricing)
- Financial flows (belongs to Payments & Ledger)

---

## 2. Core Resources

**Venue**

- Fields:
  - `id`
  - `organization_id`
  - `name`
  - `slug`
  - `timezone`
  - `address` (structured or JSON)
  - `max_capacity` (sanity bound; actual seating comes from Seating)
  - `settings` JSONB (e.g. access rules, default door times)
- Invariants:
  - `slug` is unique per organization.
  - `max_capacity` must be ≥ 0 and consistent with seating plans.

**Event**

- Fields:
  - `id`
  - `organization_id`
  - `venue_id`
  - `name`
  - `slug`
  - `description`
  - `status` (draft, published, on_sale, paused, closed)
  - `start_at`, `end_at`
  - `settings` JSONB (event-level rules, age restrictions, etc.)
- Invariants:
  - Event belongs to exactly one organization and one venue.
  - `start_at < end_at`.
  - `status` controls downstream behavior (ticket sales, scanning, etc.).

**Gate / Entrance (optional)**

- If modeled:
  - Represents gates/doors where scanning happens.
  - Links to venue and/or event.

---

## 3. Key Invariants

- Every event has a single `organization_id` and must never “float” without one.
- Event status must reflect real lifecycle:
  - Only `on_sale` (or equivalent) can generate sellable inventory.
  - Scanning allowed only for specific statuses (`on_sale`, `in_progress`).
- Venue capacity constraints:
  - `max_capacity` acts as a global guard. Seating & Ticketing must respect it.

---

## 4. Performance & Caching Strategy

Data temperature:

- **Hot (ETS/Cachex):**
  - Event summaries for on_sale/upcoming events per organization:
    - `id`, `name`, `slug`, sales status, start time.
  - These power dashboards and dropdowns.
  - TTL: 30–120 seconds.
- **Warm (Redis):**
  - Event metadata used frequently in downstream flows:
    - Basic event info, venue association, timezone.
  - Lists of events per organization/venue (for UI listings).
  - TTL: 10–30 minutes.
- **Cold (Postgres):**
  - Full event/venue records, descriptions, rich settings.

Cache invalidation:

- On event update (status, time, venue):
  - Invalidate event summary in ETS.
  - Invalidate Redis hashes and lists that include this event.
- On venue update:
  - Invalidate cached venue details and any event summary that includes venue info.

---

## 5. Redis Structures

Suggested patterns:

- Event summary:
  - `events:summary:{event_id}` → Redis **hash**
    - `name`, `slug`, `status`, `start_at`, `venue_id`, `org_id`.
- Events per organization (short list for dashboards):
  - `events:list:org:{org_id}` → Redis **list** of `event_id`s or compact objects.
- Events per venue:
  - `events:list:venue:{venue_id}` → Redis **list** of `event_id`s.

---

## 6. Indexing & Query Patterns

Critical indexes:

- `events`:
  - Index on `organization_id`.
  - Index on `(organization_id, status)`.
  - Index on `(organization_id, start_at)` for upcoming event queries.
  - Unique index on `(organization_id, slug)`.
- `venues`:
  - Index on `organization_id`.
  - Unique index on `(organization_id, slug)`.

Common queries:

- List upcoming events for an org:
  - Redis list → fallback to Postgres with `WHERE organization_id = ? AND start_at >= now()`.
- Lookup event by slug:
  - Postgres index `(organization_id, slug)`; optionally cached in Redis & ETS.

---

## 7. PubSub & Real-time

Topics:

- `events:org:{org_id}`:
  - Event created, updated, status changed.
- `events:event:{event_id}`:
  - Event-specific updates that might affect seating, pricing, scanning.

Usage:

- Dashboards subscribe to `events:org:{org_id}` for live updates.
- Seating & Pricing workflows may subscribe to `events:event:{event_id}` if needed.

---

## 8. Error & Edge Cases

- Event time change close to start:
  - Downstream domains (ticketing, scanning) must be informed (PubSub).
- Venue change after tickets sold:
  - May be restricted or require a “relocation workflow”.
- Deleting events:
  - Hard deletion usually not allowed if tickets exist; soft delete or “archived” status.

---

## 9. Interactions with Other Domains

- **Seating**:
  - Events reference seating layouts; seating must validate capacity vs venue.
- **Ticketing & Pricing**:
  - Ticket types & price rules attach to events.
- **Scanning & Devices**:
  - Scanning sessions attach to event and venue (gates).
- **Reporting & Analytics**:
  - Event is a primary dimension for reports and funnels.

---

## 10. Testing & Observability

- Tests:
  - Lifecycle transitions (draft → published → on_sale → closed).
  - Capacity bounds (cannot exceed venue max_capacity in downstream domains).
- Observability:
  - Telemetry events for state changes, scheduling anomalies (start before end, etc.).
  - Include `event_id`, `venue_id`, `organization_id`.

---

## 11. Open Questions / Future Extensions

- Support for EventSeries / multi-date patterns?
- Multi-venue events?
- Virtual-only events (no physical venue, special constraints)?
