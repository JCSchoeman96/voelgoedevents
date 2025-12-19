# ASH 3.X Strict Syntax Rules (v2.4 - Audited & Corrected)

**Status:** ✅ VALIDATED & CORRECTED per official Ash 3.x guidelines  
**Last Updated:** December 19, 2025  
**Audit Authority:** Ash 3.11.1 Official Docs + Elixir Forum (Zach Daniel)

---

## CORE RULES (NON-NEGOTIABLE)

### Section 0: Mandatory Patterns

#### 0.1 Ash.Domain, Never Ash.Api
- ✅ **CORRECT:** `defmodule MyApp.Ash.Domains.Ticketing do use Ash.Domain`
- ❌ **WRONG:** `use Ash.Api` (deprecated in Ash 3.x)
- **Why:** Ash 3.0 renamed all API modules to Domain modules for clarity and namespace consistency.

#### 0.2 Action Calls Always Use Ash Module
- ✅ **CORRECT:** `Ash.create(changeset, authorize?: true)` or `Ash.read!(query, tenant: org_id)`
- ❌ **WRONG:** `MyApp.Ash.Domains.Ticketing.Ticket.create(changeset)` (legacy direct action call)
- **Why:** The Ash module enforces authorization policies and multitenancy context.

#### 0.3 Actor Must Always Be Provided (Preferred Early Injection)
**CORRECTED RULE:**

Actor must always be provided for authorized actions. **Prefer setting the actor when building queries/changesets** so Ash can use it in any internal checks (validations, changes, calculations). If an action's logic needs the actor, pass it to `Ash.Query.for_read/2` or `Ash.Changeset.for_create/3`. Otherwise, passing it in the final `Ash.create/2` or `Ash.read!/2` call is acceptable – **but one way or another, an actor must be given.**

**Why the change:** Ash's official documentation explicitly encourages providing the actor when building changesets/queries because certain hooks, validations, or calculations may need to know the actor. For example, Ash.Authentication features and custom `changes` that assign actor_id fields will not function if the actor is only provided at the action call.

**Examples:**

✅ **Early Injection (Preferred):**
```elixir
# Actor needed for validation or change logic
changeset = 
  Ash.Changeset.for_create(MyApp.Ticketing.Ticket, :create, input)
  |> Ash.Changeset.set_context(%{actor: actor})

Ash.create(changeset, authorize?: true)
```

✅ **Late Injection (Acceptable):**
```elixir
# Simple create with no actor-dependent logic
changeset = Ash.Changeset.for_create(MyApp.Ticketing.Ticket, :create, input)
Ash.create(changeset, actor: actor, authorize?: true)
```

❌ **NEVER:**
```elixir
# Omitting actor entirely
changeset = Ash.Changeset.for_create(MyApp.Ticketing.Ticket, :create, input)
Ash.create(changeset, authorize?: true)  # MISSING actor → policies cannot check authorization
```

#### 0.4 Domain Authorization: Enforce require_actor?

**CORRECTED RULE:**

Every domain should enforce `require_actor? true` to ensure no action runs without an actor in context:

```elixir
defmodule MyApp.Ash.Domains.Ticketing do
  use Ash.Domain

  authorization do
    require_actor? true  # Every request must provide an actor (even if nil for anon)
  end

  resources do
    resource MyApp.Ticketing.Ticket
  end
end
```

**Why the change:** The previous requirement of `authorizers [Ash.Policy.Authorizer]` in the domain has no effect in Ash 3.x. The authorizers are added at the resource level, not the domain level. By setting `require_actor? true`, you enforce that every action must explicitly provide an actor, preventing accidental unprotected requests.

