# RBAC and Platform Access Specification

**Document:** `/docs/domain/rbac_and_platform_access.md`  
**Status:** Production-ready specification for INDEX.md integration  
**Date:** December 9, 2025 (Final)  
**Alignment:** Phase 2 (Tenancy, Accounts & RBAC), Phase 4 (Payments), Phase 6 (Ledger), Phase 7 (Dashboards)  
**References:**
- `/docs/architecture/02_multi_tenancy.md` — Tenant isolation model
- `/docs/architecture/07_security_and_auth.md` — Authentication & identity types
- `/docs/VOELGOEDEVENTS_FINAL_ROADMAP.md` — Phase 2, Phase 4, Phase 6, Phase 7
- `/docs/ai/ai_context_map.md` — Module registry & AI routing
- `/docs/AGENTS.md` — Ash 3.x policy semantics

---

## Glossary

**Platform Admin (Super Admin):** User with `is_platform_admin == true`. Has platform-wide authority across all organizations, including override capability in emergency scenarios. Works for VoelgoedEvents. Can view any organization's data in platform dashboards without membership.

**Platform Staff:** User with `is_platform_staff == true`. Works for VoelgoedEvents and is assigned to specific organizations to provide support. Operates under their assigned tenant role (usually `:admin`, never `:owner`) inside each organization. Cannot be removed/demoted by tenants while flag is true. Protected by policy.

**System Actor:** Virtual actor type (`:system`) used by background jobs and workflows. Always includes `organization_id`. MUST NOT switch organizations mid-execution. Used only for explicitly documented, org-scoped automated operations.

**Actor Context:** The authorization context populated per-request containing `user_id`, `organization_id`, `role`, `is_platform_staff`, `is_platform_admin`, `type`. Never trust `organization_id` from client; derive from session, API key, or device token. If actor type is `:system` or `:device`, only explicitly permitted actions are allowed.

**Refund Origin:** Source of a refund. Either `:tenant_initiated` (owner starts it), `:external_psp` (payment gateway initiates via webhook), or `:super_admin_override` (Super Admin forces refund).

**Settlement:** Payout of accumulated funds to tenant organizer. Includes ledger reconciliation and PSP transfer. Only triggered by owner or Super Admin. Subject to non-RBAC preconditions (PSP config, ledger balance, timing).

**Payout Destination:** The bank account, payment method, or provider account where settlement funds are directed. Changes are restricted to owner and Super Admin, audit-logged.

---

## Terminology Consistency Rules

To prevent terminology drift in future edits:

| Term | Meaning | NOT To Be Confused With |
|------|---------|------------------------|
| **staff** | Tenant employee with `:staff` role | platform staff |
| **platform staff** | VoelgoedEvents employee assigned to org (`is_platform_staff: true`) | tenant staff |
| **viewer** | Tenant stakeholder with `:viewer` role (read-only) | scanner-only |
| **scanner-only** | Tenant user with `:scanner_only` role (device access only) | scanning device |
| **scanning device** | Non-user hardware/app authenticated via `device_token` | scanner-only user |
| **Super Admin** | Platform admin with `is_platform_admin: true` | platform staff |
| **owner** | Tenant organization owner with `:owner` role | platform staff or super admin |

---

## 1. Purpose & Scope

This document defines the complete role-based access control (RBAC) model for VoelgoedEvents.

**What this specification covers:**

- **Global identity properties** — `is_platform_admin`, `is_platform_staff` flags on User
- **Five tenant-scoped roles** — `:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only` (and only these)
- **Capability boundaries** — Exactly which roles can perform which actions in which domains
- **Platform staff modelling** — How platform staff are represented (flag + existing role, not a new role)
- **Financial permissions** — Strict controls on refunds, settlements, payout configuration
- **Multi-tenancy enforcement** — How RBAC integrates with tenant isolation
- **Ash 3.x policy patterns** — Concrete, correct implementations for resource authorization
- **Edge actors** — Scanner devices, API keys, background jobs, webhooks
- **System actor constraints** — Invariants that prevent cross-tenant leakage in workflows

**This specification is NOT:**

- Generic RBAC theory
- Permission inheritance across organizations
- A new role enumeration (no `:platform_manager`, `:support`, or custom roles)

**Conflict resolution:** If this document contradicts Phase 2 domain spec or architecture docs, those docs take precedence until reconciled with this spec.

---

## 2. Global Identity Model

VoelgoedEvents distinguishes between **global identity properties** and **per-tenant authority**.

### 2.1 Global Identity Properties (User Flags)

These are **global, platform-wide properties** set on the `User` resource:

#### `is_platform_admin: boolean`

- Default: `false`
- Meaning: User is a VoelgoedEvents Super Admin with platform-wide authority
- Set by: VoelgoedEvents technical staff only (out-of-band, never via UI)
- Effects:
  - Can create/archive organizations
  - Can assign or revoke `is_platform_staff` on any user
  - Can **override** normal RBAC in emergency scenarios (refunds, settlement, payout changes)
  - Can view any organization's data in **platform dashboards and reporting contexts** (read-only, not in tenant-facing endpoints)
  - All actions are audit-logged with Super Admin context

#### `is_platform_staff: boolean`

- Default: `false`
- Meaning: User works for VoelgoedEvents (not for the tenant organizer)
- Set by: **Only Super Admin** (via admin tools or direct DB operation, never via tenant UI)
- Effects:
  - User is marked as "Voelgoed Support" in tenant dashboards
  - User's `Membership` in a tenant organization is **protected** while this flag is `true` (cannot be removed/demoted by tenant users)
  - User operates strictly under their assigned **tenant role** inside that organization (typically `:admin`, NEVER `:owner`)
  - User can access only organizations they are explicitly assigned to (via `Membership`)
  - **User does NOT have elevated powers inside the tenant** — platform staff powers are only available in platform-level contexts (dashboards, admin tooling)

### 2.2 Per-Tenant Authority (Role via Membership)

A user's authority **within an organization** is determined by their `Membership(user_id, organization_id, role_id)`:

```elixir
{user_id, organization_id, role_id} -> {":owner" | ":admin" | ":staff" | ":viewer" | ":scanner_only"}
```

**Rules:**

1. A user can have **different roles across different organizations**
   - User A is owner of Org 1, admin of Org 2, staff of Org 3
2. A user has **at most one role per organization**
   - Unique constraint: `(user_id, organization_id)` → one role
3. All normal operations are scoped by organization context
   - Cannot see/modify data from organizations where the user has no membership
4. Role authority is **independent** of platform staff flag
   - `:admin` role with `is_platform_staff: true` operates identically to `:admin` role with `is_platform_staff: false` inside the tenant
   - Difference is purely **protection** (cannot be removed by tenant) and **audit attribution** (logged as platform action)
5. **Platform staff MUST NEVER hold `:owner` role**
   - Platform staff may be `:admin`, `:staff`, `:viewer`, or `:scanner_only`
   - Only Super Admin may grant or revoke organization ownership
   - This prevents escalation: a platform staff admin cannot become equivalent to a tenant owner

### 2.3 Actor Context Construction

The `CurrentUserPlug` or authentication layer MUST construct an `actor` context for every request:

```elixir
actor: %{
  user_id: "user-uuid",
  organization_id: "org-uuid",           # From session, API key, or device token (NEVER params)
  role: :admin,                          # From Membership.role (queried from DB)
  is_platform_staff: false,              # From User.is_platform_staff (queried from DB)
  is_platform_admin: false,              # From User.is_platform_admin (queried from DB)
  type: :user                            # :user, :device, :system, :api_key
}
```

