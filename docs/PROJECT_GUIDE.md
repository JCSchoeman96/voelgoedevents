# VoelgoedEvents – Project Guide

This document explains **what VoelgoedEvents is**, **how it’s structured**, and **how to work inside it without making a mess**.

**Audience:**

- Future maintainers.
- AI coding agents (Cursor, ChatGPT / VoelgoedEvents Architect, etc.).
- Anyone trying to get oriented quickly.

---

## 1. Vision & Scope

### 1.1 Long-Term Vision

VoelgoedEvents is a **PETAL + Ash** powered event ticketing platform with:

- Multi-tenant SaaS model (agencies, venues, organisers).
- Strong **GA + seated ticketing**.
- **Offline-capable scanning** (Svelte/SvelteKit + Capacitor).
- **Phoenix LiveView** dashboards and back-office.
- Clear APIs and webhooks for integrations.

Long-term goal: become the **top-tier South African ticketing + check-in platform**, with first-class scanning and a strong seating experience.

### 1.2 MVP Scope (Ruthless Version)

MVP is deliberately smaller than the endgame vision:

- **Single-tenant** (one organisation to start).
- Events, venues, GA ticket types (simple seat maps = read-only).
- Orders, payments, ticket issuing.
- QR-based scanning app (PWA) talking to Phoenix APIs.
- Basic LiveView dashboards.
- Fundamental analytics events:  
  `view → add_to_cart → checkout_success`.

Multi-tenant, advanced seating, complex pricing, loyalty, and white-label come in later phases.

---

## 2. Tech Stack

### 2.1 Backend

- Elixir / Erlang / Phoenix
- **PETAL**: Phoenix, Elixir, Tailwind, AlpineJS, LiveView
- **Ash Framework** – domain logic (resources, actions, policies)
- **AshPostgres** – persistence
- **AshPhoenix** – Phoenix integration
- **AshAuthentication** – auth flows
- **AshAdmin** – admin/introspection
- **Oban / AshOban** – background jobs
- **PostgreSQL + pgBouncer** – primary DB + connection pooling
- **Redis** – caching, rate limiting, hot state
- **ETS / Cachex** – in-memory caches
- Telemetry + logging for observability (see ADRs).

### 2.2 Frontend

- **Phoenix LiveView + HEEx** – main admin UI & dashboards, organiser tools.
- **Svelte/SvelteKit PWA** (in `/scanner_pwa` or `/frontend/scanner`) for **offline-capable scanning**, wrapped with Capacitor for mobile when needed.
- Optional future **Svelte organiser app** (separate from admin dashboard).

---

## 3. Architecture Overview

### 3.1 Ash as Domain Engine

Ash holds all business rules:

- Domains/resources: `Accounts`, `Organizations`, `Venues`, `Events`, `Seating`, `Ticketing`, `Payments`, `Scanning`, `Analytics`, `Integrations`.
- Constraints, validations, state machines, and policies live in **Ash resources/actions**.
- Multi-step flows are orchestrated in dedicated **workflows**, not controllers.

### 3.2 Phoenix as I/O Layer

Phoenix is **“delivery only”**:

- LiveView UI for organisers and internal tools.
- JSON APIs for scanner PWA and any future Svelte frontends.
- Webhook endpoints for external systems (payments, integrations).
- No business logic beyond light formatting and parameter handling.

### 3.3 Frontends as Clients of the Domain

- LiveView and Svelte apps **consume Ash-powered APIs/domains**.
- They **never implement domain rules**  
  (no duplicate validation, no ticket state machine in JS).

---

## 4. Repository Structure (Mental Map)

Top-level folders of interest:

- `lib/voelgoed/` – core app logic, Ash domains/resources, workflows, caching, queues, analytics.
- `lib/voelgoed_web/` – Phoenix + LiveView web layer (endpoint, router, controllers, LiveViews, components).
- `lib/voelgoed/ash/` – domains, resources, policies, support utilities.
- `lib/voelgoed/contracts/` – typed boundary contracts (API + workflows, optional).
- `assets/` – Phoenix asset pipeline (JS, CSS, TS types for web app).
- `scanner_pwa/` – Svelte-based offline-first scanner PWA.
- `schemas/` – OpenAPI + JSON Schemas for API/analytics contracts.
- `priv/repo/migrations/` – DB schema migrations.
- `test/` – tests.

