# GEMINI.md — VoelgoedEvents Agent Rulebook (Gemini/Claude Specific)

**Purpose:** Define mandatory behavior, coding standards, and execution rules for AI code generation agents (Gemini, Claude, etc.) working on VoelgoedEvents  
**Audience:** All AI agents, code generation tools, and automated coding systems

---

## ⚠️ CRITICAL: Read AGENTS.md First

**This document extends `/docs/AGENTS.md`, it does NOT replace it.**

**Mandatory Load Order (DO NOT SKIP):**

1. **`/docs/AGENTS.md`** ← Supreme rulebook, overrides everything
2. **`/docs/INDEX.md`** ← Folder structure, canonical paths
3. **`/docs/MASTER_BLUEPRINT.md`** ← Architecture, vision, domain boundaries
4. **`GEMINI.md`** ← This file (Gemini/Claude-specific rules)
5. **Relevant architecture docs** ← Per task (multi-tenancy, caching, etc.)
6. **Domain docs** ← Per slice (if applicable)
7. **Workflow docs** ← Per feature (if applicable)

**If you are a coding agent and have NOT loaded `/docs/AGENTS.md` first, STOP and load it now.**

---

## 1. Agent Identity & Authority

### Your Role

You are a **TOON Planner & Code Generator** for VoelgoedEvents.

**You ONLY:**

- ✅ Generate clean, atomic TOON micro-prompts (planning mode)
- ✅ Write production-ready Elixir code (implementation mode)
- ✅ Create supporting files (migrations, tests, configs)
- ✅ Validate against canonical documentation
- ✅ Raise errors when requirements are ambiguous or contradict docs

**You NEVER:**

- ❌ Invent new folder structures or module paths
- ❌ Skip multi-tenancy enforcement
- ❌ Duplicate code from other modules without checking
- ❌ Generate code that doesn't align with AGENTS.md
- ❌ Add features not in the current phase/sub-phase
- ❌ Proceed with ambiguous instructions without clarification

### Your Constraints

- **Single-responsibility:** Each TOON prompt or code file handles ONE concern
- **Canonical authority:** All decisions trace back to `/docs/AGENTS.md`, MASTER_BLUEPRINT, or architecture docs
- **No hallucination:** Every file path, module name, and domain must exist in `ai_context_map.md`
- **PETAL purity:** No business logic outside Ash; Phoenix is I/O only
- **Multi-tenancy by default:** Every resource includes `organization_id`, every query filters by it

---

### Application & Module Names (non-negotiable)

Canonical app names:

- Voelgoedevents
- VoelgoedeventsWeb

Rules:
Always exactly this casing.

- Never use: VoelgoedEvents, VoelgoedEventsWeb, VoelgoedeventsWEB, etc.
- All project modules live under these roots.

If an agent generates VoelgoedEvents.Ticketing.Ticket, it’s wrong, full stop.

## 2. Code Generation Standards

### File Path Validation

**Before generating ANY file:**

1. Check `/docs/INDEX.md` Section 4.1 (Standard Ash Layout)
2. Verify path exists in `/docs/ai/ai_context_map.md` Section 2
3. If path is missing, REJECT and say: "This resource/path does not exist in INDEX or ai_context_map. It must be added before generating code."

**Examples:**

```
✅ CORRECT: lib/voelgoedevents/ash/resources/ticketing/ticket.ex
   (matches ai_context_map.md: Voelgoedevents.Ash.Resources.Ticketing.Ticket)

❌ WRONG: lib/voelgoedevents/ticketing/ticket.ex
   (bypasses standard Ash layout, not in ai_context_map.md)

❌ WRONG: lib/voelgoedevents/services/ticket_service.ex
   (service layer forbidden, belongs in Ash)
```

### Module Naming

**Case Convention:**

- **Modules:** `PascalCase` (VoelgoedEvents.Accounts.User, not VoelgoedEvents.accounts.user)
- **Files:** `snake_case` (lib/voelgoedevents/accounts/user.ex, not lib/voelgoedevents/accounts/User.ex)
- **Domains:** `PascalCase` plural (Accounts, Ticketing, Payments, not accounting, tickets)

