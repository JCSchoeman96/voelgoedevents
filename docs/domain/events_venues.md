<!-- docs/domain/events_venues.md -->

# Events & Venues Domain

## 1. Scope & Responsibility

The Events & Venues domain owns:

- Venues (physical or virtual locations)
- Events (per-organization event definitions)
- Gates (entrance points for scanning)
- Event scheduling (start/end, lifecycle, state transitions)

Out of scope:

- Seating layout logic (belongs to Seating)
- Pricing and ticket rules (belongs to Ticketing & Pricing)
- Financial flows (belongs to Payments & Ledger)
- Ticket holds and checkouts (belongs to Ticketing)

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
  - `max_capacity` (sanity bound; actual seating comes from Seating domain)
  - `settings` JSONB (e.g. access rules, default door times)
  - timestamps (`inserted_at`, `updated_at`)
- Invariants:
  - `slug` is unique per organization.
  - `max_capacity` must be ≥ 0 and consistent with seating plans.

**Event**

- Core Fields:
  - `id`
  - `organization_id`
  - `venue_id`
  - `name`
  - `slug`
  - `description`
  - `status` (state machine – see canonical states below)
  - `start_at`, `end_at`
  - `sale_start_at`, `sale_end_at`
  - `capacity` (event-specific capacity bound)
  - `settings` JSONB (event-level rules, age restrictions, etc.)
  - timestamps (`inserted_at`, `updated_at`)

- Additional fields for postponement & recurrence:
  - `replaced_by_event_id` (nullable UUID) – For postponed/duplicated events pointing to the replacement event.
  - `recurrence_group_id` (nullable UUID) – Groups recurring runs of the "same" event series (e.g. Passievol 2025, 2026, 2027).
  - `rescheduled_at` (nullable datetime) – When `status == :postponed`, holds the new date/time if known.
  - `postponement_reason` (string/enum, optional) – Reason code or message (weather, restrictions, low sales, etc.).

- Invariants:
  - Event belongs to exactly one organization and one venue.
  - `start_at < end_at`.
  - `status` controls downstream behavior (ticket sales, scanning, visibility).

**Event Status States (Canonical)**

Event lifecycle is managed via a state machine with the following **canonical states**:

- `:draft` – Work-in-progress; not yet published.
- `:published` – Listed publicly; not yet started; ticket sales allowed (if within sale window).
- `:live` – Event is actively happening; real scanning allowed.
- `:ended` – Event finished; no further sales or real scans.
- `:cancelled` – Event cancelled; all sales stopped; visible to organizers only.
- `:postponed` – Event postponed; may or may not have a rescheduled date.
- `:archived` – Event archived for historical/reporting purposes only.

**Ticket-Selling Behaviour by Status:**

| status      | can_sell_tickets?                                 | note                                    |
|-------------|---------------------------------------------------|-----------------------------------------|
| `:draft`    | no (dev/test only)                               | Work-in-progress                        |
| `:published`| yes (if within `sale_start_at..sale_end_at`)     | Publicly listed, not yet live           |
| `:live`     | yes (if within `sale_start_at..sale_end_at`)     | Event in progress                       |
| `:ended`    | no                                                | Finished; read-only                     |
| `:cancelled`| no (sales stop immediately)                      | Cancelled; refunds handled separately   |
| `:postponed`| if `rescheduled_at` is nil: no; if set: yes      | Depends on rescheduling status          |
| `:archived` | no                                                | Long-term storage                       |

**Important: "On Sale" is Derived, Not a Status**

The concept of "on sale" is **not** a status state. Instead, it is a **derived computation**:

```
on_sale? = status in [:published, :live, :postponed] 
           AND rescheduled_at is nil (or current time >= rescheduled_at if postponed)
           AND now in [sale_start_at, sale_end_at]
```

For detailed state behaviour table including scanning and visibility rules, see **PHASE_03_Core_Events_&_GA_Ticketing.md** (Section 3.2.1).

**Scanning Rules**

Real scanning is allowed **only** when:

- `Event.status == :live`, OR
- `Event.status == :postponed` AND `rescheduled_at` is set AND current datetime is within `[rescheduled_at, rescheduled_at + event_duration]`

Scanning is **not** allowed when:

- `Event.status == :draft` (only test scans in dev tools, which must not count)
- `Event.status == :published` (only test scans allowed, must not count as real)
- `Event.status == :ended`, `:cancelled`, `:archived`

**Visibility Rules for Storefront**

| status      | visible_on_storefront? | note                                          |
|-------------|------------------------|-----------------------------------------------|
| `:draft`    | no                     | Internal only                                 |
| `:published`| yes                    | Publicly listed                               |
| `:live`     | yes                    | Event happening now                           |
| `:ended`    | no                     | Finished; hidden from storefront              |
| `:cancelled`| no                     | Visible in organiser/admin UI only            |
| `:postponed`| yes                    | With strong "postponed/rescheduled" messaging |
| `:archived` | no                     | Only via reporting/history screens            |

**Gate / Entrance**

