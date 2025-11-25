# VoelgoedEvents Documentation Index  
**File:** `/docs/INDEX.md`  
**Audience:** Humans & AI Agents  
**Purpose:** Single entry point into all VoelgoedEvents docs

---

## 0. Reading Order for AI Agents (MANDATORY)

If you are an **AI coding or planning agent**, you MUST:

1. Read: `AGENTS.md`  
2. Read: `INDEX.md` (this file)  
3. Then follow the “AI Agent Navigation Path” section below.

If you are a **human developer/architect**, start with the “Human Navigation Path”.

---

## 1. High-Level Orientation

The VoelgoedEvents documentation is designed as a **stack**:

- **Top Layer – What is this platform?**  
  Conceptual understanding, vision, and overall architecture.

- **Middle Layer – How is it structured?**  
  Domains, architecture, workflows, slices.

- **Bottom Layer – How do I work with it?**  
  Project setup, coding rules, agent rules, tests, deployment.

This file ties everything together.

---

## 2. Core Entry Documents

These are the **four primary documents** every person or agent should know:

1. **Agent Rules**  
   - `AGENTS.md`  
   - Defines how AI agents must behave, constraints, TOON format, vertical slice rules, file path conventions, and performance/scaling assumptions.

2. **Platform Overview**  
   - `platform_overview.md`  
   - Explains what VoelgoedEvents *is* as a product & system, how PETAL + Ash + vertical slices + caching + eventing fit together.

3. **Project Overview**  
   - `project_overview.md`  
   - Explains how to work with the repository: structure, dev environment, commands, workflows, expectations.

4. **Domain Map (Authoritative)**  
   - `DOMAIN_MAP.md`  
   - High-level map of all domains in the system and how they relate: Tenancy, Events, Seating, Ticketing, Payments, Scanning, Analytics, Integrations, Notifications, Reporting, Audit, Public API, Ephemeral State.

These four files form the **mental model** of the platform.

---

## 3. Human Navigation Path

If you’re a **human developer/architect**, recommended reading order:

1. `platform_overview.md`  
2. `project_overview.md`  
3. `DOMAIN_MAP.md`  
4. `architecture/01_foundation.md`  
5. `architecture/04_vertical_slices.md`  
6. Then dip into:
   - `architecture/02_multi_tenancy.md`  
   - `architecture/03_caching_and_realtime.md`  
   - `architecture/05_eventing_model.md`  
7. Finally:
   - `domain/README.md` and individual domain docs  
   - `workflows/README.md` and specific workflows relevant to your task

Use this file (`INDEX.md`) as your **table of contents**.

---

## 4. AI Agent Navigation Path

If you are an **AI coding agent**, you must:

1. **Load hard constraints:**
   - `AGENTS.md`
   - `architecture/01_foundation.md`
   - `architecture/02_multi_tenancy.md`
   - `architecture/03_caching_and_realtime.md`
   - `architecture/04_vertical_slices.md`

2. **Load context for the current task:**
   - `DOMAIN_MAP.md`  
   - Relevant `domain/*.md` files  
   - Relevant `workflows/*.md` files

3. **Respect file paths and naming** from:
   - `project_overview.md`
   - `architecture/README.md`
   - `domain/README.md`

4. **NEVER**:
   - Put business logic in controllers or LiveViews.  
   - Bypass the Ash domain model.  
   - Ignore performance rules (ETS/Redis/Postgres).  
   - Violate multi-tenancy boundaries.

---

## 5. Architecture Documentation

Folder: `/docs/architecture/`  
Index: `/docs/architecture/README.md`

Key files:

- `01_foundation.md`  
  Core architecture: PETAL, Ash, vertical slices, hot/warm/cold data.

- `02_multi_tenancy.md`  
  Multi-tenant rules, organization scoping, redis key naming, DB indexes.

- `03_caching_and_realtime.md`  
  Caching strategy (ETS/Redis/Postgres), real-time behavior, availability modeling.

- `04_vertical_slices.md`  
  How features are built end-to-end; mandatory slice structure and rules.

- `05_eventing_model.md`  
  Domain events, PubSub topics, Redis streams, workflow event flows.

- `06_jobs_and_async.md`  
  Oban jobs, queues, idempotency, retry policies, DLQ patterns.

- `07_security_and_auth.md`  
  Identity types, sessions, API keys, device auth, rate limiting, QR security, audit.

- `08_cicd_and_deployment.md`  
  CI pipeline, releases, migrations, blue/green & canary deploys.

- `09_scaling_and_resilience.md`  
  Horizontal scaling, flash-sale strategy, real-time scaling, resilience.

Use the architecture docs whenever you are:

- Designing or modifying core behavior  
- Introducing new slices  
- Dealing with performance, scaling, or security  