**Reference:** [Ash Domain Authorization Configuration](https://hexdocs.pm/ash/actors-and-authorization.html#:~:text=Domain%20Authorization%20Configuration)

#### 0.5 No Ecto.Repo Calls in Domain Logic
- ✅ **CORRECT:** `Ash.read!(query)` with proper actor and tenant
- ❌ **WRONG:** `Repo.get(Ticket, id)` or `Repo.all(Ticket)` (bypasses authorization & multitenancy)
- **Why:** Direct Repo calls bypass all Ash policies and multitenancy filters, creating security holes.

#### 0.6 Default Policy is Deny
Every policy set must end with `default_policy :deny` to be explicit about the deny-by-default stance:

```elixir
policies do
  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:organization_id) == organization_id)
    default_policy :deny  # ← REQUIRED: explicitly forbid anything not authorized above
  end
end
```

**Correct syntax:** `default_policy :deny` (not `default: :deny`, which is invalid Ash DSL)

**Why:** Ash's Policy Authorizer defaults to forbidding everything not explicitly allowed. Making this explicit prevents confusion and reinforces deny-first security.

**Reference:** [Ash Policy Documentation](https://hexdocs.pm/ash/policies.html) and [Forum Q&A on Forbidden Policy](https://elixirforum.com/t/trying-to-grok-ash-authentication-i-keep-getting-forbidden/71332)

---

## SECTION 1: MULTITENANCY (3-Layer Enforcement)

### Layer 1: Non-Null Tenant Attribute
Every multi-tenant resource must have an organization_id (or equivalent) attribute that is:
- **Required:** `allow_nil? false`
- **Private:** `private? true` (users cannot set it; only the system/policy can)

```elixir
defmodule MyApp.Ticketing.Ticket do
  use Ash.Resource, domain: MyApp.Ash.Domains.Ticketing

  attributes do
    uuid_primary_key :id
    attribute :organization_id, :uuid, allow_nil?: false, private?: true
  end
end
```

### Layer 2: Automatic Tenant Filter (CORRECTED GUIDANCE)

Configure multitenancy with strategy :attribute:

```elixir
multitenancy do
  strategy :attribute
  attribute :organization_id
end
```

**Runtime Requirement (NEW):** You must set the tenant context on every request. Without it, Ash will raise an error (by default, global? is false, requiring a tenant).

**In Phoenix (via plug):**
```elixir
Ash.PlugHelpers.set_tenant(conn, org_id)
```

**In Ash.read/Ash.create directly:**
```elixir
Ash.read!(query, tenant: org_id, authorize?: true)
Ash.create(changeset, tenant: org_id, authorize?: true)
```

**In tests or scripts:**
```elixir
Ash.Query.set_tenant(query, org_id)
```

**If you need global queries** (rare – only for platform-wide metrics), use `global? true`:
```elixir
multitenancy do
  strategy :attribute
  attribute :organization_id
  global? true  # Allow queries without a tenant (but policies MUST enforce org isolation)
end
```

**Why:** Ash enforces that if you've declared a tenant strategy, you must provide a tenant value. This prevents accidental cross-tenant queries. The automatic filter applies the tenant to every query scope.

**Reference:** [Ash Multitenancy Documentation](https://hexdocs.pm/ash/multitenancy.html)

### Layer 3: Policy Enforcement (Defense in Depth)
Even with automatic filters, policies add a second gate:

```elixir
policies do
  policy :all do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:organization_id) != organization_id)  # Prevent tenant leaks
    authorize_if expr(true)  # Fallback for authenticated users in the same org
    default_policy :deny
  end
end
```

**Why:** Defense in depth. If a misconfiguration allows a query without a tenant, the policy still checks the actor's org against the record's org.

---

## SECTION 2: ACTOR SHAPE (6 Fields - Strictly Enforced)

Every actor in VoelgoedEvents must be one of these shapes. **Use the map representation:**

```elixir
%{
  user_id: UUID,        # nil for anonymous, UUID for logged-in
  organization_id: UUID,  # nil for platform admins only, UUID for org users
  role: :admin | :member | :guest | :platform_admin | :platform_staff,
  is_platform_admin: boolean,
  is_platform_staff: boolean,
  type: :user | :system | :service
}
```

### Critical: Use `actor(:user_id)`, NOT `actor(:id)`

When writing policies, always reference fields as they exist in the actor:

✅ **CORRECT:**
```elixir
forbid_if expr(is_nil(actor(:user_id)))  # Blocks unauthenticated
authorize_if expr(actor(:organization_id) == organization_id)  # Tenant check
authorize_if expr(actor(:role) in [:admin, :member])  # Role check
authorize_if expr(actor(:is_platform_admin) == true)  # Platform admin override
```

❌ **WRONG (Will not work as intended):**
```elixir
forbid_if expr(is_nil(actor(:id)))  # ALWAYS true because actor has no :id field!
```

**Why:** The actor map has exactly these 6 fields. Using a non-existent field like `:id` will always be nil, causing the policy to behave incorrectly. Always match the actor structure you define.

---

## SECTION 3: POLICIES (Forbid First, Then Authorize)

### Policy Structure (Standard Pattern)

```elixir
policies do
  policy action_type(:create) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:type) not in [:user, :system])
    authorize_if expr(actor(:role) in [:admin, :member])
    authorize_if expr(actor(:is_platform_admin) == true)
    default_policy :deny
  end

  policy action_type(:read) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:organization_id) == organization_id)
    default_policy :deny
  end

  policy action_type(:update) do
    forbid_if expr(is_nil(actor(:user_id)))
    forbid_if expr(actor(:organization_id) != organization_id)
    authorize_if expr(actor(:role) == :admin)
    default_policy :deny
  end

  policy action_type(:destroy) do
    forbid_if expr(is_nil(actor(:user_id)))
    authorize_if expr(actor(:is_platform_admin) == true)
    default_policy :deny
  end
end
```

### Key Rules
1. **forbid_if comes first** – Deny dangerous conditions immediately
2. **authorize_if comes next** – Explicitly allow specific cases
3. **default_policy :deny comes last** – Deny anything not explicitly authorized
4. **expr() is mandatory** – All conditions use `expr(...)` so Ash can translate them to SQL
5. **actor(:field) only inside expr()** – Never call `actor(:field)` outside expr

---

## SECTION 4: CODE INTERFACE (Optional in Ash 3.x)

### Old Pattern (Still Valid, but Optional)

```elixir
defmodule MyApp.Ticketing.Ticket do
  use Ash.Resource, domain: MyApp.Ash.Domains.Ticketing

  code_interface do
    define_for MyApp.Ash.Domains.Ticketing
  end
end
```

### Why It's Optional Now

Because you specify `domain: MyApp.Ash.Domains.Ticketing` in the resource, Ash 3.x will automatically attach this resource's code interface functions to the domain module. The `define_for` is redundant but harmless.

**Recommendation:** You can safely remove it or keep it for explicitness. Omitting it relies on Ash's convention:

```elixir
defmodule MyApp.Ticketing.Ticket do
  use Ash.Resource, domain: MyApp.Ash.Domains.Ticketing
  # code_interface block omitted – Ash infers define_for automatically
end
```

**Reference:** [Ash 3.0 Teaser – Domain Configuration](https://elixirforum.com/t/ash-3-0-teasers/61857)

---

## SECTION 5: TESTING (3-Case Pattern)

Every resource action must have at least 3 tests:

1. **Authorized Actor** – Verify the action succeeds
2. **Unauthorized Actor** – Verify the action is forbidden
3. **Nil Actor (Anonymous)** – Verify the action is forbidden for unauthenticated users

```elixir
test "create ticket – authorized actor" do
  actor = %{user_id: uuid(), organization_id: org_id, role: :admin, ...}
  assert {:ok, ticket} = Ash.create(changeset, actor: actor, authorize?: true)
end

test "create ticket – unauthorized role" do
  actor = %{user_id: uuid(), organization_id: org_id, role: :guest, ...}
  assert {:error, :forbidden} = Ash.create(changeset, actor: actor, authorize?: true)
end

test "create ticket – nil actor (anonymous)" do
  actor = %{user_id: nil, organization_id: nil, ...}
  assert {:error, :forbidden} = Ash.create(changeset, actor: actor, authorize?: true)
end
```

---

## SECTION 6: COMMON MISTAKES (What NOT to Do)

### ❌ Mistake 1: Passing actor only at Ash.create
```elixir
# BAD – actor-dependent changesets won't work
changeset = Ash.Changeset.for_create(Ticket, :create, input)
Ash.create(changeset, actor: actor)

# GOOD – actor available to all hooks
changeset = 
  Ash.Changeset.for_create(Ticket, :create, input)
  |> Ash.Changeset.set_context(%{actor: actor})
Ash.create(changeset)
```

### ❌ Mistake 2: Using actor(:id) instead of actor(:user_id)
```elixir
# BAD
forbid_if expr(is_nil(actor(:id)))  # Always true, wrong logic

# GOOD
forbid_if expr(is_nil(actor(:user_id)))  # Correctly checks auth
```

### ❌ Mistake 3: Calling actor(:field) outside expr()
```elixir
# BAD – Will fail at compile time
authorize_if actor(:user_id) == 123

# GOOD
authorize_if expr(actor(:user_id) == 123)
```

### ❌ Mistake 4: Forgetting default_policy
```elixir
# BAD – Ash defaults to forbidding, but intent is unclear
policies do
  policy action_type(:read) do
    authorize_if expr(actor(:organization_id) == organization_id)
  end
end

# GOOD – Explicit deny
policies do
  policy action_type(:read) do
    authorize_if expr(actor(:organization_id) == organization_id)
    default_policy :deny
  end
end
```

### ❌ Mistake 5: Bypassing Ash with Repo.get
```elixir
# BAD – Skips authorization and multitenancy
Repo.get(Ticket, id)

# GOOD – Enforces policies and tenant context
Ash.read!(Ash.Query.filter(Ticket, id == ^id), tenant: org_id, authorize?: true)
```

### ❌ Mistake 6: Omitting tenant context in multitenancy
```elixir
# BAD – Will raise error
Ash.read!(query, authorize?: true)

# GOOD – Always provide tenant
Ash.read!(query, tenant: org_id, authorize?: true)
```

### ❌ Mistake 7: Using domain-level authorizers block that has no effect
```elixir
# BAD (No-op in Ash 3.x)
defmodule MyApp.Ash.Domains.Ticketing do
  use Ash.Domain

  authorization do
    authorizers [Ash.Policy.Authorizer]  # Does nothing here
  end
end

# GOOD – Use require_actor? for enforcement
defmodule MyApp.Ash.Domains.Ticketing do
  use Ash.Domain

  authorization do
    require_actor? true  # Enforces that all actions get an actor
  end
end
```

---

## SECTION 7: CHECKLIST (Pre-Commit)

- [ ] No `use Ash.Api` (only `use Ash.Domain`)
- [ ] All actions use `Ash.create`, `Ash.read!`, `Ash.update!` (never Repo)
- [ ] All authorized actions provide an actor (early or late)
- [ ] All policies use `expr()` with actor fields that exist in actor shape
- [ ] All policies end with `default_policy :deny`
- [ ] All multitenancy resources have `organization_id` (required, private)
- [ ] All multitenancy resources set tenant at runtime via plug or action call
- [ ] Every policy action has actor(:user_id) checks, NOT actor(:id)
- [ ] Domain has `authorization do require_actor? true end` (or omit if using resources' policies only)
- [ ] At least 3 tests per action (authorized, unauthorized, nil-actor)
- [ ] No `Repo.get`, `Repo.all`, or other Ecto calls in domain logic
- [ ] Code interface `define_for` is optional; can be removed if desired

---

## OFFICIAL REFERENCES

✅ [Ash 3.0 Teaser – Ash News](https://elixirforum.com/t/ash-3-0-teasers/61857) – Confirms Ash.Domain rename and domain-based configuration  
✅ [Actors & Authorization – Ash v3.11.1](https://hexdocs.pm/ash/actors-and-authorization.html) – Official guide for actor setup and early injection  
✅ [Policies – Ash v3.11.1](https://hexdocs.pm/ash/policies.html) – Policy DSL and expr() requirements  
✅ [Multitenancy – Ash v3.11.1](https://hexdocs.pm/ash/multitenancy.html) – Tenant context and strategy configuration  
✅ [Policy Authorizer Forum Q&A](https://elixirforum.com/t/trying-to-grok-ash-authentication-i-keep-getting-forbidden/71332) – Confirms deny-by-default behavior  

---

**Document Version:** 2.4 (Audited & Corrected)  
**Last Audit:** December 19, 2025  
**Status:** ✅ Aligned with Ash 3.11.1 Official Guidelines