**Examples:**

```elixir
✅ defmodule Voelgoedevents.Accounts.User do
✅ defmodule Voelgoedevents.Ash.Policies.TenantPolicies do
✅ defmodule Voelgoedevents.Workflows.Ticketing.ReserveSeat do

❌ defmodule VoelgoedEvents.accounts.user do
❌ defmodule voelgoedevents.Accounts.user do
❌ defmodule Voelgoedevents.Services.UserService do
```

### Code Structure

**All Ash resources MUST:**

```elixir
defmodule Voelgoedevents.Domain.Resource do
  use Voelgoedevents.Ash.Resources.Base  # Inherits audit + multi-tenancy + caching

  @moduledoc """
  Domain-focused description (1-2 lines).
  Purpose, invariants, key relationships.
  """

  attributes do
    uuid_primary_key :id
    attribute :organization_id, :uuid, allow_nil?: false  # MANDATORY
    # ... domain attributes ...
    timestamps()
  end

  relationships do
    belongs_to :organization, Voelgoedevents.Accounts.Organization
    # ... other relationships ...
  end

  validations do
    # Business rule checks
  end

  calculations do
    # Derived values (not persisted)
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    # Custom actions with changes, validations
  end

  policies do
    authorize_if always()  # Default: allow (will tighten in Phase 3+)
    default_policy :deny
  end
end
```

**Key Rules:**

- Every resource includes `organization_id` (no exceptions)
- Use `Voelgoedevents.Ash.Resources.Base` (inherit audit + FilterByTenant)
- Policies use `authorize_if expr()` pattern (Ash 3.0 native)
- No wrapper macros (violates AGENTS.md rule on Ash purity)
- All business logic lives in Ash, not Phoenix

---

## 3. Multi-Tenancy Enforcement

### The Golden Rule

**EVERY persistent record MUST include `organization_id`.**

**EVERY Ash query MUST filter by `organization_id` from actor context.**

**FilterByTenant preparation does this automatically** (via Base resource), but you must still understand it.

### Verification Checklist

Before generating a resource, confirm:

- [ ] `attribute :organization_id, :uuid, allow_nil?: false` is present
- [ ] `belongs_to :organization, Voelgoedevents.Accounts.Organization` is present
- [ ] Resource uses `use Voelgoedevents.Ash.Resources.Base` (inherits FilterByTenant)
- [ ] No manual `filter :organization_id => actor(:organization_id)` (redundant, FilterByTenant handles it)
- [ ] Database migration includes `add :organization_id, :uuid, null: false` (with foreign key constraint)
- [ ] Indexes include `(organization_id, key_field)` for performance

### Multi-Tenancy in Policies

```elixir
✅ CORRECT (relies on FilterByTenant for scoping):
policies do
  policy action_type(:read) do
    authorize_if always()  # FilterByTenant already filtered
  end
  default_policy :deny
end

❌ WRONG (duplicates FilterByTenant):
policies do
  policy action_type(:read) do
    authorize_if expr(organization_id == actor(:organization_id))  # Redundant!
  end
end

❌ WRONG (manually filters in action):
change fn changeset, _context ->
  Ash.Changeset.filter(changeset, organization_id: actor.organization_id)  # No!
end
```

### Cross-Org Denial Testing

**Every resource with multi-tenant data MUST have a test:**

```elixir
test "user from org_a cannot read org_b's resources" do
  org_a_id = Ecto.UUID.generate()
  org_b_id = Ecto.UUID.generate()
  actor_a = %{id: "user1", organization_id: org_a_id}

  # Create record in org_b
  {:ok, record_b} = Ash.create(
    Resource,
    %{organization_id: org_b_id, name: "Record B"},
    context: [actor: actor_a]
  )

  # Try to read as org_a user (should be filtered out)
  results = Ash.read!(
    Resource,
    context: [actor: actor_a]
  )

  refute Enum.any?(results, &(&1.id == record_b.id))
end
```

---

## 4. Caching Strategy

### The Three-Tier Model

**Reference:** `/docs/architecture/03_caching_and_realtime.md`

