# VoelgoedEvents — Domain Documentation Index

This folder contains the **authoritative documentation for every domain** in the VoelgoedEvents platform.  
Each domain doc provides:

- Domain scope & responsibilities  
- Core resources and invariants  
- Performance & caching strategy (ETS, Redis, warm/cold data)  
- Required indexes & query patterns  
- PubSub channels & real-time rules  
- Interactions with other domains  
- Testing, observability & edge cases  

> **This is the primary reference for all vertical slices and architecture decisions.**

---

## 📁 Domain Index Overview

| Domain | File | Description | Status |
|--------|------|-------------|--------|
| **Tenancy & Accounts** | [`tenancy_accounts.md`](./tenancy_accounts.md) | Organizations, users, roles, membership, multi-tenant scoping. | ✅ Complete |
| **Events & Venues** | [`events_venues.md`](./events_venues.md) | Events, venues, scheduling, lifecycle, event states. | ✅ Complete |
| **Seating** | [`seating.md`](./seating.md) | Layouts, sections, rows, seats, availability structure. | ✅ Complete |
| **Ticketing & Pricing** | [`ticketing_pricing.md`](./ticketing_pricing.md) | Ticket types, GA/seated inventory, price rules, seat holds. | ✅ Complete |
| **Payments & Ledger** | [`payments_ledger.md`](./payments_ledger.md) | Payment attempts, ledger entries, payouts, financial correctness. | ✅ Complete |
| **Scanning & Devices** | [`scanning_devices.md`](./scanning_devices.md) | QR validation, offline/online scanning, device management. | ✅ Complete |
| **Analytics, Funnels & Marketing** | [`analytics_marketing.md`](./analytics_marketing.md) | Funnels, tracking, event metrics, audience segmentation. | ✅ Complete |
| **Integrations & Webhooks** | [`integrations_webhooks.md`](./integrations_webhooks.md) | Incoming & outgoing webhooks, integration configs, retry semantics. | ✅ Complete |
| **Reporting** | [`reporting.md`](./reporting.md) | Reports, exports, materialized views, scheduling, summaries. | ✅ Complete |
| **Notifications & Delivery** | [`notifications_delivery.md`](./notifications_delivery.md) | Templates, delivery queues, channels, retry, rate limits. | ✅ Complete |
| **Audit Logging** | [`audit_logging.md`](./audit_logging.md) | Immutable audit events, filtering, compliance, actor tracking. | ✅ Complete |
| **Public API & Access Keys** | [`public_api_access_keys.md`](./public_api_access_keys.md) | API authentication, rate limits, quotas, API logs. | ✅ Complete |
| **Ephemeral / Real-Time State** | [`ephemeral_realtime_state.md`](./ephemeral_realtime_state.md) | Redis/ETS hot/warm state, seat holds, rate limits, real-time streams. | ✅ Complete |

---

## 🧠 Domain Philosophy

Each domain follows:

- **Vertical slice boundaries**  
- **Ash domain purity** (no cross-domain leaking or controller logic)  
- **Multi-tier caching strategy**  
  - **Hot:** ETS/GenServer  
  - **Warm:** Redis  
  - **Cold:** Postgres  
- **Real-time event propagation** using Phoenix PubSub  
- **Performance constraints:**  
  - 100k+ concurrents  
  - Zero oversell  
  - Sub-100ms read latency  
  - Flash-sale readiness  
- **Strict invariants** enforced inside domain logic  

Domains map directly to the **PETAL Comprehensive Ultimate Build Plan** and **VoelgoedEvents Architecture**.

---

## 📐 How Domains Fit Together

### High-Level Flow

1. **Tenancy & Accounts** provides organizational boundaries and RBAC.  
2. **Events & Venues** creates the core event container.  
3. **Seating** attaches layout + physical capacity rules.  
4. **Ticketing & Pricing** creates sellable inventory.  
5. **Payments & Ledger** finalizes transactions.  
6. **Scanning & Devices** manages entry and validation.  
7. **Analytics** tracks funnels + real-time dashboards.  
8. **Reporting** exports structured summaries.  
9. **Notifications** delivers updates to customers.  
10. **Integrations** syncs external systems.  
11. **Audit Logging** records compliance events.  
12. **Public API & Access Keys** exposes programmatic access.  
13. **Ephemeral Domain** powers real-time performance for all domains.  

---

## 🔗 Real-Time & Performance Architecture

Many domains depend on the **Ephemeral / Real-Time State Domain**:

- Seat holds (ZSET)  
- Ticket availability (bitmaps)  
- Scanning flags (Redis)  
- API rate limits  
- Pricing cache  
- Notification queues  
- Webhook queues  
- Report generation queues  

This is the “operational memory layer” that ensures the system can run under heavy load.

---

## 🧪 How to Maintain Domain Docs

To keep docs accurate:

- Update the domain docs **whenever a new resource, rule, or invariant is added**.
- Keep **invariants and constraints** in sync with Ash actions.
- Update **Redis key patterns** if naming or structure changes.
- Add **indexing rules** whenever new query paths are introduced.
- Note **PubSub topics** used by LiveView or SvelteKit.
- Call out **performance-critical paths** and TTLs.

Each domain doc should be considered a **source of truth** for coding agents.

---

## 📌 Next Steps (Optional)

If needed, we can also generate:

- `docs/domain/DOMAIN_MAP.md` (indexes domain → Ash resources → file paths)  
- `docs/architecture/` suite (foundation, caching, multi-tenancy, slice rules)  
- `docs/workflows/` (checkout, scanning, settlement, refunds, etc.)  
- `docs/operations/` (scaling, observability, flash-sale readiness)

Just say:

**“Generate domain map”**  
or  
**“Start architecture docs”**  
or  
**“Generate workflow docs”**  
or  
**“Create operations docs”**  

---

## 🏁 Summary

This README is your **top-level index** for all domain-level documentation.  
Everything in `/docs/domain/` now forms a complete, production-grade, performance-aware foundation for the VoelgoedEvents platform.