**Critical rules:**

- `organization_id`: MUST be derived from session or API key context, NEVER from request params
- `role`, `is_platform_staff`, `is_platform_admin`: MUST be loaded from DB, never from cached session data that could be stale
- `type`: MUST be set correctly to distinguish user from device/system/API key actors
- Missing `organization_id` in session-based auth: MUST reject request (user must select org first or auth must establish org context)
- **Global invariant (critical):** If `actor.type` is `:system` or `:device`, and the action is not explicitly permitted for that actor type, RBAC MUST deny the request regardless of `organization_id`. No exceptions.

### 2.4 Identity: Global Flags + Per-Tenant Role

**User authority is the intersection of:**

- **Global flags** (`is_platform_admin`, `is_platform_staff`)
- **Per-tenant role** (from `Membership`)

### 2.5 Canonical Role Catalog

System-defined roles are immutable and seeded with human-friendly names and explicit permission sets to keep capabilities
consistent across tenants and platform tooling.

| Role atom | Display name | Permissions |
|-----------|--------------|-------------|
| `:owner` | Owner | `manage_tenant_users`, `manage_events_and_venues`, `manage_ticketing_and_pricing`, `manage_financials`, `manage_devices`, `view_full_analytics` |
| `:admin` | Admin | `manage_tenant_users`, `manage_events_and_venues`, `manage_ticketing_and_pricing`, `view_financials`, `manage_devices`, `view_full_analytics` |
| `:staff` | Staff | `manage_ticketing_and_pricing`, `view_orders`, `view_limited_analytics` |
| `:viewer` | Viewer | `view_read_only` |
| `:scanner_only` | Scanner Only | `perform_scans` |

**Examples:**

| User | Org A | Org B | Org C | Global Flags | Capabilities |
|------|-------|-------|-------|--------------|--------------|
| Alice | owner | — | — | `is_platform_admin: true` | Super admin everywhere + owner in Org A (owner authority, not elevated) |
| Bob | admin | — | — | `is_platform_staff: true` | Platform staff + admin in Org A (admin authority, protected from removal); cannot be removed by Org A |
| Carol | owner | — | — | none | Owner in Org A only (standard owner authority) |
| Dave | staff | viewer | — | `is_platform_staff: true` | Platform staff + staff in Org A (staff authority), viewer in Org B (viewer authority); visible with "Support" badge in both |
| Eve | — | — | — | `is_platform_admin: true` | Super admin with no org context (platform dashboards only) |

---

## 3. Actor Type Matrix

The RBAC system supports multiple actor types, each with different authorization semantics:

| Actor Type | Description | Required Fields | Forbidden Behaviors | Example Use |
|------------|-------------|-----------------|-------------------|-------------|
| `:user` | Authenticated human user | `user_id`, `organization_id`, `role` | Cross-tenant reads, device operations, system tasks | Dashboard login, event creation |
| `:device` | Scanner or kiosk hardware | `device_id`, `device_token`, `organization_id` | Membership changes, financial actions, event creation, any action outside scanning domain | QR code scanning at gate |
| `:system` | Background job or workflow | `organization_id` (MUST have it, MUST NOT switch mid-execution) | Any action without `organization_id`, cross-tenant operations, switching orgs mid-workflow | Cleanup jobs, email notifications, offline sync |
| `:api_key` | Public API client | `api_key_id`, `organization_id`, `scopes` | Undeclared scopes, financial actions, membership changes | External integrations, webhooks |

**Critical invariants:**
- Every actor type MUST include `organization_id` in its context (except Super Admin in platform dashboards). No actor may operate without clear tenant scoping.
- If actor type is `:system` or `:device`, and the action is not explicitly permitted for that actor type, RBAC MUST deny the request regardless of `organization_id`.
- `:system` actors MUST NOT mutate or switch `organization_id` mid-execution. Workflows must be instantiated per organization.

---

## 4. The Five Tenant Roles (Complete Definition)

VoelgoedEvents has **exactly five tenant-scoped roles**. These are system-defined and seeded in `priv/repo/seeds.exs`. No new roles are created.

### 4.1 Owner (`:owner`)

**Typical archetype:** Event organizer founder, business owner, principal decision-maker.

**In Ash:** `actor(:role) == :owner and actor(:organization_id) == resource.organization_id`

**Capabilities:**

| Domain | Action | Allowed | Notes |
|--------|--------|---------|-------|
| **Tenancy & Accounts** | Invite users | ✅ | Send invitations; can only invite non-platform users |
| | Change user roles | ✅ | Except: cannot change roles of platform staff users |
| | Remove memberships | ✅ | Except: cannot remove platform staff (unless `is_platform_staff` becomes false) |
| | View team | ✅ | See all members including platform staff (with badge) |
| **Events & Venues** | Create events | ✅ | |
| | Publish events | ✅ | Transition from draft to published |
| | Archive events | ✅ | |
| | Create venues | ✅ | |
| | Configure gates | ✅ | |
| **Ticketing** | Create ticket types | ✅ | |
| | Set prices | ✅ | |
| | Modify pricing rules | ✅ | |
| | Hide/pause ticket sales | ✅ | |
| | Create coupons | ✅ | |
| **Orders & Refunds** | View orders | ✅ | Full visibility |
| | Export order data | ✅ | CSV, PDF, etc. |
| | **Initiate refunds (full or partial)** | ✅ | **Owner-primary capability** |
| **Finance & Ledger** | View ledger accounts | ✅ | Read-only |
| | View settlements | ✅ | Read-only |
| | **Trigger settlement** | ✅ | **Owner-primary, with preconditions** |
| | Export financial reports | ✅ | |
| | **Change payout destination** | ✅ | **Owner-primary, audit-logged** |
| **Scanning** | Register devices | ✅ | |
| | Start/stop scan sessions | ✅ | |
| | View scan history | ✅ | |
| | Manage device permissions | ✅ | |
| **Analytics** | View all analytics (event, funnel, revenue, financial, settlement) | ✅ | Full access |
| | Export analytics | ✅ | |

---

### 4.2 Admin (`:admin`)

**Typical archetype:** Event coordinator, operations lead, trusted staff member. Often assigned to platform staff.

**In Ash:** `actor(:role) in [:admin, :owner] and actor(:organization_id) == resource.organization_id`

**Capabilities:**

