# VoelgoedEvents Development Roadmap — CANONICAL EDITION v7.1

**Document Version:** 7.1 FINAL CANONICAL (Refinement Update)  
**Date:** December 2, 2025  
**Author:** VoelgoedEvents Planning & Coding Agent  
**Purpose:** TOON-consumable, DRY, fully reference-linked implementation roadmap  
**Compliance:** `/docs/AGENTS.md`, `/docs/INDEX.md`, Standard Ash Layout, TOON micro-prompt standards

---

## 📌 DOCUMENT STATUS

✅ **CANONICAL** — This is the authoritative roadmap for VoelgoedEvents  
✅ **TOON-ALIGNED** — All sub-phases are atomic, executable TOON prompts  
✅ **DUPLICATION-FREE** — All repeated patterns replaced with canonical references  
✅ **REFERENCE-LINKED** — Every constraint links to source documentation  
✅ **FOLDER-VALIDATED** — All paths match `/docs/INDEX.md` Section 4.1 and `/docs/ai/ai_context_map.md`  
✅ **ABSTRACTION-LAYERED** — Clear separation between UI, domain logic, and infrastructure

## 📋 TABLE OF CONTENTS

1. [How to Use This Roadmap](#how-to-use-this-roadmap)
2. [Repository Analysis](#repository-analysis)
3. [Phase 0: Agent Setup & Safety Rails](#phase-0-agent-setup--safety-rails)
4. [Phase 1: Technical Foundation](#phase-1-technical-foundation)
5. [Phase 2: Tenancy, Accounts & RBAC](#phase-2-tenancy-accounts--rbac)
6. [Phase 3: Core Events & GA Ticketing](#phase-3-core-events--ga-ticketing)
7. [Phase 4: Orders, Payments & Ticket Issuance](#phase-4-orders-payments--ticket-issuance)
8. [Phase 5: Scanning Backend & Integration](#phase-5-scanning-backend--integration)
9. [Phase 6: Full Financial Ledger & Settlement Engine](#phase-6-full-financial-ledger--settlement-engine)
10. [Phase 7: Organiser Admin Dashboards](#phase-7-organiser-admin-dashboards)
11. [Phase 8: Seating Engine Domain Layer](#phase-8-seating-engine-domain-layer)
12. [Phase 9: Seating Builder LiveView UI](#phase-9-seating-builder-liveview-ui)
13. [Phase 10: Integrations, Webhooks & Public API](#phase-10-integrations-webhooks--public-api)
14. [Phase 11: Hardening, Security & Performance](#phase-11-hardening-security--performance)
15. [Phase 12: Mobile & Svelte Apps](#phase-12-mobile--svelte-apps)
16. [Phase 13: Questionnaires & Polls](#phase-13-questionnaires--polls)
17. [Phase 14: Merchandise & Physical Products](#phase-14-merchandise--physical-products)
18. [Phase 15: Advanced Marketing & Affiliates](#phase-15-advanced-marketing--affiliates)
19. [Phase 16: CMS & Site Management](#phase-16-cms--site-management)
20. [Phase 17: Enhanced Ticketing Features](#phase-17-enhanced-ticketing-features)
21. [Phase 18: Advanced SEO & Discoverability](#phase-18-advanced-seo--discoverability)
22. [Phase 19: Dynamic Pricing Engine Expansion](#phase-19-dynamic-pricing-engine-expansion)
23. [Phase 20: Internationalization & Localization](#phase-20-internationalization--localization)
24. [Phase 21: Monetization & Feature Flagging](#phase-21-monetization--feature-flagging)
25. [Appendix A: Technical Specifications Reference](#appendix-a-technical-specifications-reference)
26. [Appendix B: Multi-Tenancy Security Deep Dive](#appendix-b-multi-tenancy-security-deep-dive)
27. [Appendix C: Performance & Scaling Strategy](#appendix-c-performance--scaling-strategy)

---

## 🎯 HOW TO USE THIS ROADMAP

### For Project Managers

- **Phases** = Major milestones delivering shippable vertical slices
- **Sub-Phases** = Atomic implementation tasks (15-30 minutes each)
- **Dependencies** = Sequential within phases; some phases can run in parallel
- **MVP Scope** = Phases 0–7 (must complete before production launch)

### For Developers

**Before coding ANY sub-phase:**

1. Load `/docs/AGENTS.md` (supreme rulebook — overrides everything)
2. Load `/docs/INDEX.md` (folder structure & doc navigation)
3. Load `/docs/MASTER_BLUEPRINT.md` (architecture & vision)
4. Load relevant architecture docs from `/docs/architecture/`
5. Load relevant domain docs from `/docs/domain/`
6. Load relevant workflow docs from `/docs/workflows/`
7. Load relevant coding style docs from `/docs/coding_style/`

**Never:**

- Create custom folders (always use Standard Ash 3.0 Layout)
- Put business logic outside Ash resources
- Skip multi-tenancy enforcement (see Appendix B)
- Duplicate caching logic (reference Appendix C)

### For AI Coding Agents

**Critical Rules:**

- Every sub-phase is a **TOON micro-prompt** (atomic, single-purpose)
- Always read **Note** sections for constraints, edge cases, and canonical references
- Never hallucinate file paths or modules (validate against `/docs/ai/ai_context_map.md`)
- When you see **"Apply Standard VoelgoedEvents Caching Model"** → reference Appendix C (do NOT re-describe caching logic)
- When you see **"Reference `/docs/workflows/[name].md`"** → load that workflow spec (do NOT duplicate steps)
- Enforce multi-tenancy per Appendix B (every resource MUST include `organization_id`)
- Ask clarifying questions when specifications are ambiguous

### Reading Sub-Phases

Every sub-phase follows this structure:

```markdown
#### Sub-Phase X.Y.Z: [Descriptive Name]

**Task:** [One clear sentence — what to build]  
**Objective:** [Why this matters / what it enables]  
**Output:** [Expected files/modules with exact paths]  
**Note:**  
- [Constraints, edge cases, Ash rules, MT rules]
- [Links to canonical source docs]
```

---

## 📦 REPOSITORY ANALYSIS

## 📦 Repository Structure

✅ See `/docs/INDEX.md` Section 4.1 for the current validated folder and file structure.  
✅ This roadmap is folder-agnostic — it enforces folder correctness via `/docs/INDEX.md`, not duplication.  

## 🔧 PHASE 0: Agent Setup & Safety Rails

**Goal:** Establish agent behavior, TOON consumption rules, and safety guardrails before any business logic  
**Duration:** 2–3 days  
**Deliverables:** Agent rulebooks, vision docs, domain glossary, WSL workflow setup  
**Critical:** Must complete Phase 0 before proceeding to Phase 1

---

### Phase 0.1: Product Vision & Target Segment [DONE]

#### Sub-Phase 0.1.1: Create Product Vision Document

**Task:** Document target market, positioning, differentiators, and long-term vision  
**Objective:** Provide all agents and developers with a shared north star  
**Output:** `/docs/PRODUCT_VISION.md`  
**Note:**  
- Must align with `/docs/MASTER_BLUEPRINT.md` Section 1 (Vision & Product Overview)
- Emphasize South African market context (ZAR-first, Paystack/Yoco integration)
- Core differentiators: offline-first scanning, multi-tenancy, financial integrity
- Reference existing content from MASTER_BLUEPRINT; do not rewrite from scratch

---

#### Sub-Phase 0.1.2: Create MVP Boundaries Document

**Task:** Define what is IN and OUT of MVP scope  
**Objective:** Prevent scope creep and align Phase 0–7 delivery  
**Output:** `/docs/MVP_SCOPE.md`  
**Note:**  
- MVP = Phases 0–7 only
- Reference `/docs/PROJECT_GUIDE.md` Section 1.2 for alignment
- Explicitly list non-goals (multi-currency, advanced CMS, mobile apps, etc.)
- Must include clear "MVP INCLUDES" and "MVP EXCLUDES" sections

---

### Phase 0.2: Core Domain Glossary

#### Sub-Phase 0.2.1: Review & Validate DOMAIN_MAP.md

**Task:** Verify `/docs/domain/DOMAIN_MAP.md` includes all required entities from all phases  
**Objective:** Ensure complete domain coverage before implementation begins  
**Output:** Updated `/docs/domain/DOMAIN_MAP.md` (if gaps found)  
**Note:**  
- Must include all entities from `/docs/ai/ai_context_map.md` Section 2
- Verify slice boundaries align with `/docs/architecture/04_vertical_slices.md`
- Validate relationships between domains (e.g., Ticket → Event, Order → Transaction)
- Add entities for Phases 8+ (Seating, Merchandise, Polls, Affiliates, CMS)

---

### Phase 0.3: MVP Non-Goals

#### Sub-Phase 0.3.1: Document What We Won't Build in MVP

**Task:** Update `/docs/MVP_SCOPE.md` with explicit non-goals  
**Objective:** Set clear boundaries to avoid over-engineering early phases  
**Output:** Updated `/docs/MVP_SCOPE.md` — Non-Goals section  
**Note:**  
- Reference `/docs/PROJECT_GUIDE.md` Section 17 (Non-Goals For Now)
- Explicitly exclude: multi-currency, global tax engine, ERP-grade accounting, heavy CMS, full SPA frontend, complete white-label

---

### Phase 0.4: Agent Rulebook Validation

#### Sub-Phase 0.4.1: Verify AGENTS.md Compliance

**Task:** Confirm `/docs/AGENTS.md` is loaded and understood by all agents  
**Objective:** Ensure agents follow mandatory load order and behavior rules  
**Output:** Agent self-check report (logged in Space/thread context)  
**Note:**  
- Agents must load documents in this order:
  1. `/docs/AGENTS.md` (supreme rulebook)
  2. `/docs/INDEX.md` (folder structure & navigation)
  3. `/docs/MASTER_BLUEPRINT.md` (vision & architecture)
  4. Architecture docs (as needed per task)
  5. Domain docs (as needed per slice)
  6. Workflow docs (as needed per feature)
  7. Coding style docs (as needed per file type)
- Reference `/docs/AGENTS.md` Section 2 (Mandatory Load Order)

---

### Phase 0.5: WSL & Workflow Setup

#### Sub-Phase 0.5.1: Configure .agent/ Rules (if using Antigravity)

**Task:** Set up `.agent/rules` and `.agent/workflows` for WSL integration  
**Objective:** Enable agents to execute Mix commands correctly in WSL environment  
**Output:**  
- `.agent/rules/wsl_integration.md`
- `.agent/workflows/mix-compile.md`  
**Note:**  
- Reference `/docs/AGENTS.md` Section 8 (Environment Rules)
- Ensure Mix compile, Mix test, and Mix ecto.migrate work correctly in WSL
- Command execution: `wsl bash -l -c "cd /home/jcs/projects/voelgoedevents && mix <command>"`

---

## ✅ [DONE] PHASE 1: Technical Foundation

**Goal:** Clean, disciplined, extensible codebase with high-concurrency primitives  
**Duration:** 1.5 weeks  
**Deliverables:** Configured tools, CI pipeline, foundation docs, ETS/Redis/Oban setup  
**Dependencies:** Completes Phase 0

---

### Phase 1.1: Project Scaffolding

#### Sub-Phase 1.1.1: Verify Dependencies

**Task:** Check `mix.exs` contains all required dependencies with correct versions  
**Objective:** Ensure correct versions of Ash, Phoenix, Oban, Redis, etc.  
**Output:** Verified `mix.exs`  
**Note:**  
- **Status:** COMPLETE (verified from GitHub)
- Required versions:
  - Elixir: `~> 1.17`
  - Phoenix: `~> 1.7`
  - Ash: `~> 3.0`
  - AshPostgres: `~> 2.0`
  - AshPhoenix: `~> 2.0`
  - AshAuthentication: `~> 4.0`
  - AshStateMachine: `~> 0.2`
  - Oban: `~> 2.17`
  - AshOban: `~> 0.2`
  - Redix: `~> 1.5`
  - Cachex: `~> 3.6`
  - Swoosh: `~> 1.16`

---

### Phase 1.2: Folder & Domain Layout

#### Sub-Phase 1.2.1: Validate Folder Structure

**Task:** Verify Standard Ash Layout exists and matches `/docs/INDEX.md` Section 4.1  
**Objective:** Ensure all code follows canonical folder structure  
**Output:** Folder structure audit report  
**Note:**  
- **Status:** COMPLETE (folders exist, empty)
- Never create custom folders like `lib/voelgoedevents/ticketing/ash/`
- Always use Standard Ash Layout: `lib/voelgoedevents/ash/resources/ticketing/`
- Reference `/docs/ai/ai_context_map.md` for authoritative module registry

---

#### Sub-Phase 1.2.2: Create Foundation Architecture Document

**Task:** Document PETAL stack rationale, Ash philosophy, caching tiers, DLM requirements  
**Objective:** Provide architectural context for all future implementation  
**Output:** `/docs/architecture/01_foundation.md`  
**Note:**  
- Must align with existing architecture docs in `/docs/architecture/`
- Link to `/docs/PROJECT_GUIDE.md` Section 2 (Tech Stack)
- Define DLM pattern (Redlock or Redis SET NX EX)
- Reference Appendix C for caching model details

---

### Phase 1.3: Tooling & CI

#### Sub-Phase 1.3.1: Add Credo

**Task:** Configure Credo for code quality enforcement  
**Objective:** Maintain consistent code style across all contributions  
**Output:** `.credo.exs`  
**Note:**  
- Use strict mode
- Max cyclomatic complexity: 10
- Enforce module documentation

---

#### Sub-Phase 1.3.2: Add Dialyzer

**Task:** Configure Dialyxir for static type analysis  
**Objective:** Catch type errors early  
**Output:** `mix.exs` updated with `:dialyxir` dependency  
**Note:**  
- Add to `:dev` and `:test` only
- Dependency: `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`

---

#### Sub-Phase 1.3.3: Add ExCoveralls

**Task:** Configure test coverage reporting  
**Objective:** Track code coverage across domains  
**Output:** `mix.exs` updated, `.coveralls.json` created  
**Note:**  
- Target: 80% coverage minimum for MVP
- Dependency: `{:excoveralls, "~> 0.18", only: :test}`

---

#### Sub-Phase 1.3.4: Configure GitHub Actions CI

**Task:** Create `.github/workflows/ci.yml` for automated testing  
**Objective:** Ensure all PRs pass tests, Credo, Dialyzer before merge  
**Output:** `.github/workflows/ci.yml`  
**Note:**  
- Run on `push` to `main` and all PRs
- Cache Mix deps and PLT files
- Steps: checkout → setup Elixir → deps.get → compile → credo → test → dialyzer

---

### Phase 1.4: Core Infrastructure Modules

#### Sub-Phase 1.4.1: Initialize ETS Tables for Hot Cache

**Task:** Create `lib/voelgoedevents/infrastructure/ets_registry.ex`  
**Objective:** Initialize per-node ETS tables for hot-path caching  
**Output:** `lib/voelgoedevents/infrastructure/ets_registry.ex`  
**Note:**  
- Tables: `:seat_holds_hot`, `:recent_scans`, `:pricing_cache`, `:rbac_cache`
- Start under `Voelgoedevents.Application` supervision tree
- Reference `/docs/architecture/03_caching_and_realtime.md` Section 3.1 (Hot Layer)

---

#### Sub-Phase 1.4.2: Configure Redis Connection Pool

**Task:** Set up Redix connection pool in `config/config.exs`  
**Objective:** Enable warm-layer caching and distributed state  
**Output:**  
- Updated `config/config.exs`
- `lib/voelgoedevents/infrastructure/redis.ex`  
**Note:**  
- Pool size: 10 connections
- Reference `/docs/architecture/03_caching_and_realtime.md` Section 3.2 (Warm Layer)

---

#### Sub-Phase 1.4.3: Initialize Phoenix PubSub

**Task:** Verify Phoenix.PubSub is configured in supervision tree  
**Objective:** Enable real-time event broadcasting for LiveView and analytics  
**Output:** Verified `lib/voelgoedevents/application.ex`  
**Note:**  
- **Status:** Should already exist in Phoenix 1.7 scaffold
- Name: `Voelgoedevents.PubSub`
- Adapter: `Phoenix.PubSub.PG2` (default)

---

#### Sub-Phase 1.4.4: Configure Oban Job Queue

**Task:** Add Oban to supervision tree and create queue configuration  
**Objective:** Enable background job processing for cleanup, emails, reports  
**Output:**  
- `lib/voelgoedevents/queues/oban_config.ex`
- Updated `lib/voelgoedevents/application.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_add_oban_jobs_table.exs`  
**Note:**  
- Use AshOban for Ash resource integration
- Queues: `:default`, `:mailers`, `:analytics`, `:cleanup`, `:webhooks`
- Reference `/docs/architecture/06_jobs_and_async.md`

---

### Phase 1.5: Distributed Lock Manager (DLM) Setup

#### Sub-Phase 1.5.1: Implement Redlock-Based DLM

**Task:** Create `lib/voelgoedevents/infrastructure/distributed_lock.ex`  
**Objective:** Prevent race conditions in seat holds, checkout, payment capture  
**Output:** `lib/voelgoedevents/infrastructure/distributed_lock.ex`  
**Note:**  
- Use Redis `SET key value NX EX seconds` pattern (simplified Redlock)
- Lock TTL: 10 seconds (must be short to prevent deadlocks)
- Implement `acquire/2` and `release/2` functions
- Use Lua script for safe release (only lock holder can release)
- Reference `/docs/architecture/01_foundation.md` Section on DLM

---

## ✅ [DONE] PHASE 2: Tenancy, Accounts & RBAC

**Goal:** Multi-tenant foundation with user authentication and role-based access control  
**Duration:** 2 weeks  
**Deliverables:** Organization, User, Membership, Role resources; AshAuthentication integration  
**Dependencies:** Completes Phase 1

---

### Phase 2.1: Organization Resource

#### Sub-Phase 2.1.1: Create Organization Resource

**Task:** Define Organization resource with name, slug, status, settings  
**Objective:** Establish tenant boundary for all domain resources  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/organization.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_organizations.exs`  
**Note:**  
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C)
- Reference `/docs/domain/tenancy_accounts.md` for complete specification
- Enforce multi-tenancy per Appendix B (all resources must include `organization_id`)
- Attributes: `id`, `name`, `slug` (unique), `status` (`:active`, `:suspended`, `:archived`), `settings` (map), timestamps
- Actions: `create`, `read`, `update`, `archive`
- Policies: Only super admins can create organizations (MVP: single org only)

---

### Phase 2.2: User Resource

#### Sub-Phase 2.2.1: Create User Resource with AshAuthentication

**Task:** Define User resource with email, hashed_password, integration with AshAuthentication  
**Objective:** Enable user login, session management, and JWT generation  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/user.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_users.exs`  
**Note:**  
- Use `AshAuthentication.Strategy.Password` for email/password auth
- Tokens stored in `user_tokens` table (AshAuthentication convention)
- Reference `/docs/domain/tenancy_accounts.md`
- Apply policies: users belong to organizations, never cross-org access
- Attributes: `id`, `email` (CiString, unique), `hashed_password` (sensitive), `confirmed_at`, `first_name`, `last_name`, `status`, timestamps
- Relationships: `has_many :memberships`, `many_to_many :organizations` (through Membership)

---

### Phase 2.3: Membership & Role Resources

#### Sub-Phase 2.3.1: Create Role Resource

**Task:** Define Role resource with predefined roles  
**Objective:** Support RBAC for multi-tenant access control  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/role.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_roles.exs`  
**Note:**  
- Roles: `:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only`
- Roles are system-defined (not user-created in MVP)
- Seed roles in `priv/repo/seeds.exs`
- Attributes: `id`, `name` (atom), `display_name`, `permissions` (list of atoms)

---

#### Sub-Phase 2.3.2: Create Membership Resource

**Task:** Define Membership (join table) linking User, Organization, Role  
**Objective:** Enforce per-organization RBAC  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/membership.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_memberships.exs`  
**Note:**  
- Unique constraint: `(user_id, organization_id)` — one role per org
- Cache in ETS for fast RBAC checks (reference Appendix C)
- Attributes: `id`, `user_id`, `organization_id`, `role_id`, `status` (`:active`, `:inactive`), `invited_at`, `joined_at`
- Relationships: `belongs_to :user`, `belongs_to :organization`, `belongs_to :role`
- Policies: Organization owners can invite/remove members

---

### Phase 2.4: Multi-Tenancy Policies

#### Sub-Phase 2.4.1: Create Shared Tenancy Policies

**Task:** Implement reusable policy checks  
**Objective:** Enforce organization scoping on all resources  
**Output:** `lib/voelgoedevents/ash/policies/tenant_policies.ex`  
**Note:**  
- All persistent resources MUST include `organization_id`
- All queries MUST filter by `organization_id` from actor context
- Reference `/docs/architecture/02_multi_tenancy.md`
- Enforce rules from Appendix B (6 Critical Rules)

---

### Phase 2.5: Session & Auth Flow

#### Sub-Phase 2.5.1: Create CurrentUserPlug

**Task:** Implement plug to load current user from session/JWT  
**Objective:** Populate `conn.assigns.current_user` and `conn.assigns.organization_id` for all authenticated requests  
**Output:** `lib/voelgoedevents_web/plugs/current_user_plug.ex`  
**Note:**  
- Extract `user_id` from session
- Load `User` with `memberships` preloaded
- Set `conn.assigns.organization_id` from active membership
- **Never trust `organization_id` from request params** (Appendix B, Rule 1)

---

## 🎟️ PHASE 3: Core Events & GA Ticketing

**Goal:** Implement Event, Venue, TicketType resources and basic inventory-based ticketing  
**Duration:** 2 weeks  
**Deliverables:** Event CRUD, GA ticket sales, basic seat hold/release workflows  
**Dependencies:** Completes Phase 2

---

### Phase 3.1: Venue & Gate Resources

#### Sub-Phase 3.1.1: Create Venue Resource

**Task:** Define Venue resource with name, address, capacity, timezone  
**Objective:** Establish physical location context for events  
**Output:**  
- `lib/voelgoedevents/ash/resources/venues/venue.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_venues.exs`  
**Note:**  
- Include `organization_id` for multi-tenancy (Appendix B enforcement)
- Apply policies: only org members can create venues
- Reference `/docs/domain/events_venues.md`
- Attributes: `id`, `organization_id`, `name`, `address`, `city`, `country`, `postal_code`, `timezone`, `capacity`, `settings`, `status`, timestamps

---

#### Sub-Phase 3.1.2: Create Gate Resource

**Task:** Define Gate resource linking to Venue with access control settings  
**Objective:** Support multi-gate scanning and occupancy tracking  
**Output:**  
- `lib/voelgoedevents/ash/resources/venues/gate.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_gates.exs`  
**Note:**  
- Each gate has unique code (e.g., "GATE_A", "MAIN_ENTRANCE")
- Used by scanning devices for entry validation
- Attributes: `id`, `venue_id`, `organization_id`, `gate_code`, `name`, `status` (`:open`, `:closed`), `capacity`, `settings`, timestamps

---

### Phase 3.2: Event Resource

#### Sub-Phase 3.2.1: Create Event Resource with State Machine

**Task:** Define Event resource with status state machine  
**Objective:** Enable event lifecycle management and publishing workflow  
**Output:**  
- `lib/voelgoedevents/ash/resources/events/event.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_events.exs`  
**Note:**  
- Use `AshStateMachine` extension for status transitions
- States: `:draft`, `:published`, `:live`, `:ended`, `:archived`
- Transitions: `:draft` → `:published` (admin), `:published` → `:live` (auto/manual), `:live` → `:ended` (auto/manual), `:ended` → `:archived` (admin)
- Apply policies: only org admins can publish events
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache published events in Redis (TTL: 1 hour)
- Reference `/docs/domain/events_venues.md`
- Attributes: `id`, `organization_id`, `venue_id`, `name`, `description`, `status`, `start_time`, `end_time`, `sale_start`, `sale_end`, `capacity`, `settings`, timestamps

---

### Phase 3.3: TicketType Resource (GA)

#### Sub-Phase 3.3.1: Create TicketType Resource

**Task:** Define TicketType resource for GA (General Admission) tickets  
**Objective:** Support inventory-based ticket sales with pricing and availability  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_ticket_types.exs`  
**Note:**  
- GA only in Phase 3 (seated ticketing in Phase 8)
- Inventory tracking: `total_quantity`, `sold_count`, `held_count`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — ETS + Redis counters
- Reference `/docs/domain/ticketing_pricing.md`
- Attributes: `id`, `event_id`, `organization_id`, `name`, `description`, `price` (Decimal), `currency` (`:ZAR`), `total_quantity`, `sold_count` (default: 0), `held_count` (default: 0), `sale_start`, `sale_end`, `status` (`:available`, `:sold_out`, `:hidden`), `settings`, timestamps
- Calculations: `available_quantity = total_quantity - sold_count - held_count`

---

### Phase 3.4: Seat Hold & Release Workflows

#### Sub-Phase 3.4.1: Create SeatHold Resource (for GA)

**Task:** Define SeatHold resource to track temporary reservations (5-minute TTL)  
**Objective:** Prevent overselling during checkout process  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/seat_hold.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_seat_holds.exs`  
**Note:**  
- TTL: 5 minutes (300 seconds)
- Status: `:active`, `:expired`, `:converted`, `:cancelled`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C):
  - Store in Redis ZSET for expiry tracking (key: `voelgoed:org:{org_id}:event:{event_id}:seat_holds`)
  - Mirror in ETS for per-node fast lookup
- Reference `/docs/workflows/reserve_seat.md` for full workflow specification
- Attributes: `id`, `ticket_type_id`, `event_id`, `user_id`, `organization_id`, `quantity`, `status`, `held_until`, `source` (`:web`, `:scanner`), `notes`, timestamps

---

#### Sub-Phase 3.4.2: Implement Reserve Workflow (GA)

**Task:** Create workflow to hold GA tickets with optimistic lock and cache population  
**Objective:** Atomic hold creation with Redis/ETS sync  
**Output:** `lib/voelgoedevents/workflows/ticketing/reserve_ga_tickets.ex`  
**Note:**  
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — do NOT re-describe caching logic
- Use DLM for critical section: `"hold:ticket_type:#{ticket_type_id}"`
- Reference `/docs/workflows/reserve_seat.md` for full specification
- Validate available quantity (optimistic lock on `TicketType.version`)
- Schedule Oban cleanup job (5 min TTL)
- Broadcast PubSub occupancy update

---

#### Sub-Phase 3.4.3: Implement Release Workflow (GA)

**Task:** Create workflow to release expired or cancelled holds  
**Objective:** Restore inventory and clean up caches  
**Output:** `lib/voelgoedevents/workflows/ticketing/release_ga_tickets.ex`  
**Note:**  
- Triggered by Oban job at `held_until + 10s`
- Decrement `TicketType.held_count`
- Clear Redis + ETS entries (Appendix C write-through pattern)
- Reference `/docs/workflows/release_seat.md` for full specification

---

### Phase 3.5: Basic Checkout Flow (Simplified)

#### Sub-Phase 3.5.1: Create Checkout Session Workflow (Stub)

**Task:** Create minimal checkout workflow for Phase 3 (no payment yet)  
**Objective:** Convert holds to "reserved" state (payment in Phase 4)  
**Output:** `lib/voelgoedevents/workflows/checkout/start_checkout.ex`  
**Note:**  
- Phase 3: Validates holds, creates placeholder order
- Phase 4: Adds payment integration
- Reference `/docs/workflows/start_checkout.md` for full specification

---

## 💳 PHASE 4: Orders, Payments & Ticket Issuance

**Goal:** Full payment processing, order management, QR ticket generation  
**Duration:** 2.5 weeks  
**Deliverables:** Transaction, Order, Ticket resources; payment webhooks; PDF generation  
**Dependencies:** Completes Phase 3

---

### Phase 4.1: Transaction Resource

#### Sub-Phase 4.1.1: Create Transaction Resource with State Machine

**Task:** Define Transaction resource tracking payment lifecycle  
**Objective:** Enable atomic payment state management  
**Output:**  
- `lib/voelgoedevents/ash/resources/payments/transaction.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_transactions.exs`  
**Note:**  
- Use `AshStateMachine` for status transitions
- States: `:initiated`, `:pending`, `:succeeded`, `:failed`, `:refunded`
- Store `provider` (`:paystack`, `:yoco`) and `provider_transaction_id`
- Apply policies: users can only view their own transactions
- Reference `/docs/domain/payments_ledger.md`
- Attributes: `id`, `organization_id`, `user_id`, `order_id`, `provider`, `provider_transaction_id`, `amount`, `currency`, `status`, `metadata`, timestamps

---

### Phase 4.2: Order Resource

#### Sub-Phase 4.2.1: Create Order Resource

**Task:** Define Order resource linking user, event, tickets, transaction  
**Objective:** Group tickets into a single purchase with fulfillment status  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/order.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_orders.exs`  
**Note:**  
- Status: `:pending`, `:paid`, `:fulfilled`, `:cancelled`, `:refunded`
- Apply policies: users can view their own orders
- Attributes: `id`, `organization_id`, `user_id`, `event_id`, `status`, `total_amount`, `currency`, `payment_status`, `fulfillment_status`, `notes`, timestamps
- Relationships: `has_many :tickets`, `has_one :transaction`

---

### Phase 4.3: Ticket Resource

#### Sub-Phase 4.3.1: Create Ticket Resource with State Machine

**Task:** Define Ticket resource (individual ticket instance) with QR code and status  
**Objective:** Enable ticket scanning and validation  
**Output:**  
- `lib/voelgoedevents/ash/resources/ticketing/ticket.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_tickets.exs`  
**Note:**  
- Use `AshStateMachine` for status transitions
- States: `:active`, `:scanned`, `:used`, `:voided`, `:refunded`
- Generate unique `ticket_code` (16-char base62, e.g., "3KQR-7F92-4M1X")
- QR payload: signed JWT with `{ticket_id, org_id, event_id, signature}`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache recently scanned tickets in ETS (5-min dedup window)
- Reference `/docs/workflows/process_scan.md` for QR validation specification
- Attributes: `id`, `order_id`, `ticket_type_id`, `event_id`, `organization_id`, `user_id`, `ticket_code` (unique), `qr_payload`, `status`, `scanned_at`, `last_gate_id`, `scan_count`, `seat_id` (nullable, for Phase 8), timestamps

---

### Phase 4.4: Complete Checkout Workflow

#### Sub-Phase 4.4.1: Implement Complete Checkout Workflow

**Task:** Create full checkout workflow from holds to paid tickets  
**Objective:** Atomic transaction handling with payment provider integration  
**Output:** `lib/voelgoedevents/workflows/checkout/complete_checkout.ex`  
**Note:**  
- Reference `/docs/workflows/complete_checkout.md` for full specification (do NOT duplicate steps)
- Workflow is transactional (all-or-nothing)
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) for cache invalidation
- Integrates with Phase 6 ledger entry creation
- Steps (high-level):
  1. Validate active holds (not expired)
  2. Initiate payment with provider (Paystack/Yoco)
  3. Create Order + Transaction records
  4. On success: convert holds → tickets, update inventory, create ledger entries
  5. On failure: release holds, cancel order

---

### Phase 4.5: Payment Provider Integration

#### Sub-Phase 4.5.1: Create Payment Provider Abstraction

**Task:** Create payment provider interface and Paystack/Yoco implementations  
**Objective:** Support multiple payment providers with unified interface  
**Output:**  
- `lib/voelgoedevents/payments/provider.ex` (behavior)
- `lib/voelgoedevents/payments/providers/paystack.ex`
- `lib/voelgoedevents/payments/providers/yoco.ex`  
**Note:**  
- Behavior defines: `initiate_payment/2`, `verify_payment/2`, `refund_payment/2`
- Store provider credentials in config (environment variables)
- Handle webhooks for payment confirmation
- Reference `/docs/domain/payments_ledger.md` for provider integration patterns

---

### Phase 4.6: QR Code & PDF Generation

#### Sub-Phase 4.6.1: Implement QR Code Generation

**Task:** Generate signed QR codes for tickets  
**Objective:** Enable secure, offline-verifiable ticket validation  
**Output:** `lib/voelgoedevents/ticketing/qr_generator.ex`  
**Note:**  
- QR payload: signed JWT with `{ticket_id, org_id, event_id, issued_at, signature}`
- Use Phoenix.Token for signing (secret key from config)
- TTL: Event end time + 7 days
- Reference `/docs/workflows/process_scan.md` for QR validation specification

---

#### Sub-Phase 4.6.2: Implement PDF Ticket Generation

**Task:** Generate PDF tickets with QR codes using Oban background job  
**Objective:** Provide downloadable, printable tickets to customers  
**Output:**  
- `lib/voelgoedevents/queues/worker_generate_pdf.ex`
- `lib/voelgoedevents/ticketing/pdf_generator.ex`  
**Note:**  
- Use `pdf_generator` or `wkhtmltopdf` for PDF rendering
- Store PDFs in S3-compatible storage or local filesystem
- Queue PDF generation in Oban `:default` queue
- Reference `/docs/architecture/06_jobs_and_async.md` for Oban patterns

---

## 📱 PHASE 5: Scanning Backend & Integration

**Goal:** Scanning API endpoints, device authentication, online validation  
**Duration:** 2 weeks  
**Deliverables:** Scan, ScanSession, Device resources; process_scan workflow  
**Dependencies:** Completes Phase 4

---

### Phase 5.1: Device & ScanSession Resources

#### Sub-Phase 5.1.1: Create Device Resource

**Task:** Define Device resource for scanner device authentication and tracking  
**Objective:** Enable secure device registration and session management  
**Output:**  
- `lib/voelgoedevents/ash/resources/scanning/device.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_devices.exs`  
**Note:**  
- Each device has unique `device_id` and API token
- Attributes: `id`, `organization_id`, `device_id` (unique), `name`, `device_type` (`:scanner`, `:mobile`), `status` (`:active`, `:inactive`), `last_seen_at`, `settings`, timestamps
- Policies: Organization admins can register/revoke devices

---

#### Sub-Phase 5.1.2: Create ScanSession Resource

**Task:** Define ScanSession resource linking device to event/gate for shift tracking  
**Objective:** Track which devices are scanning at which gates  
**Output:**  
- `lib/voelgoedevents/ash/resources/scanning/scan_session.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_scan_sessions.exs`  
**Note:**  
- Attributes: `id`, `organization_id`, `device_id`, `event_id`, `gate_id`, `status` (`:active`, `:ended`), `started_at`, `ended_at`, `scan_count`
- One active session per device at a time

---

### Phase 5.2: Scan Resource

#### Sub-Phase 5.2.1: Create Scan Resource

**Task:** Define Scan resource to record each scan attempt  
**Objective:** Enable audit trail and deduplication  
**Output:**  
- `lib/voelgoedevents/ash/resources/scanning/scan.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_scans.exs`  
**Note:**  
- Attributes: `id`, `organization_id`, `ticket_id`, `event_id`, `device_id`, `gate_id`, `scan_session_id`, `result` (`:valid`, `:duplicate`, `:invalid_token`, `:wrong_event`, `:wrong_gate`), `scanned_at`, `metadata`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache recent scans in ETS for 5-min dedup window

---

### Phase 5.3: Process Scan Workflow

#### Sub-Phase 5.3.1: Implement Process Scan Workflow (Online)

**Task:** Create workflow for online scan validation  
**Objective:** Validate ticket QR codes with deduplication and status updates  
**Output:** `lib/voelgoedevents/workflows/scanning/process_scan.ex`  
**Note:**  
- Reference `/docs/workflows/process_scan.md` for full specification (do NOT duplicate steps)
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C):
  - Three-tier dedup: ETS (1ms) → Redis (10ms) → DB (50ms)
- Workflow steps (high-level):
  1. Authenticate scanner device (bearer token)
  2. Parse ticket code (16-char base62)
  3. Check ETS cache for recent scan (5-min window)
  4. Verify QR signature (Phoenix.Token)
  5. Fetch ticket from DB (validate status, event, gate)
  6. Update ticket status (`:active` → `:scanned`)
  7. Create Scan record
  8. Populate ETS + Redis caches
  9. Broadcast PubSub occupancy update
  10. Return result (`:valid`, `:duplicate`, `:invalid_token`, etc.)

---

### Phase 5.4: Scanning API Endpoints

#### Sub-Phase 5.4.1: Create Scanning API Controller

**Task:** Implement JSON API endpoints for scanner devices  
**Objective:** Enable RESTful communication between scanner apps and backend  
**Output:** `lib/voelgoedevents_web/controllers/scanning/scan_controller.ex`  
**Note:**  
- Endpoints:
  - `POST /api/v1/scanning/sessions` — Start scan session
  - `POST /api/v1/scanning/scan` — Process single scan
  - `GET /api/v1/scanning/sessions/:id` — Get session details
  - `PUT /api/v1/scanning/sessions/:id/end` — End session
- Authenticate using device bearer tokens
- Reference `/docs/coding_style/phoenix_liveview.md` for controller conventions

---

## 💰 PHASE 6: Full Financial Ledger & Settlement Engine

**Goal:** Double-entry accounting, settlement calculations, financial reporting  
**Duration:** 2.5 weeks  
**Deliverables:** LedgerAccount, JournalEntry, Settlement resources; accounting workflows; FunnelSnapshot storage  
**Dependencies:** Completes Phase 4

---

### Phase 6.1: LedgerAccount Resource

#### Sub-Phase 6.1.1: Create LedgerAccount Resource

**Task:** Define LedgerAccount resource for double-entry bookkeeping  
**Objective:** Enable chart of accounts for financial integrity  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/ledger_account.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_ledger_accounts.exs`  
**Note:**  
- Account types: `:asset`, `:liability`, `:equity`, `:revenue`, `:expense`
- System accounts (seeded): `cash`, `accounts_receivable`, `ticket_revenue`, `platform_fees`, `organizer_payable`
- Reference `/docs/domain/payments_ledger.md` for chart of accounts
- Attributes: `id`, `organization_id`, `account_code` (unique per org), `name`, `account_type`, `parent_id` (nullable), `balance` (Decimal), `currency`, `status`, timestamps

---

### Phase 6.2: JournalEntry Resource

#### Sub-Phase 6.2.1: Create JournalEntry Resource

**Task:** Define JournalEntry resource for immutable transaction records  
**Objective:** Enable audit-grade financial tracking  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/journal_entry.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_journal_entries.exs`  
**Note:**  
- Each entry has paired debit/credit records (sum to zero)
- Attributes: `id`, `organization_id`, `entry_date`, `description`, `reference_id` (transaction_id, order_id, etc.), `reference_type`, `total_amount`, `status` (`:pending`, `:posted`, `:voided`), timestamps
- Relationships: `has_many :line_items, JournalEntryLineItem`

---

#### Sub-Phase 6.2.2: Create JournalEntryLineItem Resource

**Task:** Define JournalEntryLineItem (individual debit/credit line)  
**Objective:** Support double-entry bookkeeping integrity  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/journal_entry_line_item.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_journal_entry_line_items.exs`  
**Note:**  
- Attributes: `id`, `journal_entry_id`, `ledger_account_id`, `debit_amount`, `credit_amount`, `description`
- Constraint: `debit_amount` and `credit_amount` mutually exclusive (only one can be non-zero)
- Validation: Sum of debits = Sum of credits per entry

---

#### Sub-Phase 6.2.3: Create FunnelSnapshot Resource with Storage Strategy

**Task:** Define FunnelSnapshot resource for aggregated analytics with explicit caching strategy  
**Objective:** Store conversion funnel data with predictable performance characteristics  
**Output:**  
- `lib/voelgoedevents/ash/resources/analytics/funnel_snapshot.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_funnel_snapshots.exs`  
**Note:**  
- **Storage Strategy** (v7.1 clarification):
  - **Postgres (Primary):** Authoritative, durable storage for all snapshots
  - **Redis (Secondary):** Write-through cache for recent snapshots only
  - **TTL:** Redis snapshots expire after 24 hours (EXPIRE 86400)
  - **Write Pattern:** Write to Postgres first (authoritative), then populate Redis asynchronously
  - **Read Pattern:** Check Redis first (hot snapshots), fallback to Postgres (cold/historical snapshots)
- Reference `/docs/workflows/funnel_builder.md` for snapshot generation logic
- Reference Appendix C Section "Snapshot Caching Pattern" for implementation details
- Attributes: `id`, `organization_id`, `event_id`, `campaign_id` (nullable), `snapshot_date`, `visitor_count`, `checkout_started_count`, `checkout_completed_count`, `revenue_total`, `metadata`, timestamps
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) with snapshot-specific TTL

---

### Phase 6.3: Accounting Workflows

#### Sub-Phase 6.3.1: Implement Record Sale Workflow

**Task:** Create workflow to generate journal entries on ticket sale  
**Objective:** Automatically record revenue and payables  
**Output:** `lib/voelgoedevents/workflows/finance/record_sale.ex`  
**Note:**  
- Reference `/docs/domain/payments_ledger.md` for accounting logic
- Triggered by `complete_checkout` workflow (Phase 4)
- Example entries:
  - Debit: `cash` (total amount)
  - Credit: `ticket_revenue` (ticket price * quantity)
  - Credit: `platform_fees` (platform fee)
  - Credit: `organizer_payable` (net to organizer)
- All entries are atomic (transaction boundary)

---

#### Sub-Phase 6.3.2: Implement Record Refund Workflow

**Task:** Create workflow to reverse journal entries on refund  
**Objective:** Maintain accounting integrity during refunds  
**Output:** `lib/voelgoedevents/workflows/finance/record_refund.ex`  
**Note:**  
- Reference `/docs/domain/payments_ledger.md` for refund accounting
- Triggered by refund action (Phase 4)
- Reverse original entries (debit/credit swap)
- Update ledger account balances

---

### Phase 6.4: Settlement Resource

#### Sub-Phase 6.4.1: Create Settlement Resource

**Task:** Define Settlement resource for organizer payouts  
**Objective:** Track scheduled and completed payouts to organizers  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/settlement.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_settlements.exs`  
**Note:**  
- Attributes: `id`, `organization_id`, `event_id` (nullable), `settlement_date`, `total_amount`, `currency`, `status` (`:pending`, `:processing`, `:completed`, `:failed`), `metadata`, timestamps
- Relationships: `has_many :journal_entries` (payout entries)

---

#### Sub-Phase 6.4.2: Implement Calculate Settlement Workflow

**Task:** Create workflow to calculate net organizer payout  
**Objective:** Aggregate sales, fees, refunds into settlement amount  
**Output:** `lib/voelgoedevents/workflows/finance/calculate_settlement.ex`  
**Note:**  
- Reference `/docs/domain/payments_ledger.md` for settlement logic
- Query `organizer_payable` ledger account balance
- Apply settlement schedule (weekly, event-based, etc.)
- Generate Settlement record

---

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

## 💺 PHASE 8: Seating Engine Domain Layer

**Goal:** Seating resources, seat allocation/reservation workflows  
**Duration:** 2.5 weeks  
**Deliverables:** Layout, Section, Block, Seat resources; seated ticketing workflows  
**Dependencies:** Completes Phase 3

---

### Phase 8.1: Seating Layout & Section Resources

#### Sub-Phase 8.1.1: Create Layout Resource

**Task:** Define Layout resource representing venue seating configuration  
**Objective:** Enable reusable seating plans across events  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/layout.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_layouts.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `organization_id`, `venue_id`, `name`, `description`, `total_capacity`, `status` (`:draft`, `:active`, `:archived`), `metadata`, timestamps

---

#### Sub-Phase 8.1.2: Create Section Resource

**Task:** Define Section resource (e.g., "Orchestra", "Balcony")  
**Objective:** Group seats into logical zones with pricing tiers  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/section.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_sections.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `layout_id`, `organization_id`, `name`, `section_type` (`:seated`, `:standing`), `capacity`, `price_tier`, `metadata`, timestamps

---

### Phase 8.2: Block & Seat Resources

#### Sub-Phase 8.2.1: Create Block Resource

**Task:** Define Block resource (e.g., "Row A", "Block 101")  
**Objective:** Further subdivide sections into manageable units  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/block.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_blocks.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `section_id`, `organization_id`, `name`, `capacity`, `metadata`, timestamps

---

#### Sub-Phase 8.2.2: Create Seat Resource

**Task:** Define Seat resource (individual seat with row/number)  
**Objective:** Enable per-seat inventory and allocation  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/seat.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_seats.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `block_id`, `organization_id`, `row`, `number`, `status` (`:available`, `:held`, `:sold`, `:blocked`), `metadata`, timestamps
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache seat status in Redis bitmaps

---

### Phase 8.3: Seated Ticketing Workflows

#### Sub-Phase 8.3.1: Extend Reserve Workflow for Seated Tickets

**Task:** Update reserve workflow to handle specific seat allocation  
**Objective:** Support per-seat holds with Redis bitmap tracking  
**Output:** Updated `lib/voelgoedevents/workflows/ticketing/reserve_seat.ex`  
**Note:**  
- Reference `/docs/workflows/reserve_seat.md` for full specification
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — use Redis SETBIT for seat occupancy
- Use DLM for critical section: `"hold:seat:#{seat_id}"`
- Validate seat is `:available` before hold

---

#### Sub-Phase 8.3.2: Extend Release Workflow for Seated Tickets

**Task:** Update release workflow to free specific seats  
**Objective:** Clear seat holds and restore availability  
**Output:** Updated `lib/voelgoedevents/workflows/ticketing/release_seat.ex`  
**Note:**  
- Reference `/docs/workflows/release_seat.md` for full specification
- Clear Redis bitmap bits for released seats
- Update Seat status: `:held` → `:available`

---

## 🎨 PHASE 9: Seating Builder LiveView UI

**Goal:** Visual seating plan editor for organizers  
**Duration:** 2 weeks  
**Deliverables:** Manual admin CRUD interface for seating layouts (Figma import deferred to future enhancement)  
**Dependencies:** Completes Phase 8  
**Note (v7.1):** Removed ambiguous "Create Venue from Figma Map" sub-phase; replaced with explicit manual admin interface

---

### Phase 9.1: Seating Admin CRUD Interface

#### Sub-Phase 9.1.1: Create Seating Layout Admin LiveView

**Task:** Build LiveView page for creating/editing seating layouts manually  
**Objective:** Enable visual layout design with manual section/block/seat creation  
**Output:**  
- `lib/voelgoedevents_web/live/seating/layout_admin_live.ex`
- `lib/voelgoedevents_web/live/seating/layout_admin_live.html.heex`  
**Note:**  
- Reference `/docs/coding_style/phoenix_liveview.md` for LiveView conventions
- Reference `/docs/coding_style/heex.md` for template best practices
- Features:
  - Create/edit/delete layouts
  - Add sections (name, capacity, pricing tier)
  - Add blocks (name, capacity, row/column configuration)
  - Batch-generate seats (e.g., "Generate 20 seats in Row A")
- **NO FIGMA INTEGRATION IN MVP** — defer Figma JSON parsing to Phase 9+ enhancement
- Use Phoenix LiveView Streams for efficient updates
- Associated JavaScript hooks for basic drag-and-drop (optional, not required for MVP)

---

#### Sub-Phase 9.1.2: Create Seat Grid Visualization Component

**Task:** Build reusable LiveView component to render seat grid  
**Objective:** Visual representation of seating layout for selection/management  
**Output:**  
- `lib/voelgoedevents_web/live/seating/components/seat_grid.ex`
- `lib/voelgoedevents_web/live/seating/components/seat_grid.html.heex`  
**Note:**  
- Component accepts: layout_id, selected_seats (list)
- Renders: sections, blocks, seats with status colors (available, held, sold, blocked)
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — read seat status from ETS/Redis
- Use SVG or CSS Grid for visual layout

---

## 🔗 PHASE 10: Integrations, Webhooks & Public API

**Goal:** Outbound webhooks, public REST API, third-party integrations  
**Duration:** 2 weeks  
**Deliverables:** Webhook delivery system, API endpoints, integration framework  
**Dependencies:** Completes Phase 7

---

### Phase 10.1: Webhook System

#### Sub-Phase 10.1.1: Create WebhookEndpoint Resource

**Task:** Define WebhookEndpoint resource for registering webhook URLs  
**Objective:** Enable customers to subscribe to event notifications  
**Output:**  
- `lib/voelgoedevents/ash/resources/integrations/webhook_endpoint.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_webhook_endpoints.exs`  
**Note:**  
- Reference `/docs/domain/integrations.md` (if exists, otherwise document in Phase 10)
- Attributes: `id`, `organization_id`, `url`, `secret`, `events` (list of subscribed event types), `status` (`:active`, `:inactive`), timestamps

---

#### Sub-Phase 10.1.2: Create WebhookEvent Resource

**Task:** Define WebhookEvent resource for tracking delivery attempts  
**Objective:** Enable retry mechanism and delivery audit  
**Output:**  
- `lib/voelgoedevents/ash/resources/integrations/webhook_event.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_webhook_events.exs`  
**Note:**  
- Attributes: `id`, `webhook_endpoint_id`, `organization_id`, `event_type`, `payload`, `status` (`:pending`, `:delivered`, `:failed`), `attempts`, `last_attempt_at`, timestamps

---

#### Sub-Phase 10.1.3: Implement Webhook Delivery Worker

**Task:** Create Oban worker for webhook delivery with retries  
**Objective:** Reliable, asynchronous webhook dispatch  
**Output:** `lib/voelgoedevents/queues/worker_webhook_delivery.ex`  
**Note:**  
- Queue webhook delivery in Oban `:webhooks` queue
- Retry strategy: exponential backoff (3 attempts)
- Sign requests with HMAC-SHA256 using endpoint secret
- Reference `/docs/architecture/06_jobs_and_async.md` for Oban patterns

---

### Phase 10.2: Public REST API

#### Sub-Phase 10.2.1: Create API Authentication System

**Task:** Implement API key authentication for public API  
**Objective:** Secure programmatic access to VoelgoedEvents data  
**Output:**  
- `lib/voelgoedevents/ash/resources/integrations/api_key.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_api_keys.exs`
- `lib/voelgoedevents_web/plugs/api_auth_plug.ex`  
**Note:**  
- Generate API keys with prefix (e.g., `vge_live_...`)
- Store hashed keys in DB (never plaintext)
- Authenticate using `Authorization: Bearer <api_key>` header
- Rate limit per API key (Redis-based, reference Appendix C)

---

#### Sub-Phase 10.2.2: Create Public API Endpoints

**Task:** Implement JSON API endpoints for events, orders, tickets  
**Objective:** Enable third-party integrations and custom frontends  
**Output:**  
- `lib/voelgoedevents_web/controllers/api/v1/event_controller.ex`
- `lib/voelgoedevents_web/controllers/api/v1/order_controller.ex`
- `lib/voelgoedevents_web/controllers/api/v1/ticket_controller.ex`  
**Note:**  
- Reference `/docs/coding_style/phoenix_liveview.md` for controller conventions
- Endpoints:
  - `GET /api/v1/events` — List events
  - `GET /api/v1/events/:id` — Get event details
  - `GET /api/v1/orders` — List orders
  - `POST /api/v1/orders` — Create order (checkout)
  - `GET /api/v1/tickets/:id` — Get ticket details
- Enforce multi-tenancy per Appendix B
- Return JSON:API format responses

---

## 🔒 PHASE 11: Hardening, Security & Performance

**Goal:** Production readiness, load testing, security audits, performance optimization  
**Duration:** 2 weeks  
**Deliverables:** Load test results, security fixes, performance improvements  
**Dependencies:** Completes Phase 7 (MVP complete)

---

### Phase 11.1: Security Hardening

#### Sub-Phase 11.1.1: Implement Rate Limiting

**Task:** Add Redis-based rate limiting to all public endpoints  
**Objective:** Prevent abuse and DDoS attacks  
**Output:** `lib/voelgoedevents/infrastructure/rate_limiter.ex`  
**Note:**  
- Use Redis counters with sliding window
- Limits: 100 requests/minute per IP for public endpoints, 1000 requests/minute per API key
- Return `429 Too Many Requests` when exceeded
- Reference Appendix C for Redis counter pattern

---

#### Sub-Phase 11.1.2: Add Content Security Policy

**Task:** Configure CSP headers in Phoenix endpoint  
**Objective:** Prevent XSS attacks  
**Output:** Updated `lib/voelgoedevents_web/endpoint.ex`  
**Note:**  
- Use `plug :put_secure_browser_headers` with strict CSP
- Allow inline scripts only for LiveView
- Reference Phoenix security best practices

---

### Phase 11.2: Performance Optimization

#### Sub-Phase 11.2.1: Add Database Indexes

**Task:** Audit all queries and add missing indexes  
**Objective:** Ensure sub-100ms query performance  
**Output:** New migration with index additions  
**Note:**  
- Index all foreign keys
- Index `organization_id` on all tenant-scoped resources
- Composite indexes for common query patterns (e.g., `event_id, status` on Tickets)

---

#### Sub-Phase 11.2.2: Optimize Cache TTLs

**Task:** Review and tune cache expiration times  
**Objective:** Balance freshness vs performance  
**Output:** Updated cache TTL configurations  
**Note:**  
- Reference Appendix C for caching model
- Hot cache (ETS): 1–5 minutes
- Warm cache (Redis): 5–60 minutes
- Invalidate on write (write-through pattern)

---

### Phase 11.3: Load Testing

#### Sub-Phase 11.3.1: Conduct Load Testing

**Task:** Simulate high-concurrency scenarios (flash sales, scanning spikes)  
**Objective:** Validate performance under load  
**Output:** Load test report with results and recommendations  
**Note:**  
- Use `k6` or `Tsung` for load testing
- Test scenarios:
  - 1000 concurrent checkout requests
  - 500 scans/second across 10 gates
  - 10,000 concurrent event page views
- Target: p95 latency < 500ms, p99 < 1s

---

_[Phases 12-21 continue with same structure as v7.0, unchanged]_

---

## 📚 APPENDIX A: Technical Specifications Reference

_[Unchanged from v7.0 — complete mandatory load order and coverage tables]_

---

## 📚 APPENDIX B: Multi-Tenancy Security Deep Dive

_[Unchanged from v7.0 — 6 critical rules, enforcement checklist, code examples]_

---

## 📚 APPENDIX C: Performance & Scaling Strategy

### What "Apply Standard VoelgoedEvents Caching Model" Means

When a sub-phase says **"Apply Standard VoelgoedEvents Caching Model"**, it means:

#### Hot Layer (ETS)
- **Storage:** Per-node memory (`:ets` tables)
- **Latency:** Microseconds (μs)
- **TTL:** 1–5 minutes (auto-evict or manual cleanup)
- **Use Cases:** Seat status, recent scans (5-min dedup window), RBAC checks, pricing tiers

#### Warm Layer (Redis)
- **Storage:** Cluster-wide, durable (Redix connection pool)
- **Latency:** Milliseconds (1–10ms)
- **TTL:** 5–60 minutes (explicit expiration with `EXPIRE`)
- **Use Cases:** Seat bitmaps, seat holds (ZSET with expiry), occupancy counters, session data

#### Cold Layer (Postgres)
- **Storage:** Authoritative, durable (Ecto + Ash)
- **Latency:** 10–100ms (depends on indexes, query complexity)
- **TTL:** Infinite (permanent)
- **Use Cases:** All persistent resources, audit logs, financial records

### Lookup Pattern (Hot → Warm → Cold)

```elixir
def get_seat_status(org_id, event_id, seat_id) do
  # 1. Check ETS (hot layer)
  case :ets.lookup(:seat_holds_hot, {org_id, event_id, seat_id}) do
    [{_, status}] -> {:ok, status}  # ✅ Hit (μs latency)
    [] ->
      # 2. Check Redis (warm layer)
      case Redis.command!(["GET", "voelgoed:org:#{org_id}:seat:#{seat_id}:status"]) do
        nil ->
          # 3. Query DB (cold layer)
          case Ash.get(Seat, seat_id, organization_id: org_id) do
            {:ok, seat} ->
              status = seat.status
              # Populate ETS + Redis
              :ets.insert(:seat_holds_hot, {{org_id, event_id, seat_id}, status})
              Redis.command!(["SET", "voelgoed:org:#{org_id}:seat:#{seat_id}:status", status, "EX", 300])
              {:ok, status}
            {:error, reason} -> {:error, reason}
          end
        redis_status ->
          # Populate ETS
          :ets.insert(:seat_holds_hot, {{org_id, event_id, seat_id}, redis_status})
          {:ok, redis_status}
      end
  end
end
```

### Write Pattern (Write-Through to All Layers)

```elixir
def update_seat_status(org_id, event_id, seat_id, new_status) do
  # 1. Write to DB (authoritative)
  {:ok, seat} = Ash.update(Seat, seat_id, %{status: new_status}, organization_id: org_id)

  # 2. Write-through to Redis (warm layer)
  Redis.command!(["SET", "voelgoed:org:#{org_id}:seat:#{seat_id}:status", new_status, "EX", 300])

  # 3. Write-through to ETS (hot layer)
  :ets.insert(:seat_holds_hot, {{org_id, event_id, seat_id}, new_status})

  # 4. Broadcast PubSub event (non-blocking)
  Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, "occupancy:org:#{org_id}:event:#{event_id}", {:seat_status_changed, seat_id, new_status})

  # 5. Invalidate derived caches (e.g., occupancy snapshot)
  Redis.command!(["DEL", "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"])
  :ets.delete(:occupancy_cache, {org_id, event_id})

  {:ok, seat}
end
```

### Snapshot Caching Pattern (v7.1 Addition)

**Use Case:** FunnelSnapshot (Phase 6.2.3), EventMetrics (Phase 7.1b)

**Storage Strategy:**
- **Postgres (Primary):** Authoritative, durable storage for all snapshots
- **Redis (Secondary):** Write-through cache for recent snapshots only

**TTL Configuration:**
- **Redis TTL:** 24 hours (86400 seconds) for FunnelSnapshot
- **Redis TTL:** 30 seconds (30 seconds) for EventMetrics (real-time dashboard data)

**Write Pattern:**
```elixir
def create_funnel_snapshot(org_id, event_id, data) do
  # 1. Write to Postgres (authoritative)
  {:ok, snapshot} = Ash.create(FunnelSnapshot, data, organization_id: org_id)

  # 2. Write-through to Redis (asynchronous, non-blocking)
  Task.start(fn ->
    Redis.command!(["SET", "voelgoed:org:#{org_id}:event:#{event_id}:funnel:#{snapshot.snapshot_date}", 
                    Jason.encode!(snapshot), "EX", 86400])
  end)

  {:ok, snapshot}
end
```

**Read Pattern:**
```elixir
def get_funnel_snapshot(org_id, event_id, date) do
  # 1. Check Redis (hot path)
  case Redis.command!(["GET", "voelgoed:org:#{org_id}:event:#{event_id}:funnel:#{date}"]) do
    nil ->
      # 2. Query Postgres (cold path)
      case Ash.read(FunnelSnapshot, filter: [organization_id: org_id, event_id: event_id, snapshot_date: date]) do
        {:ok, [snapshot]} ->
          # Populate Redis for future reads
          Redis.command!(["SET", "voelgoed:org:#{org_id}:event:#{event_id}:funnel:#{date}", 
                          Jason.encode!(snapshot), "EX", 86400])
          {:ok, snapshot}
        {:ok, []} -> {:error, :not_found}
      end
    redis_data ->
      # Deserialize from Redis
      {:ok, Jason.decode!(redis_data)}
  end
end
```

### Redis Structure Reference Table

| Use Case | Redis Structure | Key Pattern | TTL |
|----------|----------------|-------------|-----|
| Seat holds (expiry tracking) | ZSET | `voelgoed:org:{org_id}:event:{event_id}:seat_holds` | Score = expiry timestamp |
| Seat status | STRING | `voelgoed:org:{org_id}:seat:{seat_id}:status` | 5 minutes |
| Occupancy count | STRING (counter) | `voelgoed:org:{org_id}:event:{event_id}:occupancy` | 1 minute |
| Recent scans (dedup) | SET | `voelgoed:org:{org_id}:event:{event_id}:recent_scans` | 5 minutes |
| Session data | STRING (JSON) | `voelgoed:org:{org_id}:session:{session_id}` | 30 minutes |
| Pricing cache | STRING (JSON) | `voelgoed:org:{org_id}:pricing:{ticket_type_id}` | 60 minutes |
| **FunnelSnapshot** (v7.1) | STRING (JSON) | `voelgoed:org:{org_id}:event:{event_id}:funnel:{date}` | **24 hours** |
| **EventMetrics** (v7.1) | STRING (JSON) | `voelgoed:org:{org_id}:event:{event_id}:metrics` | **30 seconds** |

### PubSub Topic Reference Table

| Event Type | Topic Pattern | Payload Example |
|------------|--------------|-----------------|
| Seat status changed | `occupancy:org:{org_id}:event:{event_id}` | `{:seat_status_changed, seat_id, :sold}` |
| Scan occurred | `scans:org:{org_id}:event:{event_id}` | `{:scan_occurred, ticket_id, gate_id, :valid}` |
| Order completed | `orders:org:{org_id}` | `{:order_completed, order_id, total_amount}` |
| Payment succeeded | `payments:org:{org_id}` | `{:payment_succeeded, transaction_id}` |

### Performance Targets Table

| Metric | Target | Context |
|--------|--------|---------|
| Seat status lookup | < 1ms | Hot path (ETS hit) |
| Seat hold creation | < 50ms | Including DB write + cache population |
| Scan validation | < 150ms | Including QR verification + dedup check |
| Checkout completion | < 500ms | Including payment provider call |
| Event page load | < 200ms | LiveView mount + initial render |
| Admin dashboard update | < 100ms | PubSub broadcast latency |

### Caching Invalidation Rules

**When to invalidate caches:**

| Trigger Event | Caches to Invalidate | Invalidation Method |
|---------------|---------------------|---------------------|
| Ticket sold | Seat status (ETS + Redis), Occupancy count (Redis), Available inventory (Redis) | Delete keys |
| Seat hold expired | Seat status (ETS + Redis), Occupancy count (Redis), Available inventory (Redis) | Delete keys |
| Event updated | Event details (Redis), Published events list (Redis) | Delete keys |
| Pricing rule changed | Pricing cache (Redis + ETS) | Delete keys matching `pricing:{ticket_type_id}` |
| User role changed | RBAC cache (ETS) | Delete user-specific keys |
| **Snapshot created** (v7.1) | None (write-through only) | N/A |
| **Event metrics refreshed** (v7.1) | EventMetrics (ETS + Redis) | Delete + repopulate |

---

## ✅ ROADMAP COMPLETION CHECKLIST

_[Unchanged from v7.0 — MVP and Post-MVP completion criteria]_

---

## 🎉 CONCLUSION

This roadmap provides a **complete, canonical, TOON-aligned implementation path** for VoelgoedEvents from Phase 0 (agent setup) through Phase 21 (monetization).

**Version 7.1 Key Improvements:**

✅ **Phase 2.2 Clarification** — Removed ambiguous Figma parsing; replaced with explicit manual admin CRUD  
✅ **Phase 6.2 Snapshot Storage** — Added explicit TTL, write-through behavior, and Redis eviction constraints  
✅ **Phase 7 Reorganization** — Split into 7.1a (UI) and 7.1b (backend aggregation) for single-responsibility  
✅ **Appendix C Enhancement** — Added snapshot caching pattern with TTL specifications

**Key Success Factors:**

✅ **Agent-First Design** — Every sub-phase is an atomic TOON prompt  
✅ **DRY Enforcement** — All repeated patterns replaced with canonical references  
✅ **Multi-Tenancy by Default** — Appendix B enforced in every resource  
✅ **Performance by Design** — Appendix C applied to all hot paths  
✅ **Standard Ash Layout** — Zero custom folders, verified against INDEX.md  
✅ **Abstraction-Layered** — Clear separation between UI, domain logic, and infrastructure

**Next Steps:**

1. **Begin Phase 0** — Load all canonical documentation and establish agent behavior
2. **Execute sequentially** — Complete each phase before proceeding to next
3. **Validate continuously** — Check against Appendix A, B, C after each sub-phase
4. **Test rigorously** — Write tests for every resource and workflow
5. **Document exceptions** — Any deviation from this roadmap must be documented with rationale

**Final Note:** This roadmap is a **living document**. As implementation progresses, update this file to reflect learnings, optimizations, and architectural refinements. All changes must maintain TOON-alignment and canonical reference integrity.

---

**Document Status:** ✅ FINAL CANONICAL v7.1  
**Last Updated:** December 2, 2025  
**Compliance:** `/docs/AGENTS.md`, `/docs/INDEX.md`, Standard Ash Layout, TOON standards  
**Validation:** Passed all correctness checklist items from `ROADMAP_REFACTORING_GUIDE.md`