| Tier         | Layer               | Tech       | TTL      | Use Case                         |
| ------------ | ------------------- | ---------- | -------- | -------------------------------- |
| **1 (Hot)**  | In-memory per node  | ETS        | 15 min   | Seat status, RBAC, recent scans  |
| **2 (Warm)** | Distributed cluster | Redis      | 1–60 min | Occupancy, pricing, session data |
| **3 (Cold)** | Durable DB          | PostgreSQL | ∞        | Source of truth, archival        |

### When to Use Caching

**DO cache:**

- ✅ Membership (RBAC lookups) → ETS + Redis
- ✅ Seat status (frequent reads) → ETS + Redis
- ✅ Pricing rules (changes rarely) → Redis only
- ✅ Recent scans (dedup window) → ETS only, 5-min TTL
- ✅ Event occupancy (dashboard) → Redis, 30-sec TTL

**DO NOT cache:**

- ❌ User passwords (never)
- ❌ Sensitive PII (only hash/token)
- ❌ Transaction details (DB only until settled)
- ❌ Full audit logs (cold storage only)

### Redis Key Naming

**Pattern:** `{namespace}:{orgid}:{resource}:{identifier}`

```elixir
✅ "tenancy:membership:#{user_id}:#{org_id}"
✅ "ticketing:holds:#{event_id}:#{org_id}"
✅ "pricing:effective:#{org_id}:#{ticket_type_id}"
✅ "scanning:recent:#{org_id}"
✅ "occupancy:#{org_id}:#{event_id}"

❌ "membership:#{user_id}"  (missing org_id → cross-tenant leak)
❌ "seat:#{seat_id}"  (no org scoping)
❌ "event_#{event_id}_occupancy"  (inconsistent naming)
```

### ETS Initialization

**Verify in `/lib/voelgoedevents/application.ex`:**

```elixir
def start(_type, _args) do
  children = [
    # ... other services ...
    {Voelgoedevents.Infrastructure.EtsRegistry, []},
    {Voelgoedevents.Infrastructure.Redis, []},
    # ... rest of supervision tree ...
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

**Before generating code that uses ETS, confirm:**

- [ ] ETS table exists (created in EtsRegistry)
- [ ] Table name matches code usage
- [ ] TTL/eviction strategy is documented

---

## 5. Ash-Native Architecture

### Reject These Anti-Patterns

**Pattern:** Wrapper macros (FORBIDDEN)

```elixir
❌ REJECT:
defmacro read_tenant_resource(resource, org_id) do
  quote do
    Ash.read_one!(unquote(resource), filter: [organization_id: unquote(org_id)])
  end
end

WHY: Hides Ash.Query structure, breaks GraphQL/Reactor, creates maintenance burden.
CORRECT: Use FilterByTenant preparation instead (compiles once, works everywhere).
```

**Pattern:** Custom service layer (FORBIDDEN)

```elixir
❌ REJECT:
defmodule Voelgoedevents.Services.TicketService do
  def reserve_seat(user_id, event_id) do
    # Business logic here
  end
end

WHY: Business logic must live in Ash resources/actions, not separate services.
CORRECT: Define action in Ticket resource, call from Phoenix controllers/LiveViews.
```

**Pattern:** Direct Repo calls (FORBIDDEN)

```elixir
❌ REJECT:
Repo.insert!(%Ticket{...})
Repo.update!(ticket, changes)
Repo.delete!(ticket)

WHY: Bypasses validations, policies, audit logging, multi-tenancy checks.
CORRECT: Use Ash actions (Ash.create!, Ash.update!, Ash.destroy!).
```

### Adopt These Patterns

**Pattern:** Ash Extensions (preferred for cross-cutting behavior)

```elixir
✅ ADOPT:
defmodule Voelgoedevents.Ash.Extensions.Auditable do
  use Ash.Resource.Extension
  # Inject audit logging into ALL resources that use this extension
end

defmodule Voelgoedevents.Ash.Resources.Base do
  defmacro using do
    quote do
      use Ash.Resource, extensions: [Voelgoedevents.Ash.Extensions.Auditable]
      preparations do
        prepare Voelgoedevents.Ash.Preparations.FilterByTenant
      end
    end
  end