| Domain | Action | Allowed | Notes |
|--------|--------|---------|-------|
| **Tenancy & Accounts** | Invite users | ✅ | Cannot invite platform staff users |
| | Change user roles | ✅ | Cannot change owner or platform staff roles |
| | Remove memberships | ✅ | Cannot remove owner or platform staff (unless `is_platform_staff` becomes false) |
| | View team | ✅ | See all members including platform staff (with badge) |
| **Events & Venues** | Create events | ✅ | |
| | Publish events | ✅ | |
| | Archive events | ✅ | |
| | Create venues | ✅ | |
| | Configure gates | ✅ | |
| **Ticketing** | Create ticket types | ✅ | |
| | Set prices | ✅ | |
| | Modify pricing rules | ✅ | |
| | Hide/pause sales | ✅ | |
| | Create coupons | ✅ | |
| **Orders & Refunds** | View orders | ✅ | |
| | Export order data | ✅ | |
| | **Initiate refunds** | ❌ | **Owner-only + Super Admin exception** |
| **Finance & Ledger** | View ledger accounts | ✅ | Read-only |
| | View settlements | ✅ | Read-only |
| | **Trigger settlement** | ❌ | **Owner-only + Super Admin exception** |
| | Export financial reports | ✅ | |
| | **Change payout destination** | ❌ | **Owner-only + Super Admin exception** |
| **Scanning** | Register devices | ✅ | |
| | Start/stop sessions | ✅ | |
| | View scan history | ✅ | |
| | Manage device permissions | ✅ | |
| **Analytics** | Event analytics | ✅ | Full access |
| | Funnel analytics | ✅ | Full access |
| | Revenue analytics | ⚠️ | Partial (non-sensitive) |
| | Financial reports | ⚠️ | Partial (summary only, no payout details) |
| | Settlement reports | ❌ | Owner-only |
| | Export analytics | ✅ | Limited scope |

---

### 4.3 Staff (`:staff`)

**Typical archetype:** Marketing coordinator, event assistant, ticket sales representative.

**In Ash:** `actor(:role) in [:staff, :admin, :owner] and actor(:organization_id) == resource.organization_id`

**Capabilities:**

| Domain | Action | Allowed | Notes |
|--------|--------|---------|-------|
| **Tenancy & Accounts** | Invite users | ❌ | |
| | Change roles | ❌ | |
| | Remove members | ❌ | |
| | View team | ✅ | Read-only |
| **Events & Venues** | Create events | ✅ | Delegated capability |
| | Publish events | ✅ | |
| | Archive events | ❌ | |
| | Create venues | ❌ | |
| | Configure gates | ❌ | |
| **Ticketing** | Create ticket types | ✅ | |
| | Set prices | ⚠️ | Within owner-set bounds (Phase 7+ feature) |
| | Modify pricing rules | ❌ | |
| | Hide/pause sales | ✅ | |
| | Create coupons | ✅ | |
| **Orders & Refunds** | View orders | ✅ | |
| | Export order data | ✅ | |
| | Initiate refunds | ❌ | |
| **Finance & Ledger** | View ledger accounts | ❌ | No financial visibility |
| | View settlements | ❌ | |
| | Any financial action | ❌ | |
| **Scanning** | Register devices | ❌ | |
| | Start/stop sessions | ❌ | |
| | View scan history | ✅ | Read-only, monitoring only |
| | Manage permissions | ❌ | |
| **Analytics** | Event analytics | ⚠️ | Limited to high-level metrics |
| | Funnel analytics | ⚠️ | Limited to high-level metrics |
| | Revenue analytics | ❌ | No financial visibility |
| | Financial reports | ❌ | |
| | Settlement reports | ❌ | |
| | Export analytics | ✅ | Limited scope |

---

### 4.4 Viewer (`:viewer`)

**Typical archetype:** Stakeholder, partner, read-only observer.

**In Ash:** `actor(:role) in [:viewer, :staff, :admin, :owner] and actor(:organization_id) == resource.organization_id`

**Capabilities:**

| Domain | Action | Allowed | Notes |
|--------|--------|---------|-------|
| **Tenancy & Accounts** | Any write action | ❌ | |
| | View team | ✅ | Read-only |
| **Events & Venues** | Any write action | ❌ | |
| | View events/venues | ✅ | Read-only |
| **Ticketing** | Any write action | ❌ | |
| | View tickets/pricing | ✅ | Read-only |
| **Orders & Refunds** | View orders | ✅ | |
| | Any write action | ❌ | |
| **Finance & Ledger** | Any action | ❌ | No financial visibility |
| **Scanning** | Any action | ❌ | |
| **Analytics** | View high-level dashboards | ✅ | Non-sensitive metrics only; excludes revenue, financial, settlement data |

---

### 4.5 Scanner-Only (`:scanner_only`)

**Typical archetype:** Door staff, venue personnel, scanning operators.

**Authentication:** Typically via device token, not password login. If logged in via web, access is device-constrained.

**In Ash:** `actor(:role) == :scanner_only and device_token_valid(actor(:device_token))`

**Capabilities:**

| Domain | Action | Allowed | Notes |
|--------|--------|---------|-------|
| **Tenancy & Accounts** | Any action | ❌ | |
| **Events & Venues** | Any action | ❌ | |
| **Ticketing** | Any action | ❌ | |
| **Orders & Refunds** | Any action | ❌ | |
| **Finance & Ledger** | Any action | ❌ | |
| **Scanning** | Start/stop scan sessions | ✅ | Assigned event/gate only |
| | View scan history (own session) | ✅ | Session-scoped, no cross-session access |
| | Initiate check-in | ✅ | Validate QR, record scan |
| | Any other action | ❌ | |
| **Analytics** | Any action | ❌ | |

---

## 5. Platform Staff (Modelled as Flag + Existing Role)

**Platform staff are NOT a new role.** They are represented as:

- `User.is_platform_staff = true` (global flag)
- A regular `Membership` with role `:admin` (or occasionally `:staff`, but NEVER `:owner`) in the organizations they support

### 5.1 Platform Staff in Organizations

When a platform staff user joins an organization:

1. They appear in the team list **with a "Voelgoed Support" badge** (UI responsibility)
2. They have **exactly the authority of their assigned role** (`:admin`, `:staff`, etc.)
   - **Critical:** Platform staff do NOT have elevated powers beyond their role inside the tenant
   - If platform staff need to perform actions their role forbids, only Super Admin can grant those exceptions via override
3. **Tenants cannot remove or demote them** while `is_platform_staff: true` — policy enforces this
4. All their actions are audit-logged with `is_platform_staff=true` marker for attribution
5. **Platform staff MUST NEVER hold `:owner` role** — only Super Admin may grant or revoke organization ownership

### 5.2 Platform Staff vs Admin: Quick Reference

This table clarifies the distinction between platform staff and tenant admins:

| Capability | Tenant Admin | Platform Staff (Admin Role) |
|------------|--------------|------------------------------|
| **Inside tenant: Admin authority** | ✅ Full | ✅ Full |
| **Removable by tenant** | ✅ Yes | ❌ No (while flag is true) |
| **Financial operations** | ❌ No | ❌ No |
| **Refund override** | ❌ No | ❌ No |
| **Settlement override** | ❌ No | ❌ No |
| **Event override** | ❌ No | ❌ No |
| **Platform dashboard access** | ❌ No | ✅ Yes |
| **Cross-tenant viewing** | ❌ No | ❌ No |
| **Super Admin override** | ❌ No | ❌ No |
| **Can become :owner** | ✅ Yes (tenant choice) | ❌ No (forbidden) |

---

### 5.3 Platform Staff Membership Protection Logic

**Who can manage platform staff memberships:**

```elixir
# Membership resource — create action
policies do
  # Tenant admins can invite regular users
  policy action_type(:create) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) in [:owner, :admin] and
      resource.user.is_platform_staff == false
    )
  end

  # Only Super Admin can assign platform staff
  policy action_type(:create) do
    authorize_if expr(actor(:is_platform_admin) == true)
  end
end

# Membership resource — update & destroy actions
policies do
  # Cannot modify platform staff memberships (while flag is true)
  forbid_if expr(
    resource.user.is_platform_staff == true and
    actor(:is_platform_admin) == false
  )

  # Cannot assign :owner role to platform staff
  forbid_if expr(
    resource.user.is_platform_staff == true and
    resource.role == :owner
  )

  # Tenants can manage regular staff
  policy action_type([:update, :destroy]) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) in [:owner, :admin] and
      resource.user.is_platform_staff == false
    )
  end
end
```