---

## 6. Domain Documentation

Folder: `/docs/domain/`  
Index: `/docs/domain/README.md`  
Map: `/docs/DOMAIN_MAP.md` (top-level overview)

Each domain file defines:

- Scope & responsibility  
- Core resources & invariants  
- Performance and caching strategy  
- Redis/ETS structures  
- PubSub topics  
- Domain interactions  
- Testing and observability notes

Examples (by intention):

- `tenancy_accounts.md` – Organizations, users, roles, membership  
- `events_venues.md` – Events, venues, scheduling  
- `seating.md` – Layouts, seats, availability structures  
- `ticketing_pricing.md` – Ticket types, GA & reserved inventory, price rules  
- `payments_ledger.md` – Payments, ledger, refunds, reconciliation  
- `scanning_devices.md` – Scanner devices, online/offline flows  
- `analytics_marketing.md` – Funnels, event metrics, targeting  
- `integrations_webhooks.md` – Incoming/outgoing webhooks, PSP & API integration points  
- `reporting.md` – Reports, exports, materialized views  
- `notifications_delivery.md` – Email/SMS/WhatsApp, templates, rate limits  
- `audit_logging.md` – Immutable audit trail  
- `public_api_access_keys.md` – API keys, scopes, rate limiting  
- `ephemeral_realtime_state.md` – Redis/ETS hot state for the entire platform

When changing behavior in a domain, update its doc and ensure it remains consistent with:

- `DOMAIN_MAP.md`  
- `architecture/*.md`  

---

## 7. Workflow Documentation

Folder: `/docs/workflows/`  
Index: `/docs/workflows/README.md` (if present)

Each workflow doc explains an **end-to-end flow** across multiple domains and slices, for example:

- Checkout & payment flow  
- Ticket lifecycle (create → reserve → pay → issue → scan → refund/cancel)  
- Seating plan builder flow  
- Scanning online/offline sync  
- Webhook delivery and retry  
- Notification delivery flow  
- Event lifecycle (draft → published → ongoing → completed)  
- Reporting & export lifecycle  

Use workflow docs when you want to understand:

- How domains work together  
- Where vertical slices start and end  
- What invariants must hold across the entire process  

---

## 8. Agent-Specific Docs (AGENTS, GEMINI, etc.)

### 8.1 `AGENTS.md` (Canonical)

`AGENTS.md` is the **canonical** specification for all AI agents working on VoelgoedEvents:

- Defines TOON format  
- Defines vertical slice behavior  
- Defines performance and caching defaults  
- Defines safety & architectural constraints  

All AI agents (ChatGPT, Gemini, etc.) should treat `AGENTS.md` as the **source of truth**.

### 8.2 `GEMINI.md` (Optional but Recommended)

If you are using Gemini (or another LLM vendor) and want to tune instructions for that ecosystem, you can add:

- `GEMINI.md`

Recommended content for `GEMINI.md`:

- A short preface: “Gemini, always read AGENTS.md and INDEX.md first.”  
- Any Gemini-specific prompt formatting or limitations.  
- Links back to:
  - `AGENTS.md`  
  - `INDEX.md`  
  - The core docs it should preload for coding.

This avoids duplication while giving vendor-specific agents a clear entry point.

**Important:**  
- Don’t fork the entire ruleset into `GEMINI.md`.  
- Point Gemini to `AGENTS.md` as the canonical rules, and only layer *differences* or *usage notes* in `GEMINI.md`.

---

## 9. Project & Contribution Docs

Additional helpful docs you might have:

- `project_overview.md`  
  - How to set up dev environment, run tests, use tools.

- `CONTRIBUTING.md` (if added)  
  - How to open PRs, branch strategy, review rules.

- `adr/` (if present)  
  - Architecture Decision Records for tracking big decisions over time.

---

## 10. Summary

- **AGENTS.md** → Rules of the game (especially for AI).  
- **INDEX.md** → This file: how to navigate the whole documentation universe.  
- **platform_overview.md** → What VoelgoedEvents *is*.  
- **project_overview.md** → How to work on VoelgoedEvents.  
- **DOMAIN_MAP.md** → Overview of all domains.  
- **architecture/** → Platform-wide technical rules & constraints.  
- **domain/** → Deep domain-specific contracts.  
- **workflows/** → End-to-end process flows across domains.

If you’re unsure where something belongs:

- Platform-wide concerns → `architecture/`  
- Single business capability → `domain/`  
- Multi-step flows → `workflows/`  
- Agent or LLM-specific behavior → `AGENTS.md` (+ optional `GEMINI.md`, etc.)

This document (`INDEX.md`) is the **home page** of the VoelgoedEvents documentation.