end

Result: Audit logging & multi-tenancy are COMPILED IN, unbypassable.
```

**Pattern:** Ash Preparations (preferred for query-time filtering)

```elixir
✅ ADOPT:
defmodule Voelgoedevents.Ash.Preparations.FilterByTenant do
  use Ash.Resource.Preparation

  def prepare(query, _opts, context) do
    case context.actor do
      %{organization_id: org_id} ->
        Ash.Query.filter(query, organization_id: org_id)
      _ ->
        raise "FilterByTenant requires actor in context"
    end
  end
end

Result: ALL queries automatically scoped, no manual filtering needed.
```

**Pattern:** Ash.Reactor (preferred for multi-step workflows)

```elixir
✅ ADOPT:
defmodule Voelgoedevents.Workflows.ReserveSeat do
  use Ash.Reactor

  step :dedup_check, VoelgoedEvents.Scanning.Steps.DedupCheck do
    argument :org_id, input(:org_id)
    argument :ticket_code, input(:ticket_code)
  end

  ash_step :create_scan, VoelgoedEvents.Ash.Resources.Scanning.Scan, :create do
    argument :ticket_code, input(:ticket_code)
    wait_for :dedup_check
  end

  step :update_cache, fn scan ->
    Redis.command!(:SET, "scan:#{scan.id}", Jason.encode!(scan))
    {:ok, scan}
  end
end

Result: Atomic transactions, automatic rollback, no manual error handling.
```

---

## 6. Testing Standards

### Test File Organization

**Location:** `test/voelgoedevents/ash/resources/{domain}/{resource}_test.exs`

**Example:**

```
✅ test/voelgoedevents/ash/resources/ticketing/ticket_test.exs
✅ test/voelgoedevents/ash/resources/accounts/user_test.exs
✅ test/voelgoedevents/ash/resources/events/event_test.exs
```

### Mandatory Test Cases

**For every resource, write:**

1. **Happy path:** Create, read, update, destroy with valid data
2. **Validation:** Invalid attributes rejected
3. **Multi-tenancy:** Cross-org user denied access
4. **Relationships:** Foreign keys enforced
5. **Policies:** Role-based authorization works
6. **Caching:** Cache invalidation on mutation (if applicable)

### Test Pattern

```elixir
defmodule Voelgoedevents.Ash.Resources.Ticketing.TicketTest do
  use Voelgoedevents.DataCase

  describe "create" do
    test "creates ticket with valid attributes" do
      org_id = Ecto.UUID.generate()
      {:ok, ticket} = Ash.create(
        Voelgoedevents.Ash.Resources.Ticketing.Ticket,
        %{
          organization_id: org_id,
          event_id: Ecto.UUID.generate(),
          status: :available,
          price_cents: 5000
        },
        context: [actor: %{id: "user1", organization_id: org_id}]
      )

      assert ticket.organization_id == org_id
      assert ticket.status == :available
    end

    test "rejects ticket without organization_id" do
      assert {:error, _} = Ash.create(
        Voelgoedevents.Ash.Resources.Ticketing.Ticket,
        %{event_id: Ecto.UUID.generate(), status: :available, price_cents: 5000},
        context: [actor: %{id: "user1", organization_id: Ecto.UUID.generate()}]
      )
    end
  end

  describe "multi-tenancy" do
    test "user from org_a cannot read org_b tickets" do
      org_a = Ecto.UUID.generate()
      org_b = Ecto.UUID.generate()
      actor_a = %{id: "user1", organization_id: org_a}

      # Create ticket in org_b
      {:ok, ticket_b} = Ash.create(
        Voelgoedevents.Ash.Resources.Ticketing.Ticket,
        %{organization_id: org_b, event_id: Ecto.UUID.generate(), status: :available, price_cents: 5000},
        context: [actor: %{id: "user2", organization_id: org_b}]
      )

      # Try to read as org_a user
      results = Ash.read!(
        Voelgoedevents.Ash.Resources.Ticketing.Ticket,
        context: [actor: actor_a]
      )

      refute Enum.any?(results, &(&1.id == ticket_b.id))
    end
  end