### 5.4 De-Protection Rule: When `is_platform_staff: false`

**Critical operational rule:**

When a user's `is_platform_staff` flag changes from `true` → `false` (e.g., employee leaves):

1. **Membership protection evaporates immediately**
   - Tenants may now remove, demote, or manage that user's membership
   - This is NOT a special policy; it flows from the forbid condition: `is_platform_staff == true` no longer applies
2. **Audit logging:** The flag change MUST be logged as a sensitive action
3. **Notification:** Ideally, the tenant should be notified that a platform staff member has been converted to regular staff (operational decision)

**In policy terms:**

```elixir
forbid_if expr(resource.user.is_platform_staff == true and ...)
# When is_platform_staff becomes false, this condition is no longer true
# → Tenants regain control over the membership
```

### 5.5 Platform Staff Visibility & Protection

- **Visible:** Platform staff appear in tenant dashboards with a visual "Support" badge
- **Protected:** Tenants see them but have no "Remove", "Demote", or "Edit Role" buttons in the UI for platform staff
- **Protected by policy:** Even if a tenant tries to call the API to remove/change platform staff, policies forbid it (as long as `is_platform_staff == true`)
- **Immutable by tenant (with exceptions):** Only Super Admin can modify platform staff memberships, except when flag is false

---

## 6. Super Admin Exceptions (Financial & Emergency)

Super Admin (`is_platform_admin == true`) has the ability to **override normal tenant RBAC rules** in specific, audit-logged scenarios. These are exceptional, not routine. Super Admin may also view any organization's data in **platform dashboards and reporting contexts** (read-only) without membership.

### 6.1 Refunds (Super Admin Exception)

**Normal rule:** Only `:owner` can initiate refunds.

**Refund authority:**

Refund authority applies per refund transaction (full or partial), not per line-item. Owners may create full or partial refunds of orders containing multiple tickets. Other roles cannot refund any portion of an order.

**Refund sources:**

1. **Tenant-initiated:** Owner calls "Refund this order" in dashboard
   - Authorization: Owner only
   - Refund origin: `:tenant_initiated`

2. **External PSP:** Payment gateway (Paystack, Stripe, Yoco) initiates refund via webhook
   - Chargeback, dispute resolution, merchant error correction
   - Authorization: `:system` actor with org scoping (not RBAC)
   - Refund origin: `:external_psp`
   - No RBAC check; webhook authenticates against PSP secret
   - Audit: Logged as `refund_origin: :external_psp`

3. **Super Admin override:** Emergency refund initiated by platform admin
   - Authorization: Super Admin only
   - Refund origin: `:super_admin_override`
   - Audit: Logged with `actor_is_platform_admin: true`, required context/reason field

**Policy:**

```elixir
# Refund resource — create action
policies do
  # Owner is primary refunder (tenant-initiated, full or partial)
  policy action_type(:create) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) == :owner and
      resource.refund_origin == :tenant_initiated
    )
  end

  # External PSP refunds (via webhook)
  policy action_type(:create) do
    authorize_if expr(
      actor(:type) == :system and
      actor(:organization_id) == resource.organization_id and
      resource.refund_origin == :external_psp
    )
  end

  # Super Admin emergency override
  authorize_if expr(
    actor(:is_platform_admin) == true and
    resource.refund_origin == :super_admin_override
  )

  # All other roles forbidden
  forbid_if expr(
    actor(:role) in [:admin, :staff, :viewer, :scanner_only] and
    actor(:is_platform_admin) == false
  )
end
```

**Audit requirement:** Every Super Admin refund must be logged with:
- `actor_id`, `actor_is_platform_admin=true`
- `action: :refund_created_by_super_admin`
- `refund_origin: :super_admin_override`
- Context/reason (required field)

---

### 6.2 Settlement (Super Admin Exception)

**Normal rule:** Only `:owner` can trigger settlements.

**Settlement preconditions (non-RBAC):**

Before any settlement can be triggered (by owner or super admin), these non-RBAC constraints must be met:

1. PSP integration configured for the organization
2. Ledger is balanced/reconciled (no pending adjustments)
3. Settlement period is valid (not in blackout window, etc.)
4. Minimum payout threshold met (if configured)

**These preconditions are business logic, not RBAC.** The RBAC document states they exist, but enforcement is elsewhere.

**Policy:**

```elixir
policies do
  # Owner triggers settlement (after preconditions pass)
  policy action_type(:create) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) == :owner
    )
  end

  # Super Admin can force settlement (overriding some preconditions in emergency)
  authorize_if expr(actor(:is_platform_admin) == true)

  # All others forbidden
  forbid_if expr(
    actor(:role) in [:admin, :staff, :viewer, :scanner_only] and
    actor(:is_platform_admin) == false
  )
end
```

**Audit requirement:** Settlement actions by Super Admin must log:
- `actor_is_platform_admin: true`
- `action: :settlement_triggered_by_super_admin`
- Context explaining why override was needed

---

### 6.3 Payout Configuration (Super Admin Exception)

**Normal rule:** Only `:owner` can change payout destination, account details, routing info.

**Policy:**

```elixir
policies do
  # Owner changes payout config
  policy action_type(:update) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) == :owner
    )
  end

  # Super Admin can modify payout config as emergency override
  authorize_if expr(actor(:is_platform_admin) == true)

  # All others forbidden
  forbid_if expr(
    actor(:role) in [:admin, :staff, :viewer, :scanner_only] and
    actor(:is_platform_admin) == false
  )
end
```

**Audit requirement:** Log all payout config changes by Super Admin with:
- Full details of what changed (old vs new bank account, routing, etc.)
- Reason/context
- Timestamp and actor attribution

---

### 6.4 Super Admin vs Tenant Owner: Conflict Resolution

**Scenario:** Tenant owner wants to unpublish an event; Super Admin forbids it (for compliance/legal reasons).

**Rule:** Super Admin authority overrides tenant owner decisions **except for billing obligations**.

**Meaning:**

- Super Admin can forcibly unpublish, delete, or modify any event
- All changes logged as super admin actions
- **Exception:** Super Admin cannot unilaterally change billing agreements or void a settlement (Phase 6 rule; requires legal process)

**Policy pattern:**

```elixir
# Super Admin can override normal publish/unpublish rules
policies do
  policy action_type(:unpublish) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) == :owner
    )
  end

  # Super Admin override for compliance
  authorize_if expr(actor(:is_platform_admin) == true)
end
```

### 6.5 Super Admin Platform Dashboards

**Rule:** Super Admin may view any organization's data in **platform dashboards and reporting contexts** (read-only) without membership or role assignment.

**Meaning:**

- Super Admin can query cross-org financial reports
- Super Admin can view user management dashboards across all orgs
- Super Admin can access feature flags and configuration
- **NOT allowed in tenant-facing endpoints:** Super Admin cannot call `/api/organizations/{org_id}/events` without membership scoping

**Policy pattern for platform dashboards:**

```elixir
# Platform dashboard for super admin (read-only, cross-org)
policies do
  policy action_type(:read) do
    authorize_if expr(actor(:is_platform_admin) == true)
  end

  # Normal users must be scoped by org
  policy action_type(:read) do
    authorize_if expr(actor(:organization_id) == resource.organization_id)
  end
end
```

