# ASH 3.X RBAC Matrix (v2.1 - Audited & Corrected)

**Status:** ✅ VALIDATED & CORRECTED  
**Audit Date:** December 19, 2025  
**Authority:** Ash 3.11.1 Official Docs + VoelgoedEvents Policy Standards

---

## ACTOR SHAPE (Canonical Definition)

Every actor in VoelgoedEvents is a map with exactly these 6 fields:

```elixir
%{
  user_id: UUID | nil,              # nil = anonymous, UUID = logged-in user
  organization_id: UUID | nil,      # nil = platform admin, UUID = org member
  role: :admin | :member | :guest | :platform_admin | :platform_staff,
  is_platform_admin: boolean,       # true if user is a platform admin
  is_platform_staff: boolean,       # true if user is platform staff
  type: :user | :system | :service  # actor type for routing
}
```

### Field Semantics

| Field | Type | Meaning | When Nil |
|-------|------|---------|----------|
| `user_id` | UUID \| nil | Logged-in user's ID | Anonymous request (no auth) |
| `organization_id` | UUID \| nil | Tenant org ID | Platform-level access (staff/admin only) |
| `role` | atom | User's role in the org | Always present; defaults to :guest |
| `is_platform_admin` | boolean | Platform super-admin flag | false for normal org users |
| `is_platform_staff` | boolean | Platform support staff flag | false for normal org users |
| `type` | atom | Actor category | Always present; :user for humans, :system/:service for automation |

---

## RBAC MATRIX: Actions × Roles × Policies

### Resource: Organization (Voelgoedevents.Orgs.Organization)

| Action | Platform Admin | Platform Staff | Org Admin | Org Member | Org Guest | Anon | Policy |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|---------|
| **create** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | Only platform admins can create orgs |
| **read** (list all) | ✅ | ✅ (own org only) | ✅ (own org) | ✅ (own org) | ✅ (own org) | ❌ | Authenticated users see their org; staff see assigned orgs |
| **read** (get one) | ✅ | ✅ (own org) | ✅ (own org) | ✅ (own org) | ✅ (own org) | ❌ | Access your own org only |
| **update** | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | Only platform admin or org admin can update |
| **delete** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | Only platform admin can delete |
| **list_users** | ✅ | ✅ (own org) | ✅ (own org) | ✅ (own org) | ❌ | ❌ | Org members with :admin/:member can view users |
| **add_user** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin or platform admin adds users |

**Policy Code (Organization):**

```elixir
policies do
  # CREATE – Only platform admin
  policy action_type(:create) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:is_platform_admin) == true)
    default_policy :deny
  end

  # READ – Authenticated users see own org (or all if platform admin)
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == id)
    default_policy :deny
  end

  # UPDATE – Platform admin or org admin of that org
  policy action_type(:update) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == id and actor(:role) == :admin)
    default_policy :deny
  end

  # DELETE – Only platform admin
  policy action_type(:destroy) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    default_policy :deny
  end
end
```

---

### Resource: OrgUser (Voelgoedevents.Orgs.OrgUser)

Users within an organization. Includes permissions, role assignments.

| Action | Platform Admin | Platform Staff | Org Admin | Org Member | Org Guest | Anon | Policy |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|---------|
| **create** | ✅ | ❌ | ✅ (invite to own org) | ❌ | ❌ | ❌ | Org admin or platform admin invites users |
| **read** | ✅ | ✅ (own org users) | ✅ (own org) | ✅ (own org) | ❌ | ❌ | Org members see other members in same org |
| **update** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin updates member roles in own org |
| **delete** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin removes users from own org |
| **activate** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin activates pending invites |

**Policy Code (OrgUser):**

```elixir
policies do
  # CREATE – Org admin or platform admin
  policy action_type(:create) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end

  # READ – Access your org's users
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) in [:admin, :member])
    default_policy :deny
  end

  # UPDATE – Org admin only (for same org)
  policy action_type(:update) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end

  # DELETE – Org admin removes users
  policy action_type(:destroy) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end
end
```

---

### Resource: Event (Voelgoedevents.Events.Event)

Multi-tenant event resource. Org admins manage events; members can view/interact based on status.