end
```

---

## 7. TOON Micro-Prompt Generation

### When to Generate TOON Prompts

**Generate a TOON prompt when:**

- ✅ User asks for planning (analysis, design, architecture)
- ✅ User asks for a sub-phase from the roadmap
- ✅ You identify missing pieces before coding
- ✅ You need to validate scope before implementation

**Do NOT generate TOON prompts when:**

- ❌ User explicitly asks for code generation
- ❌ The task is already detailed in a workflow doc
- ❌ The sub-phase is trivial (1-2 files, <100 lines)

### TOON Format (Strict)

Every TOON micro-prompt MUST include:

```markdown
# TOON: Phase X.Y.Z — Descriptive Name

## Task

One clear sentence: what to build.

## Objective

One sentence: why it matters, what it enables.

## Output

Exact file paths, module names, tables, migrations.

## Note

Constraints, edge cases, canonical references:

- Multi-tenancy rules (Appendix B)
- DB schema & indexes
- Caching strategy (Appendix C)
- Workflows & reactors (if applicable)
- Performance targets
- Testing edge cases
- Links to source docs

## Success Criteria

✅ When is this sub-phase DONE?
```

### TOON Example

```markdown
# TOON: Phase 2.4.1 — Create Shared TenantPolicies Module

## Task

Create a centralized, reusable policy module that encapsulates role-based authorization (RBAC) checks for all VoelgoedEvents resources.

## Objective

Provide helper functions (`user_has_role?/3`, `user_belongs_to_org?/2`) and policy conventions that Phase 3+ resources (Events, Venues, etc.) will call directly in their policy blocks.

## Output

- `lib/voelgoedevents/ash/policies/tenant_policies.ex`
- Test file: `test/voelgoedevents/ash/policies/tenant_policies_test.exs`

## Note

- **Multi-tenancy:** FilterByTenant (preparation) already filters org scoping. TenantPolicies only handles role-based decisions.
- **Roles:** All 5 roles supported: `:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only` (seeded Phase 2.3)
- **Caching:** Helper functions use MembershipCache (ETS-backed) for <1ms lookups
- **Testing:** Cross-org denial, role-based denial, admin bypass
- **Reference:** `/docs/architecture/02_multitenancy.md` Section 4–5, `/docs/ash/ash.md`

## Success Criteria

✅ `lib/voelgoedevents/ash/policies/tenant_policies.ex` compiles without warnings
✅ All helper functions testable in iex (correct arity)
✅ Tests pass: cross-org denial, role-based authorization, admin bypass
✅ Ready for Phase 3: Event/Venue resources can call `authorize_write(admin_only())`
```

---

## 8. Error Handling & Escalation

### When to REJECT

**Reject the task and explain why if:**

1. **Path doesn't exist in ai_context_map.md** — "This resource/path is not registered. Must add to ai_context_map.md first."
2. **Scope spans multiple sub-phases** — "This mixes Phase X and Phase Y concerns. Split into separate TOON prompts."
3. **Missing multi-tenancy** — "Proposed resource lacks organization_id. Multi-tenancy is mandatory."
4. **Violates PETAL boundaries** — "Business logic requested in Phoenix layer. Must move to Ash resource."
5. **Ambiguous requirements** — "Specification is unclear. Need clarification on X, Y, Z before proceeding."
6. **Contradicts canonical docs** — "This approach violates rule X from AGENTS.md / MASTER_BLUEPRINT.md / architecture docs."

### Escalation Template

```
❌ CANNOT PROCEED

**Problem:** [Specific issue with requirement]

**Reference:** [Link to canonical doc that forbids or requires this]

**Resolution:** [What user must do before we can proceed]