---

## 7. Edge Actors (Non-Human)

### 7.1 Scanner Devices

**Authentication:**
- Identified by `device_id` + `device_token`
- Token is organization-scoped, venue/gate-scoped
- Tokens stored securely in device app storage, never in plaintext

**Authorization:**
- Device must be owned by the organization (from request context or token)
- Device must be active (not deactivated/revoked)
- Device must have permission for the gate being accessed

**Capabilities:**
- Call `/api/scan` endpoint to validate and process QR codes
- Create `Scan` records in the scanning domain
- Broadcast real-time scan updates via PubSub (org-scoped)

**Limitations:**
- Cannot modify configuration, pricing, membership, or financial data
- Cannot authenticate as a user (no password login)
- Cannot access any resource outside scanning domain

**In Ash (Scan resource):**

```elixir
policies do
  # Device authentication
  policy action_type(:create) do
    authorize_if expr(
      actor(:type) == :device and
      device_token_valid(actor(:device_token)) and
      actor(:organization_id) == resource.organization_id
    )
  end

  # Non-devices cannot scan
  forbid_if expr(actor(:type) != :device)
end
```

---

### 7.2 Public API Keys

**Backing:** `ApiKey` resource (Phase 10+, forward-compatible), scoped to organization.

**Authentication:**
- Via `Authorization: Bearer {key_secret}` or `x-api-key: {key_secret}`
- Secret is hashed server-side, checked on every request

**Authorization:**
- Key is scoped to organization (cannot cross orgs)
- Key has scopes (`:events.read`, `:tickets.read`, `:tickets.write`, etc.)
- Key is rate-limited (e.g., 1000 req/hour)

**Capabilities (depend on scopes):**
- `:events.read` — list events
- `:tickets.read` — list tickets
- `:orders.read` — list orders
- Scopes are **opt-in**, defaulting to read-only

**Limitations:**
- Cannot initiate refunds or financial operations (even if scoped)
- Cannot modify membership, roles, or billing
- Always tenant-scoped

---

### 7.3 Webhooks & External Integrations

**Sources:** PSP webhooks (Paystack, Yoco), partner integrations.

**Authentication:**
- HMAC signature validation with shared secret
- IP allowlist (if supported by PSP)

**Authorization:**
- Webhook is organization-scoped (from request path or payload)
- Webhook can only update specific resources (e.g., transaction status)

**Capabilities:**
- Update transaction/payment status (automated)
- Create refund records (if PSP initiates refund)
- Cannot escalate privileges, modify membership, or access unrelated orgs

**Limitations:**
- Cannot arbitrarily call domain actions
- All webhook payloads validated against strict schema
- Processing must be idempotent

---

### 7.4 Background Jobs (Oban, Workflows)

**Execution context:** Virtual `:system` actor with elevated privileges (used carefully).

**Requirements:**
- MUST always include `organization_id` in context
- MUST NOT switch `organization_id` mid-execution — workflows must be instantiated per organization
- MUST NOT bypass tenant policies except in **explicitly documented, org-scoped workflows**

**Examples of valid system jobs:**
- Cleanup: Expire seat holds (scoped to org + event)
- Notifications: Send emails to users (scoped to org)
- Analytics: Aggregate funnel data (scoped to org)
- Reconciliation: Sync offline scans (scoped to org)

**In Ash:**

```elixir
policies do
  # System jobs with org context
  policy action_type(:create) do
    authorize_if expr(
      actor(:type) == :system and
      actor(:organization_id) == resource.organization_id
    )
  end

  # No global system jobs without org
  forbid_if expr(
    actor(:type) == :system and
    actor(:organization_id) == nil
  )
end
```

---

## 8. Analytics: Role-Based Visibility of Sensitive Metrics

**Critical rule:** Analytics that include financial metrics MUST follow the same visibility rules as revenue analytics.

Derived metrics (e.g., conversion rates calculated from revenue data) inherit the visibility restrictions of their source data. Developers must not expose sensitive financial aggregates to staff/viewers.

**Analytics visibility by role:**

| Analytics Type | Owner | Admin | Staff | Viewer | Scanner-Only | Super Admin |
|----------------|:-----:|:-----:|:-----:|:-------:|:------------:|:----------:|
| Event-level (attendance, timing) | ✅ | ✅ | ⚠️ (high-level) | ⚠️ (high-level) | ❌ | ✅ |
| Funnel (views→cart→purchase) | ✅ | ✅ | ⚠️ (high-level) | ❌ | ❌ | ✅ |
| Revenue (tickets sold, per-type) | ✅ | ⚠️ (summary only) | ❌ | ❌ | ❌ | ✅ |
| Financial (breakdown by fees, taxes) | ✅ | ⚠️ (summary only) | ❌ | ❌ | ❌ | ✅ |
| Settlement (payouts, timing, status) | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Derived metrics (conversion %, margin %) | ✅ | ⚠️ (if from allowed sources) | ❌ | ❌ | ❌ | ✅ |

---

## 9. Ash 3.x Policy Patterns (Mandatory)

All policies MUST use Ash 3.x semantics. This section provides canonical patterns.

### 9.1 Tenant Isolation (Mandatory on All Resources)

Every persistent domain resource MUST enforce organization scoping:

```elixir
policies do
  # Read
  policy action_type(:read) do
    authorize_if expr(resource.organization_id == actor(:organization_id))
  end

  # Create
  policy action_type(:create) do
    authorize_if expr(resource.organization_id == actor(:organization_id))
  end

  # Update & destroy
  policy action_type([:update, :destroy]) do
    authorize_if expr(resource.organization_id == actor(:organization_id))
  end
end
```

**Non-negotiable:** No exceptions to this pattern (except Super Admin in tightly controlled platform dashboards, which must be explicit and audited).

---

### 9.2 Role-Based Capability Control

For actions that differ by role:

```elixir
policies do
  # Owners can publish events
  policy action_type(:publish) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) == :owner
    )
  end

  # Admins and owners can create events
  policy action_type(:create_event) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) in [:owner, :admin]
    )
  end

  # Staff can create but check other constraints
  policy action_type(:create_coupon) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) in [:owner, :admin, :staff]
    )
  end

  # Viewers cannot write
  policy action_type([:create, :update, :destroy]) do
    forbid_if expr(actor(:role) == :viewer)
  end
end
```

---

### 9.3 Financial Gates with Super Admin Exception

```elixir
policies do
  # Owner is primary actor
  policy action_type(:create) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) == :owner
    )
  end

  # Super Admin can override
  authorize_if expr(actor(:is_platform_admin) == true)

  # Block non-owners/non-super-admin
  forbid_if expr(
    actor(:role) in [:admin, :staff, :viewer, :scanner_only] and
    actor(:is_platform_admin) == false
  )
end
```

---

### 9.4 Scanner-Only Access

```elixir
policies do
  # Device-authenticated scanning
  policy action_type(:create) do
    authorize_if expr(
      actor(:type) == :device and
      device_token_valid(actor(:device_token)) and
      actor(:organization_id) == resource.organization_id
    )
  end

  # Scanner-only human users (if authenticating via web)
  authorize_if expr(
    actor(:role) == :scanner_only and
    actor(:organization_id) == resource.organization_id
  )

  # No other role can scan
  forbid_if expr(actor(:role) not in [:scanner_only] and actor(:type) != :device)
end
```

