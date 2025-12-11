# ASH_3_RBAC_MATRIX_VGE – Ash 3.x RBAC Implementation Guide for Voelgoedevents

## Scope

**This file is an Ash implementation companion**, not a competing authority.

**Canonical hierarchy (in order):**
1. `/docs/domain/rbac_and_platform_access.md` – Semantic RBAC, phase timing, business rules
2. `/docs/ash/ASH_3_AI_STRICT_RULES_v2_3_FINAL.md` – Syntax, actor usage, hard bans, testing patterns
3. **This file** – Canonical actor shape, policy matrix, templates, CI checks, agent workflow

If these docs conflict, 1 and 2 win.

---

## 1. Canonical Actor Shape

**All six fields are required. Every Ash.read/create/update/destroy call must pass an actor with this exact shape:**

```elixir
actor = %{
  user_id: uuid | "system",                            # User ID or "system" for background jobs
  organization_id: uuid | nil,                         # Org ID; nil only for platform operations (rare)
  role: :owner | :admin | :staff | :viewer | :scanner_only | :system,
  is_platform_admin: false | true,                     # true only for Super Admin (rare)
  is_platform_staff: false | true,                     # true for platform support staff
  type: :user | :system | :device | :api_key          # Actor type; determines allowed actions
}
```

**RULE:** Every policy can assume these six fields exist. If any field is missing, policy checks fail – this is intentional.

**RULE:** Type field gates permissions by identity kind:
- `:user` – regular tenant user, scoped by organization_id + role
- `:system` – background job, CLI task (rare cross-org operations)
- `:device` – scanner hardware, kiosk (scanning-only)
- `:api_key` – external partner (scoped to granted permissions)

**RULE:** If `actor(:type)` is `:system` or `:device` and the action is NOT explicitly documented as permitted in `/docs/domain/rbac_and_platform_access.md`, policies **must deny by default**.

---

## 2. Canonical Role & Flag Set

### 2.1 Tenant Roles (Only These Atoms)

| Atom | Scope | Use |
|---|---|---|
| `:owner` | Per org | First/primary user; full control (events, members, settings, billing, refunds) |
| `:admin` | Per org | Delegate for owner; create/manage events, members, reporting; no billing |
| `:staff` | Per org | Day-to-day operator; create/manage events, basic reporting |
| `:viewer` | Per org | Stakeholder; read-only (events, reports, dashboards) |
| `:scanner_only` | Per org | On-site check-in; scan tickets, mark attendance, read ticket/seat data only |
| `:system` | Special | System actor for background jobs, migrations, CLI tasks |

### 2.2 Platform Flags (NOT Role Atoms)

| Flag | Type | Use | Reference |
|---|---|---|---|
| `is_platform_admin` | boolean | **Super Admin**: VoelgoedEvents employee + system actors; access all orgs, bypass tenant filters. Never tenant-owned. | `/docs/domain/rbac_and_platform_access.md` §6 |
| `is_platform_staff` | boolean | **Support Staff**: Can view cross-org data for support. Must still have a real tenant role to mutate in that org. | `/docs/domain/rbac_and_platform_access.md` §5 |

**RULE:** Platform flags are NOT roles. A `is_platform_staff: true` actor MUST ALSO have a role (`:staff`, `:admin`, etc.) in each org they access to perform mutations.

---

## 3. Role × ResourceGroup × Action Matrix

**Status Legend:**
- ✅ **Implemented** – tests and resources exist; enforce now
- 🔶 **Planned (Phase X)** – domain doc defined; not yet in code; do not implement until phase is live
- ❌ **Forbidden** – never implement for this role

### 3.1 Accounts / Tenancy

(See `/docs/domain/rbac_and_platform_access.md` §4.1)

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **Organization** | create new org | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ Implemented |
| **Organization** | read settings | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ Implemented |
| **Organization** | update settings | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ Implemented |
| **User** (self) | read own profile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ Implemented |
| **User** (others) | list members | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ Implemented |
| **Membership** | invite user | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ Implemented |
| **Membership** | change role | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ Implemented |
| **Membership** | revoke | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ Implemented |

### 3.2 Events & Ticketing

