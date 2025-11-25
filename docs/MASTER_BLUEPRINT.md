# VoelgoedEvents – Master Blueprint

> **Status:** Living master document  
> **Audience:** Founders, senior engineers, AI coding agents, architects, integrators  
> **Scope:** Product vision, domain model, architecture, performance model, workflows, and implementation roadmap for the entire VoelgoedEvents platform and ecosystem.

---

## 1. Vision & Product Overview

### 1.1 Mission

VoelgoedEvents is a **full-stack event ticketing, scanning, and marketing intelligence platform** built to outperform existing South African and global solutions in:

- **Reliability under extreme load** (flash sales, big events)
- **Offline-first scanning and operations**
- **Seating plans and complex venues**
- **Multi-tenant, white-label-ready architecture**
- **Deep marketing attribution and analytics**
- **Operational dashboards for organisers and venues**

The goal is to be the **top-tier, enterprise-grade event platform** in South Africa, with architecture solid enough to scale beyond.

### 1.2 Core Product Pillars

1. **Ticketing & Checkout**
   - Multi-event, multi-venue, multi-date.
   - General admission and complex seating.
   - Smart pricing rules, discounts, bundles.

2. **Seating & Venue Management**
   - Visual seating plan builder.
   - Sections, rows, seats, price zones.
   - Easy reuse of venue layouts.

3. **Scanning & Access Control**
   - Offline-first scanner apps (PWA + Svelte + Capacitor).
   - Fast, robust QR scanning.
   - Anti-fraud, double-scan detection, multi-gate sync.

4. **Operations & Dashboards**
   - LiveView admin dashboards.
   - Live occupancy & check-in status.
   - Financial reconciliation and ledger.

5. **Marketing & Attribution**
   - UTM-driven links.
   - Funnels and campaigns tracking.
   - QR-based campaigns and deep attribution.

6. **Multi-Tenant Platform**
   - Many organisers, agencies, white-label brands.
   - Tenancy isolation and permissioned access.
   - Separate branding, domains, and settings.

---

## 2. Target Users & Personas

1. **Event Organisers**
   - Create events, manage ticketing, view sales and check-ins.
   - Need reliable scanning and simple dashboards.

2. **Venues**
   - Manage seating layouts, sections, and multiple event hosts.
   - Need operational dashboards and control over capacity.

3. **Marketing Teams / Agencies**
   - Build campaigns and track performance.
   - Require precise attribution across UTM/QR/referral links.

4. **Door Staff / Security**
   - Use scanning app at gates.
   - Need fast, clear feedback (valid, invalid, already scanned, wrong event).

5. **Admins / Platform Operators**
   - Ensure platform stability, manage tenants, handle disputes and refunds.
   - Oversee compliance, observability, and system health.

---

## 3. High-Level System Overview

### 3.1 Stack Summary

- **Backend:** Elixir, Phoenix, Ash Framework, Oban
- **Frontend:**
  - Phoenix LiveView for admin & ops dashboards
  - Svelte (PWA + Capacitor) for scanner / mobile-facing UI
  - Standard Phoenix HTML / HEEx for public ticket pages
- **Database:** PostgreSQL (+ possibly read replicas)
- **Caching & Realtime:**
  - Redis (warm data, queues, bitmaps, ZSETs)
  - ETS / GenServer (hot data)
  - Phoenix PubSub + LiveView
- **Background Jobs:** Oban (via ash_oban/oban_web)
- **Multi-tenancy:** Tenant-aware domains, policies, and data partitioning (Ash + Postgres)
- **Infrastructure:** WSL dev, containerized deploys (future: Docker/K8s or managed PaaS)

### 3.2 Major Components

- **Core Phoenix/Ash application (`voelgoedevents`)**
- **Domain slices (Logical):**
  - Tenants & orgs
  - Authentication & permissions
  - Events & venues
  - Seating & sections
  - Ticketing & pricing
  - Checkout & orders
  - Payments & ledger
  - Scanning & devices
  - Marketing & analytics
  - Notifications
  - Integrations & webhooks
- **Scanner App:**
  - Svelte PWA
  - Capacitor Android wrapper
  - Offline cache & sync engine

---

## 4. Domain Map (High-Level)

### 4.1 Core Domain Entities

- **Org / Tenant**
  - `orgs`
  - Attributes: id, name, slug, branding, settings
  - Relationships: users, events, venues, integrations

- **User & Membership**
  - `users`, `org_memberships`
  - Authentication (password, magic link, API keys)
  - Roles: admin, organiser, door staff, finance, read-only

- **Event**
  - `events`
  - Attributes: name, description, start & end times, status, capacity
  - Relationships: venue, tickets, sessions, price rules