---

### 9.5 Platform Staff Protection (Membership Resource)

```elixir
policies do
  # Tenants can invite regular users
  policy action_type(:create) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) in [:owner, :admin] and
      resource.user.is_platform_staff == false
    )
  end

  # Only Super Admin can assign platform staff
  policy action_type(:create) do
    authorize_if expr(actor(:is_platform_admin) == true)
  end

  # Cannot modify platform staff memberships (except Super Admin)
  policy action_type([:update, :destroy]) do
    forbid_if expr(
      resource.user.is_platform_staff == true and
      actor(:is_platform_admin) == false
    )
  end

  # Cannot assign :owner to platform staff
  forbid_if expr(
    resource.user.is_platform_staff == true and
    resource.role == :owner
  )

  # Tenants can remove/modify regular staff
  policy action_type([:update, :destroy]) do
    authorize_if expr(
      actor(:organization_id) == resource.organization_id and
      actor(:role) in [:owner, :admin] and
      resource.user.is_platform_staff == false
    )
  end
end
```

---

## 10. Multi-Tenancy Integration

The RBAC model is deeply integrated with multi-tenancy rules from `/docs/architecture/02_multi_tenancy.md`.

### 10.1 Core Invariants

1. **Every resource includes `organization_id`** (immutable, set at creation)
2. **All reads filtered by org** — `filter: [organization_id: actor(:organization_id)]`
3. **All policies enforce org scoping** — `authorize_if expr(resource.organization_id == actor(:organization_id))`
4. **No cross-org joins** — Users cannot accidentally see other orgs' data
5. **No permission inheritance** — Owner of Org A has no authority in Org B unless explicitly assigned membership
6. **Actor type enforcement:** If actor type is `:system` or `:device`, and the action is not explicitly permitted, RBAC MUST deny it

### 10.2 Actor Context Requirements

Every request must populate an `actor` context:

```elixir
actor: %{
  user_id: "user-uuid",
  organization_id: "org-uuid",           # From session or API key (NEVER from params)
  role: :admin,                          # From Membership.role
  is_platform_staff: false,              # From User.is_platform_staff
  is_platform_admin: false,              # From User.is_platform_admin
  type: :user                            # :user, :device, :system, :api_key
}
```

**Rule:** Never trust `organization_id` from request params. Always derive from session, API key, or device token.

### 10.3 Caching RBAC (ETS + Redis)

Per `/docs/architecture/03_caching_and_realtime.md`:

**Hot layer (ETS):** Cache `Membership` per user per org
- Key: `tenancy:membership:{user_id}:{org_id}`
- Value: `{role, is_platform_staff, status}`
- TTL: 2–5 minutes
- Write-through on membership changes

**Warm layer (Redis):** Mirror for cross-node consistency
- Key: `tenancy:membership:{user_id}:{org_id}`
- TTL: 1 minute
- Populated by hot layer on miss

**Cold layer (Postgres):** Authoritative `Membership` table, queried on cache miss

---

## 11. Phase Alignment

This RBAC model is introduced and refined across multiple phases:

### Phase 2 — Tenancy, Accounts & RBAC

**Deliverables:**
- `Organization`, `User`, `Role`, `Membership` resources
- Five tenant roles (`:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only`)
- `User.is_platform_staff` and `User.is_platform_admin` flags
- Multi-tenant policies (org scoping on all resources)
- Membership caching (ETS + Redis)
- `CurrentUserPlug` to populate actor context
- `AuditLog` resource for tracking sensitive changes

**Policies:**
- Shared tenant policies enforce org scoping
- Membership protection policies (platform staff immutable by tenants)

### Phase 3 — Core Events & GA Ticketing

**RBAC constraints:**
- Only `:owner`, `:admin`, `:staff` can create events
- Only `:owner`, `:admin` can publish events
- All event/ticket queries filtered by `actor(:organization_id)`

### Phase 4 — Orders, Payments & Ticket Issuance

**RBAC constraints:**
- Only `:owner` (and Super Admin exception) can initiate refunds (tenant-initiated source), full or partial
- `:admin` and `:staff` can view orders but not refund
- Payment webhooks run as `:system` actor (org-scoped) — refund source is `:external_psp`
- `AuditLog` captures refund origin and actor attribution

### Phase 5 — Scanning Backend & Integration

**RBAC constraints:**
- `:scanner_only` users authenticate via device token
- Device tokens are organization-scoped
- All scan records include `organization_id`

### Phase 6 — Full Financial Ledger & Settlement Engine

**RBAC constraints:**
- Only `:owner` (and Super Admin exception) can trigger settlements, with non-RBAC preconditions
- Only `:owner` (and Super Admin exception) can modify payout destination
- `:admin` can view ledger (read-only), no settlement authority
- `:staff` and `:viewer` cannot see financial data
- All financial actions audit-logged with role attribution and actor context

### Phase 7 — Organiser Admin Dashboards

**UI Requirements:**
- Show role-appropriate data per user
- Display platform staff with "Voelgoed Support" badge
- Hide actions user cannot perform (policy-enforced anyway)
- Audit log visible to `:owner` and `:admin`
- Analytics breakdown per role (per Section 8)

**Platform Dashboards (Super Admin only):**
- Cross-org financial reporting
- User management and platform staff assignment
- Feature flags and configuration

---

## 12. RBAC Constraints & Non-Negotiables

### 12.1 Ash Versioning

- **All examples assume Ash 3.x only**
- Use `policies do` blocks with `authorize_if/1` and `forbid_if/1`
- Use `expr/1` for all conditions
- Refer to resource fields as `resource.field_name` (not bare identifiers)
- Refer to actor fields as `actor(:field_name)`
- Do **not** reference Ash 2.x patterns (`authorize?` callbacks, `after_action`, etc.)

### 12.2 Multi-Tenancy

- **Every persistent resource MUST include `organization_id`**
- All read/write operations must be scoped by `organization_id`
- Actor access defined **per organization** via `Membership`, never by "raw" user id
- Cross-tenant access forbidden except explicitly documented Super Admin flows
- No inheritance of roles/permissions across organizations

### 12.3 No Role Invention

- **Exactly five tenant roles:** `:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only`
- Platform staff use `is_platform_staff: true` flag + existing `:admin` or `:staff` role (NEVER `:owner`)
- **Platform staff do NOT have elevated powers inside the tenant** — they operate under their assigned role
- New permissions in future phases are **added to existing roles**, not new roles created
- Any new role atom requires explicit roadmap addition and cannot be added ad-hoc

### 12.4 Financial Safety

- **Refunds:** Only `:owner` (tenant-initiated, full or partial) and Super Admin (override)
- **Settlement triggers:** Only `:owner` and Super Admin (with non-RBAC preconditions)
- **Payout config changes:** Only `:owner` and Super Admin
- **Ledger modifications:** Super Admin only (or none — immutable preferred)
- **All financial actions must be audit-logged** with actor attribution, origin, and context

### 12.5 Auditability

- **Membership changes:** Role changes, invites, removals → logged
- **Policy boundary crossings:** High-privilege actions logged with actor role
- **Financial actions:** Refund, settlement, payout → logged with actor, timestamp, origin, amount, context
- **Platform staff actions:** When `is_platform_staff=true` user acts → logged with staff marker
- **Audit log:** Queryable by organization, searchable by actor, immutable

