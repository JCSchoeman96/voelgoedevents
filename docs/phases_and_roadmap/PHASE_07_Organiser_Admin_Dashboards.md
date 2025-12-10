## 📊 PHASE 7: Organiser Admin Dashboards

**Goal:** LiveView dashboards for event management, sales tracking, scanning monitoring  
**Duration:** 2 weeks  
**Deliverables:** Event dashboard, order list, scan monitoring LiveView pages  
**Dependencies:** Completes Phase 5  
**Note (v7.1):** Phase 7 is now split into two distinct responsibilities: (7.1a) UI implementation and (7.1b) backend data aggregation

---

### Phase 7.1: Event Dashboard LiveView

#### Sub-Phase 7.1a: Build Event Dashboard UI Components

**Task:** Create LiveView page structure and UI components for event overview  
**Objective:** Render real-time operational visibility to organizers  
**Output:**  
- `lib/voelgoedevents_web/live/events/event_dashboard_live.ex`
- `lib/voelgoedevents_web/live/events/event_dashboard_live.html.heex`
- `lib/voelgoedevents_web/live/events/components/sales_chart.ex`
- `lib/voelgoedevents_web/live/events/components/occupancy_gauge.ex`  
**Note:**  
- Reference `/docs/coding_style/phoenix_liveview.md` for LiveView conventions
- Reference `/docs/coding_style/heex.md` for template best practices
- Subscribe to PubSub for real-time updates: `"occupancy:org:#{org_id}:event:#{event_id}"`
- Display sections: event details, ticket sales breakdown, current occupancy, revenue totals
- No aggregation logic here — data is fetched from Phase 7.1b backend

---

#### Sub-Phase 7.1b: Implement Dashboard Data Aggregation Backend

**Task:** Create data aggregation module to compute dashboard metrics  
**Objective:** Provide efficient, cached metrics for dashboard UI consumption  
**Output:**  
- `lib/voelgoedevents/analytics/dashboard_metrics.ex`
- ETS table: `:dashboard_metrics_cache`  
**Note:**  
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — read from ETS/Redis for occupancy stats
- Aggregation queries:
  - Total tickets sold (by ticket type)
  - Current occupancy (live attendees)
  - Revenue breakdown (gross, fees, net)
  - Sales velocity (tickets/hour)
- Cache metrics in ETS with 30-second TTL
- Invalidate on PubSub events (`:ticket_sold`, `:scan_occurred`)
- Functions: `get_event_metrics/2`, `refresh_metrics/2`

---

### Phase 7.2: Order Management LiveView

#### Sub-Phase 7.2.1: Create Order List LiveView

**Task:** Build LiveView page listing orders with search/filter  
**Objective:** Enable organizers to view and manage ticket orders  
**Output:**  
- `lib/voelgoedevents_web/live/orders/order_list_live.ex`
- `lib/voelgoedevents_web/live/orders/order_list_live.html.heex`  
**Note:**  
- Reference `/docs/coding_style/phoenix_liveview.md`
- Filters: status, event, date range, user
- Actions: view details, initiate refund, resend confirmation email
- Enforce multi-tenancy per Appendix B (filter by `organization_id`)
- Use LiveView Streams for efficient list updates

---

### Phase 7.3: Scan Monitoring LiveView

#### Sub-Phase 7.3.1: Create Scan Monitoring LiveView

**Task:** Build LiveView page showing real-time scan activity per gate  
**Objective:** Enable door staff supervisors to monitor entry flow  
**Output:**  
- `lib/voelgoedevents_web/live/scanning/scan_monitor_live.ex`
- `lib/voelgoedevents_web/live/scanning/scan_monitor_live.html.heex`  
**Note:**  
- Reference `/docs/coding_style/phoenix_liveview.md`
- Subscribe to PubSub for real-time scan updates: `"scans:org:#{org_id}:event:#{event_id}"`
- Display: active gates, scans per minute, valid/duplicate/invalid counts, device status
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — read scan counts from Redis counters
- Use LiveView Streams for efficient scan log updates

---