- **Venue & Seating**
  - `venues`, `seating_layouts`, `seating_sections`, `seats`
  - Graph of seats and sections, mapped to price categories

- **Ticket Type & Allocation**
  - `ticket_types`, `ticket_categories`, `price_rules`
  - GA, seating, VIP, group discounts, bundles.

- **Order & Checkout**
  - `orders`, `order_items`, `seat_reservations`
  - State machine: new → pending_payment → paid → cancelled / expired

- **Payment & Ledger**
  - `payments`, `payment_attempts`, `ledger_entries`
  - Provider integration, reconciliation, refunds.

- **Ticket Instance**
  - `tickets`
  - Tied to order + attendee info + QR code/token.

- **Scanning & Devices**
  - `scan_devices`, `scan_logs`, `gate_assignments`
  - Online/offline status, device identity, trust model.

- **Marketing & Attribution**
  - `campaigns`, `links`, `utm_variants`, `qr_codes`
  - Attribution down to ticket/order or customer, by campaign.

- **Analytics & Reporting**
  - `event_metrics`, `daily_rollups`, `realtime_counters`
  - Derived views built from events + ledger + scans.

- **Notifications**
  - `notification_templates`, `notification_jobs`, `channels`
  - Email, SMS (future), webhooks.

- **Integrations & API**
  - `api_keys`, `webhook_endpoints`, `webhook_events`
  - CRUD + event-based integrations (CRM, marketing tools, etc.).

- **Audit & Compliance**
  - `audit_logs`, domain events persisted.
  - Critical changes tracked and queryable.

---

## 5. Multi-Tenancy Model

### 5.1 Tenancy Strategy

- **Logical multi-tenancy** within a single database.
- All tenant-specific data includes `org_id` (or equivalent).
- Cross-tenant access is strictly forbidden by:
  - Ash policies and authorization
  - Query filters
  - Resource design

### 5.2 Tenant Isolation Rules

- No query may return records from multiple orgs unless explicitly a platform-level tool.
- Redis keys are always tenant-scoped:
  - `org:{org_id}:event:{event_id}:...`
- Analytics & caching must respect tenant boundaries.
- Admin-only “platform” views exist but are rare and isolated.

### 5.3 Branding & Configuration

- Tenant-level branding: logo, colors, domain, email templates.
- Tenant settings: feature flags, limits (max events, max seats, etc.).

---

## 6. Performance & Scalability Model

### 6.1 Performance Goals

- Support **flash sales**, high-concurrency checkouts.
- Support **massive events**: 10k–50k+ attendees.
- Support **100k concurrent users** in worst-case scenarios (aspirational).
- Support **fast scanning** (sub-150ms response) even with poor connectivity.

### 6.2 Caching Layers

1. **Hot Layer – ETS / GenServer**
   - For ultra-fast, node-local reads.
   - Seat availability snapshots, live counts, simple counters.
   - TTL: seconds to minutes.

2. **Warm Layer – Redis**
   - Seat bitmaps (SETBIT/GETBIT).
   - Seat holds (ZSETs with expirations).
   - Visitor counts (HyperLogLog).
   - Activity feeds, queue positions.
   - TTL: minutes to hours.

3. **Cold Layer – Postgres**
   - Durable storage and source of truth.
   - Writes via Ash + Ecto.
   - Indexed queries and read replicas.

4. **Client Caching**
   - Browser: localStorage/IndexedDB (scanner app).
   - CDN for static assets.

### 6.3 High-Load Concerns

- **Thundering herd:** Use Redis locks + backpressure.
- **Overselling:** Seat hold registry + transactional updates + optimistic locking.
- **Flash sales:** Rate limiting + queue UI + asynchronous confirmation.
- **Analytics:** Use materialized views or cached aggregates instead of raw large table scans.

### 6.4 Real-Time & Background Processing

- Phoenix PubSub + LiveView for dashboards and operator UI.
- Oban job processing for:
  - Heavy exports
  - Bulk notifications
  - Reconciliation
  - Scheduled tasks
- Domain events feed into:
  - Metrics aggregation
  - Business workflows
  - Integration/webhook delivery.

---

## 7. Key Workflows (End-to-End)

### 7.1 Event Setup

1. Create organisation (tenant)
2. Create venue
3. Design seating layout (sections, rows, seats)
4. Attach layout to event
5. Configure ticket types & price rules
6. Optionally create campaigns and links
7. Publish event (status change with associated validations)

### 7.2 Seating Plan Builder

- Visual UI to:
  - Create sections, rows, individual seats
  - Batch-generate seats
  - Assign seat groups and price categories