### 12.6 Platform vs Tenant Clarity

- **Platform staff** work **for VoelgoedEvents** (marked `is_platform_staff: true`)
- **Tenant staff** work **for the organizer** (unmarked flag)
- Clear distinction in audit logs and UI (badge)
- Tenants cannot remove platform staff while `is_platform_staff: true` (policy-enforced)
- Only Super Admin can assign/unassign platform staff
- De-protection rule: When flag becomes false, tenants regain control immediately

### 12.7 Scanner-Only Specificity

- `:scanner_only` users can authenticate via **device token** (not password)
- `:scanner_only` users cannot log in to web dashboard (device-access-only)
- Device tokens are organization + venue/gate-scoped
- Cannot be used to escalate to other roles or actions

### 12.8 Actor Type Invariant

- If actor type is `:system` or `:device`, and the action is not explicitly permitted for that actor type, RBAC MUST deny the request regardless of `organization_id`
- `:system` actors MUST NOT switch `organization_id` mid-execution
- Workflows MUST be instantiated per organization

### 12.9 Cross-Domain Consistency

All RBAC rules must be consistent across domains:

- `:admin` means the same in Events, Ticketing, Scanning, Analytics
- Refund rules apply uniformly regardless of domain
- Financial gates apply uniformly regardless of resource
- No domain-specific exceptions without explicit rationale in domain spec

### 12.10 Document Update Rules

**This specification applies Option A (no new roles).**

All future modifications MUST preserve Option A unless the project roadmap explicitly introduces a new role. When modifying this document:

1. Never invent new role atoms (`:support`, `:platform_manager`, etc.)
2. Always refactor permissions into existing roles or global flags
3. Update the Implementation Checklist if requirements change
4. Link changes to roadmap phase decision if adding new capabilities

---

## 13. Gotchas & Anti-Patterns

### 13.1 Cross-Tenant Leakage

**❌ WRONG:**

```elixir
# Missing organization_id filter
Ash.read(Order, filter: [user_id: user_id])
# Result: User can see orders from any org they've ever been in
```

**✅ RIGHT:**

```elixir
# Always include org context
Ash.read(Order, filter: [user_id: user_id, organization_id: actor(:organization_id)])

# Better: Use policy to auto-filter
policies do
  policy action_type(:read) do
    authorize_if expr(resource.organization_id == actor(:organization_id))
  end
end
```

---

### 13.2 Overpowering Non-Owner Roles

**❌ WRONG:**

```elixir
# Giving :admin full financial powers
policy action_type(:create_refund) do
  authorize_if expr(actor(:role) in [:owner, :admin])
end
```

**✅ RIGHT:**

```elixir
# Restrict to owner only, with Super Admin exception
policy action_type(:create_refund) do
  authorize_if expr(
    actor(:organization_id) == resource.organization_id and
    actor(:role) == :owner
  )

  authorize_if expr(actor(:is_platform_admin) == true)

  forbid_if expr(actor(:role) in [:admin, :staff, :viewer, :scanner_only] and actor(:is_platform_admin) == false)
end
```

---

### 13.3 Tenants Removing Platform Staff

**❌ WRONG:**

```elixir
# No protection for platform staff
policy action_type(:destroy) do
  authorize_if expr(
    actor(:organization_id) == resource.organization_id and
    actor(:role) in [:owner, :admin]
  )
end
# Result: Tenant can fire support staff while is_platform_staff == true
```

**✅ RIGHT:**

```elixir
# Explicit protection
policy action_type(:destroy) do
  # Cannot remove platform staff (while flag is true)
  forbid_if expr(
    resource.user.is_platform_staff == true and
    actor(:is_platform_admin) == false
  )

  # Tenants can remove regular staff
  authorize_if expr(
    actor(:organization_id) == resource.organization_id and
    actor(:role) in [:owner, :admin] and
    resource.user.is_platform_staff == false
  )
end
```

---

### 13.4 Platform Staff Escalation to Owner

**❌ WRONG:**

```elixir
# Allowing platform staff to become owner
policy action_type(:update_role) do
  authorize_if expr(
    resource.user.is_platform_staff and
    new_role == :owner
  )
end
# Result: Platform staff can escalate to owner (dangerous)
```

**✅ RIGHT:**

```elixir
# Forbid platform staff owner assignment
forbid_if expr(
  resource.user.is_platform_staff == true and
  resource.role == :owner
)

# Only Super Admin can grant ownership
policy action_type(:update_role) do
  authorize_if expr(
    actor(:organization_id) == resource.organization_id and
    actor(:role) == :owner and
    resource.role != :owner
  )
end
```

---

### 13.5 Forgetting Actor Type in Policies

**❌ WRONG:**

```elixir
# No distinction between user, device, system actors
policy action_type(:create) do
  authorize_if expr(actor(:organization_id) == resource.organization_id)
end
# Result: Device actors can bypass role-based checks if org matches
```

**✅ RIGHT:**

```elixir
# Explicit actor type checks
policy action_type(:create) do
  # Users must have role
  authorize_if expr(
    actor(:type) == :user and
    actor(:role) == :owner and
    actor(:organization_id) == resource.organization_id
  )

  # Devices can only create scans
  authorize_if expr(
    actor(:type) == :device and
    actor(:organization_id) == resource.organization_id
  )

  # System actors must have org context
  authorize_if expr(
    actor(:type) == :system and
    actor(:organization_id) == resource.organization_id
  )

  # Block unintended actor types
  forbid_if expr(actor(:type) not in [:user, :device, :system])
end
```

---

### 13.6 System Actors Switching Organizations

**❌ WRONG:**

```elixir
# System actor switching org mid-workflow
def process_offline_sync(org_id_1, org_id_2) do
  actor = %{type: :system, organization_id: org_id_1}
  # Process org 1
  # ... later ...
  actor.organization_id = org_id_2  # WRONG: Switching org mid-execution
  # Process org 2
end
# Result: Cross-tenant leakage, state confusion
```

**✅ RIGHT:**

```elixir
# System actors instantiated per organization
def process_offline_sync(org_id_1) do
  actor_1 = %{type: :system, organization_id: org_id_1}
  # Process org 1 only
  # ... done ...
end

def process_offline_sync_other(org_id_2) do
  actor_2 = %{type: :system, organization_id: org_id_2}
  # Process org 2 in separate workflow
  # ... done ...
end
```

---

## 14. Sample Actor Contexts

These examples clarify actor construction for implementers:

### Tenant Admin in Org 123

```elixir
%{
  user_id: "user-u1",
  organization_id: "org-123",
  role: :admin,
  is_platform_staff: false,
  is_platform_admin: false,
  type: :user
}
```

**Capabilities:** Admin authority in Org 123 (create events, manage staff, view orders)

---

### Platform Staff Admin for Org 456

```elixir
%{
  user_id: "user-u2",
  organization_id: "org-456",
  role: :admin,
  is_platform_staff: true,
  is_platform_admin: false,
  type: :user
}
```

**Capabilities:** Admin authority in Org 456 (identical to tenant admin), protected from removal by tenant, visible with "Support" badge

---

### Super Admin Acting in Platform Dashboard

```elixir
%{
  user_id: "user-super",
  organization_id: nil,
  role: nil,
  is_platform_staff: false,
  is_platform_admin: true,
  type: :user
}
```

**Capabilities:** View any organization's data in platform dashboards (read-only), manage users/platform staff, override financial operations