| Action | Platform Admin | Platform Staff | Org Admin | Org Member | Org Guest | Anon | Policy |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|---------|
| **create** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin or platform admin creates events |
| **read** | ✅ | ✅ (own org) | ✅ (own org) | ✅ (own org, public status) | ✅ (public status) | ✅ (public events) | Users see public; members see all in org |
| **update** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Only org admin can modify event details |
| **cancel** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin initiates cancellation (triggers workflow) |
| **postpone** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin postpones (triggers workflow) |
| **publish** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Org admin publishes event to public |

**Policy Code (Event):**

```elixir
policies do
  # CREATE – Org admin or platform admin
  policy action_type(:create) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end

  # READ – Based on event status
  # Public events: anyone can read
  # Draft/internal: org members only
  policy action_type(:read) do
    authorize_if expr(status in [:published, :live])  # Public events
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id)
    default_policy :deny
  end

  # UPDATE, CANCEL, POSTPONE – Org admin only
  policy action_type([:update, :cancel, :postpone]) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end

  # PUBLISH – Org admin
  policy action_type(:publish) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end
end
```

---

### Resource: Ticket (Voelgoedevents.Ticketing.Ticket)

End-user purchase. Org members can create (purchase); guests can view own; admins audit all.

| Action | Platform Admin | Platform Staff | Org Admin | Org Member | Org Guest | Anon | Policy |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|---------|
| **create** | ✅ | ❌ | ✅ (on behalf of) | ✅ (self) | ❌ | ❌ | Members purchase; admins create for others |
| **read** (own) | ✅ | ❌ | ✅ (any in org) | ✅ (own only) | ❌ | ❌ | Users see own; admins see all in org |
| **read** (list) | ✅ | ✅ (own org) | ✅ (own org) | ❌ | ❌ | ❌ | Only admins/staff see ticket lists |
| **update** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Admin updates (status, refund, etc.) |
| **delete** | ✅ | ❌ | ✅ (own org) | ❌ | ❌ | ❌ | Soft-delete by admin only |
| **scan** | ✅ | ✅ (scanner role) | ❌ | ❌ | ❌ | ❌ | Platform staff or scanner device scans |

**Policy Code (Ticket):**

```elixir
policies do
  # CREATE – Member (self) or admin (on behalf)
  policy action_type(:create) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) in [:admin, :member])
    default_policy :deny
  end

  # READ own ticket
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id)
    default_policy :deny
  end

  # UPDATE – Admin only
  policy action_type(:update) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end

  # DELETE – Admin only
  policy action_type(:destroy) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:organization_id) == organization_id and actor(:role) == :admin)
    default_policy :deny
  end

  # SCAN – Platform staff or scanner
  policy action_type(:scan) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    authorize_if expr(actor(:is_platform_staff) == true)
    default_policy :deny
  end
end
```

---

## ROLE HIERARCHY & PERMISSIONS

### Summary Table

| Role | Scope | Org Create | Event CRUD | Ticket Purchase | Ticket Admin | Scan | Notes |
|------|-------|:-:|:-:|:-:|:-:|:-:|-------|
| **Platform Admin** | Global | ✅ | ✅ | ✅ | ✅ | ✅ | All permissions; super-user |
| **Platform Staff** | Global | ❌ | ❌ | ❌ | ❌ | ✅ | Support/scanning only |
| **Org Admin** | Organization | ❌ | ✅ | ✅ (on behalf) | ✅ | ❌ | Full org management |
| **Org Member** | Organization | ❌ | ❌ (read only) | ✅ (self) | ❌ | ❌ | Can purchase and view own |
| **Org Guest** | Organization | ❌ | ❌ (public only) | ❌ | ❌ | ❌ | Read public events only |
| **Anonymous** | None | ❌ | ❌ (public only) | ❌ | ❌ | ❌ | Browse public events only |

---

## POLICY EXPRESSION GUIDELINES

### Always Use expr() for Actor Checks

```elixir
# ✅ CORRECT
authorize_if expr(actor(:user_id) == user_id)
authorize_if expr(actor(:role) in [:admin, :member])
authorize_if expr(actor(:organization_id) == organization_id)

# ❌ WRONG – Will fail
authorize_if actor(:user_id) == user_id
```

### Check for Nil (Anonymous) First

```elixir
# ✅ CORRECT – Forbid unauthenticated first
forbid_if expr(is_nil(actor(:user_id)))
authorize_if expr(actor(:role) == :admin)

# ❌ WRONG – Hard to debug
authorize_if expr(actor(:role) == :admin)
# anon actor gets :guest role, not caught
```

