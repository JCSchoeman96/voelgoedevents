# Reporting Domain

## 1. Scope & Responsibility

The Reporting domain owns:

- Structured, queryable reports for events, financials, and operations.
- Exportable data (CSV, XLSX, PDF).
- Scheduled reports (daily, weekly, post-event).
- The reporting data model (materialized views, aggregates).
- Ensuring reports are accurate, performant, and consistent with Ledger.

It is responsible for:
- Turning raw domain data into denormalized analytical tables.
- Serving dashboards and exports without hammering production tables.
- Providing a unified schema for cross-domain analytics.

Out of scope:
- Real-time dashboards (Analytics domain).
- Financial correctness (Ledger domain is the source of truth).
- Delivery of reports via email (Notifications domain).

---

## 2. Core Resources

### **ReportDefinition**
Describes a report type and structure.

Fields:
- `id`
- `organization_id`
- `name`
- `category` (financial, sales, operational)
- `config` JSONB (filters, columns)
- `schedule` (manual, daily, weekly)
- `status`

Invariants:
- Definitions are versioned for safety.
- Reports referencing financial numbers must align to Ledger entries.

---

### **GeneratedReport**
A concrete output instance.

Fields:
- `id`
- `organization_id`
- `definition_id`
- `format` (csv, xlsx, pdf)
- `storage_path`
- `generated_at`
- `status`

---

### **ReportDataStore (Materialized Tables)**

Tables include:
- `report_sales_daily`
- `report_revenue_daily`
- `report_attendance_daily`
- `report_event_summary`

All derived from Ledger, Ticketing, Seating, and Scanning.

---

## 3. Key Invariants

- Ledger is the canonical source for any financial figure.
- Reports must be deterministic for a given time window.
- Regeneration should overwrite old outputs for the same period.
- Scheduled reports must be idempotent.

---

## 4. Performance & Caching Architecture

**Hot (ETS):**
- Recently generated reports (for quick re-download).
- Recent event report summaries.

**Warm (Redis):**
- Report job queue:
  - `reporting:queue:{org_id}` → list of pending generation tasks.
- Report generation locks:
  - Prevent concurrent regeneration.

**Cold (Postgres):**
- Materialized views.
- Historical generated reports.

TTL guidelines:
- ETS: 10–30 minutes.
- Redis queue: no TTL.
- Report outputs stored in S3/local storage indefinitely.

---

## 5. Redis Structures

- `reporting:queue:{org_id}` → Redis **list**  
- `reporting:lock:{definition_id}` → Redis **string** with short TTL

---

## 6. Indexing & Query Patterns

Indexes:
- `{daily}_reports`: `(event_id, date)`
- `generated_reports`: `(organization_id, definition_id)`

Patterns:
- Export requests:
  - Check ETS → fallback to DB → regenerate if missing.
- Dashboard summaries:
  - Use materialized views refreshed incrementally.

---

## 7. PubSub & Real-time

Topics:
- `reporting:org:{org_id}`
- `reporting:definition:{definition_id}`

Broadcasts:
- Report generation completed
- Report failed
- New report available for download

---

## 8. Error & Edge Cases

- Heavy reports should run via Oban async jobs.
- Missing ledger entries cause inconsistencies → must raise alerts.
- Extremely large exports must stream rather than load to memory.

---

## 9. Domain Interactions

- **Ledger** → revenue, refunds, payouts  
- **Ticketing** → ticket counts, sales  
- **Seating** → occupancy  
- **Scanning** → attendance  

---

## 10. Testing & Observability

Tests:
- Report determinism
- Correct rollup from ledger
- Export formatting

Telemetry:
- Report job durations
- Materialized view refresh times

---

## 11. Future Extensions

- Custom report builder (drag-and-drop)
- BI integration (Tableau, Looker)