(See `/docs/domain/rbac_and_platform_access.md` §4.2)

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **Event** | create | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 3) |
| **Event** | read | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔶 Planned (Phase 3) |
| **Event** | update | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 3) |
| **Event** | publish / close | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 3) |
| **Event** | destroy (draft) | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 3) |
| **Ticket** (type) | create | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 3) |
| **Ticket** (instance) | read details | ✅ | ✅ | ✅ | ✅ | 🔶 | ✅ | 🔶 Planned (Phase 3) |
| **Ticket** (instance) | scan / mark scanned | ✅ | 🔶 | 🔶 | ❌ | ✅ | ✅ | 🔶 Planned (Phase 3) |
| **PricingRule** | create / update | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 4) |
| **Coupon** | create / update | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 4) |

**Notes:**
- 🔶 **Ticket scan (Phase 3)**: Owner/admin/staff may scan if on-site; `:scanner_only` is primary.
- 🔶 **Ticket read (scanner_only)**: `:scanner_only` reads tickets only via Scanning domain workflows (mediated access, not general Ticketing access).

### 3.3 Seating

(See `/docs/domain/rbac_and_platform_access.md` §4.3; Phase 4+)

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **Layout** | create / import | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 4) |
| **Layout** | read | ✅ | ✅ | ✅ | ✅ | 🔶 | ✅ | 🔶 Planned (Phase 4) |
| **Seat** | read occupancy | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔶 Planned (Phase 4) |

### 3.4 Orders & Payments

(See `/docs/domain/rbac_and_platform_access.md` §6.1; Phase 4+)

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **Order** | create | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 4) |
| **Order** | read (own org) | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | 🔶 Planned (Phase 4) |
| **Transaction** | read (own org) | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | 🔶 Planned (Phase 4) |
| **Transaction** | capture / void | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 4) |
| **Refund** | issue | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 4) |

**Notes:**
- **Refund authority (Phase 4):** Only `:owner` and `platform_admin` can issue refunds. Domain doc §6.1 explicitly forbids `:admin` and `:staff` from issuing refunds. (Staff/admin may request refunds via workflow, but resource-level policies deny their direct mutation.)

### 3.5 Scanning

(See `/docs/domain/rbac_and_platform_access.md` §4.5; Phase 3+)

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **Scan** | create (process QR) | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | 🔶 Planned (Phase 3) |
| **Scan** | read (own org) | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | 🔶 Planned (Phase 3) |
| **ScanSession** | create (start) | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | 🔶 Planned (Phase 3) |
| **ScanSession** | read own session | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔶 Planned (Phase 3) |

**Notes:**
- Scanner-only access to tickets is always mediated by Scanning workflows (part of Scanning domain, not general Ticketing access).

### 3.6 Analytics

(See `/docs/domain/rbac_and_platform_access.md` §7; Phase 5+)

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **AnalyticsEvent** | write (internal) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🔶 Planned (Phase 5) |
| **FunnelSnapshot** | read (org funnel) | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | 🔶 Planned (Phase 5) |

### 3.7 Finance & Ledger

(See `/docs/domain/rbac_and_platform_access.md` §12.4; Phase 6+)

⚠️ **Extremely sensitive.** Only `:owner` and `platform_admin` permitted.

| Resource | Action | owner | admin | staff | viewer | scanner_only | platform_admin | Status |
|---|---|---|---|---|---|---|---|---|
| **LedgerEntry** | create (audit trail) | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 6) |
| **Settlement** | initiate | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 6) |
| **PayoutConfig** | read | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 6) |
| **PayoutConfig** | update | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | 🔶 Planned (Phase 6) |

**Notes:**
- All Ledger mutations restricted to `:owner` + `platform_admin` only. Highest security tier.
- `:admin`, `:staff`, `:viewer`, `:scanner_only` have ❌ on all Ledger mutations.

---

## 3.8 Matrix → Policy Template Mapping

**Use this to pick the right template from Section 4:**

- **Row has ✅ only for owner + admin writes** → Template §4.2 (Owner/Admin Only)
- **Row has ✅ for owner + admin + staff writes, ❌ for viewer/scanner_only** → Template §4.3 (Staff-Level Writes)
- **All columns ✅ on reads, role-gated writes** → Combine §4.1 (read) + write template
- **Only scanner_only ✅ for custom action** → Template §4.4 (Scanner-Only Action)
- **Only platform_admin ✅ for custom action** → Template §4.5 (Platform Admin Override)
- **Only owner ✅ on all writes (ledger, refunds)** → Variant of §4.2, extremely strict
- **All writes are ❌** → Read-only only; do NOT define create/update/destroy actions