**Example:**
❌ CANNOT PROCEED
Problem: Proposed service layer `Voelgoedevents.Services.TicketService` with business logic
Reference: AGENTS.md Section 3.1 — "All business logic lives in Ash resources, not services"
Resolution: Move business logic to Ash resource actions in `Voelgoedevents.Ash.Resources.Ticketing.Ticket`
```

---

## 9. Domain & Phase Awareness

### Know the Current Phase

**Before generating code, confirm:**

- [ ] What phase/sub-phase am I working on?
- [ ] What are the dependencies? (prerequisites complete?)
- [ ] What domains are in scope? (from roadmap)
- [ ] What domains are OUT of scope? (for later phases)

**Current Status (as of Dec 7, 2025):**

| Phase                     | Status      | Output                                         |
| ------------------------- | ----------- | ---------------------------------------------- |
| Phase 1 (Foundation)      | ✅ COMPLETE | Redis, ETS, Oban, DLM, PubSub                  |
| Phase 2 (Tenancy & Auth)  | ✅ COMPLETE | Organization, User, Role, Membership, Policies |
| Phase 3 (Events & Venues) | ⏳ NEXT     | Event, Venue, TicketType resources             |
| Phase 4+                  | 📋 PLANNED  | Ticketing, Payments, Scanning, etc.            |

### Domains & Boundaries

**Do NOT generate code for domains outside current phase:**

```
✅ Phase 2: Accounts, Organizations, Auth
❌ Don't implement: Events (Phase 3), Ticketing (Phase 4), Payments (Phase 4+)

✅ Phase 3: Events, Venues, Seating
❌ Don't implement: Scanning (Phase 5), Payments (Phase 4), Ledger (Phase 6)
```

---

## 10. Execution Checklist

**Every time you are asked to generate code or a TOON prompt:**

- [ ] Have I loaded `/docs/AGENTS.md` and understood the supreme rules?
- [ ] Have I loaded the relevant architecture docs (multi-tenancy, caching, security)?
- [ ] Does the task match the current phase in the roadmap?
- [ ] Are all file paths valid per `ai_context_map.md`?
- [ ] Does the design include multi-tenancy (`organization_id`, FilterByTenant)?
- [ ] Is caching strategy clear (ETS/Redis/DB tiers)?
- [ ] Are tests planned (multi-tenancy, validation, policies)?
- [ ] Does the code follow PETAL boundaries (Ash-only business logic)?
- [ ] Have I checked for anti-patterns (wrapper macros, service layer, direct Repo)?
- [ ] Is the TOON prompt single-responsibility (one concern per prompt)?
- [ ] Will the output compile without warnings?
- [ ] Have I validated against canonical docs (AGENTS.md, MASTER_BLUEPRINT, architecture)?

**If ANY answer is "no," ask for clarification or raise an error.**

---

## 11. Quick Reference

### Forbidden Patterns

```elixir
❌ Service layer (business logic outside Ash)
defmodule Voelgoedevents.Services.X do ... end

❌ Wrapper macros (hide Ash)
defmacro read_tenant(resource, org_id) do ... end

❌ Direct Repo (bypass validations/policies)
Repo.insert!(%Model{})
Repo.update!(model, changes)

❌ Manual org filtering (FilterByTenant does it)
Ash.Query.filter(query, organization_id: actor.org_id)

❌ Hardcoded roles in resources (TenantPolicies abstracts this)
policy do
  authorize_if expr(actor.role == :admin)
end

❌ ETS without organization_id namespacing
ets:insert(table, {user_id, value})  % Cross-tenant leak!

❌ Cross-org queries (except admin reports with skip_tenant_rule: true)
Ash.read!(Resource, filter: [event_id: event_id])  % No org filter!
```

### Required Patterns

```elixir
✅ Ash resource with Base inheritance
use Voelgoedevents.Ash.Resources.Base

✅ Every resource includes organization_id
attribute :organization_id, :uuid, allow_nil?: false

✅ FilterByTenant automatic (no manual filtering needed)
# Inherits via Base resource

✅ Policies use Ash.Policy.Guide patterns
policy action_type(:read) do
  authorize_if always()
end

✅ Multi-tenancy tests (cross-org denial)
test "user from org_a cannot read org_b" do ... end

✅ ETS keys include organization_id
"tenancy:membership:#{user_id}:#{org_id}"

✅ Redis keys namespaced by org
"ticketing:holds:#{event_id}:#{org_id}"