This guide explains **how to use** this structure, not every file in it.

---

## 5. Domains & Resources (High-Level)

All business logic lives behind **Ash domains** and **Ash resources**.  
Detailed docs go in `/docs/domain/*.md`.

### 5.1 Accounts & Tenancy

- **Organization** (`organizations/organization.ex`)  
  Tenant using the system: name, slug, plan, settings, status.

- **User** (`accounts/user.ex`)  
  Global user identity (email, hashed password, profile). Integrated with AshAuthentication.

- **Role** (`accounts/role.ex`)  
  Role definitions (owner, admin, staff, viewer, scanner_only, etc.).

- **Membership** (`accounts/membership.ex`)  
  User ↔ organization link with a role. Enforces per-org RBAC.

### 5.2 Events & Venues

- **Venue** (`venues/venue.ex`)  
  Physical location: address, capacity, timezone, settings.

- **Gate** (`venues/gate.ex`)  
  Entry point at a venue: gate code, settings (allowed ticket types, schedules).

- **Event** (`events/event.ex`)  
  Event instance: name, description, venue, schedule, status (draft/published/closed), optional capacity.

- **OccupancySnapshot** (`events/occupancy_snapshot.ex`)  
  Periodic, read-optimised snapshots for fast dashboards.

### 5.3 Ticketing

- **TicketType / Ticket** (`ticketing/ticket.ex`, etc.)  
  GA or seated tickets, with a **state machine** (`reserved → sold → refunded…`).

- **PricingRule** (`ticketing/pricing_rule.ex`)  
  Tiered and rule-based pricing (MVP = simple tiers; advanced models later).

- **Coupon** (`ticketing/coupon.ex`)  
  Discount codes, validity, usage limits.

- **Order** (if separated)  
  Customer order abstraction with payment and fulfilment status.

### 5.4 Seating (Phase After GA MVP)

- **Block / Section / Seat / Layout** (`seating/*.ex`)  
  Hierarchical seat model; supports complex layouts and future builder.  
  Initial MVP can treat maps as **read-only** or **simplified**.

### 5.5 Payments

- **Transaction** (`payments/transaction.ex`)  
  Payment transaction lifecycle (`initiated → pending → succeeded/failed`).

- **Refund** (`payments/refund.ex`)  
  Links refunds to transactions/tickets.

- **LedgerAccount / JournalEntry**  
  Double-entry accounting for revenue & fees  
  (MVP can start simple and grow to full ledger).

### 5.6 Scanning

- **Scan** (`scanning/scan.ex`)  
  Scan event: ticket, device, gate, timestamp, result (accepted/rejected).

- **ScanSession** (`scanning/scan_session.ex`)  
  Session per device/event/gate.

Includes offline/conflict-resolution logic orchestrated via **workflows** and **background jobs**.

### 5.7 Analytics

- **AnalyticsEvent** (`analytics/analytics_event.ex`)  
  First-party funnel events (`page_view`, `add_to_cart`, `checkout_success`, etc.).

- **FunnelSnapshot** (`analytics/funnel_snapshot.ex`)  
  Pre-aggregated funnel metrics per event/date range.

### 5.8 Integrations

- `WebhookEndpoint`, `WebhookEvent`
- Public API key model, rate limiting, and delivery workers.

---

## 6. Policies & Support Modules

### 6.1 Policies

`lib/voelgoed/ash/policies/`:

- `common_policies.ex` – shared rules  
  (e.g. “user must belong to organisation”, “must be organiser/admin”, etc.).
- `tenant_policies.ex` – multi-tenant protection, isolation.

**Rule:**  
Always **reuse shared policies** instead of ad-hoc checks in resources or controllers.

### 6.2 Changes, Calculations, Validations

`lib/voelgoed/ash/support/`:

- `changes/` – state transitions tied to resources (seat holds, transaction state, etc.).
- `calculations/` – derived values (final ticket price, occupancy percentages).
- `validations/` – invariant checks (event dates, seating consistency).