- Persisted as layout that can be reused across events.

### 7.3 Checkout Flow

1. User visits event landing page.
2. Selects tickets (and seats if applicable).
3. System creates seat holds in Redis + DB.
4. Checkout session created with expiry.
5. User fills attendee info + payment.
6. External payment provider flow.
7. On success:
   - Order marked paid
   - Tickets created
   - Seat holds converted to “occupied”
   - Emails / notifications dispatched
8. On failure/timeout:
   - Seat holds released
   - Order closed/cancelled.

### 7.4 Scanning Workflow (Online)

1. Device authenticates (org + permissions).
2. Operator selects event/gate.
3. For each scan:
   - App sends token/QR to backend.
   - Backend validates ticket:
     - Exists.
     - Correct event & date.
     - Not already checked in (with concurrency-safe update).
   - Returns result: OK, already scanned, invalid, wrong event.
   - Live counters updated (PubSub).

### 7.5 Scanning Workflow (Offline & Sync)

1. Device syncs event + ticket metadata upfront.
2. Offline mode:
   - Scans recorded locally.
   - Local decision logic:
     - Mark as “checked in (local)”.
   - Provide operator feedback.
3. When connectivity returns:
   - Sync queue pushes scan logs to backend.
   - Backend resolves conflicts:
     - Double scans.
     - Late syncs.
   - Live state updated across all devices.

### 7.6 Refunds & Cancellations

- Reverse or partial reverse ledger entries.
- Seat state: freed or kept occupied depending on policy.
- Send notifications to attendees.
- Mark tickets as invalid for future scanning.

### 7.7 Marketing & Attribution

1. Organiser creates campaign.
2. System generates UTM-tagged links and QR codes.
3. Each click + visit is tracked and associated with campaign.
4. Conversions link to orders and tickets.
5. Dashboards show:
   - Clicks
   - Conversions
   - Revenue per campaign
   - Per-channel comparisons.

---

## 8. Client Applications

### 8.1 LiveView Admin & Ops Dashboard

- Admin UI for:
  - Event management
  - Seating & pricing
  - Order & ticket management
  - Refunds
  - Integrations
- Live operations view:
  - Real-time check-in counts
  - Gate activity and performance
  - Fraud suspicion (e.g., too many invalid scans from one device)

### 8.2 Public Ticketing Site

- Event discovery (future).
- Event detail pages.
- Checkout forms.
- Self-service (download tickets, view orders).

### 8.3 Scanner App (Svelte + PWA + Capacitor)

- Built as offline-first PWA.
- Wrapped in Capacitor for Android APK.
- Uses:
  - Local storage / IndexedDB for cache.
  - Background sync when connectivity returns.
- Separate codebase linked to same backend API.

---

## 9. Security, Auth & Permissions

### 9.1 Authentication

- Ash Authentication with:
  - Email/password
  - Magic link
  - API keys for programmatic access
- Session management:
  - Secure cookies
  - CSRF protection
  - MFA (future)

### 9.2 Authorization

- Role- and policy-based:
  - Org admin
  - Event manager
  - Door staff
  - Finance
  - Read-only
- All Ash actions governed by policies:
  - Tenant scoping
  - Role and ownership checks
  - Action-specific rules (e.g., only finance can refund)

### 9.3 Data Protection

- PII stored minimally and encrypted where necessary.
- Cloak/Ash_Cloak for encryption of sensitive fields.
- TLS enforced on all public endpoints.

---

## 10. Observability, Audit & Compliance

### 10.1 Logging & Metrics

- Structured logs for:
  - Checkouts
  - Payment flows
  - Scan events
  - Background jobs
- Metrics:
  - Request latency
  - Error rates
  - Job metrics (Oban)
  - Per-event/tenant metrics.

### 10.2 Audit Logging

- Audit log for sensitive operations:
  - Role changes
  - Refunds
  - Manual ticket changes
  - Manual scan overrides

### 10.3 Failure Handling

- Graceful degradation:
  - If analytics fails, checkout still works.
  - If Redis down, system falls back to safe but slower flows where possible.
- Clear error surfaces for admins.

---

## 11. Integrations & Public API

### 11.1 Public REST/JSON API

- Authentication via API keys.
- Endpoints for:
  - Events, venues, tickets, orders, scans
  - Webhook management
  - Reporting

### 11.2 Webhooks

- Outbound event notifications:
  - Order created/paid
  - Ticket issued
  - Scan event
  - Refund processed
- Delivery:
  - Signed requests
  - Retry mechanism
  - Dead-letter queue for failed endpoints.

### 11.3 Third-Party Systems