---

## 4. Canonical Ash 3.x Policy Templates

### 4.1 Tenant-Scoped Read (All Roles)

**Use when:** All org members can read a resource.

❌ WRONG:
```elixir
policies do
  policy action_type(:read) do
    authorize_if expr(actor(:user_id) != nil)
    # BUG: No org check; cross-org reads allowed
  end
end
```

✅ RIGHT:
```elixir
policies do
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(organization_id == actor(:organization_id))
  end

  default_policy :deny
end
```

### 4.2 Owner / Admin Only (Gated Writes)

**Use when:** Only owner/admin can create/update/destroy.

❌ WRONG:
```elixir
policies do
  policy action_type(:create) do
    authorize_if expr(organization_id == actor(:organization_id))
    # BUG: All org members can create
  end
end
```

✅ RIGHT:
```elixir
policies do
  policy action_type([:create, :update, :destroy]) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) in [:owner, :admin]
    )
  end

  default_policy :deny
end
```

### 4.3 Staff-Level Writes

**Use when:** Staff + owner/admin can create/update; only owner/admin can destroy.

✅ RIGHT:
```elixir
policies do
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(organization_id == actor(:organization_id))
  end

  policy action_type([:create, :update]) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) in [:owner, :admin, :staff]
    )
  end

  policy action_type(:destroy) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) in [:owner, :admin]
    )
  end

  default_policy :deny
end
```

### 4.4 Scanner-Only Action

**Use when:** Only `:scanner_only` role can perform a custom action.

✅ RIGHT:
```elixir
policies do
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(organization_id == actor(:organization_id))
  end

  policy action_type(:process_scan) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) == :scanner_only
    )
  end

  default_policy :deny
end
```

### 4.5 Platform Admin Override

**Use for:** Platform admin cross-org access (rare; system operations, migrations, CLI).

⚠️ **ONLY use with `skip_tenant_rule: true` context in migrations/bin scripts, NEVER in user-facing code.**

✅ RIGHT:
```elixir
policies do
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    
    # Normal case: tenant-scoped read
    authorize_if expr(
      actor(:is_platform_admin) == false and
      organization_id == actor(:organization_id)
    )

    # Platform admin bypass (cross-org; very rare)
    authorize_if expr(actor(:is_platform_admin) == true)
  end

  policy action_type(:admin_only) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
  end

  default_policy :deny
end
```

### 4.6 Owner-Only (Ledger, Refunds, Sensitive Operations)

**Use for:** Only `:owner` (+ platform_admin) – never staff/admin. E.g., refunds, ledger mutations, payout config.

✅ RIGHT:
```elixir
policies do
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) in [:owner]
    )
    # Platform admin can also read
    authorize_if expr(actor(:is_platform_admin) == true)
  end

  policy action_type([:create, :update, :destroy]) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) == :owner
    )
    # Platform admin can also mutate
    authorize_if expr(actor(:is_platform_admin) == true)
  end

  default_policy :deny
end
```

---

## 5. RBAC-Specific CI Checks

Run before commit.

### 5.1 Canonical Role Atoms (Must be 0 matches)

```bash
# Catch mistyped :scanner, :platform_staff used as roles
rg "actor(:role) (not_in|in) \[" lib/voelgoedevents/ash/resources -A1 -n | \
  grep -v ":owner\|:admin\|:staff\|:viewer\|:scanner_only\|:system"
# Expected: 0
```

### 5.2 Organization Isolation (Verify)

```bash
# Confirm organization_id == actor(:organization_id) in tenant policies
rg "policies do" lib/voelgoedevents/ash/resources -A20 -n | \
  grep -B20 "default_policy :deny" | \
  grep -v "organization_id == actor(:organization_id)" | wc -l
# Expected: 0 (or only non-tenant resources like Organization itself)
```

### 5.3 Default Policy Deny (Must exist)

```bash
# Every resource with policies must end with default_policy :deny
rg "policies do" lib/voelgoedevents/ash/resources -A25 -n | \
  grep "default_policy :deny"
# Expected: all tenant-scoped resources present
```

### 5.4 Platform Admin Usage (Manual verify)

```bash
# Platform admin checks should only appear in platform-scoped resources
rg "is_platform_admin" lib/voelgoedevents/ash/resources -n
# Manual review: confirm only in Organization, Ledger, Refund, or marked 🔶 PLANNED
```

