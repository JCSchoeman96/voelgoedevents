# Analytics, Funnels & Marketing Domain

## 1. Scope & Responsibility

This domain owns:

- Event-level analytics (sales, revenue, occupancy)
- Real-time dashboards
- Marketing funnels (view → cart → checkout → purchase)
- Audience segmentation & marketing lists
- Email/SMS campaign targeting

Out of scope:

- Notification delivery mechanics (Notifications Domain)
- Rendering of dashboards (UI layer)
- Financial correctness (Ledger is source of truth)

---

## 2. Core Resources

### **EventMetric**

Derived data tracked historically:
- `event_id`
- `organization_id`
- `date`
- `views`
- `add_to_cart`
- `checkouts_started`
- `tickets_sold`
- `revenue`
- `conversion_rate`

---

### **FunnelEvent**

Raw ephemeral events:
- `event_id`
- `user_or_session_id`
- `type` (view, cart_add, checkout_start, purchase)
- `timestamp`

Stored warm/hot in Redis or ClickHouse-like store (if adopted later).

---

### **AudienceSegment**

Fields:
- `id`
- `organization_id`
- `segment_name`
- `filters` JSONB (behavior, purchase history)
- `size_estimate`

---

## 3. Performance Architecture

**Hot: ETS**
- Live event dashboard counters:
  - views
  - cart adds
  - current active checkouts

**Warm: Redis**
- Funnel events streamed to Redis list/stream.
- Aggregated real-time metrics per event.

**Cold: Postgres**
- Historical aggregates (daily/weekly summaries).
- Audience segments.

Redis structures:
- `analytics:event:{event_id}:live` → Redis **hash**
- `analytics:funnel:{event_id}` → Redis **list** or **stream**
- `analytics:org:{org_id}:segments` → Redis **cache**

TTL: usually short (5–30 min) except segments.

---

## 4. Indexing & Query Patterns

Indexes:
- `event_id` on metrics tables.
- `(organization_id, created_at)` for marketing timelines.

Patterns:
- Real-time:
  - Pull from Redis hot/warm caches.
- Historical:
  - Postgres + materialized views.

---

## 5. PubSub & Real-time

Topics:
- `analytics:event:{event_id}`
- `analytics:dashboard:{org_id}`

Broadcast:
- Updated funnel stats
- Sales updates
- Live occupancy changes (via seating + ticketing)

---

## 6. Error & Edge Cases

- Bot traffic → must filter suspicious view events.
- Multiple sessions per user → dedupe properly (HLL?).
- Segment definitions changing after campaigns → versioning required.

---

## 7. Domain Interactions

- **Ticketing** — sales, conversion.
- **Payments** — revenue.
- **Events** — grouping & timeline.
- **Marketing/Notifications** — campaign audiences.

---

## 8. Testing & Observability

Tests:
- Funnel sequence correctness.
- Segment filter logic.

Telemetry:
- Funnel latency.
- Segment evaluation runtime.

---

## 9. Open Questions

- Should we introduce ClickHouse or PostgreSQL timescale partitioning?
- Should segments auto-refresh?