- CRM (e.g. HubSpot, Salesforce – future).
- Email delivery (e.g. Swoosh + provider).
- Payment providers:
  - Initial: one local provider (e.g. Paystack/PayFast/Yoco style).
  - Future: multiple providers with routing.

---

## 12. Environment & Deployment

### 12.1 Environments

- `dev` – local WSL Ubuntu + Postgres + Redis.
- `test` – automated tests, ephemeral DB.
- `staging` – near-prod, internal only.
- `prod` – live environment.

### 12.2 Deployment Strategy

- Containerized Phoenix + Oban + Redis + Postgres.
- Zero-downtime deploys where possible.
- Migrations handled via CI/CD pipeline.
- Secrets managed externally (Vault, environment, etc).

### 12.3 Local Dev Workflow

- Dev runs on WSL Ubuntu.
- Antigravity/Cursor used for code editing with WSL integration.
- Command execution (mix, npm, etc) done in WSL terminal.

---

## 13. AI & Agent Workflow

### 13.1 AGENTS.md – Canonical Rules

Defines:

- MVP-first development.
- File-size limits and refactor rules.
- TOON prompt structure.
- No hallucinated file paths.
- **Standard Ash Folder Structure constraints.**

### 13.2 GEMINI.md – Gemini-Specific Behaviour

Defines:

- Mandatory doc loading sequence:
  - AGENTS.md, INDEX.md, architecture, domain, workflows.
- Ash + Phoenix + PETAL expectations.
- **Logical Vertical Slice rules (mapped to standard Ash folders).**
- Multi-tenancy and caching rules.
- WSL execution boundaries.

### 13.3 .agent/ Rules & Workflows

- `.agent/rules/` – execution boundaries & WSL integration.
- `.agent/workflows/` – standardised flows (e.g., `mix-compile` procedure).

### 13.4 Role Separation

- **ChatGPT (cloud):** - High-level planning  
  - Domain modeling  
  - TOON prompt generation  
  - Architecture decisions  
- **Antigravity / Gemini agent:** - Implements TOON prompts  
  - Edits code  
  - Writes migrations and modules  
  - Suggests commands (user runs them)

---

## 14. Implementation Roadmap (Phased)

> Detailed per-phase TOON breakdown lives in `docs/PROJECT_GUIDE.md` and related planning docs. This section is the high-level view.

### Phase 1 – Foundation & Bootstrap

- Project skeleton with Ash, Phoenix, Oban, Auth.
- Multi-tenant org + user model.
- Basic admin UI.
- Environment/CI setup.

### Phase 2 – Events & Venues

- Event CRUD.
- Venue and seating layout basics.
- Attaching venues to events.

### Phase 3 – Ticketing & Pricing Engine

- Ticket types, prices, rules.
- Seat-aware ticketing.
- Price overrides and promo support.

### Phase 4 – Checkout & Orders

- Cart and checkout session.
- Payments integration (MVP).
- Seat holds and confirmation.

### Phase 5 – Scanner Platform

- Scanner API endpoints.
- Svelte PWA and Capacitor shell.
- Online scanning ready.

### Phase 6 – Offline & Sync

- Local scan queue and sync logic.
- Conflict resolution strategies.
- Operator feedback and logs.

### Phase 7 – Marketing & Campaigns

- Campaigns, UTM links, QR codes.
- Attribution link-click → ticket → customer.

### Phase 8 – Analytics & Dashboards

- Event dashboards.
- Campaign dashboards.
- Ops dashboards for scanning and capacity.

### Phase 9 – Integrations & Webhooks

- Outbound webhooks.
- Initial set of integrations (CRM, email, etc).

### Phase 10 – Hardening & Performance

- Load tests and tuning.
- Index review, Redis configuration.
- Incident playbooks and observability.

---

## 15. Risks & Open Questions

- Payment provider final selection and contract terms.
- Legal requirements for ticketing and refunds in each jurisdiction.
- Operational SLAs for large events.
- Long-term storage and archiving policies.
- Future support for:
  - Multi-currency
  - Multi-language
  - White-label / branded subdomains
- Extending the platform to promoters, agencies, and marketplaces.

---

## 16. How to Use This Document

- **Engineers:** Use this as the architectural north star when making decisions or designing new slices.
- **AI Agents:** Load this alongside AGENTS.md, GEMINI.md, and INDEX.md before generating TOON prompts or code.
- **Founders / Product:** Use this when prioritising features and validating they align with the long-term architecture.
- **Integrators:** Use this to understand data flows, entities, and integration points.

This is a living blueprint. Changes to core architecture, domain boundaries, or major workflows **must** be reflected here.