### 5.5 Refund Restrictions (Manual verify)

```bash
# Confirm admin and staff have ❌ on refund mutations
rg "refund" lib/voelgoedevents/ash/resources -i -n
# Manual review: policies must forbid :admin and :staff on issue/create actions
```

---

## 6. Agent Workflow (DO NOT DEVIATE)

### Step 1: Load Prerequisites (In Order)

1. `/docs/ash/ASH_3_AI_STRICT_RULES_v2_3_FINAL.md` (Section 5: resource template; Section 4: testing)
2. `/docs/domain/rbac_and_platform_access.md` (identify resource group + phase)
3. **This file** (Section 3: matrix; Section 3.8: template mapping; Section 4: templates)

### Step 2: Identify Resource Group & Phase

- Which section of matrix? (Accounts, Events, Ticketing, Scanning, Finance, etc.)
- What's the status? (✅ Implemented, 🔶 Planned, ❌ Forbidden)
- If 🔶 Planned, check roadmap before implementing

### Step 3: Check Matrix for Applicable Roles

- Which roles can read? Create? Update? Destroy?
- Any 🔶 edge cases?
- Is resource tenant-scoped (include `organization_id`) or platform-scoped?

### Step 4: Use Template Mapping (Section 3.8)

- Match the row's permission pattern to a decision
- This tells you exactly which template from Section 4 to use

### Step 5: Implement Resource

- Start with template from Strict Rules §5
- Replace policies block with template from Section 4 (as determined in step 4)
- Add `organization_id` attribute + multitenancy block (if tenant-scoped)
- Include all six actor fields in comparisons (Section 1)
- End with `default_policy :deny`

### Step 6: Write Three Test Cases

(Strict Rules §4.2 – exact pattern required)

- ✅ **Authorized**: actor with correct org + role succeeds
- ❌ **Unauthorized (wrong org or insufficient role)**: actor from wrong org or with insufficient role → Forbidden
- ❌ **Nil actor (unauthenticated)**: actor nil → Forbidden

### Step 7: Run RBAC Audit

```bash
rg "policy \[" lib/voelgoedevents/ash/resources --type elixir -n       # 0 matches
rg "default_policy :deny" lib/voelgoedevents/ash/resources -n          # all resources
rg "organization_id == actor(:organization_id)" lib/voelgoedevents/ash/resources -n  # tenant resources
```

### Step 8: Run Generic Audit (Strict Rules §16)

```bash
# All hard failure checks from Strict Rules Section 16
# Confirm all return expected 0 or verified
```

### Step 9: Compile & Test

```bash
mix compile
mix test test/voelgoedevents/ash/resources/<DOMAIN>/<resource>_test.exs
```

### Step 10: Commit Only If All Pass

---

## 7. Status & References

| Document | Purpose | Authority |
|---|---|---|
| `/docs/domain/rbac_and_platform_access.md` | Semantic RBAC, phase timing, business rules | **PRIMARY** |
| `/docs/ash/ASH_3_AI_STRICT_RULES_v2_3_FINAL.md` | Syntax, actor, hard bans, testing | **PRIMARY** |
| `/docs/architecture/07_security_and_auth.md` | Threat model, identity types, token handling | Reference |
| **This file** (ASH_3_RBAC_MATRIX_VGE.md) | Canonical actor shape, matrix, templates, CI, workflow | **Companion** |

---

## 8. What This File Is

✅ Canonical actor shape (all six fields required)  
✅ Quick reference matrix (role × resource × action + phase status)  
✅ Policy template decision tree  
✅ Six reusable Ash 3.x policy templates (✅ RIGHT vs ❌ WRONG)  
✅ RBAC-specific CI checks  
✅ Mechanical agent workflow (deterministic, ten steps)  

**NOT:**
❌ A rewrite of domain RBAC spec (use that for phase timing, business rules)  
❌ A rewrite of Ash syntax rules (use Strict Rules for those)  
❌ A source of truth on role definitions (domain doc owns that)  

**If in doubt: check the primary docs above, then use this file for templates and CI checks.**

---

**Last Updated:** December 11, 2025  
**Status:** CANONICAL COMPANION – Subordinate to domain + Strict Rules docs; verified against domain RBAC spec  
**Audience:** Ash 3.x developers, coding agents implementing resources with RBAC
