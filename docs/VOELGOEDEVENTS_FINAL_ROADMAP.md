# VoelgoedEvents - FINAL Development Roadmap

**The Ultimate Enterprise-Grade, Flash-Sale-Ready Implementation Guide**

**Document Version:** 5.0 FINAL MASTER  
**Date:** December 1, 2025  
**Author:** Senior Elixir Architect + Systems Integrator  
**Purpose:** Surgically refined roadmap with financial ledger, high-concurrency patterns, and production hardening

---

## 📋 TABLE OF CONTENTS

1. [Repository Analysis](#repository-analysis)
2. [How to Use This Roadmap](#how-to-use-this-roadmap)
3. [Phase 0: Vision & Domain Guardrails](#phase-0-vision--domain-guardrails)
4. [Phase 1: Technical Foundation](#phase-1-technical-foundation)
5. [Phase 2: Tenancy, Accounts & RBAC](#phase-2-tenancy-accounts--rbac)
6. [Phase 3: Core Events & GA Ticketing](#phase-3-core-events--ga-ticketing)
7. [Phase 4: Orders, Payments & Ticket Issuance](#phase-4-orders-payments--ticket-issuance)
8. [Phase 5: Scanning Backend & Integration](#phase-5-scanning-backend--integration)
9. [Phase 6: Full Financial Ledger & Settlement Engine](#phase-6-full-financial-ledger--settlement-engine) 🆕
10. [Phase 7: Organiser Admin Dashboards](#phase-7-organiser-admin-dashboards)
11. [Phase 8: Seating Engine (Domain Layer)](#phase-8-seating-engine-domain-layer)
12. [Phase 9: Seating Builder LiveView UI](#phase-9-seating-builder-liveview-ui)
13. [Phase 10: Integrations, Webhooks & Public API](#phase-10-integrations-webhooks--public-api)
14. [Phase 11: Hardening, Security & Performance](#phase-11-hardening-security--performance)
15. [Phase 12: Mobile Svelte Apps](#phase-12-mobile-svelte-apps)
16. [Phase 13: Questionnaires & Polls](#phase-13-questionnaires--polls)
17. [Phase 14: Merchandise & Physical Products](#phase-14-merchandise--physical-products)
18. [Phase 15: Advanced Marketing & Affiliates](#phase-15-advanced-marketing--affiliates)
19. [Phase 16: CMS & Site Management](#phase-16-cms--site-management)
20. [Phase 17: Enhanced Ticketing Features](#phase-17-enhanced-ticketing-features)
21. [Phase 18: Advanced SEO & Discoverability](#phase-18-advanced-seo--discoverability)
22. [Phase 19: Dynamic Pricing Engine Expansion](#phase-19-dynamic-pricing-engine-expansion)
23. [Phase 20: Internationalization & Localization (i18n)](#phase-20-internationalization--localization-i18n)
24. [Phase 21: Monetization & Feature Flagging](#phase-21-monetization--feature-flagging) 🔑
25. [Phase 22: Questionnaires & Polls (Advanced Features)](#phase-22-questionnaires--polls-advanced-features)
26. [Phase 23: Merchandise & Physical Products (Advanced Features)](#phase-23-merchandise--physical-products-advanced-features)
27. [Phase 24: Advanced Marketing & Affiliates (Advanced Features)](#phase-24-advanced-marketing--affiliates-advanced-features)
28. [Phase 25: CMS & Site Management (Advanced Features)](#phase-25-cms--site-management-advanced-features)
29. [Phase 26: Enhanced Ticketing Features (Advanced Features)](#phase-26-enhanced-ticketing-features-advanced-features)
30. [Phase 27: Advanced SEO & Discoverability (Advanced Features)](#phase-27-advanced-seo--discoverability-advanced-features)
31. [Appendix A: Technical Specifications Reference](#appendix-a-technical-specifications-reference)
32. [Appendix B: Multi-Tenancy Security Deep Dive](#appendix-b-multi-tenancy-security-deep-dive)
33. [Appendix C: Performance & Scaling Strategy](#appendix-c-performance--scaling-strategy)

---

## 🔍 REPOSITORY ANALYSIS

### Current State (as of December 1, 2025)

**Repository:** `https://github.com/JCSchoeman96/voelgoedevents`

**✅ What's Already There:**

```
lib/voelgoedevents/
├── ash/
│   ├── domains/          ✅ Folder exists (empty)
│   ├── resources/        ✅ Folder exists (empty subdirs)
│   ├── policies/         ✅ Folder exists (empty)
│   ├── preparations/     ✅ Folder exists (empty)
│   ├── validations/      ✅ Folder exists (empty)
│   ├── calculations/     ✅ Folder exists (empty)
│   ├── changes/          ✅ Folder exists (empty)
│   └── extensions/       ✅ Folder exists (empty)
├── workflows/            ✅ Folder exists (empty)
├── caching/              ✅ Folder exists (empty)
├── queues/               ✅ Folder exists (empty)
├── contracts/            ✅ Folder exists (empty)
├── notifications/        ✅ Folder exists (empty)
├── application.ex        ✅ Basic supervision tree
├── repo.ex               ✅ Ecto repo configured
└── mailer.ex             ✅ Swoosh configured

lib/voelgoedevents_web/
├── controllers/          ✅ Basic scaffold
├── components/           ✅ Phoenix 1.7 components
├── endpoint.ex           ✅ Phoenix endpoint
└── router.ex             ✅ Basic routes

mix.exs                   ✅ Phoenix + Ash dependencies
config/                   ✅ Basic config files
priv/repo/migrations/     ✅ Empty (no migrations yet)
```

**❌ What's Missing (Starting Point for Roadmap):**

- No Ash resources defined
- No migrations run
- No authentication implemented
- No multi-tenancy enforcement
- No business logic
- No LiveViews beyond scaffold
- No background jobs configured
- No caching implementation
- No analytics
- No external integrations

**🎯 Conclusion:** You have a **clean, well-structured scaffold**. This roadmap starts from Phase 1 and builds the entire platform systematically.

---

## 📖 HOW TO USE THIS ROADMAP

### For Project Managers

- **Phases** = Major milestones (each delivers a shippable vertical slice)
- **Sub-Phases** = Atomic implementation tasks (15-30 min each)
- **Dependencies** = Sequential within each phase; some phases can run in parallel

### For Developers

- **Always** load `AGENTS.md`, `INDEX.md`, `MASTER_BLUEPRINT.md` before coding
- **Follow** Standard Ash Layout (never create custom folders)
- **Use** TOON micro-prompts for each sub-phase
- **Test** after every resource/workflow creation

### For AI Coding Agents

- **Read** Section "Note" in each sub-phase for critical constraints
- **Never hallucinate** file paths or modules
- **Enforce** multi-tenancy, Ash purity, performance rules
- **Ask questions** when specifications are ambiguous

### Reading the Phases

Each phase includes:

1. **Goal** - What we're achieving
2. **Deliverable** - Concrete output
3. **Sub-Phases** - Step-by-step breakdown with:
   - **Task** - What to build
   - **File Path** - Exact location using Standard Ash Layout
   - **Attributes** - Complete resource specifications
   - **Relationships** - How resources connect
   - **Validations** - Business rules to enforce
   - **Policies** - Authorization rules
   - **Migrations** - Database schema changes
   - **Cache Strategy** - Performance optimization
   - **Testing** - Required test coverage

---

## PHASE 0: Vision & Domain Guardrails

**Goal:** Define product boundaries and prevent scope creep  
**Duration:** 1 week  
**Deliverables:** 3 documentation files

### Phase 0.1: Product Vision & Target Segment

#### Sub-Phase 0.1.1: Create Product Vision Document

**File:** `docs/PRODUCT_VISION.md`

**Content:**

```markdown
# VoelgoedEvents Product Vision

## Target Market

- **Primary:** South African event organisers, agencies, venue operators
- **Secondary:** International events looking for offline-first ticketing

## Positioning

- Reliable GA + seated ticketing platform
- Offline-first scanning (works in stadiums with poor connectivity)
- Multi-tenant SaaS (agencies manage multiple clients)

## Differentiators

1. **Speed:** Sub-150ms scan validation even offline
2. **Reliability:** No overselling, atomic transactions
3. **Multi-Tenant:** White-label ready, tenant isolation
4. **Seat Maps:** Visual builder, complex venue support
5. **Offline Scanning:** Queue-based sync, conflict resolution
6. **Analytics:** Funnel tracking, marketing attribution
7. **Flexibility:** Merchandise, polls, affiliates, CMS
8. **Financial Integrity:** Double-entry ledger, audit-grade accounting

## Long-Term Vision

- #1 ticketing platform in South Africa
- Expand to Africa, then globally
- White-label for agencies and large venues
- Full ecosystem: ticketing, marketing, merchandise, insights
```

#### Sub-Phase 0.1.2: Create MVP Boundaries Document

**File:** `docs/MVP_SCOPE.md`

**Content:**

```markdown
# MVP Scope Definition

## ✅ MVP INCLUDES (Phases 0-7)

- Multi-tenant organization management
- User authentication & RBAC
- Event & venue CRUD
- GA ticketing (inventory-based)
- Checkout & payment processing (Paystack/Yoco for SA)
- QR ticket generation
- Online scanning API
- Offline scanning with sync
- **Full financial ledger & settlement engine**
- Basic organiser dashboards
- Email notifications

## ❌ MVP EXCLUDES (Post-MVP)

- Multi-currency support
- Advanced seating builder (read-only in MVP)
- Full ERP-grade accounting (double-entry only)
- Heavy CMS (comes in Phase 16)
- Mobile apps (Phase 12)
- Merchandise sales (Phase 14)
- Polls & questionnaires (Phase 13)
- Affiliate marketing (Phase 15)
- Advanced analytics (Phase 11+)
```

### Phase 0.2: Core Domain Glossary

#### Sub-Phase 0.2.1: Review DOMAIN_MAP.md

**Action:** Verify `docs/domain/DOMAIN_MAP.md` includes all entities

**Required Entities:**

- **Tenancy/Accounts:** Organization, User, Membership, Role
- **Events/Venues:** Venue, VenueSection, Gate, Event, EventSeries
- **Seating:** Layout, Section, Block, Seat, StandingArea
- **Ticketing:** Ticket, TicketType, PricingRule, Coupon
- **Payments:** Transaction, Refund, **LedgerAccount, JournalEntry, Settlement**
- **Scanning:** Scan, ScanSession, Device, GateAssignment, **AccessLog**
- **Analytics:** AnalyticsEvent, FunnelSnapshot, MarketingAttribution, Campaign
- **Integrations:** WebhookEndpoint, WebhookEvent, IntegrationProvider
- **Reporting:** EventReport, FinancialReport, GateReport
- **Notifications:** Notification, DeliveryAttempt, Template
- **Audit:** AuditLog, ChangeSetLog, UserActionLog
- **API:** ApiKey, ApiRequestLog, RateLimitRule
- **NEW - Merchandise:** Product, ProductVariant, Inventory, Order (extended)
- **NEW - Polls:** Questionnaire, Question, Response, QuestionnaireSubmission
- **NEW - Affiliates:** Affiliate, AffiliateLink, AffiliateConversion, Payout
- **NEW - CMS:** Page, Post, CustomField, MediaLibrary

### Phase 0.3: MVP Non-Goals

#### Sub-Phase 0.3.1: Document What We Won't Build in MVP

**File:** Update `docs/MVP_SCOPE.md`

**Non-Goals:**

- No multi-currency (ZAR only in MVP)
- No global tax engine (SA tax only)
- No ERP-grade accounting (double-entry ledger only, not full GL)
- No general-purpose CMS (comes later)
- No heavy SPA frontend (LiveView-first)
- No full multi-tenant white-label in MVP (single branding)

---

## PHASE 1: Technical Foundation (Ash + Phoenix + Tooling)

**Goal:** Clean, disciplined, extensible codebase with high-concurrency primitives  
**Duration:** 1.5 weeks  
**Deliverables:** Configured tools, CI pipeline, distributed lock manager, foundation docs

### Phase 1.1: Project Scaffolding

**Status:** ✅ COMPLETE (verified from GitHub)

#### Sub-Phase 1.1.1: Verify Dependencies

**Check:** `mix.exs` contains:

```elixir
{:phoenix, "~> 1.7"},
{:ash, "~> 3.0"},
{:ash_postgres, "~> 2.0"},
{:ash_phoenix, "~> 2.0"},
{:ash_authentication, "~> 4.0"},
{:ash_state_machine, "~> 0.2"},
{:oban, "~> 2.17"},
{:ash_oban, "~> 0.2"},
{:redix, "~> 1.5"},
{:cachex, "~> 3.6"},
{:swoosh, "~> 1.16"}
```

### Phase 1.2: Folder & Domain Layout

**Status:** ✅ COMPLETE (folders exist, but empty)

#### Sub-Phase 1.2.1: Validate Folder Structure

**Expected:**

```
lib/voelgoedevents/
├── ash/
│   ├── domains/
│   ├── resources/
│   │   ├── accounts/
│   │   ├── organizations/
│   │   ├── events/
│   │   ├── venues/
│   │   ├── ticketing/
│   │   ├── seating/
│   │   ├── payments/
│   │   ├── finance/          # NEW - Ledger resources
│   │   ├── scanning/
│   │   ├── analytics/
│   │   ├── integrations/
│   │   ├── merchandise/      # NEW
│   │   ├── polls/            # NEW
│   │   ├── affiliates/       # NEW
│   │   └── cms/              # NEW
│   ├── policies/
│   ├── preparations/
│   ├── validations/
│   ├── calculations/
│   ├── changes/
│   └── extensions/
├── workflows/
│   ├── finance/              # NEW - Settlement workflows
├── infrastructure/           # NEW - DLM, caching
├── pricing/                  # NEW - Dynamic pricing
├── caching/
├── queues/
└── notifications/
```

#### Sub-Phase 1.2.2: Create Foundation Architecture Document

**File:** `docs/architecture/01_foundation.md`

**Content:**

- PETAL stack rationale
- Ash philosophy (business logic in resources)
- Standard Ash Layout enforcement
- Vertical slice definition
- Multi-tenancy strategy overview
- Caching tiers (ETS → Redis → Postgres)
- **Distributed Lock Manager (DLM) for critical sections**
- **Financial integrity requirements**

### Phase 1.3: Tooling & CI

#### Sub-Phase 1.3.1: Add Credo

**File:** `.credo.exs`

```elixir
%{
  configs: [
    %{
      name: "default",
      strict: true,
      color: true,
      checks: %{
        enabled: [
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 10]}
        ]
      }
    }
  ]
}
```

#### Sub-Phase 1.3.2: Add Dialyzer

**File:** `mix.exs` (add to deps)

```elixir
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
```

#### Sub-Phase 1.3.3: Add Test Coverage

**File:** `mix.exs` (add to project)

```elixir
test_coverage: [tool: ExCoveralls],
preferred_cli_env: [
  coveralls: :test,
  "coveralls.detail": :test
]
```

#### Sub-Phase 1.3.4: Add Mix Check

**File:** `.check.exs`

```elixir
[
  tools: [
    {:compiler, "mix compile --warnings-as-errors"},
    {:formatter, "mix format --check-formatted"},
    {:credo, "mix credo --strict"},
    {:dialyzer, "mix dialyzer"},
    {:ex_unit, "mix test"}
  ]
]
```

#### Sub-Phase 1.3.5: Add GitHub Actions CI

**File:** `.github/workflows/ci.yml`

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: 1.16
          otp-version: 26
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix test
      - run: mix credo --strict
      - run: mix dialyzer
```

#### Sub-Phase 1.3.6: 🔑 Implement Distributed Lock Manager (DLM)

**File:** `lib/voelgoedevents/infrastructure/distributed_lock.ex`

**Purpose:** Provide safe, non-blocking distributed locks using Redis Redlock algorithm for critical sections like final inventory commits during checkout.

**Functions:**

```elixir
defmodule Voelgoedevents.Infrastructure.DistributedLock do
  @moduledoc """
  Distributed lock manager using Redis Redlock algorithm.

  Critical for preventing race conditions in:
  - Seat reservation finalization
  - Checkout completion
  - Inventory updates
  """

  @doc """
  Acquire a distributed lock with automatic expiry.

  ## Parameters
  - resource: Lock identifier (e.g., "seat:#{seat_id}")
  - ttl_ms: Lock timeout in milliseconds (default: 5000)
  - retry_count: Number of retries (default: 3)

  ## Returns
  - {:ok, lock_value} - Lock acquired
  - {:error, :timeout} - Could not acquire lock
  """
  @spec acquire(String.t(), pos_integer(), pos_integer()) ::
    {:ok, String.t()} | {:error, :timeout}
  def acquire(resource, ttl_ms \\ 5000, retry_count \\ 3)

  @doc """
  Release a distributed lock.

  ## Parameters
  - resource: Lock identifier
  - lock_value: Value returned from acquire/3

  ## Returns
  - :ok - Lock released
  - {:error, :not_owner} - Lock owned by another process
  """
  @spec release(String.t(), String.t()) :: :ok | {:error, :not_owner}
  def release(resource, lock_value)

  @doc """
  Execute function within distributed lock context.

  ## Example
      DistributedLock.with_lock("seat:#{seat_id}", fn ->
        # Critical section - seat reservation
        Seat.mark_as_sold(seat_id)
      end)
  """
  @spec with_lock(String.t(), (-> any()), Keyword.t()) ::
    {:ok, any()} | {:error, :timeout}
  def with_lock(resource, func, opts \\ [])
end
```

**Implementation Notes:**

- Use `SET resource value NX PX ttl` for atomic lock acquisition
- Generate unique `lock_value` using UUID
- Use Lua script for atomic release (compare lock_value before deletion)
- Must be used by `ReserveSeat` and `CompleteCheckout` workflows

**Testing:**

- Test concurrent lock attempts (simulate race conditions)
- Test lock expiry (TTL enforcement)
- Test lock release edge cases

---

## PHASE 2: Tenancy, Accounts & RBAC (Ash-First)

**Goal:** Multi-tenant, secure, RBAC-driven foundation with strict tenant isolation  
**Duration:** 2 weeks  
**Deliverables:** User auth, Organization model, RBAC system, bulletproof tenant isolation

### Phase 2.1: User Auth & Accounts

#### Sub-Phase 2.1.1: Create User Resource

**File:** `lib/voelgoedevents/ash/resources/accounts/user.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :email, :string, allow_nil?: false
attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
attribute :name, :string
attribute :status, :atom, constraints: [one_of: [:active, :suspended, :deleted]], default: :active
attribute :last_login_at, :utc_datetime
timestamps()
```

**Identities:**

- `identity :unique_email, [:email]`

**Extension:**

```elixir
extensions: [AshAuthentication]

authentication do
  strategies do
    password :password do
      identity_field :email
      hashed_password_field :hashed_password
      hash_provider AshAuthentication.BcryptProvider
    end
  end
end
```

**Postgres Table:** `users`

**Indexes:**

- Unique index on `:email`
- Index on `:status`

#### Sub-Phase 2.1.2: Create Migration for Users

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_users.exs`

```elixir
defmodule Voelgoedevents.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :name, :string
      add :status, :string, default: "active"
      add :last_login_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:status])
  end
end
```

#### Sub-Phase 2.1.3: Create User Domain

**File:** `lib/voelgoedevents/ash/domains/accounts.ex`

```elixir
defmodule Voelgoedevents.Ash.Domains.Accounts do
  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Accounts.User
  end
end
```

### Phase 2.2: Tenant Model & Flags

#### Sub-Phase 2.2.1: Create Organization Resource

**File:** `lib/voelgoedevents/ash/resources/organizations/organization.ex`

**⚠️ CRITICAL SECURITY NOTE:**
`organization_id` must **NEVER** be directly exposed or user-editable in LiveView forms or API payloads. It must be derived securely from the authenticated actor or the URL slug via the `LoadTenant` plug. Any direct manipulation of `organization_id` in forms or API requests is a **CRITICAL SECURITY VULNERABILITY**.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :name, :string, allow_nil?: false
attribute :slug, :string, allow_nil?: false
attribute :plan, :atom, constraints: [one_of: [:free, :starter, :pro, :enterprise]], default: :free
attribute :status, :atom, constraints: [one_of: [:active, :suspended, :closed]], default: :active
attribute :branding, :map, default: %{
  logo_url: nil,
  primary_color: "#21808D",
  secondary_color: "#5E5240"
}
attribute :settings, :map, default: %{
  max_events: nil,
  max_tickets_per_event: nil,
  features: []
}
timestamps()
```

**Relationships:**

```elixir
has_many :memberships, Voelgoedevents.Ash.Resources.Accounts.Membership
has_many :venues, Voelgoedevents.Ash.Resources.Venues.Venue
has_many :events, Voelgoedevents.Ash.Resources.Events.Event
```

**Identities:**

- `identity :unique_slug, [:slug]`

**Postgres Table:** `organizations`

**Indexes:**

- Unique index on `:slug`
- Index on `:status`

#### Sub-Phase 2.2.2: Create Migration for Organizations

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_organizations.exs`

#### Sub-Phase 2.2.3: Document Multi-Tenancy Strategy

**File:** `docs/architecture/02_multitenancy.md`

**Content:**

- Row-based multi-tenancy (every resource has `organization_id`)
- Ash policies enforce tenant isolation
- Redis keys scoped: `org:{org_id}:{key}`
- PubSub channels scoped: `events:org:{org_id}`
- No cross-tenant queries allowed (except platform admin)
- **CRITICAL:** `organization_id` NEVER exposed in forms/APIs - always derived from actor/slug

### Phase 2.3: Memberships & Roles

#### Sub-Phase 2.3.1: Create Membership Resource

**File:** `lib/voelgoedevents/ash/resources/accounts/membership.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :user_id, :uuid, allow_nil?: false
attribute :organization_id, :uuid, allow_nil?: false
attribute :role, :atom, constraints: [one_of: [:owner, :admin, :staff, :viewer, :scanner_only]], allow_nil?: false
timestamps()
```

**Relationships:**

```elixir
belongs_to :user, Voelgoedevents.Ash.Resources.Accounts.User
belongs_to :organization, Voelgoedevents.Ash.Resources.Organizations.Organization
```

**Identities:**

- `identity :unique_user_org, [:user_id, :organization_id]`

**Validations:**

- At least one `:owner` per organization (custom validation)

**Postgres Table:** `memberships`

**Indexes:**

- Unique index on `[:user_id, :organization_id]`
- Index on `:organization_id`

#### Sub-Phase 2.3.2: Create Migration for Memberships

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_memberships.exs`

#### Sub-Phase 2.3.3: Create RBAC Policy Module

**File:** `lib/voelgoedevents/ash/policies/common_policies.ex`

**Functions:**

```elixir
def can_manage_events?(actor) do
  actor.role in [:owner, :admin]
end

def can_view_financials?(actor) do
  actor.role in [:owner, :admin]
end

def can_manage_scanners?(actor) do
  actor.role in [:owner, :admin, :staff]
end

def can_scan_tickets?(actor) do
  actor.role in [:owner, :admin, :staff, :scanner_only]
end
```

### Phase 2.4: Tenant-Aware Sessions

#### Sub-Phase 2.4.1: Create LoadTenant Plug

**File:** `lib/voelgoedevents_web/plugs/load_tenant.ex`

**⚠️ CRITICAL SECURITY NOTE:**
This plug is the **ONLY** secure source for `organization_id` in the request lifecycle. It must:

1. Read `tenant_slug` from route params
2. Query `Organization` by slug
3. Verify current user has membership in organization
4. Assign `:current_tenant` to conn
5. Raise 403 if user lacks access

**Implementation:**

```elixir
defmodule VoelgoedeventsWeb.Plugs.LoadTenant do
  @moduledoc """
  Securely loads the tenant (organization) from the URL slug.

  This is the ONLY way organization_id should be determined.
  NEVER trust organization_id from form params or API payloads.
  """

  import Plug.Conn
  alias Voelgoedevents.Ash.Resources.Organizations.Organization
  alias Voelgoedevents.Ash.Resources.Accounts.Membership

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant_slug = conn.params["tenant_slug"]
    current_user = conn.assigns[:current_user]

    case load_tenant(tenant_slug, current_user) do
      {:ok, tenant} ->
        assign(conn, :current_tenant, tenant)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> Phoenix.Controller.put_view(VoelgoedeventsWeb.ErrorView)
        |> Phoenix.Controller.render("404.html")
        |> halt()

      {:error, :forbidden} ->
        conn
        |> put_status(403)
        |> Phoenix.Controller.put_view(VoelgoedeventsWeb.ErrorView)
        |> Phoenix.Controller.render("403.html")
        |> halt()
    end
  end

  defp load_tenant(slug, user) do
    # Verify user has membership
    # Query organization by slug
    # Return {:ok, organization} or error
  end
end
```

#### Sub-Phase 2.4.2: Update Router for Tenant Scoping

**File:** `lib/voelgoedevents_web/router.ex`

```elixir
scope "/t/:tenant_slug", VoelgoedeventsWeb do
  pipe_through [:browser, :require_authenticated_user, :load_tenant]

  live "/dashboard", DashboardLive.Index
  live "/events", EventLive.Index
  # ... all authenticated routes
end
```

#### Sub-Phase 2.4.3: Create Tenant Switcher Component

**File:** `lib/voelgoedevents_web/components/tenant_switcher.ex`

**Display:** Dropdown of user's organizations  
**Action:** Navigate to `/t/{new_slug}/dashboard`

### Phase 2.5: RBAC Guards

#### Sub-Phase 2.5.1: Create Tenant Isolation Policy

**File:** `lib/voelgoedevents/ash/policies/tenant_policies.ex`

**Logic:** Auto-filter all queries by `actor.organization_id`

#### Sub-Phase 2.5.2: Apply Policies to Resources

**Update:** User, Organization, Membership resources with policies

---

## PHASE 3: Core Events & GA Ticketing

**Goal:** Event & venue models, GA ticketing  
**Duration:** 2 weeks  
**Deliverables:** Event CRUD, venue management, ticket types, public event pages

### Phase 3.1: Venue & Event Resources

#### Sub-Phase 3.1.1: Create Venue Resource

**File:** `lib/voelgoedevents/ash/resources/venues/venue.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :address, :string
attribute :city, :string
attribute :country, :string, default: "South Africa"
attribute :capacity, :integer
attribute :timezone, :string, allow_nil?: false, default: "Africa/Johannesburg"
attribute :latitude, :decimal  # NEW - for proximity features
attribute :longitude, :decimal # NEW - for proximity features
attribute :settings, :map, default: %{}
timestamps()
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `venues`

**Indexes:**

- Index on `[:latitude, :longitude]` for proximity queries

#### Sub-Phase 3.1.2: Create Event Resource

**File:** `lib/voelgoedevents/ash/resources/events/event.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :venue_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :slug, :string, allow_nil?: false
attribute :description, :text
attribute :start_at, :utc_datetime, allow_nil?: false
attribute :end_at, :utc_datetime, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:draft, :published, :closed]], default: :draft
attribute :capacity, :integer
attribute :settings, :map, default: %{}
timestamps()
```

**Validations:**

- `validate :start_at_before_end_at` → `start_at < end_at`

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `events`

**Indexes:**

- Unique index on `[:organization_id, :slug]`
- Index on `[:organization_id, :status]`
- Index on `:start_at` for chronological queries

#### Sub-Phase 3.1.3: Create Migrations

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_venues.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_events.exs`

### Phase 3.2: GA Ticket Types

#### Sub-Phase 3.2.1: Create TicketType Resource

**File:** `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :kind, :atom, constraints: [one_of: [:general_admission, :assigned_seating]], default: :general_admission
attribute :inventory, :integer
attribute :sold, :integer, default: 0
attribute :price_cents, :integer, allow_nil?: false
attribute :currency, :string, default: "ZAR"
attribute :sales_start_at, :utc_datetime
attribute :sales_end_at, :utc_datetime
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
timestamps()
```

**Calculations:**

```elixir
calculate :available, :integer, expr(inventory - sold)
```

**Validations:**

- Soft capacity warning when `sold >= inventory`
- Hard capacity block (configurable)

**Postgres Table:** `ticket_types`

**Indexes:**

- Index on `[:event_id, :status]`
- Index on `:sold` for availability checks

#### Sub-Phase 3.2.2: Create Migration for TicketType

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_ticket_types.exs`

### Phase 3.3: Public Event Flow

#### Sub-Phase 3.3.1: Create Event Index LiveView

**File:** `lib/voelgoedevents_web/live/event/event_index_live.ex`

**Purpose:** List published events  
**Query:** Filter by `status: :published`

#### Sub-Phase 3.3.2: Create Event Show LiveView

**File:** `lib/voelgoedevents_web/live/event/event_show_live.ex`

**Purpose:** Show event details + ticket options  
**Action:** "Add to Cart" button

#### Sub-Phase 3.3.3: Create Cart LiveView (Stub)

**File:** `lib/voelgoedevents_web/live/checkout/cart_live.ex`

**Purpose:** Display selected tickets (no payment yet)

### Phase 3.4: Organiser Event Management

#### Sub-Phase 3.4.1: Create Admin Event CRUD LiveView

**File:** `lib/voelgoedevents_web/live/admin/events_live.ex`

**Actions:** Create, edit, delete, publish events

#### Sub-Phase 3.4.2: Create Admin Venue CRUD

**File:** `lib/voelgoedevents_web/live/admin/venues_live.ex`

**Actions:** Manage venues

---

## PHASE 4: Orders, Payments & Ticket Issuance (MVP)

**Goal:** Complete checkout flow with SA payment integration and ticket generation  
**Duration:** 3 weeks  
**Deliverables:** Order/Ticket resources, Paystack/Yoco integration, QR generation, email delivery

### Phase 4.1: Order & Ticket Resources

#### Sub-Phase 4.1.1: Create Order Resource

**File:** `lib/voelgoedevents/ash/resources/ticketing/order.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid, allow_nil?: false
attribute :user_id, :uuid
attribute :email, :string, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:pending, :paid, :canceled, :expired]], default: :pending
attribute :subtotal_cents, :integer, allow_nil?: false
attribute :fee_cents, :integer, default: 0
attribute :tax_cents, :integer, default: 0
attribute :total_cents, :integer, allow_nil?: false
attribute :currency, :string, default: "ZAR"
attribute :payment_id, :uuid

# NEW - Queue & Checkout Window (Post-MVP Phase 19 dependency)
attribute :queue_token, :string          # For validating queue bypass
attribute :checkout_expires_at, :utc_datetime  # Strict TTL for checkout window

timestamps()
```

**State Machine:** Use `AshStateMachine`

- `:pending → :paid`
- `:pending → :expired`
- `:paid → :canceled`

**Postgres Table:** `orders`

**Indexes:**

- Index on `[:organization_id, :event_id, :status]`
- Index on `:checkout_expires_at` for cleanup jobs

#### Sub-Phase 4.1.2: Create Ticket Resource

**File:** `lib/voelgoedevents/ash/resources/ticketing/ticket.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid, allow_nil?: false
attribute :order_id, :uuid, allow_nil?: false
attribute :ticket_type_id, :uuid, allow_nil?: false
attribute :seat_id, :uuid # Nullable for GA
attribute :public_id, :string, allow_nil?: false
attribute :secure_token, :string, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:issued, :revoked, :refunded]], default: :issued
attribute :attendee_name, :string
attribute :attendee_email, :string
attribute :send_to_attendee, :boolean, default: false  # NEW - Phase 17
timestamps()
```

**Identities:**

- `identity :unique_public_id, [:public_id]`
- `identity :unique_secure_token, [:secure_token]`

**Postgres Table:** `tickets`

**Indexes:**

- Index on `[:event_id, :status]`
- Index on `[:order_id]`

#### Sub-Phase 4.1.3: Create Migrations

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_orders.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_tickets.exs`

### Phase 4.2: Payment Abstraction

#### Sub-Phase 4.2.1: Create Transaction Resource

**File:** `lib/voelgoedevents/ash/resources/payments/transaction.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :order_id, :uuid, allow_nil?: false
attribute :provider, :atom, constraints: [one_of: [:paystack, :yoco]], allow_nil?: false
attribute :provider_transaction_id, :string
attribute :amount_cents, :integer, allow_nil?: false
attribute :currency, :string, default: "ZAR"
attribute :status, :atom, constraints: [one_of: [:initiated, :pending, :succeeded, :failed]], default: :initiated
attribute :metadata, :map, default: %{}
timestamps()
```

**State Machine:**

- `:initiated → :pending → :succeeded`
- `:initiated → :failed`

**Postgres Table:** `transactions`

**Indexes:**

- Index on `[:order_id, :status]`
- Index on `:provider_transaction_id` for webhook lookups

#### Sub-Phase 4.2.2: Create Payment Provider Behavior

**File:** `lib/voelgoedevents/payments/provider.ex`

**Callbacks:**

```elixir
@callback create_checkout_session(order, opts) :: {:ok, session} | {:error, reason}
@callback verify_webhook(payload, signature) :: {:ok, event} | {:error, reason}
@callback capture_payment(transaction_id) :: {:ok, result} | {:error, reason}
```

#### Sub-Phase 4.2.3: Create Paystack/Yoco Adapter (SA Specific)

**File:** `lib/voelgoedevents/payments/adapters/paystack.ex`

**⚠️ CHANGE FROM ORIGINAL:** Replace Stripe with South African payment providers.

**Implementation:**

```elixir
defmodule Voelgoedevents.Payments.Adapters.Paystack do
  @moduledoc """
  Paystack payment adapter for South African ZAR transactions.

  Handles:
  - Checkout session creation
  - Webhook verification (HMAC signature)
  - Asynchronous payment confirmation
  """

  @behaviour Voelgoedevents.Payments.Provider

  @impl true
  def create_checkout_session(order, opts) do
    # Create Paystack transaction
    # Return checkout URL
  end

  @impl true
  def verify_webhook(payload, signature) do
    # Verify HMAC signature
    # Parse webhook event
    # Return {:ok, %{event: "payment.success", transaction_id: "..."}}
  end

  @impl true
  def capture_payment(transaction_id) do
    # Verify payment status with Paystack API
    # Return {:ok, result} or {:error, reason}
  end
end
```

**File:** `lib/voelgoedevents/payments/adapters/yoco.ex`

**Implementation:** Similar pattern for Yoco API

**Testing:**

- Test webhook signature verification
- Test ZAR currency handling
- Test async payment confirmation

#### Sub-Phase 4.2.4: Create Migration for Transactions

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_transactions.exs`

### Phase 4.3: QR Payload Design

#### Sub-Phase 4.3.1: Document QR Format

**File:** `docs/architecture/04_ticket_identity.md`

**Format:**

- **Version:** v1
- **Public URL:** `https://voelgoedevents.com/scan/{public_id}/{secure_token}`
- **Signed Payload:** JWT with `ticket_id`, `event_id`, `issued_at`, `expires_at`

#### Sub-Phase 4.3.2: Implement Token Generator

**File:** `lib/voelgoedevents/ticketing/token_generator.ex`

**Functions:**

- `generate_public_id()` → 8-char alphanumeric
- `generate_secure_token(ticket_id)` → Signed JWT
- `verify_secure_token(token)` → Verify JWT

### Phase 4.4: Ticket Issuance Workflow

#### Sub-Phase 4.4.1: Create Issue Tickets Workflow

**File:** `lib/voelgoedevents/workflows/ticketing/issue_tickets.ex`

**Steps:**

1. Verify order status is `:paid`
2. Generate `public_id` and `secure_token` for each ticket
3. Create `Ticket` records
4. Queue email notification

**⚠️ CRITICAL:** Must use `DistributedLock.with_lock/3` around ticket creation to prevent duplicate issuance.

#### Sub-Phase 4.4.2: Create Oban Job for Ticket Email

**File:** `lib/voelgoedevents/queues/workers/send_ticket_email.ex`

**Job:** Send email with QR attachment

### Phase 4.5: Ticket Email Delivery

#### Sub-Phase 4.5.1: Configure Swoosh

**File:** `config/config.exs`

**Adapter:** SendGrid or Mailgun

#### Sub-Phase 4.5.2: Create Email Template

**File:** `lib/voelgoedevents/notifications/templates/ticket_email.html.heex`

**Content:**

- Event details
- Ticket info
- QR code image
- Add to calendar link (Phase 18)
- Add to wallet links (Phase 18)

#### Sub-Phase 4.5.3: Implement Mailer

**File:** `lib/voelgoedevents/notifications/ticket_mailer.ex`

**Function:** `send_ticket_email(ticket, email)`

---

## PHASE 5: Scanning Backend & Integration

**Goal:** Online/offline scanning with in/out tracking and QR validation  
**Duration:** 2 weeks  
**Deliverables:** Scan API with state machine, device management, offline sync

### Phase 5.1: Scanning Domain

#### Sub-Phase 5.1.1: Create Scan Resource

**File:** `lib/voelgoedevents/ash/resources/scanning/scan.ex`

**⚠️ REFINEMENT:** Changed `scanned_at` to `captured_at` for offline sync clarity.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid, allow_nil?: false
attribute :ticket_id, :uuid, allow_nil?: false
attribute :device_id, :uuid, allow_nil?: false
attribute :gate_id, :uuid
attribute :captured_at, :utc_datetime, allow_nil?: false  # Device time - single source of truth for conflict resolution
attribute :result, :atom, constraints: [one_of: [:accepted, :rejected]], allow_nil?: false
attribute :rejection_reason, :string
timestamps()
```

**Postgres Table:** `scans`

**Indexes:**

- Index on `[:event_id, :captured_at]` for time-series queries
- Index on `[:ticket_id, :captured_at]` for duplicate detection

#### Sub-Phase 5.1.2: Create AccessLog Resource (NEW)

**File:** `lib/voelgoedevents/ash/resources/scanning/access_log.ex`

**Purpose:** Track in/out state for tickets (single entry/re-entry tracking).

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :ticket_id, :uuid, allow_nil?: false
attribute :event_id, :uuid, allow_nil?: false
attribute :scan_id, :uuid, allow_nil?: false
attribute :access_type, :atom, constraints: [one_of: [:check_in, :check_out]], allow_nil?: false
attribute :occurred_at, :utc_datetime, allow_nil?: false
timestamps()
```

**Postgres Table:** `access_logs`

**Indexes:**

- Index on `[:ticket_id, :occurred_at DESC]` for latest state lookup
- Index on `[:event_id, :occurred_at]` for reporting

#### Sub-Phase 5.1.3: Create Device Resource

**File:** `lib/voelgoedevents/ash/resources/scanning/device.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :device_token, :string, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
attribute :last_sync_at, :utc_datetime
timestamps()
```

**Identities:**

- `identity :unique_device_token, [:device_token]`

**Postgres Table:** `devices`

#### Sub-Phase 5.1.4: Create Migrations

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_scans.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_access_logs.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_devices.exs`

### Phase 5.2: Document Scanner Contract

#### Sub-Phase 5.2.1: Create Scanner API Documentation

**File:** `docs/architecture/05_scanner_contract.md`

**Endpoints:**

- `POST /api/scans/validate` → Online scan
- `POST /api/scans/sync` → Offline batch upload

**QR Format:** `{public_id}:{secure_token}`

**Response:**

```json
{
  "result": "accepted" | "rejected",
  "reason": null | "already_scanned" | "invalid_ticket",
  "ticket": {...},
  "access_state": "checked_in" | "checked_out"
}
```

### Phase 5.3: Online Scan Endpoint

#### Sub-Phase 5.3.1: Create Scan Controller

**File:** `lib/voelgoedevents_web/controllers/api/scan_controller.ex`

**Endpoint:** `POST /api/scans/validate`

**Logic:**

1. Authenticate device by `device_token`
2. Decode QR token
3. Validate ticket (exists, not revoked, correct event)
4. Check duplicate scan (Redis deduplication)
5. Determine access state (check last AccessLog)
6. Create `Scan` record
7. Create `AccessLog` record
8. Return result with access state

#### Sub-Phase 5.3.2: Implement Process Scan Workflow

**File:** `lib/voelgoedevents/workflows/scanning/process_scan.ex`

**⚠️ REFINEMENT:** Must check `AccessLog` to determine in/out state.

**Steps:**

1. Verify device
2. Decode token
3. Validate ticket
4. Check duplicate (Redis)
5. **Query last AccessLog for ticket**
6. **Determine next state:**
   - No logs → `:check_in`
   - Last log `:check_in` → `:check_out`
   - Last log `:check_out` → `:check_in`
7. Record scan
8. Record AccessLog entry
9. Broadcast PubSub

### Phase 5.4: Offline Sync Endpoint

#### Sub-Phase 5.4.1: Create Sync Controller

**File:** `lib/voelgoedevents_web/controllers/api/scan_controller.ex` (add action)

**Endpoint:** `POST /api/scans/sync`

**Request:**

```json
{
  "device_token": "...",
  "scans": [{ "ticket_token": "...", "captured_at": "2025-12-01T10:00:00Z" }]
}
```

**Logic:**

1. Authenticate device
2. Sort scans by `captured_at` (chronological order for state machine)
3. Process each scan
4. Return per-scan results

#### Sub-Phase 5.4.2: Implement Offline Sync Workflow

**File:** `lib/voelgoedevents/workflows/scanning/offline_sync.ex`

**Steps:**

1. Verify device
2. Sort scans by `captured_at`
3. Validate each
4. Determine access state for each
5. Resolve conflicts (earliest `captured_at` wins)
6. Create scan + AccessLog records

### Phase 5.5: Scan Monitoring UI

#### Sub-Phase 5.5.1: Create Scan Dashboard LiveView

**File:** `lib/voelgoedevents_web/live/admin/scans_live.ex`

**Display:**

- Real-time scan feed (PubSub)
- Check-in counts
- Check-out counts
- Device activity
- Access state visualization

---

## PHASE 6: 🆕 Full Financial Ledger & Settlement Engine

**Goal:** Audit-grade financial accounting with double-entry ledger and settlement tracking  
**Duration:** 2 weeks  
**Deliverables:** LedgerAccount, JournalEntry, Settlement resources, settlement workflow

### Phase 6.1: Financial Domain Resources

#### Sub-Phase 6.1.1: Create LedgerAccount Resource

**File:** `lib/voelgoedevents/ash/resources/finance/ledger_account.ex`

**Purpose:** Represents accounts in double-entry bookkeeping system.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :code, :string, allow_nil?: false  # e.g., "1000" (Assets), "4000" (Revenue)
attribute :name, :string, allow_nil?: false  # e.g., "Bank Account", "Ticket Revenue"
attribute :account_type, :atom, constraints: [one_of: [:asset, :liability, :equity, :revenue, :expense]], allow_nil?: false
attribute :balance_cents, :integer, default: 0
attribute :currency, :string, default: "ZAR"
attribute :status, :atom, constraints: [one_of: [:active, :closed]], default: :active
timestamps()
```

**Identities:**

- `identity :unique_org_code, [:organization_id, :code]`

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `ledger_accounts`

**Standard Chart of Accounts:**

- `1000` - Bank Account (Asset)
- `4000` - Ticket Revenue (Revenue)
- `4100` - Platform Fees (Revenue)
- `2000` - Pending Settlements (Liability)

#### Sub-Phase 6.1.2: Create JournalEntry Resource

**File:** `lib/voelgoedevents/ash/resources/finance/journal_entry.ex`

**Purpose:** Records individual debits and credits in double-entry system.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :ledger_account_id, :uuid, allow_nil?: false
attribute :order_id, :uuid  # Link to order if applicable
attribute :transaction_id, :uuid  # Link to payment transaction
attribute :entry_type, :atom, constraints: [one_of: [:debit, :credit]], allow_nil?: false
attribute :amount_cents, :integer, allow_nil?: false
attribute :currency, :string, default: "ZAR"
attribute :description, :string, allow_nil?: false
attribute :posted_at, :utc_datetime, allow_nil?: false, default: &DateTime.utc_now/0
attribute :metadata, :map, default: %{}
timestamps()
```

**Relationships:**

```elixir
belongs_to :ledger_account, Voelgoedevents.Ash.Resources.Finance.LedgerAccount
belongs_to :order, Voelgoedevents.Ash.Resources.Ticketing.Order
belongs_to :transaction, Voelgoedevents.Ash.Resources.Payments.Transaction
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `journal_entries`

**Indexes:**

- Index on `[:organization_id, :posted_at]`
- Index on `[:order_id]`
- Index on `[:transaction_id]`

#### Sub-Phase 6.1.3: Create Settlement Resource

**File:** `lib/voelgoedevents/ash/resources/finance/settlement.ex`

**Purpose:** Track payments owed to organizers (net revenue after fees).

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :period_start, :date, allow_nil?: false
attribute :period_end, :date, allow_nil?: false
attribute :gross_revenue_cents, :integer, allow_nil?: false  # Total ticket sales
attribute :platform_fee_cents, :integer, allow_nil?: false   # Our fees
attribute :payment_processor_fee_cents, :integer, default: 0
attribute :tax_cents, :integer, default: 0
attribute :net_payout_cents, :integer, allow_nil?: false     # Amount to pay organizer
attribute :currency, :string, default: "ZAR"
attribute :status, :atom, constraints: [one_of: [:pending, :processing, :paid, :failed]], default: :pending
attribute :payout_date, :date
attribute :payout_reference, :string
attribute :metadata, :map, default: %{}
timestamps()
```

**Calculations:**

```elixir
calculate :net_payout_cents, :integer,
  expr(gross_revenue_cents - platform_fee_cents - payment_processor_fee_cents - tax_cents)
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `settlements`

**Indexes:**

- Index on `[:organization_id, :period_start]`
- Index on `[:status]`

#### Sub-Phase 6.1.4: Create Migrations for Finance

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_ledger_accounts.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_journal_entries.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_settlements.exs`

### Phase 6.2: Financial Workflows

#### Sub-Phase 6.2.1: Create Record Sale Workflow

**File:** `lib/voelgoedevents/workflows/finance/record_sale.ex`

**Purpose:** Create journal entries for every completed order.

**Triggered by:** `CompleteCheckout` workflow (Phase 4)

**Logic:**

```elixir
def record_sale(order) do
  # CRITICAL: Every order creates at least three journal entries

  # 1. Debit: Bank Account (Asset increases)
  JournalEntry.create!(%{
    ledger_account_id: bank_account.id,
    entry_type: :debit,
    amount_cents: order.total_cents,
    description: "Ticket sale revenue - Order #{order.id}"
  })

  # 2. Credit: Ticket Revenue (Revenue increases)
  JournalEntry.create!(%{
    ledger_account_id: revenue_account.id,
    entry_type: :credit,
    amount_cents: order.subtotal_cents,
    description: "Ticket revenue - Order #{order.id}"
  })

  # 3. Credit: Platform Fees (Revenue increases)
  JournalEntry.create!(%{
    ledger_account_id: fees_account.id,
    entry_type: :credit,
    amount_cents: order.fee_cents,
    description: "Platform fees - Order #{order.id}"
  })

  # Update ledger account balances
  # Ensure double-entry balance: Debits = Credits
end
```

**Validation:**

- Sum of debits MUST equal sum of credits
- Atomic transaction (all or nothing)

#### Sub-Phase 6.2.2: Create Process Settlement Workflow

**File:** `lib/voelgoedevents/workflows/finance/process_settlement.ex`

**Purpose:** Aggregate revenue, calculate net payout, create settlement record.

**Triggered by:** Scheduled Oban job (weekly/monthly)

**Logic:**

```elixir
def process_settlement(organization_id, period_start, period_end) do
  # 1. Aggregate all paid orders in period
  orders = Order.paid_in_period(organization_id, period_start, period_end)

  # 2. Calculate totals
  gross_revenue_cents = Enum.sum(orders, & &1.subtotal_cents)
  platform_fee_cents = Enum.sum(orders, & &1.fee_cents)
  payment_processor_fee_cents = calculate_processor_fees(orders)
  tax_cents = calculate_tax(gross_revenue_cents)

  # 3. Calculate net payout
  net_payout_cents = gross_revenue_cents - platform_fee_cents - payment_processor_fee_cents - tax_cents

  # 4. Create settlement record
  Settlement.create!(%{
    organization_id: organization_id,
    period_start: period_start,
    period_end: period_end,
    gross_revenue_cents: gross_revenue_cents,
    platform_fee_cents: platform_fee_cents,
    payment_processor_fee_cents: payment_processor_fee_cents,
    tax_cents: tax_cents,
    net_payout_cents: net_payout_cents,
    status: :pending
  })

  # 5. Queue payout notification to organizer
  Oban.insert(Voelgoedevents.Queues.Workers.NotifySettlementReady, %{settlement_id: settlement.id})
end
```

#### Sub-Phase 6.2.3: Create Initiate Payout Workflow

**File:** `lib/voelgoedevents/workflows/finance/initiate_payout.ex`

**Purpose:** Mark settlement as processing and trigger bank transfer.

**Logic:**

```elixir
def initiate_payout(settlement_id) do
  settlement = Settlement.get!(settlement_id)

  # 1. Verify settlement status is :pending
  # 2. Mark as :processing
  # 3. Create bank transfer request (external API call)
  # 4. Record payout reference
  # 5. Update settlement status to :paid on success
  # 6. Notify organizer
end
```

### Phase 6.3: Financial Reporting UI

#### Sub-Phase 6.3.1: Create Financial Dashboard LiveView

**File:** `lib/voelgoedevents_web/live/admin/finance_dashboard_live.ex`

**Display:**

- Current period revenue
- Platform fees collected
- Net payout pending
- Settlement history
- Export ledger as CSV

#### Sub-Phase 6.3.2: Create Ledger Viewer LiveView

**File:** `lib/voelgoedevents_web/live/admin/ledger_viewer_live.ex`

**Display:**

- All journal entries for period
- Filter by account
- Double-entry validation report
- Audit trail

---

## PHASE 7: Organiser Admin Dashboards

**Goal:** Professional admin UI for event management  
**Duration:** 2 weeks  
**Deliverables:** Dashboard shell, event metrics, reporting

### Phase 7.1: Admin Shell

#### Sub-Phase 7.1.1: Create Admin Layout

**File:** `lib/voelgoedevents_web/components/layouts/admin_layout.ex`

**Navigation:**

- Dashboard
- Events
- Venues
- Ticket Types
- Orders
- Scanning
- **Financials** (NEW)
- Reports
- Settings

#### Sub-Phase 7.1.2: Apply Role-Based Visibility

**Logic:** Hide links based on user role

### Phase 7.2: Event Dashboards

#### Sub-Phase 7.2.1: Create Event Dashboard LiveView

**File:** `lib/voelgoedevents_web/live/admin/event_dashboard_live.ex`

**Metrics:**

- Tickets sold
- Revenue
- Check-ins
- Remaining capacity
- **Net payout estimate** (NEW)

#### Sub-Phase 7.2.2: Implement Real-Time Updates

**Subscribe to:**

- `ticketing:event:#{event_id}`
- `scans:event:#{event_id}`
- `finance:event:#{event_id}` (NEW)

#### Sub-Phase 7.2.3: Cache Hot Metrics

**Redis Keys:**

- `org:#{org_id}:event:#{event_id}:tickets_sold`
- `org:#{org_id}:event:#{event_id}:revenue_cents`
- `org:#{org_id}:event:#{event_id}:net_payout_cents` (NEW)

### Phase 7.3: Tenant-Wide Reporting

#### Sub-Phase 7.3.1: Create Reports LiveView

**File:** `lib/voelgoedevents_web/live/admin/reports_live.ex`

**Reports:**

- Revenue summary
- Performance by event
- Attendance rates
- Financial ledger export
- Settlement history
- CSV export

### Phase 7.4: Operational Workflows

#### Sub-Phase 7.4.1: Create Refund Workflow

**File:** `lib/voelgoedevents/workflows/payments/refund_order.ex`

**Steps:**

1. Verify order is `:paid`
2. Create `Refund` record
3. Revoke tickets
4. **Create reversing journal entries** (NEW)
5. Update ledger
6. Notify user

#### Sub-Phase 7.4.2: Create Revoke Ticket Action

**Add to Ticket resource:** `revoke` action

#### Sub-Phase 7.4.3: Create Resend Email Action

**Logic:** Queue Oban job to resend

---

## PHASE 8: Seating Engine (Domain Layer)

**Goal:** Seat-aware events with dynamic pricing and visual integrity  
**Duration:** 2 weeks  
**Deliverables:** Seating resources, reservation logic, seat holds, dynamic pricing engine

### Phase 8.1: Seating Domain Resources

#### Sub-Phase 8.1.1: Create SeatingPlan Resource

**File:** `lib/voelgoedevents/ash/resources/seating/seating_plan.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :venue_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :version, :integer, default: 1
attribute :status, :atom, constraints: [one_of: [:draft, :published, :locked]], default: :draft
attribute :metadata, :map, default: %{}
timestamps()
```

#### Sub-Phase 8.1.2: Create SeatingSection Resource

**File:** `lib/voelgoedevents/ash/resources/seating/seating_section.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :seating_plan_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :code, :string
attribute :capacity, :integer
attribute :seating_type, :atom, constraints: [one_of: [:assigned, :open]], default: :assigned  # NEW - Phase 19.2
timestamps()
```

#### Sub-Phase 8.1.3: Create SeatingRow Resource

**File:** `lib/voelgoedevents/ash/resources/seating/seating_row.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :seating_section_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :row_order, :integer
timestamps()
```

#### Sub-Phase 8.1.4: Create Seat Resource

**File:** `lib/voelgoedevents/ash/resources/seating/seat.ex`

**⚠️ ENHANCED:** Added visual canvas attributes for complex venue rendering.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :seating_row_id, :uuid, allow_nil?: false
attribute :seat_number, :string, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:available, :held, :sold, :blocked]], default: :available
attribute :blocked_reason, :string  # NEW - VIP holds, maintenance, etc.

# Visual Canvas Attributes (NEW)
attribute :position_x, :integer
attribute :position_y, :integer
attribute :rotation, :decimal          # For angled seats/rows
attribute :poly_points, :map           # Optional, for irregular boundaries/shapes
attribute :category_color, :string     # For caching/rendering price zones

attribute :metadata, :map, default: %{}
timestamps()
```

**Indexes:**

- Index on `[:status]` for availability queries
- Index on `[:seating_row_id, :seat_number]` for lookups

#### Sub-Phase 8.1.5: Create Migrations for Seating

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_seating_plans.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_seating_sections.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_seating_rows.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_seats.exs`

#### Sub-Phase 8.1.6: 🆕 Performance Validation

**File:** `test/performance/seating_load_test.exs`

**Purpose:** Verify data model can handle large venues.

**Test Scenarios:**

- Load 50,000 seats (large stadium)
- Query availability for section (< 100ms)
- Hold 100 seats concurrently (no race conditions)
- Render seat map with 10,000+ seats (< 2s)

### Phase 8.2: Ticketing Integration

#### Sub-Phase 8.2.1: Extend TicketType for Seating

**Update:** `lib/voelgoedevents/ash/resources/ticketing/ticket_type.ex`

**Add:**

- For `kind: :assigned_seating`, capacity comes from seats, not manual inventory
- `min_price_cents` and `max_price_cents` for dynamic pricing bounds

#### Sub-Phase 8.2.2: Extend Ticket for Seat Assignment

**Update:** `lib/voelgoedevents/ash/resources/ticketing/ticket.ex`

**Add:**

- `seat_id`, `seat_label`, `row_label`, `section_label`

### Phase 8.3: Reservation & Issuing Logic

#### Sub-Phase 8.3.1: Implement Seat Hold Workflow

**File:** `lib/voelgoedevents/workflows/seating/hold_seats.ex`

**⚠️ CRITICAL:** Must use `DistributedLock.with_lock/3` around seat status changes.

**Logic:**

```elixir
def hold_seats(seat_ids, session_id) do
  DistributedLock.with_lock("seats:#{Enum.join(seat_ids, ":")}", fn ->
    # 1. Verify all seats are :available
    # 2. Mark seats as :held in DB
    # 3. Store hold in Redis ZSET with TTL (5 min)
    # 4. Return hold ID
  end)
end
```

#### Sub-Phase 8.3.2: Implement Seat Release Workflow

**File:** `lib/voelgoedevents/workflows/seating/release_seats.ex`

**Logic:**

1. If checkout expires, mark seats as `:available`
2. Remove from Redis hold

#### Sub-Phase 8.3.3: Implement Lock Seats on Purchase

**Update:** Complete checkout workflow to mark seats as `:sold`

### Phase 8.4: Seating Plan Locking Rules

#### Sub-Phase 8.4.1: Create Locking Validation

**File:** `lib/voelgoedevents/ash/validations/seating_plan_locked.ex`

**Logic:**

- Once seats are sold, plan status → `:locked`
- Only safe edits allowed (metadata, not structure)

---

## PHASE 9: Seating Builder LiveView UI

**Goal:** Visual seating plan editor  
**Duration:** 3 weeks  
**Deliverables:** Seating builder UI, seat map preview

### Phase 9.1: Backend Builder API

#### Sub-Phase 9.1.1: Create Batch Seat Creation Action

**File:** Add actions to seating resources

**Actions:**

- `create_section_with_rows`
- `bulk_create_seats`
- `auto_number_seats`

### Phase 9.2: Seating Builder LiveView

#### Sub-Phase 9.2.1: Create Builder LiveView

**File:** `lib/voelgoedevents_web/live/admin/seating_builder_live.ex`

**Features:**

- Visual canvas (sections, rows, seats)
- Drag/zoom
- Add section/row tools
- Bulk seat creation
- Set rotation, poly_points for irregular shapes
- Price zone assignment

### Phase 9.3: Customer Seat Selection

#### Sub-Phase 9.3.1: Create Public Seat Map UI

**File:** `lib/voelgoedevents_web/live/event/seat_selection_live.ex`

**Features:**

- Color-coded zones (by price)
- Seat hover/select
- Real-time availability updates (PubSub)
- Continue to checkout

#### Sub-Phase 9.3.2: Cache Seat Availability

**Redis Key:** `org:#{org_id}:event:#{event_id}:seats:availability`

**Format:** Bitmap or hash of seat statuses

**TTL:** 30 seconds

### Phase 9.4: Seating as Add-On

#### Sub-Phase 9.4.1: Feature Flag for Seating

**Logic:** Tenants with `seating_maps` feature can create seating, others only see GA

---

## PHASE 10: Integrations, Webhooks & Public API

**Goal:** External tool integration  
**Duration:** 2 weeks  
**Deliverables:** Webhook engine, public API, optional connectors

### Phase 10.1: Webhook Engine

#### Sub-Phase 10.1.1: Create WebhookEndpoint Resource

**File:** `lib/voelgoedevents/ash/resources/integrations/webhook_endpoint.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :url, :string, allow_nil?: false
attribute :events, {:array, :string}, default: []
attribute :secret, :string, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
timestamps()
```

#### Sub-Phase 10.1.2: Create WebhookEvent Resource

**File:** `lib/voelgoedevents/ash/resources/integrations/webhook_event.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :endpoint_id, :uuid, allow_nil?: false
attribute :event_type, :string, allow_nil?: false
attribute :payload, :map, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:pending, :delivered, :failed]], default: :pending
attribute :attempts, :integer, default: 0
timestamps()
```

#### Sub-Phase 10.1.3: Implement Webhook Delivery Worker

**File:** `lib/voelgoedevents/queues/workers/deliver_webhook.ex`

**Logic:**

1. Sign payload with secret
2. POST to endpoint URL
3. Retry on failure (exponential backoff)
4. Dead-letter queue after 5 attempts

### Phase 10.2: Public REST API

#### Sub-Phase 10.2.1: Create ApiKey Resource

**File:** `lib/voelgoedevents/ash/resources/integrations/api_key.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :key, :string, allow_nil?: false
attribute :permissions, {:array, :string}, default: ["read"]
attribute :status, :atom, constraints: [one_of: [:active, :revoked]], default: :active
timestamps()
```

#### Sub-Phase 10.2.2: Create Public API Endpoints

**File:** `lib/voelgoedevents_web/controllers/api/v1/`

**Endpoints:**

- `GET /api/v1/events` → List events
- `GET /api/v1/events/:id` → Event details
- `GET /api/v1/tickets/:id` → Ticket details
- `POST /api/v1/orders` → Create order (if allowed)

#### Sub-Phase 10.2.3: Implement Rate Limiting

**Use:** `PlugAttack` or custom rate limiter

**Logic:** Limit API calls per key per minute

### Phase 10.3: Optional Connectors

#### Sub-Phase 10.3.1: CRM Export (Future)

**File:** `lib/voelgoedevents/integrations/crm_export.ex`

**Logic:** Export attendees to HubSpot/Salesforce

#### Sub-Phase 10.3.2: Email Provider Integration

**Logic:** Already using Swoosh (configurable)

#### Sub-Phase 10.3.3: Calendar Export (iCal)

**File:** `lib/voelgoedevents/integrations/icalendar_export.ex`

**Logic:** Generate `.ics` files for events

---

## PHASE 11: Hardening, Security & Performance

**Goal:** Production-ready platform with anti-fraud, bot protection, and chaos testing  
**Duration:** 3 weeks  
**Deliverables:** Audit logging, observability, performance optimization, security hardening

### Phase 11.1: Security & Auditing

#### Sub-Phase 11.1.1: Create AuditLog Resource

**File:** `lib/voelgoedevents/ash/resources/audit/audit_log.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :user_id, :uuid
attribute :resource, :string, allow_nil?: false
attribute :action, :string, allow_nil?: false
attribute :resource_id, :uuid
attribute :changes, :map
timestamps()
```

#### Sub-Phase 11.1.2: Implement Auditable Extension

**File:** `lib/voelgoedevents/ash/extensions/auditable.ex`

**Logic:** Auto-log all create/update/delete actions

#### Sub-Phase 11.1.3: 🆕 Implement Redis Sliding Window Rate Limiter

**File:** `lib/voelgoedevents_web/plugs/rate_limiter_plug.ex`

**⚠️ MOVED FROM PHASE 19:** Rate limiting is a security primitive, not a queue feature.

**Implementation:**

```elixir
defmodule VoelgoedeventsWeb.Plugs.RateLimiter do
  @moduledoc """
  Redis-backed sliding window rate limiter.

  Protects sensitive endpoints:
  - Login attempts (5/min per IP)
  - Checkout (10/min per user)
  - API calls (100/min per API key)
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    key = build_key(conn, opts)
    limit = opts[:limit] || 10
    window = opts[:window] || 60

    case check_rate_limit(key, limit, window) do
      {:ok, _remaining} ->
        conn

      {:error, :rate_limited} ->
        conn
        |> put_status(429)
        |> Phoenix.Controller.json(%{error: "Rate limit exceeded"})
        |> halt()
    end
  end

  defp check_rate_limit(key, limit, window) do
    # Redis sliding window algorithm
    # ZREMRANGEBYSCORE to remove old entries
    # ZADD to add current request
    # ZCARD to count requests in window
    # Compare against limit
  end
end
```

#### Sub-Phase 11.1.4: 🆕 Anti-Fraud Logic and Bot Protection

**File:** `lib/voelgoedevents/security/fraud_detector.ex`

**Purpose:** Framework for detecting fraudulent activity.

**Functions:**

```elixir
defmodule Voelgoedevents.Security.FraudDetector do
  @moduledoc """
  Anti-fraud and bot detection system.

  Detects:
  - Impossible travel (large geographic jumps between login/purchase)
  - Bot patterns (rapid repeated actions)
  - Card testing (multiple failed payments)
  """

  @doc """
  Check for impossible travel pattern.

  Flags if user logs in from location A, then location B
  within timeframe that's physically impossible.
  """
  @spec detect_impossible_travel(user_id, ip_address, timestamp) ::
    {:ok, :safe} | {:warning, :suspicious} | {:block, :impossible_travel}
  def detect_impossible_travel(user_id, ip_address, timestamp)

  @doc """
  Detect bot-like behavior patterns.

  Flags rapid repeated actions, scripted behavior.
  """
  @spec detect_bot_pattern(user_id, action, timestamp) ::
    {:ok, :human} | {:warning, :suspicious} | {:block, :bot}
  def detect_bot_pattern(user_id, action, timestamp)
end
```

**Integration:**

- Hook into checkout flow (Phase 4)
- Hook for invisible CAPTCHA service (e.g., hCaptcha, reCAPTCHA)
- Log suspicious activity to `AuditLog`

### Phase 11.2: Observability

#### Sub-Phase 11.2.1: Add Telemetry Events

**File:** `lib/voelgoedevents/telemetry.ex`

**Events:**

- Order creation
- Payment processing
- Ticket issuance
- Scan validation
- Dashboard views
- Seat reservations
- Settlement processing
- Fraud detection triggers

#### Sub-Phase 11.2.2: Configure Logging

**Use:** Logger with structured logging

**Output:** JSON logs for production

#### Sub-Phase 11.2.3: Add Monitoring (Optional)

**Tools:** AppSignal, Sentry, or Grafana

### Phase 11.3: Performance

#### Sub-Phase 11.3.1: Add Database Indexes

**Review:** All foreign keys, query paths

**Add indexes for:**

- `organization_id` on all tenant-scoped tables
- `event_id` on tickets, orders, scans
- Composite indexes for common queries
- Indexes on financial reporting queries

#### Sub-Phase 11.3.2: Optimize Ash Queries

**Use:** Preloading, batch loading

**Avoid:** N+1 queries

#### Sub-Phase 11.3.3: Implement Caching

**Redis Caching:**

- Event details (TTL: 5 min)
- Seat availability (TTL: 30 sec)
- Dashboard metrics (TTL: 1 min)
- Financial summaries (TTL: 5 min)

**ETS Caching:**

- Hot counters (tickets sold, check-ins)
- Ledger account balances (1 min TTL)

#### Sub-Phase 11.3.4: Load Test

**Tools:** K6 or Locust

**Scenarios:**

- Flash sale (1000 concurrent checkouts)
- Scanning rush (500 scans/min)
- Dashboard load (100 concurrent admins)
- Seat selection (500 concurrent seat browsers)

#### Sub-Phase 11.3.5: 🆕 Chaos Engineering Integration

**File:** Update `.github/workflows/ci.yml`

**Purpose:** Verify system resilience under failure conditions.

**Chaos Testing Scenarios:**

```yaml
chaos_tests:
  - name: "Redis Connection Drop During Checkout"
    action: Kill Redis connection mid-transaction
    expected: DLM prevents duplicate charges, graceful error

  - name: "High DB Latency During Flash Sale"
    action: Introduce 500ms delay to all DB queries
    expected: Optimistic locks prevent overselling

  - name: "Scan Device Offline Sync Conflict"
    action: Submit same ticket from 2 devices with 1s delay
    expected: First scan wins (captured_at ordering)
```

**Implementation:**

- Use `toxiproxy` or similar tool to inject failures
- Run chaos tests in CI on PRs
- Verify metrics stay within bounds

---

## PHASE 12: Mobile Svelte Apps

**Goal:** Mobile-first scanner and organiser apps  
**Duration:** 3 weeks  
**Deliverables:** PWA scanner upgrade, organiser mobile app

### Phase 12.1: Scanner PWA Upgrade

#### Sub-Phase 12.1.1: Upgrade Scanner to SvelteKit

**File:** `scanner_pwa/` (separate app)

**Features:**

- Capacitor for native camera
- Improved offline queue
- Sync conflict UX
- Access log state visualization

### Phase 12.2: Organiser Mobile App

#### Sub-Phase 12.2.1: Create Organiser Svelte App

**File:** `organiser_mobile/` (separate app)

**Features:**

- Event dashboards
- Quick scan lookup
- Ticket details
- Financial summaries
- Push notifications (optional)

### Phase 12.3: Mobile Observability

#### Sub-Phase 12.3.1: Add Crash Tracking

**Tool:** Sentry for mobile

#### Sub-Phase 12.3.2: Version API Contract

**Logic:** Support multiple API versions (`/api/v1`, `/api/v2`)

---

## PHASE 22: Questionnaires & Polls (Advanced Features)

**Goal:** Market research and audience engagement  
**Duration:** 2 weeks  
**Deliverables:** Poll builder, response collection, analytics

### Phase 13.1: Poll Domain Resources

#### Sub-Phase 13.1.1: Create Questionnaire Resource

**File:** `lib/voelgoedevents/ash/resources/polls/questionnaire.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid # Optional - can be event-specific or standalone
attribute :title, :string, allow_nil?: false
attribute :description, :text
attribute :status, :atom, constraints: [one_of: [:draft, :active, :closed]], default: :draft
attribute :start_at, :utc_datetime
attribute :end_at, :utc_datetime
attribute :settings, :map, default: %{
  allow_anonymous: true,
  allow_multiple_submissions: false,
  show_results: false
}
timestamps()
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `questionnaires`

#### Sub-Phase 13.1.2: Create Question Resource

**File:** `lib/voelgoedevents/ash/resources/polls/question.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :questionnaire_id, :uuid, allow_nil?: false
attribute :question_text, :text, allow_nil?: false
attribute :question_type, :atom, constraints: [one_of: [:multiple_choice, :single_choice, :text, :rating, :yes_no]], allow_nil?: false
attribute :options, {:array, :string} # For multiple/single choice
attribute :required, :boolean, default: false
attribute :order, :integer, allow_nil?: false
timestamps()
```

**Postgres Table:** `questions`

#### Sub-Phase 13.1.3: Create Response Resource

**File:** `lib/voelgoedevents/ash/resources/polls/response.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :question_id, :uuid, allow_nil?: false
attribute :submission_id, :uuid, allow_nil?: false
attribute :answer, :text # JSON for complex answers
timestamps()
```

**Postgres Table:** `responses`

#### Sub-Phase 13.1.4: Create Submission Resource

**File:** `lib/voelgoedevents/ash/resources/polls/submission.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :questionnaire_id, :uuid, allow_nil?: false
attribute :user_id, :uuid # Nullable for anonymous
attribute :submitted_at, :utc_datetime, allow_nil?: false, default: &DateTime.utc_now/0
timestamps()
```

**Postgres Table:** `submissions`

#### Sub-Phase 13.1.5: Create Migrations for Polls

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_questionnaires.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_questions.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_responses.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_submissions.exs`

### Phase 13.2: Poll Builder UI

#### Sub-Phase 13.2.1: Create Questionnaire Builder LiveView

**File:** `lib/voelgoedevents_web/live/admin/questionnaire_builder_live.ex`

**Features:**

- Add/remove questions
- Set question types
- Define options
- Preview

#### Sub-Phase 13.2.2: Create Public Poll Submission UI

**File:** `lib/voelgoedevents_web/live/polls/submit_live.ex`

**Features:**

- Display questions
- Collect responses
- Validate required fields
- Thank you page

### Phase 13.3: Poll Analytics

#### Sub-Phase 13.3.1: Create Poll Results Dashboard

**File:** `lib/voelgoedevents_web/live/admin/poll_results_live.ex`

**Display:**

- Response count
- Charts for multiple choice (bar/pie)
- Word clouds for text responses
- Export CSV

---

## PHASE 23: Merchandise & Physical Products (Advanced Features)

**Goal:** Sell merchandise alongside tickets  
**Duration:** 3 weeks  
**Deliverables:** Product catalog, inventory, checkout integration

### Phase 14.1: Product Domain Resources

#### Sub-Phase 14.1.1: Create Product Resource

**File:** `lib/voelgoedevents/ash/resources/merchandise/product.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid # Optional - can be event-specific or standalone
attribute :name, :string, allow_nil?: false
attribute :description, :text
attribute :price_cents, :integer, allow_nil?: false
attribute :currency, :string, default: "ZAR"
attribute :sku, :string, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
attribute :images, {:array, :string}, default: []
attribute :metadata, :map, default: %{}
timestamps()
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `products`

#### Sub-Phase 14.1.2: Create ProductVariant Resource

**File:** `lib/voelgoedevents/ash/resources/merchandise/product_variant.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :product_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false # E.g., "Small", "Blue"
attribute :sku, :string, allow_nil?: false
attribute :price_cents, :integer # Override product price if needed
attribute :inventory, :integer, allow_nil?: false
attribute :sold, :integer, default: 0
timestamps()
```

**Calculations:**

```elixir
calculate :available, :integer, expr(inventory - sold)
```

**Postgres Table:** `product_variants`

#### Sub-Phase 14.1.3: Extend Order for Merchandise

**Update:** `lib/voelgoedevents/ash/resources/ticketing/order.ex`

**Add:**

- `has_many :order_items` (can be tickets OR products)

#### Sub-Phase 14.1.4: Create OrderItem Resource

**File:** `lib/voelgoedevents/ash/resources/ticketing/order_item.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :order_id, :uuid, allow_nil?: false
attribute :item_type, :atom, constraints: [one_of: [:ticket, :product]], allow_nil?: false
attribute :item_id, :uuid, allow_nil?: false # ticket_id OR product_variant_id
attribute :quantity, :integer, default: 1
attribute :price_cents, :integer, allow_nil?: false
attribute :metadata, :map, default: %{}
timestamps()
```

**Postgres Table:** `order_items`

#### Sub-Phase 14.1.5: Create Migrations for Merchandise

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_products.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_product_variants.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_order_items.exs`

### Phase 14.2: Product Catalog UI

#### Sub-Phase 14.2.1: Create Product CRUD LiveView

**File:** `lib/voelgoedevents_web/live/admin/products_live.ex`

**Features:**

- Create/edit products
- Manage variants
- Upload images
- Set inventory

#### Sub-Phase 14.2.2: Create Public Product Listing

**File:** `lib/voelgoedevents_web/live/shop/product_index_live.ex`

**Features:**

- Display products
- Filter by event/category
- Add to cart

### Phase 14.3: Checkout Integration

#### Sub-Phase 14.3.1: Update Cart to Support Products

**Update:** `lib/voelgoedevents_web/live/checkout/cart_live.ex`

**Display:**

- Tickets + Products in one cart
- Calculate total

#### Sub-Phase 14.3.2: Update Complete Checkout Workflow

**Update:** `lib/voelgoedevents/workflows/checkout/complete_checkout.ex`

**Logic:**

- Process ticket + product orders atomically
- Reduce inventory for products
- Issue tickets + generate shipping labels (if physical)
- **Create journal entries for product revenue**

---

## PHASE 24: Advanced Marketing & Affiliates (Advanced Features)

**Goal:** Affiliate program, UTM tracking, shortened URLs  
**Duration:** 2 weeks  
**Deliverables:** Affiliate system, link tracking, dashboard

### Phase 15.1: Affiliate Domain Resources

#### Sub-Phase 15.1.1: Create Affiliate Resource

**File:** `lib/voelgoedevents/ash/resources/affiliates/affiliate.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :user_id, :uuid # Link to User if affiliate is a registered user
attribute :name, :string, allow_nil?: false
attribute :email, :string, allow_nil?: false
attribute :affiliate_code, :string, allow_nil?: false # Unique code
attribute :commission_rate, :decimal, allow_nil?: false # Percentage (e.g., 10.0 for 10%)
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
timestamps()
```

**Identities:**

- `identity :unique_affiliate_code, [:affiliate_code]`

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `affiliates`

#### Sub-Phase 15.1.2: Create AffiliateLink Resource

**File:** `lib/voelgoedevents/ash/resources/affiliates/affiliate_link.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :affiliate_id, :uuid, allow_nil?: false
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid # Optional - specific event or site-wide
attribute :short_url, :string, allow_nil?: false # E.g., "vg.events/abc123"
attribute :full_url, :string, allow_nil?: false # Target URL with UTM params
attribute :clicks, :integer, default: 0
attribute :conversions, :integer, default: 0
timestamps()
```

**Identities:**

- `identity :unique_short_url, [:short_url]`

**Postgres Table:** `affiliate_links`

#### Sub-Phase 15.1.3: Create AffiliateConversion Resource

**File:** `lib/voelgoedevents/ash/resources/affiliates/affiliate_conversion.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :affiliate_id, :uuid, allow_nil?: false
attribute :organization_id, :uuid, allow_nil?: false
attribute :order_id, :uuid, allow_nil?: false
attribute :commission_cents, :integer, allow_nil?: false
attribute :status, :atom, constraints: [one_of: [:pending, :paid]], default: :pending
timestamps()
```

**Postgres Table:** `affiliate_conversions`

#### Sub-Phase 15.1.4: Create Migrations for Affiliates

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_affiliates.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_affiliate_links.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_affiliate_conversions.exs`

### Phase 15.2: UTM Builder & Link Shortener

#### Sub-Phase 15.2.1: Create UTM Builder Module

**File:** `lib/voelgoedevents/marketing/utm_builder.ex`

**Function:**

```elixir
def build_utm_url(base_url, campaign, source, medium, content \\ nil, term \\ nil) do
  # Returns URL with UTM params
end
```

#### Sub-Phase 15.2.2: Create Link Shortener

**File:** `lib/voelgoedevents/marketing/link_shortener.ex`

**Logic:**

1. Generate short code (6-8 chars)
2. Store mapping in DB
3. Return shortened URL

#### Sub-Phase 15.2.3: Create Link Redirect Controller

**File:** `lib/voelgoedevents_web/controllers/link_controller.ex`

**Endpoint:** `GET /:short_code`

**Logic:**

1. Lookup short code
2. Increment click counter
3. Redirect to full URL

### Phase 15.3: Affiliate Dashboard

#### Sub-Phase 15.3.1: Create Affiliate Dashboard LiveView

**File:** `lib/voelgoedevents_web/live/admin/affiliates_live.ex`

**Display:**

- List affiliates
- Clicks, conversions, revenue
- Filter by date range
- CSV export

#### Sub-Phase 15.3.2: Create Affiliate Portal (Optional)

**File:** `lib/voelgoedevents_web/live/affiliate/portal_live.ex`

**Features:**

- Affiliate login
- View stats
- Generate links
- Track earnings

### Phase 15.4: Commission Payout

#### Sub-Phase 15.4.1: Create Payout Workflow

**File:** `lib/voelgoedevents/workflows/affiliates/process_payout.ex`

**Logic:**

1. Aggregate pending conversions
2. Calculate total commission
3. Create `Payout` record
4. Mark conversions as `:paid`
5. Notify affiliate

---

## PHASE 25: CMS & Site Management (Advanced Features)

**Goal:** Content management for marketing pages  
**Duration:** 3 weeks  
**Deliverables:** Page builder, custom fields, media library

### Phase 16.1: CMS Domain Resources

#### Sub-Phase 16.1.1: Create Page Resource

**File:** `lib/voelgoedevents/ash/resources/cms/page.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid # Nullable for site-wide pages
attribute :title, :string, allow_nil?: false
attribute :slug, :string, allow_nil?: false
attribute :content, :text # Rich text or JSON
attribute :status, :atom, constraints: [one_of: [:draft, :published]], default: :draft
attribute :meta_title, :string
attribute :meta_description, :text
attribute :published_at, :utc_datetime
timestamps()
```

**Identities:**

- `identity :unique_slug, [:slug]`

**Postgres Table:** `pages`

#### Sub-Phase 16.1.2: Create Post Resource

**File:** `lib/voelgoedevents/ash/resources/cms/post.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid
attribute :author_id, :uuid, allow_nil?: false
attribute :title, :string, allow_nil?: false
attribute :slug, :string, allow_nil?: false
attribute :excerpt, :text
attribute :content, :text
attribute :status, :atom, constraints: [one_of: [:draft, :published]], default: :draft
attribute :published_at, :utc_datetime
timestamps()
```

**Postgres Table:** `posts`

#### Sub-Phase 16.1.3: Create CustomField Resource

**File:** `lib/voelgoedevents/ash/resources/cms/custom_field.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :resource_type, :string, allow_nil?: false # "page", "post", "event"
attribute :resource_id, :uuid, allow_nil?: false
attribute :field_name, :string, allow_nil?: false
attribute :field_value, :text
timestamps()
```

**Postgres Table:** `custom_fields`

#### Sub-Phase 16.1.4: Create MediaLibrary Resource

**File:** `lib/voelgoedevents/ash/resources/cms/media.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid
attribute :file_name, :string, allow_nil?: false
attribute :file_url, :string, allow_nil?: false
attribute :file_type, :string # "image", "video", "document"
attribute :file_size, :integer
timestamps()
```

**Postgres Table:** `media`

#### Sub-Phase 16.1.5: Create Migrations for CMS

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_pages.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_posts.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_custom_fields.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_media.exs`

### Phase 16.2: Page Builder UI

#### Sub-Phase 16.2.1: Create Page Editor LiveView

**File:** `lib/voelgoedevents_web/live/admin/page_editor_live.ex`

**Features:**

- Rich text editor (TipTap or similar)
- Drag-drop content blocks
- Custom field management
- Media insertion

#### Sub-Phase 16.2.2: Create Media Library UI

**File:** `lib/voelgoedevents_web/live/admin/media_library_live.ex`

**Features:**

- Upload images/videos
- Organize in folders
- Search/filter
- Insert into pages

### Phase 16.3: Public CMS Routes

#### Sub-Phase 16.3.1: Add CMS Routes

**File:** `lib/voelgoedevents_web/router.ex`

**Routes:**

- `GET /p/:slug` → Page show
- `GET /blog/:slug` → Post show

#### Sub-Phase 16.3.2: Create Page Show Controller

**File:** `lib/voelgoedevents_web/controllers/page_controller.ex`

**Logic:**

1. Query page by slug
2. Render template with content

### Phase 16.4: VoelgoedEvents-Owned Events

#### Sub-Phase 16.4.1: Create Platform Tenant

**Action:** Create a special "VoelgoedEvents" organization

**Purpose:**

- List events hosted by VoelgoedEvents itself
- Separate from client tenants

**OR**

**Alternative:** Add `is_platform_event` boolean to Event resource

---

## PHASE 26: Enhanced Ticketing Features (Advanced Features)

**Goal:** VIP seats, ticket templates, multi-attendee handling  
**Duration:** 2 weeks  
**Deliverables:** VIP workflow, template builder, attendee info collection

### Phase 17.1: VIP Seat Management

#### Sub-Phase 17.1.1: Add VIP Seat Blocking

**Update:** Seat resource (already has `blocked_reason` attribute from Phase 8.1.4)

**Logic:**

- Admin can mark seats as `:blocked` without creating orders
- Still generates ticket + QR code
- Does not affect revenue analytics (marked as "comp")

#### Sub-Phase 17.1.2: Create VIP Ticket Workflow

**File:** `lib/voelgoedevents/workflows/ticketing/issue_vip_tickets.ex`

**Logic:**

1. Admin selects seats
2. Mark seats as `:blocked`
3. Create tickets with `price_cents: 0`
4. Generate QR codes
5. Email to VIP contact
6. **Do NOT create journal entries** (comped tickets)

### Phase 17.2: Ticket Template Builder

#### Sub-Phase 17.2.1: Create TicketTemplate Resource

**File:** `lib/voelgoedevents/ash/resources/ticketing/ticket_template.ex`

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :name, :string, allow_nil?: false
attribute :template_html, :text, allow_nil?: false
attribute :template_css, :text
attribute :default, :boolean, default: false
timestamps()
```

**Postgres Table:** `ticket_templates`

#### Sub-Phase 17.2.2: Create Template Builder UI

**File:** `lib/voelgoedevents_web/live/admin/ticket_template_builder_live.ex`

**Features:**

- Visual editor with placeholders: `{event_name}`, `{ticket_id}`, `{qr_code}`
- CSS customization
- Preview

#### Sub-Phase 17.2.3: Update Ticket Email to Use Template

**Update:** `lib/voelgoedevents/notifications/ticket_mailer.ex`

**Logic:**

1. Load template
2. Replace placeholders
3. Render HTML

### Phase 17.3: Multi-Attendee Handling

#### Sub-Phase 17.3.1: Add Guest Info Collection

**Update:** Checkout flow

**Options:**

1. **Populate with buyer info** (default)
2. **Force guest info entry** (optional)
3. **Allow choice** (checkbox: "Different attendee?")

#### Sub-Phase 17.3.2: Add Attendee Email Option

**Update:** Ticket resource (already has `send_to_attendee` attribute from Phase 4.1.2)

**Logic:**

- If `true` and `attendee_email` present, send ticket to attendee
- Otherwise, send all tickets to buyer

#### Sub-Phase 17.3.3: Validate No Duplicate Attendees

**Add validation:**

- Check if `attendee_email` already has ticket for this event (configurable)

---

## PHASE 27: Advanced SEO & Discoverability (Advanced Features)

**Goal:** Schema markup, sitemap, calendar integration  
**Duration:** 1 week  
**Deliverables:** Auto schema, sitemap, wallet integration

### Phase 18.1: Schema Implementation

#### Sub-Phase 18.1.1: Create Schema Generator Module

**File:** `lib/voelgoedevents/seo/schema_generator.ex`

**Function:**

```elixir
def generate_event_schema(event) do
  %{
    "@context" => "https://schema.org",
    "@type" => "Event",
    "name" => event.name,
    "startDate" => event.start_at,
    "endDate" => event.end_at,
    "location" => %{
      "@type" => "Place",
      "name" => event.venue.name,
      "address" => event.venue.address
    },
    "offers" => %{
      "@type" => "Offer",
      "price" => event.ticket_types |> Enum.map(&(&1.price_cents / 100)),
      "priceCurrency" => "ZAR"
    }
  }
end
```

#### Sub-Phase 18.1.2: Inject Schema into Event Pages

**Update:** `lib/voelgoedevents_web/templates/layout/root.html.heex`

**Add:**

```html
<script type="application/ld+json">
  <%= raw(@schema_json) %>
</script>
```

### Phase 18.2: Sitemap Generation

#### Sub-Phase 18.2.1: Create Sitemap Controller

**File:** `lib/voelgoedevents_web/controllers/sitemap_controller.ex`

**Endpoint:** `GET /sitemap.xml`

**Logic:**

1. Query all published events
2. Generate XML with URLs and timestamps
3. Return XML response

**Example:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://voelgoedevents.com/e/event-slug</loc>
    <lastmod>2025-12-01</lastmod>
  </url>
</urlset>
```

#### Sub-Phase 18.2.2: Add Sitemap Route

**File:** `lib/voelgoedevents_web/router.ex`

**Route:** `get "/sitemap.xml", SitemapController, :index`

### Phase 18.3: Calendar & Wallet Integration

#### Sub-Phase 18.3.1: Generate iCal Files

**File:** `lib/voelgoedevents/integrations/icalendar_generator.ex`

**Function:**

```elixir
def generate_ical(event) do
  # Generate .ics file content
end
```

#### Sub-Phase 18.3.2: Add "Add to Calendar" Link

**Update:** Event confirmation email

**Add:** Link to download `.ics` file

#### Sub-Phase 18.3.3: Generate Apple Wallet Pass

**File:** `lib/voelgoedevents/integrations/apple_wallet.ex`

**Logic:**

1. Generate `.pkpass` file with event + QR code
2. Provide download link

#### Sub-Phase 18.3.4: Generate Google Wallet Pass

**File:** `lib/voelgoedevents/integrations/google_wallet.ex`

**Logic:**

1. Use Google Wallet API
2. Generate pass with ticket details

---

## PHASE 19: Dynamic Pricing Engine Expansion

**Goal:** Implement the full data model and calculation service required for sophisticated yield management, allowing organizers to set complex, inventory-based, and location-based pricing rules.

**Scaffolding:** Use the `ticketing` and `seating` Ash domains.

---

## Phase 19.1: Dynamic Pricing Resource Model

### Sub-Phase 19.1.1: Create PricingTier Resource (Inventory-Based)

**File:** `lib/voelgoedevents/ash/resources/ticketing/pricing_tier.ex`

- **Purpose:** Define price changes based on percentage of tickets sold.
- **Attributes:**
  - `event_id` (uuid, allow_nil?: false)
  - `name` (string, allow_nil?: false)
  - `price_cents` (integer, allow_nil?: false)
  - `inventory_threshold` (decimal, allow_nil?: false)
  - `status` (atom, constraints: [one_of: [:active, :inactive]], default: :active)
  - `timestamps()`
- **Validations:**
  - `inventory_threshold` must be between 0.0 and 1.0 (`validate_number/3`)

### Sub-Phase 19.1.2: Create SeatingZonePriceOverride Resource (Location-Based)

**File:** `lib/voelgoedevents/ash/resources/seating/zone_price_override.ex`

- **Purpose:** Override the base ticket price for specific seating sections (premium locations).
- **Attributes:**
  - `event_id` (uuid, allow_nil?: false)
  - `seating_section_id` (uuid, allow_nil?: false)
  - `price_cents_delta` (integer, allow_nil?: false) # e.g. +5000 = +R50
  - `status` (atom, constraints: [one_of: [:active, :inactive]], default: :active)
  - `timestamps()`
- **Relationships:**
  - `belongs_to :seating_section, Voelgoedevents.Ash.Resources.Seating.SeatingSection`

### Sub-Phase 19.1.3: Create Migrations

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_pricing_tiers.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_zone_price_overrides.exs`

---

## Phase 19.2: Price Calculation Service

### Sub-Phase 19.2.1: Implement Advanced Price Calculator Service

**File:** `lib/voelgoedevents/pricing/price_calculator.ex`

- **Function:** `calculate_price(ticket_type, seat_id \\ nil)`
- **Logic:**
  1. Fetch the base price from `ticket_type.price_cents`.
  2. If any active `PricingTier` for the event is below or equal to the inventory sold percent, use that price (highest threshold <= current percent wins).
  3. If `seat_id` given, check for any active `SeatingZonePriceOverride` for the seat's section and add its delta to base/adjusted price.

### Sub-Phase 19.2.2: Update Checkout Workflow to use Price Calculator

**Update:** `lib/voelgoedevents/workflows/checkout/start_checkout.ex`

- **Logic:** Replace static price lookups with `PriceCalculator.calculate_price/2`. Use result in cart, validation, and billing.

---

## Phase 19.3: Admin UI & Testing

### Sub-Phase 19.3.1: Create Pricing Rules LiveView

**File:** `lib/voelgoedevents_web/live/admin/pricing_rules_live.ex`

- **Features:**
  - CRUD interface for PricingTier (create, edit, delete tiers, order by threshold)
  - CRUD for SeatingZonePriceOverride (add/edit zone premium pricing)
  - Real-time preview: Show calculated price for selected inventory percentages / zone combo

### Sub-Phase 19.3.2: Write Integration Tests for Price Engine

**File:** `test/voelgoedevents/pricing/price_calculator_test.exs`

- **Tests:**
  - Test that price updates exactly at each `PricingTier` threshold boundary
  - Test that zone overrides are stacked correctly

---

# PHASE 20: Internationalization & Localization (i18n)

**Goal:** Implement a full internationalization framework, enabling future expansion into non-English languages and allowing organizers to manage translatable content.

---

## Phase 20.1: Core Translation Setup

### Sub-Phase 20.1.1: Configure Gettext in Project

**Files:**

- `mix.exs`
- `lib/voelgoedevents_web/gettext.ex`
- **Action:** Add `:gettext` dependency and configure the domain and language folders. Set default locale to `en` and add `af` (Afrikaans) as secondary for MVP.

### Sub-Phase 20.1.2: Implement Language Switcher Plug

**File:** `lib/voelgoedevents_web/plugs/set_locale.ex`

- **Logic:**
  1. Check URL param (?locale=af)
  2. Else, use user preference (in User profile)
  3. Else, use tenant default setting
  4. Else, use browser header (`accept-language`)
  5. Fallback: `en`.

### Sub-Phase 20.1.3: Update Router and Root Layout

**Files:**

- `lib/voelgoedevents_web/router.ex`
- `lib/voelgoedevents_web/components/layouts/root.html.heex`
- **Action:** Apply `set_locale` plug to all LiveView (non-API) routes. Add a language picker in the UI.

---

## Phase 20.2: Content Translation Resource

### Sub-Phase 20.2.1: Create TranslationKey Resource

**File:** `lib/voelgoedevents/ash/resources/cms/translation_key.ex`

- **Attributes:**
  - `organization_id` (uuid, nullable: true) # null = platform default key
  - `key` (string, allow_nil?: false) # e.g. "general.checkout_button"
  - `locale` (string, allow_nil?: false)
  - `value` (string, allow_nil?: false)
  - `timestamps()`
- **Identities:** Unique index on `[:organization_id, :key, :locale]`

### Sub-Phase 20.2.2: Implement Translation Lookup Service

**File:** `lib/voelgoedevents/i18n/translator.ex`

- **Logic:**
  - Try to fetch active TranslationKey for {organization_id, key, locale}
  - Else, get default key for {nil, key, locale}
  - Else, fall back to Gettext's default

---

## Phase 20.3: UI Implementation

### Sub-Phase 20.3.1: Translate Core UI Elements

- Update all core UI, starting with Phase 2.4.3 (Tenant Switcher) and Phase 3.3.2 (Event Show LiveView), to use `Gettext.gettext/2` for static text.

### Sub-Phase 20.3.2: Create Translation Management Dashboard

**File:** `lib/voelgoedevents_web/live/admin/translation_live.ex`

- **Features:**
  - List all TranslationKeys for current org + system
  - Edit/override translations (CRUD)
  - Filter by locale, search string keys, preview fallback chain

---

## PHASE 21: Monetization & Feature Flagging

**Goal:** Formalize the ability to sell advanced features (P19, P15, P14, P22-P27) as add-ons, and establish a flexible, auditable fee calculation model to support per-tenant commission customization, free events, and donation collections  
**Duration:** 2 weeks  
**Deliverables:** FeeModel, FeePolicy, Donation resources, feature flag management, updated checkout workflow

**⚠️ CRITICAL IMPORTANCE:** This phase determines the monetization strategy for the entire platform. It must be implemented before phases 22-27 (advanced features) can be sold as add-ons.

---

### Phase 21.1: Fee Model & Policy Domain

#### Sub-Phase 21.1.1: Create FeeModel Resource

**File:** `lib/voelgoedevents/ash/resources/finance/fee_model.ex`

**Purpose:** Define the commission structure for an organization or event.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid # Optional - event-specific override
attribute :model_type, :atom, constraints: [one_of: [:percentage, :flat_fee, :free]], allow_nil?: false
attribute :platform_fee_percentage, :decimal # E.g., 5.0 for 5%
attribute :platform_fee_flat_cents, :integer # E.g., 50 cents per ticket
attribute :payment_processor_fee_percentage, :decimal # E.g., 2.9%
attribute :payment_processor_fee_flat_cents, :integer # E.g., 30 cents
attribute :allow_donations, :boolean, default: false
attribute :donation_percentage_to_platform, :decimal, default: 0.0 # E.g., 10% of donations go to platform
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
timestamps()
```

**Relationships:**

```elixir
belongs_to :organization, Voelgoedevents.Ash.Resources.Organizations.Organization
belongs_to :event, Voelgoedevents.Ash.Resources.Events.Event
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `fee_models`

**Indexes:**

- Index on `[:organization_id, :status]`
- Index on `[:event_id, :status]`

**Validations:**

- If `model_type: :percentage`, `platform_fee_percentage` must be present
- If `model_type: :flat_fee`, `platform_fee_flat_cents` must be present
- If `model_type: :free`, both fee fields must be nil

#### Sub-Phase 21.1.2: Create FeePolicy Resource

**File:** `lib/voelgoedevents/ash/resources/finance/fee_policy.ex`

**Purpose:** Track which fee model is currently active for an organization or event.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :event_id, :uuid # Optional
attribute :fee_model_id, :uuid, allow_nil?: false
attribute :active_from, :utc_datetime, allow_nil?: false, default: &DateTime.utc_now/0
attribute :active_until, :utc_datetime # Optional - for time-limited promotions
attribute :status, :atom, constraints: [one_of: [:active, :inactive]], default: :active
timestamps()
```

**Relationships:**

```elixir
belongs_to :fee_model, Voelgoedevents.Ash.Resources.Finance.FeeModel
belongs_to :organization, Voelgoedevents.Ash.Resources.Organizations.Organization
belongs_to :event, Voelgoedevents.Ash.Resources.Events.Event
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `fee_policies`

**Indexes:**

- **CRITICAL:** Unique index on `[:organization_id, :event_id, :status]` WHERE `status = 'active'` (ensures only one active policy per organization/event)
- Index on `[:active_from, :active_until]` for time-based queries

**Validations:**

- If `event_id` is nil, policy applies to entire organization
- If `event_id` is present, policy applies only to that event
- Only one active policy allowed per organization/event combination

#### Sub-Phase 21.1.3: Update Organization Resource

**File:** `lib/voelgoedevents/ash/resources/organizations/organization.ex`

**Add Attributes:**

```elixir
attribute :plan, :atom, constraints: [one_of: [:free, :starter, :pro, :enterprise]], default: :free
attribute :settings, :map, default: %{
  features: [],  # E.g., [:seating_maps, :dynamic_pricing, :merchandise, :polls]
  max_events: nil,
  max_tickets_per_event: nil
}
```

**Add Relationships:**

```elixir
has_many :fee_models, Voelgoedevents.Ash.Resources.Finance.FeeModel
has_many :fee_policies, Voelgoedevents.Ash.Resources.Finance.FeePolicy
```

#### Sub-Phase 21.1.4: Create Migrations for Fee Model

**Files:**

- `priv/repo/migrations/YYYYMMDDHHMMSS_create_fee_models.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_fee_policies.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_update_organizations_add_plan.exs`

---

### Phase 21.2: Feature Flag Management

#### Sub-Phase 21.2.1: Implement Feature Flag Module

**File:** `lib/voelgoedevents/features/feature_flags.ex`

**Purpose:** Centralized feature flag checks based on organization plan and settings.

**Functions:**

```elixir
defmodule Voelgoedevents.Features.FeatureFlags do
  @moduledoc """
  Centralized feature flag management.

  Determines which features are available to an organization based on:
  - Organization plan (:free, :starter, :pro, :enterprise)
  - Feature flags in organization.settings.features
  - Time-limited trials
  """

  @doc """
  Check if organization has access to a feature.

  ## Examples

      has_feature?(org, :seating_maps)
      has_feature?(org, :dynamic_pricing)
      has_feature?(org, :merchandise)
  """
  @spec has_feature?(Organization.t(), atom()) :: boolean()
  def has_feature?(organization, feature)

  @doc """
  Get all available features for organization.
  """
  @spec available_features(Organization.t()) :: [atom()]
  def available_features(organization)

  @doc """
  Feature matrix by plan.
  """
  @spec plan_features(atom()) :: [atom()]
  def plan_features(plan)
end
```

**Feature Matrix:**

```elixir
# Free Plan
- Basic events
- GA ticketing
- Basic scanning
- Basic dashboards

# Starter Plan ($29/month)
- All Free features
- Seating maps (read-only, must use templates)
- Basic reports
- Custom branding

# Pro Plan ($99/month)
- All Starter features
- Custom seating builder (Phase 9)
- Dynamic pricing (Phase 19)
- Merchandise (Phase 23)
- Polls (Phase 22)
- Affiliates (Phase 24)
- Advanced analytics

# Enterprise Plan (Custom pricing)
- All Pro features
- CMS (Phase 25)
- White-label
- Custom fee models
- Dedicated support
- SLA guarantees
```

#### Sub-Phase 21.2.2: Update LiveViews with Feature Guards

**Action:** Update all advanced feature LiveViews to check `FeatureFlags.has_feature?/2` before rendering.

**Example:**

```elixir
def mount(_params, _session, socket) do
  if FeatureFlags.has_feature?(socket.assigns.current_tenant, :seating_maps) do
    {:ok, socket}
  else
    {:ok, redirect(socket, to: "/upgrade")}
  end
end
```

---

### Phase 21.3: Donation System

#### Sub-Phase 21.3.1: Create Donation Resource

**File:** `lib/voelgoedevents/ash/resources/payments/donation.ex`

**Purpose:** Track voluntary donations added to orders.

**Attributes:**

```elixir
uuid_primary_key :id
attribute :organization_id, :uuid, allow_nil?: false
attribute :order_id, :uuid, allow_nil?: false
attribute :amount_cents, :integer, allow_nil?: false
attribute :currency, :string, default: "ZAR"
attribute :platform_share_cents, :integer, allow_nil?: false # Calculated from fee model
attribute :organizer_share_cents, :integer, allow_nil?: false
timestamps()
```

**Relationships:**

```elixir
belongs_to :order, Voelgoedevents.Ash.Resources.Ticketing.Order
belongs_to :organization, Voelgoedevents.Ash.Resources.Organizations.Organization
```

**Multi-Tenancy:** `strategy: :attribute, attribute: :organization_id`

**Postgres Table:** `donations`

**Indexes:**

- Index on `[:order_id]`
- Index on `[:organization_id]`

#### Sub-Phase 21.3.2: Update StartCheckout Workflow

**File:** `lib/voelgoedevents/workflows/checkout/start_checkout.ex`

**Add Fee Calculation Logic:**

```elixir
def calculate_fees_and_total(order_items, organization_id, event_id, donation_cents \\ 0) do
  # 1. Get active FeePolicy for organization/event
  fee_policy = get_active_fee_policy(organization_id, event_id)
  fee_model = fee_policy.fee_model

  # 2. Calculate subtotal from items
  subtotal_cents = Enum.sum(order_items, & &1.price_cents * &1.quantity)

  # 3. Calculate platform fee
  platform_fee_cents = case fee_model.model_type do
    :percentage ->
      round(subtotal_cents * fee_model.platform_fee_percentage / 100)

    :flat_fee ->
      fee_model.platform_fee_flat_cents * length(order_items)

    :free ->
      0
  end

  # 4. Calculate payment processor fee
  processor_fee_cents =
    round((subtotal_cents + platform_fee_cents) * fee_model.payment_processor_fee_percentage / 100) +
    fee_model.payment_processor_fee_flat_cents

  # 5. Calculate donation split if applicable
  {platform_donation_cents, organizer_donation_cents} =
    if fee_model.allow_donations and donation_cents > 0 do
      platform_share = round(donation_cents * fee_model.donation_percentage_to_platform / 100)
      {platform_share, donation_cents - platform_share}
    else
      {0, donation_cents}
    end

  # 6. Calculate total
  total_cents = subtotal_cents + platform_fee_cents + processor_fee_cents + donation_cents

  %{
    subtotal_cents: subtotal_cents,
    platform_fee_cents: platform_fee_cents,
    processor_fee_cents: processor_fee_cents,
    donation_cents: donation_cents,
    platform_donation_cents: platform_donation_cents,
    organizer_donation_cents: organizer_donation_cents,
    total_cents: total_cents,
    fee_model_id: fee_model.id
  }
end

def get_active_fee_policy(organization_id, event_id) do
  # Check ETS cache first (5 min TTL)
  cache_key = "fee_policy:#{organization_id}:#{event_id || "org"}"

  case Voelgoedevents.Caching.ETS.get(cache_key) do
    {:ok, policy} ->
      policy

    :miss ->
      # Query from DB
      policy = FeePolicy
        |> Ash.Query.filter(organization_id == ^organization_id)
        |> Ash.Query.filter(event_id == ^event_id or is_nil(event_id))
        |> Ash.Query.filter(status == :active)
        |> Ash.Query.filter(active_from <= ^DateTime.utc_now())
        |> Ash.Query.filter(is_nil(active_until) or active_until >= ^DateTime.utc_now())
        |> Ash.Query.load(:fee_model)
        |> Ash.read_one!()

      # Cache for 5 minutes
      Voelgoedevents.Caching.ETS.put(cache_key, policy, ttl: 300)

      policy
  end
end
```

#### Sub-Phase 21.3.3: Update Order Resource

**File:** `lib/voelgoedevents/ash/resources/ticketing/order.ex`

**Add Attributes:**

```elixir
attribute :fee_model_id, :uuid # Track which fee model was used
attribute :platform_fee_cents, :integer, default: 0
attribute :processor_fee_cents, :integer, default: 0
attribute :donation_cents, :integer, default: 0
```

**Add Relationship:**

```elixir
belongs_to :fee_model, Voelgoedevents.Ash.Resources.Finance.FeeModel
has_one :donation, Voelgoedevents.Ash.Resources.Payments.Donation
```

#### Sub-Phase 21.3.4: Create Migration for Donations

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_donations.exs`

**File:** `priv/repo/migrations/YYYYMMDDHHMMSS_update_orders_add_fee_tracking.exs`

---

### Phase 21.4: Fee Management UI

#### Sub-Phase 21.4.1: Create Fee Model Management LiveView

**File:** `lib/voelgoedevents_web/live/admin/fee_models_live.ex`

**Features:**

- List all fee models for organization
- Create/edit fee models
- Set active fee policy
- Preview fee calculation

#### Sub-Phase 21.4.2: Update Checkout UI for Donations

**File:** `lib/voelgoedevents_web/live/checkout/cart_live.ex`

**Add:**

- Optional donation input field (if `allow_donations: true`)
- Fee breakdown display
- Total calculation with fees

---

### Phase 21.5: Financial Reporting Updates

#### Sub-Phase 21.5.1: Update Settlement Workflow

**File:** `lib/voelgoedevents/workflows/finance/process_settlement.ex`

**Update Logic:**

- Calculate gross revenue (subtotal)
- Subtract platform fees (tracked in orders)
- Subtract processor fees
- Add organizer's share of donations
- Calculate net payout

#### Sub-Phase 21.5.2: Update Financial Dashboard

**File:** `lib/voelgoedevents_web/live/admin/finance_dashboard_live.ex`

**Display:**

- Fee model breakdown
- Donation totals (platform vs organizer)
- Effective commission rate
- Revenue projections

---

### Phase 21.6: Caching Strategy

#### Sub-Phase 21.6.1: Implement Fee Model Cache

**File:** `lib/voelgoedevents/caching/fee_model_cache.ex`

**Strategy:**

- Cache active FeePolicy for each organization in ETS
- TTL: 5 minutes
- Invalidate on fee model/policy changes
- Fallback to DB if cache miss

**Performance Target:** Fee lookup < 10ms (ETS) vs < 100ms (DB)

---

### Phase 21.7: Testing

#### Sub-Phase 21.7.1: Write Fee Calculation Tests

**File:** `test/voelgoedevents/workflows/checkout/fee_calculation_test.exs`

**Test Cases:**

- Percentage-based fees
- Flat fees
- Free events (zero fees)
- Donation splits
- Event-specific fee overrides
- Time-limited fee policies
- Cache hit/miss scenarios

#### Sub-Phase 21.7.2: Write Feature Flag Tests

**File:** `test/voelgoedevents/features/feature_flags_test.exs`

**Test Cases:**

- Plan-based feature access
- Custom feature flags
- Feature upgrade enforcement

---

## APPENDIX A: Technical Specifications Reference

### Standard Ash Folder Layout (MANDATORY)

```
lib/voelgoedevents/
├── ash/
│   ├── domains/                    # Ash Domain modules
│   ├── resources/                  # Ash Resources (business logic)
│   │   ├── accounts/              # User, Membership, Role
│   │   ├── organizations/         # Organization
│   │   ├── events/                # Event
│   │   ├── venues/                # Venue, Gate, VenueSection
│   │   ├── ticketing/             # Ticket, TicketType, Order, OrderItem
│   │   ├── seating/               # SeatingPlan, Section, Row, Seat
│   │   ├── payments/              # Transaction, Refund
│   │   ├── finance/               # 🆕 LedgerAccount, JournalEntry, Settlement
│   │   ├── scanning/              # Scan, Device, ScanSession, AccessLog
│   │   ├── analytics/             # AnalyticsEvent, FunnelSnapshot, Campaign
│   │   ├── integrations/          # WebhookEndpoint, ApiKey
│   │   ├── merchandise/           # Product, ProductVariant
│   │   ├── polls/                 # Questionnaire, Question, Response
│   │   ├── affiliates/            # Affiliate, AffiliateLink
│   │   └── cms/                   # Page, Post, CustomField, Media
│   ├── policies/                  # Authorization policies
│   ├── preparations/              # Query-time filters
│   ├── validations/               # Custom validations
│   ├── calculations/              # Derived attributes
│   ├── changes/                   # State transitions
│   └── extensions/                # Custom Ash extensions
├── workflows/                      # Multi-step orchestrations
│   ├── checkout/
│   ├── ticketing/
│   ├── scanning/
│   ├── payments/
│   ├── seating/
│   ├── finance/                   # 🆕 Settlement workflows
│   └── affiliates/
├── infrastructure/                 # 🆕 DLM, distributed systems
├── pricing/                        # 🆕 Dynamic pricing engine
├── security/                       # 🆕 Fraud detection, bot protection
├── caching/                        # Cache modules (ETS, Redis)
├── queues/                         # Oban workers
├── contracts/                      # API contracts (optional)
├── notifications/                  # Email/SMS templates
├── analytics/                      # Analytics helpers
└── integrations/                   # External service adapters

lib/voelgoedevents_web/
├── controllers/                    # Phoenix controllers
│   └── api/                       # API endpoints
├── live/                           # LiveView modules
│   ├── admin/                     # Admin dashboards
│   ├── event/                     # Public event pages
│   ├── checkout/                  # Checkout flow
│   ├── polls/                     # Poll submission
│   └── affiliate/                 # Affiliate portal
├── components/                     # Reusable UI components
├── plugs/                          # Custom plugs (LoadTenant, RateLimiter)
└── templates/                      # HEEx templates
```

### Multi-Tenancy Security Checklist

✅ **Database Level:**

- Every tenant-scoped table has `organization_id` column
- Foreign key constraints enforce referential integrity
- Indexes on `organization_id` for performance

✅ **Ash Level:**

- All resources use `multi_tenancy: strategy: :attribute, attribute: :organization_id`
- Policies enforce tenant isolation
- Preparations auto-filter queries by tenant

✅ **Redis Level:**

- All keys prefixed: `org:#{org_id}:{key}`
- No cross-tenant key access

✅ **PubSub Level:**

- All channels scoped: `events:org:#{org_id}`
- Subscriptions check user membership

✅ **Checkout Security:**

- Verify all items (tickets, products) belong to same organization
- Use Ecto transactions for atomicity
- Use optimistic locking for seat reservations
- **Use DistributedLock for critical sections**

✅ **Actor Pattern:**

- Always pass `actor` in context
- Actor contains `organization_id`
- `organization_id` NEVER exposed in forms/API payloads
- Supervisor processes per tenant (optional for high isolation)

### Caching Strategy

| Layer    | Technology | Use Case                                    | TTL            |
| -------- | ---------- | ------------------------------------------- | -------------- |
| **Hot**  | ETS        | Per-node counters (tickets sold, check-ins) | 1-5 min        |
| **Warm** | Redis      | Seat availability, pricing, session data    | 30 sec - 5 min |
| **Cold** | Postgres   | Source of truth                             | Permanent      |

**Invalidation Rules:**

- Write-through: DB write → invalidate cache
- Use Ash notifiers to trigger cache invalidation
- PubSub broadcasts for multi-node invalidation

### Performance Targets

| Operation                | Target | Notes                        |
| ------------------------ | ------ | ---------------------------- |
| Page load                | <500ms | Event listing, event detail  |
| Checkout                 | <2s    | Complete checkout flow       |
| Scan validation          | <150ms | Online scan (including DB)   |
| Dashboard load           | <1s    | Real-time metrics            |
| Seat selection           | <300ms | Seat map interaction         |
| Distributed lock acquire | <50ms  | Redis-based lock acquisition |

---

## APPENDIX B: Multi-Tenancy Security Deep Dive

### Checkout Security (Preventing Data Leaks)

**Scenario:** User from Org A tries to checkout with tickets from Org B

**Prevention:**

1. **Validation at Cart Level:**

   ```elixir
   def validate_cart_items(items, actor) do
     org_ids = items |> Enum.map(&get_org_id/1) |> Enum.uniq()

     if length(org_ids) > 1 or hd(org_ids) != actor.organization_id do
       {:error, "Invalid cart items"}
     else
       :ok
     end
   end
   ```

2. **Transaction-Level Checks:**

   ```elixir
   Ash.transaction(fn ->
     # Verify all items belong to actor's organization
     # Use `Ash.Query.for_read/3` with actor context
   end)
   ```

3. **Supervisor Pattern (Advanced):**
   - One checkout supervisor per organization
   - Processes isolated by tenant
   - Prevents accidental cross-tenant access

### Seat Hold Registry (Preventing Overselling)

**Architecture:**

```
ETS Table (per-node, hot)
    ↓ (check)
Redis ZSET (cluster-wide, warm)
    ↓ (fallback)
Postgres (durable, cold)
    ↓ (wrapped by)
DistributedLock (DLM) - Ensures atomic operations
```

**Flow:**

1. User selects seat
2. **Acquire distributed lock on seat**
3. Check ETS: Is seat available?
4. If yes, reserve in ETS
5. Write to Redis ZSET with TTL (5 min)
6. **Release distributed lock**
7. Start checkout
8. On payment success, **acquire lock**, mark seat as `:sold` in DB, **release lock**
9. Remove from ETS/Redis holds

**Conflict Resolution:**

- If two users hold same seat, first to acquire lock and pay wins
- Second user gets error: "Seat no longer available"
- DLM prevents race conditions at critical sections

---

## APPENDIX C: Performance & Scaling Strategy

### Horizontal Scaling

**Node Scaling:**

- Run multiple Phoenix nodes behind load balancer
- Use Redis for shared state (seat holds, session data)
- Use PubSub for inter-node communication
- DistributedLock works across all nodes (Redis-based)

**Database Scaling:**

- Read replicas for analytics and reports
- Connection pooling (pgBouncer)
- Partitioning by `organization_id` (optional for very large scale)

### Flash Sale Architecture

**Problem:** 10,000 users trying to buy 100 tickets

**Solution:**

1. **Queue System** (Phase 19)

   - Limit active users on event page
   - Others wait in queue

2. **Rate Limiting** (Phase 11.1.3)

   - Limit checkout attempts per user per minute
   - Use Redis counters

3. **Distributed Locking** (Phase 1.3.6)

   - Use DLM for final seat reservation
   - Fail fast if seat taken

4. **Optimistic Locking**

   - Use DB-level locks for seat reservation
   - Fail fast if seat taken

5. **Async Processing**
   - Queue ticket issuance as Oban jobs
   - Don't block user on email delivery

### Caching Hot Paths

**Event Detail Page:**

- Cache event data in Redis (5 min TTL)
- Cache seat availability bitmap (30 sec TTL)
- Cache ticket type inventory (1 min TTL)
- Cache dynamic prices (1 min TTL)

**Dashboard:**

- Cache metrics in ETS (per-node, 1 min TTL)
- Use Redis for cross-node consistency
- Cache financial summaries (5 min TTL)

**Invalidation:**

- On ticket sale, invalidate event cache
- On seat selection, invalidate seat cache
- On settlement creation, invalidate financial cache
- Use PubSub to broadcast invalidation to all nodes

---

## 🎯 EXECUTION SUMMARY

### Total Phases: 20 (Phases 0-20)

### Total Duration: ~34 weeks (8-9 months)

### Total Sub-Phases: 350+ atomic tasks

### Recommended Team Size:

- **MVP (Phases 0-7):** 2-3 developers + 1 PM
- **Post-MVP (Phases 8-20):** 3-4 developers + 1 PM + 1 QA

### Critical Changes from Original Roadmap:

**🆕 NEW PHASE 6:** Full Financial Ledger & Settlement Engine

- Double-entry accounting system
- Automatic journal entries for every order
- Settlement tracking and payout management

**🔑 HIGH-CONCURRENCY PRIMITIVES:**

- Distributed Lock Manager (DLM) - Phase 1.3.6
- Redis Sliding Window Rate Limiter - Phase 11.1.3
- Chaos Engineering Integration - Phase 11.3.5

**🇿🇦 SOUTH AFRICAN FOCUS:**

- Paystack/Yoco payment adapters (not Stripe)
- ZAR currency defaults
- SA tax handling

**🎫 ENHANCED SEATING:**

- Visual canvas attributes (rotation, poly_points, category_color)
- Dynamic pricing engine with yield management
- Performance validation for large venues (50,000+ seats)

**🔐 SECURITY HARDENING:**

- Strict multi-tenancy enforcement (organization_id never exposed)
- Anti-fraud and bot detection framework
- Impossible travel detection
- Chaos testing in CI

**📊 SCANNING STATE MACHINE:**

- AccessLog resource for in/out tracking
- `captured_at` timestamp for offline sync conflict resolution
- Check-in/check-out state visualization

### Dependencies Map:

```
Phase 0 (Docs) → Phase 1 (Foundation + DLM) → Phase 2 (Auth) → Phase 3 (Events)
                                                                  ↓
Phase 4 (Payments + SA Adapters) → Phase 5 (Scanning + AccessLog) → Phase 6 (Financial Ledger) 🆕
                                                                       ↓
Phase 7 (Dashboards) → Phase 8 (Seating + Dynamic Pricing) → Phase 9 (Builder)
                                                                ↓
Phase 10 (Integrations) → Phase 11 (Hardening + Chaos + Fraud) → Phase 12 (Mobile)
                                                                    ↓
Phase 13-20 (New Features: Polls, Merch, Affiliates, CMS, VIP, SEO, Queue)
```

### Parallel Work Opportunities:

- Phase 12 (Mobile) can start after Phase 5 (Scanning API is stable)
- Phase 13-20 (New Features) can be prioritized based on business needs
- Phase 11 (Hardening) should be ongoing throughout development

---

## 🚀 NEXT STEPS

1. **Review & Approve:** Validate this refined roadmap with stakeholders
2. **Prioritize:** Confirm feature priority (MVP first, then new features)
3. **Generate TOON Prompts:** Create atomic TOON prompts for each sub-phase
4. **Start Phase 1.3.6:** Implement Distributed Lock Manager (critical primitive)
5. **Move to Phase 2:** Begin User & Organization implementation with strict tenant isolation

---

**Document Maintainer:** Senior Elixir Architect + Systems Integrator  
**Last Updated:** December 1, 2025  
**Status:** FINAL - READY FOR EXECUTION  
**Version:** 3.0 REFINED

---

END OF ROADMAP