**Guideline:**

- Transitions → `changes/`
- Derived numbers → `calculations/`
- Checks that might fail → `validations/`

---

## 7. Workflows

Workflows orchestrate **multiple Ash actions** and glue domain operations together.

`lib/voelgoed/workflows/`:

- `checkout/start_checkout.ex` – validate cart, hold seats, open transaction.
- `checkout/complete_checkout.ex` – confirm payment, transition tickets, write ledger entries, log analytics.
- `ticketing/reserve_seat.ex` / `ticketing/release_seat.ex` – manage seat state + cache.
- `scanning/process_scan.ex` – scan validation, concurrency, analytics, occupancy touch.
- `analytics/funnel_builder.ex` – build funnel snapshots from `AnalyticsEvent`.

**Rule:**  
Any **multi-resource operation** goes in a **workflow module**, *not* in controllers or a single Ash resource.

---

## 8. Caching & Performance

`lib/voelgoed/caching/`:

- `seat_cache.ex` – hot seat availability.
- `pricing_cache.ex` – cached pricing rules.
- `occupancy_cache.ex` – fast counts for dashboards.
- `rate_limiter.ex` – Redis/ETS-based rate limiting for scanning/checkout.

**Rules for agents:**

- Hot-path reads (seat availability, occupancy, pricing) → use **cache first**, DB/Ash as fallback.
- Writes always go through **Ash + DB**; caches are **derived** and invalidated via Ash notifiers.
- TTLs are short and domain-driven  
  (e.g. seat availability ~30s, venue layout many hours).

---

## 9. Background Jobs (Oban)

`lib/voelgoed/queues/`:

- `oban_config.ex` – central queue configuration.

**Workers:**

- `worker_send_email.ex` – confirmations, reminders.
- `worker_generate_pdf.ex` – PDF tickets.
- `worker_cleanup_holds.ex` – expire seat holds, update DB & caches.
- `worker_analytics_export.ex` – exporting analytics to external systems.

**Rule:**  
If work is **not required for immediate response**, use a **worker**.

---

## 10. Web Layer (Phoenix + LiveView)

`lib/voelgoed_web/`:

- `endpoint.ex` – endpoint & sockets.
- `router.ex` – LiveView routes, scanner API routes, webhooks, health.

### 10.1 Components

`voelgoed_web/components/`:

- `core_components.ex` – generic UI pieces.
- `layout_components.ex` – page shells/layouts.
- `form_components.ex` – forms and error helpers.
- `admin_components.ex` – basic cards, tables, stat blocks.

### 10.2 Controllers

- `page_controller.ex` – marketing/landing/static.
- `health_controller.ex` – `/health` endpoint.
- `webhook_controller.ex` – payment + other inbound webhooks.

### 10.3 LiveViews (MVP Examples)

- `event/event_index_live.ex` – event listing.
- `event/event_show_live.ex` – event detail + ticket selection.
- `checkout/cart_live.ex` & `checkout/checkout_live.ex` – cart and checkout.
- `admin/dashboard_live.ex` – organiser KPIs.
- `admin/events_live.ex` – event CRUD.
- `admin/scans_live.ex` – scan monitoring.
- `seating/seating_preview_live.ex` – **read-only** seat map for MVP.

### 10.4 Plugs

- `current_user_plug.ex` – load current user.
- `current_org_plug.ex` – select active organisation.
- `analytics_plug.ex` – attach `session_id`/UTMs, seed analytics context.

---

## 11. Scanner PWA (Svelte)

`scanner_pwa/`:

- Svelte 5 (or SvelteKit) + Vite PWA.
- Talks to Phoenix scanning API (`/api/scans`, `/api/scanner/sync`).

**Responsibilities:**

- Camera access + QR decode.
- Scan queue management (offline-first).
- Sync with server when online.
- Simple UI for operators.

**Rule:**  
No business logic here. Validation lives in `scanning_domain` + workflows.

---

## 12. Testing

`test/`:

- `test/voelgoed/ash/...` – resource invariants, policies, changes/validations.
- `test/voelgoed/workflows/...` – workflow integration tests.
- `test/voelgoed/caching/...` – cache behaviour & TTL.
- `test/voelgoed_web/...` – controller and LiveView tests (MVP flows).

**Guidelines:**

- New logic ⇒ matching tests in the **correct folder**.
- Don’t dump all tests into one monster file.

---

## 13. Coding Workflow & TOON Micro-Prompts

All implementation should be driven via **TOON micro-prompts** (one clear action each):

| Field      | Description                                              |
|-----------|----------------------------------------------------------|
| **Task**  | Single, focused action (no mixed responsibilities).      |
| **Objective** | Why this matters / what it enables.                  |
| **Output**| Concrete files/changes/artifacts expected.               |
| **Note**  | Constraints, edge cases, architecture & style rules.     |

**Rules:**

- One TOON = one logical step.
- Prefer many small TOONs over big vague tasks.
- Don’t add dependencies or re-architect without explicit instruction.

---

## 14. File Size & Refactor Rules

- Aim for **< 1500 LOC per file**; soft target **600–800 lines**.
- **> 2000 LOC** = mandatory refactor signal.
- Split by **responsibility**, not arbitrary line count.
- Before big splits, write a short **Refactor Plan**, then do minimal changes to match it.

This keeps both **humans** and **AI agents** efficient.

---

## 15. Documentation Layout

`/docs/` contains (at minimum):

- `PROJECT_GUIDE.md` – this file.
- `DOMAIN_MAP.md` – high-level domain map.
- `architecture/*.md` – backend & frontend structure, ADRs, performance notes.
- `agents/AGENTS.md` – rules for AI coding agents.
- `domain/*.md` – per-domain detail (Accounts, Events, Ticketing, Seating, etc.).
- `api/*.md` – scanner API, public REST API, webhooks.
- `workflows/*.md` – lifecycle & flows (checkout, scanning, refunds…).

Every major subsystem gets at least a **lightweight doc**.

---

## 16. Guidance for AI Agents

### 16.1 Navigation Rules

- Change business rules → `lib/voelgoed/ash/resources/...` or `lib/voelgoed/ash/support/...`.
- Multi-step workflows → `lib/voelgoed/workflows/...`.
- UI changes → `lib/voelgoed_web/live/...` and `voelgoed_web/components/...`.
- Caching & rate limiting → `lib/voelgoed/caching/...`.
- Background work → `lib/voelgoed/queues/...`.
- Analytics/funnels → `lib/voelgoed/analytics/...` and `ash/resources/analytics/...`.

### 16.2 Token-Saving Behavior

- Avoid dumping whole files unless asked.
- Prefer targeted diffs and additions.
- Use this guide + `DOMAIN_MAP.md` + `AGENTS.md` as **primary context**, not repeated trees.

---

## 17. Non-Goals (For Now)

To avoid scope creep in MVP:

- No multi-currency or global tax engine.
- No ERP-grade accounting; start with simple fee/takings reporting.
- No general-purpose CMS.
- No heavy SPA front-end; LiveView + focused Svelte apps are enough.
- No full multi-tenant SaaS in MVP (phase later).

---

## 18. Roadmap & Vertical Slices

All implementation should follow **vertical slices**, not “all infrastructure first”.

**Example MVP slices:**

1. **Create & list events** – event CRUD + simple organiser UI.
2. **Sell GA tickets** – ticket types, basic checkout, simple payments.
3. **Issue & validate tickets** – QR codes, scan API, basic scanner PWA.
4. **Basic dashboards** – per-event sales & occupancy.

Each slice:

- Includes **domain, DB, APIs, UI, and tests**.
- Is **independently shippable**.
- Builds on previous slices **without blocking others**.

---

## 19. Summary

- **Ash** is the heart of the domain.
- **Phoenix/LiveView & Svelte** are delivery mechanisms.
- **Postgres** is the durable source of truth.
- **Redis/ETS** are accelerators, never the authority.
- `AnalyticsEvent` is the backbone of funnel analytics.
- **Vertical slices + TOON micro-prompts** keep the project shippable and sane.

Welcome to **VoelgoedEvents**.