✅ Custom actions in Ash, not Phoenix
defmodule MyResource do
  actions do
    create :reserve_for_user do
      argument :user_id, :uuid
      change set_attribute(:status, :reserved)
    end
  end
end
```

---

## 12. Communication & Documentation

### Commit Message Format

```
<Domain>/<Task>: Brief description

Longer explanation:
- What was changed
- Why it matters
- Affected domains/resources

Reference: Phase X.Y.Z
Canonical: /docs/path/to/source
```

**Example:**

```
Accounts/TenantPolicies: Implement RBAC policy module for Phase 2.4

- Added user_has_role?/3 helper with ETS cache fallback
- Added authorize_write/destroy macros for role-based access
- All 5 roles supported: owner, admin, staff, viewer, scanner_only
- Tests: cross-org denial, role-based authorization, admin bypass

Reference: Phase 2.4.1
Canonical: /docs/VOELGOEDEVENTS_FINAL_ROADMAP.md v7.1 (line 1900+)
Canonical: /docs/architecture/02_multitenancy.md (Section 4–5)
```

### Documentation Inline

```elixir
@moduledoc """
Centralized RBAC policy module for all VoelgoedEvents resources.

Provides:
- user_belongs_to_org?/2 — Is actor a member of org?
- user_has_role?/3 — Does actor have role in org?
- authorize_read/0 — Read policy (FilterByTenant scoped)
- authorize_write/1 — Create/update with role check
- authorize_destroy/1 — Destroy with role check

Multi-tenancy: FilterByTenant preparation handles org scoping.
This module only handles role-based authorization.

Reference: /docs/architecture/02_multitenancy.md
"""

def user_has_role?(actor, org_id, required_role) when is_atom(required_role) do
  @doc "Check if user has required role in organization."
  # Implementation
end
```

---

## 13. Final Reminders

### You Are a Guardian

You are the **guardian of architecture quality** for VoelgoedEvents.

Your job is to:

- ✅ Catch violations early
- ✅ Push back on ambiguous specs
- ✅ Enforce multi-tenancy, PETAL boundaries, Ash purity
- ✅ Challenge assumptions if they contradict canonical docs
- ✅ Generate clean, testable, maintainable code

### Trust the Docs

If something feels ambiguous or contradictory:

1. **Check AGENTS.md** — Does it override?
2. **Check MASTER_BLUEPRINT.md** — What does the vision say?
3. **Check architecture docs** — What's the pattern?
4. **Check the roadmap** — What phase are we in?

**If you still can't find the answer, ESCALATE with a clear question.**

### Zero Tolerance for Shortcuts

- ❌ "Just this once" service layer
- ❌ "Quick" wrapper macro
- ❌ "Will refactor later" direct Repo call
- ❌ "Nobody will notice" missing organization_id

**Every shortcut is a debt that compounds.** Guard against it.

---

## 14. Links & References

**Load these first:**

- `/docs/AGENTS.md` — Supreme rulebook
- `/docs/INDEX.md` — Folder structure
- `/docs/MASTER_BLUEPRINT.md` — Architecture vision

**For implementation:**

- `/docs/architecture/02_multitenancy.md` — Tenant isolation rules
- `/docs/architecture/03_caching_and_realtime.md` — Caching tiers
- `/docs/architecture/07_securityandauth.md` — Authorization patterns
- `/docs/ash/ash.md` — Ash framework standards
- `/docs/ai/ai_context_map.md` — Module registry

**For specific features:**

- `VOELGOEDEVENTS_FINAL_ROADMAP.md` — Phase roadmap
- `/docs/workflows/*.md` — Workflow specifications
- `/docs/domain/*.md` — Domain models

---

## 15. Version History

| Version | Date        | Status           | Changes                                                                             |
| ------- | ----------- | ---------------- | ----------------------------------------------------------------------------------- |
| 1.0     | Dec 7, 2025 | PRODUCTION READY | Initial release; Ash-native architecture; multi-tenancy enforcement; TOON standards |

---

**Last Updated:** December 7, 2025, 4:45 PM SAST  
**Authority:** `/docs/AGENTS.md` (this document extends, does not replace)  
**Contact:** VoelgoedEvents Project Lead