- Represents physical/virtual gates or doors where scanning occurs.
- Fields:
  - `id`
  - `organization_id`
  - `venue_id`
  - `gate_code` (unique identifier per venue, e.g., "GATE_A", "MAIN_ENTRANCE")
  - `name`
  - `status` (`:open` or `:closed`)
  - `capacity` (optional occupancy limit for this gate)
  - `settings` JSONB
  - timestamps
- Invariants:
  - `gate_code` is unique per venue.
  - Gates belong to exactly one venue.

---

## 3. Key Invariants

- Every event has a single `organization_id` and must never "float" without one.
- Event status must reflect real lifecycle:
  - Only statuses in `[:published, :live, :postponed]` can allow ticket sales.
  - Scanning allowed only for `:live` or `:postponed` (with rescheduled_at set).
- Venue capacity constraints:
  - `max_capacity` acts as a global guard. Seating & Ticketing must respect it.
- Postponement invariant:
  - If `status == :postponed` AND `rescheduled_at == nil`: no new ticket sales or checkouts allowed.
  - If `status == :postponed` AND `rescheduled_at` is set: event behaves as `:live` (sales and real scans allowed if within windows).
- Cancellation invariant:
  - When event moves to `:cancelled`: all active SeatHolds must be released immediately.
  - No new SeatHolds or checkouts may be created.

---

## 4. Performance & Caching Strategy

Data temperature:

- **Hot (ETS/Cachex):**
  - Event summaries for published/live/upcoming events per organization:
    - `id`, `name`, `slug`, `status`, `start_at`, `sale_start_at`, `sale_end_at`, `venue_id`.
  - These power dashboards and dropdowns.
  - TTL: 30–120 seconds.
- **Warm (Redis):**
  - Event metadata used frequently in downstream flows:
    - Basic event info, venue association, timezone, capacity, status.
  - Lists of events per organization/venue (for UI listings).
  - TTL: 10–30 minutes.
- **Cold (Postgres):**
  - Full event/venue records, descriptions, rich settings, postponement metadata.

Cache invalidation:

- On event update (status, time, venue, rescheduled_at, replaced_by_event_id):
  - Invalidate event summary in ETS immediately.
  - Invalidate Redis hashes and lists that include this event.
  - Publish PubSub notification to `events:org:{org_id}` and `events:event:{event_id}`.
- On venue update:
  - Invalidate cached venue details and any event summary that includes venue info.
- On status change to `:cancelled` or `:postponed`:
  - Notify SeatHold/Ticketing domain (via PubSub or direct call) to handle hold release or hold suspension.

---

## 5. Redis Structures

Suggested patterns:

- Event summary:
  - `events:summary:{event_id}` → Redis **hash**
    - `name`, `slug`, `status`, `start_at`, `end_at`, `sale_start_at`, `sale_end_at`, `venue_id`, `org_id`, `rescheduled_at` (if set), `replaced_by_event_id` (if set).
- Events per organization (short list for dashboards):
  - `events:list:org:{org_id}` → Redis **list** of `event_id`s or compact JSON objects.
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
- `gates`:
  - Index on `venue_id`.
  - Unique index on `(venue_id, gate_code)`.

Common queries:

- List upcoming events for an org:
  - Redis list → fallback to Postgres: `WHERE organization_id = ? AND start_at >= now() AND status IN (:published, :live, :postponed)`.
- Lookup event by slug:
  - Postgres index `(organization_id, slug)`; optionally cached in Redis & ETS.
- Find cancelled or postponed events:
  - Postgres: `WHERE organization_id = ? AND status IN (:cancelled, :postponed)`.
- List gates for a venue:
  - Postgres: `WHERE venue_id = ? AND status = :open`.

---

## 7. PubSub & Real-time

Topics:

- `events:org:{org_id}`:
  - Event created, updated, status changed (including cancel/postpone/reschedule).
  - Payload: `{event_id, old_status, new_status, rescheduled_at, replaced_by_event_id}`.
- `events:event:{event_id}`:
  - Event-specific updates (status change, time change, rescheduling, cancellation).
  - Used by Seating, Ticketing, and Scanning domains to react to changes.

Usage:

- Dashboards subscribe to `events:org:{org_id}` for live updates on event list and status.
- SeatHold/Ticketing domain subscribes to `events:event:{event_id}` to:
  - Release all active holds if event moves to `:cancelled`.
  - Suspend new holds if event moves to `:postponed` (no rescheduled_at).
- Scanning devices may subscribe to updates on `:live` or `:postponed` (with rescheduled_at) events.

---

## 8. RBAC Summary for Events & Venues

**Who can manage Events & Venues:**

- **Tenant `:owner` and `:admin`**:
  - Create, update, delete venues.
  - Create, update, publish, end, cancel, postpone events.
  - Change event status, time, and reschedule.
  
- **Tenant `:staff`**:
  - Create and update venues (if granted by policy).
  - Create and update events.
  - **Cannot** publish, cancel, or postpone events (admin/owner only).

- **Platform `super_admin`**:
  - Can cancel/postpone any event in any organization (e.g., for safety, abuse, legal reasons).
  - Actions must be logged with reason and actor reference.