---

### Scanner Device at Gate A

```elixir
%{
  user_id: nil,
  organization_id: "org-789",
  role: nil,
  is_platform_staff: false,
  is_platform_admin: false,
  type: :device,
  device_id: "device-scanner-1",
  device_token: "token_...",
  gate_id: "gate-a"
}
```

**Capabilities:** Create scan records for Org 789, Gate A only

---

### System Actor Processing Cleanup Job

```elixir
%{
  user_id: nil,
  organization_id: "org-789",
  role: nil,
  is_platform_staff: false,
  is_platform_admin: false,
  type: :system
}
```

**Capabilities:** Expire seat holds for Org 789 only (cannot switch orgs mid-execution)

---

## 15. Proposed Schema Additions to Phase 2

To support this RBAC model, the following additions to Phase 2 resources are required:

### 15.1 User Resource

**New attributes:**

```elixir
attribute :is_platform_staff, :boolean do
  default false
  allow_nil? false
  description "Is this user a VoelgoedEvents platform staff member?"
end

attribute :is_platform_admin, :boolean do
  default false
  allow_nil? false
  description "Is this user a platform super admin?"
end
```

**Justification:**
- Flags to distinguish platform workers from tenant staff
- Set only by out-of-band process or direct DB operation
- Never exposed to tenant UI

---

### 15.2 Membership Resource

**New policies:**

```elixir
policies do
  # Prevent tenant admins from managing platform staff
  policy action_type(:create) do
    forbid_if expr(
      resource.user.is_platform_staff == true and
      actor(:is_platform_admin) == false
    )
  end

  # Cannot assign :owner to platform staff
  forbid_if expr(
    resource.user.is_platform_staff == true and
    resource.role == :owner
  )

  # Cannot update or destroy platform staff memberships
  policy action_type([:update, :destroy]) do
    forbid_if expr(
      resource.user.is_platform_staff == true and
      actor(:is_platform_admin) == false
    )
  end
end
```

**Justification:** Platform staff memberships are immutable by tenants, modifiable only by Super Admin. Platform staff never hold `:owner` role.

---

### 15.3 AuditLog Resource (New)

Minimal but essential for compliance:

```elixir
# lib/voelgoedevents/ash/resources/accounts/audit_log.ex
resource :audit_log do
  attributes do
    attribute :id, :uuid, primary_key?: true, default: &Ash.UUID.generate/0
    attribute :organization_id, :uuid, allow_nil?: false
    attribute :actor_id, :uuid, allow_nil?: false
    attribute :actor_role, :atom  # :owner, :admin, :staff, :viewer, :scanner_only
    attribute :actor_is_platform_staff, :boolean
    attribute :actor_is_platform_admin, :boolean
    attribute :action, :atom  # :role_change, :membership_invite, :refund_created, :settlement_triggered, etc.
    attribute :resource_type, :atom  # :membership, :refund, :settlement, :payout_destination, etc.
    attribute :target_id, :uuid  # ID of affected resource
    attribute :origin, :atom  # For refunds: :tenant_initiated, :external_psp, :super_admin_override
    attribute :details, :map  # {old_role, new_role}, {old_payout, new_payout}, etc.
    attribute :reason_context, :string  # Optional context for Super Admin overrides
    attribute :inserted_at, :utc_datetime_usec, default: &DateTime.utc_now/0, allow_nil?: false
  end

  policies do
    # Only read own org's logs
    policy action_type(:read) do
      authorize_if expr(resource.organization_id == actor(:organization_id))
    end

    # Only system creates logs (not users)
    policy action_type(:create) do
      authorize_if expr(actor(:type) == :system)
    end

    # Never destroy logs (immutable)
    policy action_type(:destroy) do
      forbid_if expr(true)
    end
  end
end
```

**Justification:** Audit trail for compliance, financial safety, security investigation, and forensics.

---

## 16. Implementation Checklist (Phase 2)

When implementing Phase 2, verify ALL of the following:

- [ ] `User.is_platform_staff` boolean attribute added (default false)
- [ ] `User.is_platform_admin` boolean attribute added (default false)
- [ ] `Role` resource with exactly 5 atoms: `:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only`
- [ ] `Membership` resource with unique constraint on `(user_id, organization_id)`
- [ ] `Membership` policies forbid tenant modification of platform staff (while flag is true)
- [ ] `Membership` policies forbid platform staff `:owner` assignment
- [ ] `Membership` de-protection rule: When `is_platform_staff` becomes false, tenants regain control
- [ ] Shared tenant policies enforce org scoping on all resources (via expressions, not data filters)
- [ ] ETS cache initialized for membership lookups (key: `{user_id, org_id}`)
- [ ] Redis write-through for membership cache (TTL: 60–300 seconds)
- [ ] `AuditLog` resource created with immutable policies and `origin` field for refunds
- [ ] `CurrentUserPlug` populates actor with: `user_id`, `organization_id`, `role`, `is_platform_staff`, `is_platform_admin`, `type`
- [ ] Actor context NEVER trusts `organization_id` from params; always derives from session/API key
- [ ] Global invariant implemented: If actor type is `:system` or `:device`, and action not explicitly permitted, deny regardless of org_id
- [ ] System actors cannot switch `organization_id` mid-execution
- [ ] Tests verify:
  - [ ] Owner can refund (tenant-initiated), admin cannot
  - [ ] Owner can refund full or partial order (multi-item support)
  - [ ] Tenants cannot remove platform staff while `is_platform_staff == true`
  - [ ] Tenants cannot assign `:owner` role to platform staff
  - [ ] De-protection: Once flag becomes false, tenants can remove membership
  - [ ] Scanner-only users cannot create events
  - [ ] Super Admin can force refund in any org
  - [ ] Cross-org access forbidden for all actor types
  - [ ] Device actors can only scan (no other domain access)
  - [ ] System actors with no org_id are rejected
  - [ ] Audit log captures role changes, refunds (with origin), financial actions
  - [ ] Actor type enforcement: device can only scan, system must have org_id
  - [ ] Cross-domain consistency: `:admin` means the same in Events, Ticketing, Scanning, Analytics
- [ ] Documentation: Link to this spec in Phase 2 domain doc

---

## 17. References & Alignment

- `/docs/architecture/02_multi_tenancy.md` — Multi-tenant isolation model (Rule 3.1+)
- `/docs/architecture/07_security_and_auth.md` — Identity types (Section 3) and authentication flows
- `/docs/VOELGOEDEVENTS_FINAL_ROADMAP.md` — Phase 2, Phase 4, Phase 6, Phase 7 specifications
- `/docs/ai/ai_context_map.md` — Module registry & AI routing
- `/docs/AGENTS.md` — Agent behavior, Ash 3.x policy patterns, mandatory load order

---

**Document Status:** Production-ready specification, ready for INDEX.md integration.

**Last Updated:** December 9, 2025 (Final, All Critical Issues Resolved)

**Document Update Rule:** This specification applies **Option A (no new roles)**. All future modifications MUST preserve Option A unless the project roadmap explicitly introduces a new role. When modifying:
1. Never invent new role atoms
2. Always refactor permissions into existing roles or global flags
3. Update Implementation Checklist if requirements change
4. Link changes to roadmap phase decision if adding new capabilities

**Next Step:** Generate Phase 2 TOON micro-prompts for User, Role, Membership, AuditLog resources and comprehensive policy implementation based on this authoritative specification.