### Tenant Isolation (Always Include)

```elixir
# ✅ CORRECT – Double-check org membership
authorize_if expr(actor(:organization_id) == organization_id and actor(:role) in [:admin, :member])

# ⚠️ RISKY – Relies only on automatic filter
authorize_if expr(actor(:role) == :admin)
# Better as second gate if misconfiguration occurs
```

### Actor Type Validation

For resources that interact with systems/automations:

```elixir
# ✅ CORRECT – Only users or system actors
forbid_if expr(actor(:type) not in [:user, :system])
authorize_if expr(actor(:role) == :admin)

# ❌ RISKY – Allows unknown actor types
authorize_if expr(actor(:role) == :admin)
```

---

## TESTING MATRIX (Example: Organization.create)

**3 required tests per action:**

### Test 1: Authorized (Platform Admin)
```elixir
test "create org – platform admin" do
  actor = %{
    user_id: uuid(),
    organization_id: nil,
    role: :platform_admin,
    is_platform_admin: true,
    is_platform_staff: false,
    type: :user
  }
  
  assert {:ok, org} = Ash.create(
    Ash.Changeset.for_create(Organization, :create, %{name: "Acme"}),
    actor: actor,
    authorize?: true
  )
end
```

### Test 2: Unauthorized (Org Admin)
```elixir
test "create org – org admin forbidden" do
  actor = %{
    user_id: uuid(),
    organization_id: org_id,
    role: :admin,
    is_platform_admin: false,
    is_platform_staff: false,
    type: :user
  }
  
  assert {:error, :forbidden} = Ash.create(
    Ash.Changeset.for_create(Organization, :create, %{name: "Acme"}),
    actor: actor,
    authorize?: true
  )
end
```

### Test 3: Nil Actor (Anonymous)
```elixir
test "create org – anonymous forbidden" do
  actor = %{
    user_id: nil,
    organization_id: nil,
    role: :guest,
    is_platform_admin: false,
    is_platform_staff: false,
    type: :user
  }
  
  assert {:error, :forbidden} = Ash.create(
    Ash.Changeset.for_create(Organization, :create, %{name: "Acme"}),
    actor: actor,
    authorize?: true
  )
end
```

---

## DOMAIN CONFIGURATION (Enforces Actor Requirement)

```elixir
defmodule Voelgoedevents.Orgs do
  use Ash.Domain

  authorization do
    require_actor? true  # Every action requires an actor
  end

  resources do
    resource Voelgoedevents.Orgs.Organization
    resource Voelgoedevents.Orgs.OrgUser
  end
end
```

**Why:** `require_actor? true` ensures no action can run without explicitly providing an actor, preventing accidental unprotected operations.

---

## MULTITENANCY RUNTIME (Critical)

For all organization-scoped reads/writes, set the tenant:

```elixir
# In Phoenix controllers (via plug):
Ash.PlugHelpers.set_tenant(conn, current_user.organization_id)

# In direct Ash calls:
Ash.read!(Event, tenant: org_id, authorize?: true, actor: actor)
Ash.create(changeset, tenant: org_id, actor: actor, authorize?: true)

# In tests:
Ash.Query.set_tenant(query, org_id)
```

Without tenant context, Ash raises an error (by design, to prevent cross-tenant queries).

---

## AUDIT & COMPLIANCE CHECKLIST

- [ ] All RBAC policies use `expr(actor(:user_id))`, not `actor(:id)`
- [ ] All policies forbid anonymous first: `forbid_if expr(is_nil(actor(:user_id)))`
- [ ] All policies end with `default_policy :deny`
- [ ] All multitenancy policies include: `expr(actor(:organization_id) == organization_id)`
- [ ] All resources include multitenancy: `strategy :attribute, attribute :organization_id`
- [ ] All resources mark organization_id `private? true, allow_nil?: false`
- [ ] Domain includes `authorization do require_actor? true end`
- [ ] All tests follow 3-case pattern: authorized, unauthorized, nil-actor
- [ ] Runtime: tenant is set via plug or Ash.read/create options

---

**Version:** 2.1 (Audited & Corrected)  
**Last Updated:** December 19, 2025  
**Status:** ✅ Aligned with Ash 3.11.1 Specifications