- **Platform `tenant_manager`**:
  - May cancel/postpone an event only when the **tenant explicitly authorizes** it.
  - Must log tenant consent reference and reason.
  - Cannot perform this action without documented tenant approval.

**Audit Requirements:**

- All status change actions (publish, cancel, postpone, reschedule, end) **must be auditable**:
  - Log actor (user ID, actor type).
  - Log timestamp.
  - Log affected event ID and old/new status.
  - Log reason (if provided).
  - Log tenant approval reference (if tenant_manager initiated).
- See `/docs/rbac_and_platform_access.md` for detailed RBAC policy semantics.

## RBAC & Audit for Event Cancel/Postpone

**Roles & Permissions:**

- **Tenant roles:**
  - `:owner` and `:admin` may cancel or postpone events.
  - `:staff` cannot cancel or postpone by default.

- **Platform:**
  - Platform `super_admin` may always cancel/postpone any event (e.g., safety, abuse, legal reasons).
  - `tenant_manager` may cancel/postpone only when a tenant explicitly authorizes it, and this must be logged. (See `/docs/domain/rbac_and_platform_access.md` for pricing-related permissions.)

**Audit & Compliance:**

- All cancel/postpone actions **MUST** be auditable (see `/docs/rbac_and_platform_access.md` for detailed policy semantics):
  - Include `reason` (text/enum).
  - Include `tenant_approval_reference` (for `tenant_manager` actions).
  - Log actor identity, timestamp, and affected event ID.

**Note:** Full RBAC policy semantics are defined in `/docs/rbac_and_platform_access.md`; this section is a cross-link and behavioural summary only.

---

## 9. Error & Edge Cases

- **Event time change close to start:**
  - Downstream domains (ticketing, scanning, seating) must be informed (PubSub).
  - Existing SeatHolds remain valid if event is still within sale window; otherwise trigger release.

- **Event cancelled:**
  - All active SeatHolds must be released immediately (Ticketing domain handles via PubSub notification).
  - No new SeatHolds or checkouts allowed.
  - Existing tickets become eligible for refund (handled by Payments domain).
  - Event becomes invisible on storefront but visible in organiser/admin UI.

- **Event postponed without rescheduled_at:**
  - Existing SeatHolds remain valid but in "suspended" state.
  - No new SeatHolds or checkouts allowed until `rescheduled_at` is set.
  - UI must show prominent "postponed" messaging; customers should see "awaiting new date" notice.

- **Event postponed with rescheduled_at:**
  - Existing SeatHolds and checkouts allowed again (if within new event window).
  - UI must show "postponed/rescheduled to [new_date]" messaging prominently.
  - New ticket sales resume as normal.

- **Venue change after tickets sold:**
  - May be restricted or require explicit consent workflow.
  - All downstream stakeholders (Scanning, Seating) must be notified.

- **Deleting events:**
  - Hard deletion usually not allowed if tickets exist.
  - Soft delete or move to `:archived` status instead.

---

## 10. Interactions with Other Domains

- **Seating**:
  - Events reference seating layouts; seating must validate capacity vs venue max_capacity.
  - Seating listens to event status changes (e.g., cancel → release all seat assignments).

- **Ticketing & Pricing**:
  - TicketType resources attach to events and respect Event status and sale windows.
  - When event moves to `:cancelled`, all ticket sales stop immediately.
  - When event moves to `:postponed` (no rescheduled_at), new ticket sales are suspended.

- **Scanning & Devices**:
  - Scanning sessions attach to event and venue (via gates).
  - Scan validity depends on Event status and timing rules (see Scanning Rules section above).
  - Real scans only allowed in `:live` or `:postponed` (with rescheduled_at) states.

- **Payments & Ledger**:
  - Event cancellation triggers refund workflows (handled by Payments domain, not here).

- **Reporting & Analytics**:
  - Event is a primary dimension for reports and funnels.
  - Cancelled and postponed events must be clearly marked and tracked in reports.

---

## 11. Testing & Observability

- **Tests:**
  - Lifecycle transitions (draft → published → live → ended, or draft → published → cancelled).
  - Postponement flows (live → postponed → live at rescheduled_at).
  - Capacity bounds (cannot exceed venue max_capacity in downstream domains).
  - Scanning allowed/disallowed per status and time window.
  - Visibility rules (storefront vs admin dashboards).
  - PubSub notifications trigger on all status changes.

- **Observability:**
  - Telemetry events for state changes, scheduling anomalies (start before end, etc.).
  - Log cancellations, postponements, and rescheduling actions with reason and actor.
  - Include `event_id`, `venue_id`, `organization_id` in all telemetry.
  - Alert on cancelled or postponed events affecting active tickets/holds.

---

## 12. Open Questions / Future Extensions

- Support for EventSeries / recurring multi-date patterns (recurrence_group_id partially addresses this)?
- Multi-venue events?
- Virtual-only events (no physical venue, special constraints)?
- Conditional rescheduling (e.g., "move to backup venue if X")?
- Automated retry for postponed events (e.g., "try again in 2 weeks")?

---
