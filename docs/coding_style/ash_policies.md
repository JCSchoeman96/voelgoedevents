# Ash Policy Guidelines (VoelgoedEvents)

**Canonical policy coding standard for VoelgoedEvents**  
**Target:** `/docs/coding_style/ash_policies.md`  
**Framework:** Ash Framework 3.x  
**Last Updated:** December 2024

---

## 1. Purpose & Core Principles

This document defines the only accepted way VoelgoedEvents writes authorization policies:

- Uses **`Ash.Policy.Authorizer`** as the sole policy engine
- Uses **Ash 3.x policy DSL** and built-in check modules only
- For reusable rules, uses **`defmacro` helpers** that inject DSL into resource modules
- Enforces **multi-tenant, organization-isolated** access with platform-level overrides
- Forbids deprecated APIs and incorrect usage patterns

All examples are written to work directly in VoelgoedEvents resources without compile-time or runtime errors.

---

## 2. Ash 3.x Authorization System

### 2.1 Enabling Policies

Every resource that requires authorization must register the authorizer:

```elixir
use Ash.Resource,
  authorizers: [Ash.Policy.Authorizer]

policies do
  # policy / bypass / policy_group go here
end
```

**Rule:** In VoelgoedEvents, every exposed resource must declare `policies do` (even if using a single "allow everything" policy initially).

### 2.2 Policy Anatomy

Each policy has:

**1. Condition** (or list of conditions):
- `action_type(:read)`
- `action(:read_hidden)`
- `actor_attribute_equals(:role, "platform_admin")`
- `always()`
- `[action_type(:read), actor_attribute_equals(:admin, true)]`

**2. Checks** inside the `do` block:
- `authorize_if`
- `authorize_unless`
- `forbid_if`
- `forbid_unless`

Example:

```elixir
policies do
  policy action_type(:read) do
    forbid_unless actor_attribute_equals(:active, true)
    authorize_if expr(public == true)
    authorize_if relates_to_actor_via(:owner)
  end
end
```

**Evaluation model:**

- For a given request, determine which policies apply (condition is satisfied)
- All applicable policies must pass for authorization
- A policy produces `:authorized`, `:forbidden`, or `:unknown`
- `:unknown` is treated as forbidden

**Check ordering within a policy:**

- Checks evaluate logically from top to bottom
- First check yielding a decision (`:authorized` or `:forbidden`) determines the policy result
- If all checks return `:unknown`, the policy is `:unknown` → treated as forbidden

### 2.3 action_type/1 (Correct Function)

✅ **Supported in Ash 3.x:**
```elixir
action_type(:read)
action_type([:read, :update])
```

❌ **NOT supported:** `action_type/2` is invalid and will cause errors.

**Rule (VoelgoedEvents):**
- Only use `action_type/1` (atom or list of atoms)
- Never write `action_type/2`. Treat as a hard lint error.

Common `action_type` values:
- `:read`
- `:create`
- `:update`
- `:destroy`

### 2.4 access_type (Ash 3.x)

At policy level:

```elixir
policy action_type(:read) do
  access_type :filter # or :strict or :runtime
  # checks...
end
```

**Meanings:**

- **`:filter`** (default)
  - For read actions: policy failures produce filtered results instead of errors
  - For non-read actions: failing checks produce forbidden errors
  - Use for multi-tenant isolation and "Not found" behavior instead of "Forbidden"

- **`:strict`**
  - Checks must be resolved before data is exposed
  - Failures produce `Forbidden` errors
  - Use for admin features or actions requiring explicit authorization

- **`:runtime`**
  - Allows checks to be evaluated after data load
  - Rarely used; avoid unless documented and reviewed

**Rule (VoelgoedEvents default):**
- For most `:read` policies → `:filter` (explicit or default)
- For destructive/privileged actions (`:create`, `:update`, `:destroy`) → `:strict`
- `:runtime` requires explicit justification

### 2.5 Bypass Policies

Bypass policies short-circuit evaluation:

```elixir
bypass actor_attribute_equals(:role, "platform_admin") do
  access_type :strict
  authorize_if always()
end
```

- If a bypass passes (`:authorized`), later policies may be ignored
- If a bypass fails, evaluation continues with next policy

**Pattern:** Put admin/"can do anything" bypasses first to short-circuit:

```elixir
bypass actor_attribute_equals(:role, "platform_admin") do
  access_type :strict
  authorize_if always()
end

# other policies...
```

---

## 3. Policy Macros (Reusable Policy Helpers)

### 3.1 Why Macros (not Functions)?

The policy DSL is a compile-time DSL. To reuse policy blocks across resources:

- Use `defmacro` to generate quoted AST with DSL
- Never call DSL macros in regular `def` functions (causes `ArgumentError: nil is not a Spark DSL module`)

**Rule:**
All reusable policy helpers in VoelgoedEvents must be `defmacro` in shared modules.

### 3.2 Safe Macro Structure

**Pattern:**

```elixir
defmodule Voelgoedevents.Policies.PlatformPolicy do
  @moduledoc """
  Reusable platform-level admin policies.
  """

  defmacro platform_admin_root_access do
    quote do
      # Read access for platform admins (filter-style)
      policy action_type(:read) do
        access_type :filter
        authorize_if actor_attribute_equals(:role, "platform_admin")
      end

      # Strict access for create/update/destroy
      policy action_type([:create, :update, :destroy]) do
        access_type :strict
        authorize_if actor_attribute_equals(:role, "platform_admin")
      end
    end
  end
end
```

**Usage:**

```elixir
defmodule Voelgoedevents.Resources.SomeResource do
  use Ash.Resource,
    authorizers: [Ash.Policy.Authorizer]

  import Voelgoedevents.Policies.PlatformPolicy, only: [platform_admin_root_access: 0]

  policies do
    platform_admin_root_access()
    # resource-specific policies...
  end
end
```

### 3.3 Macro Design Rules (VoelgoedEvents)

**1. Macro naming:**
- Must be in `Voelgoedevents.Policies.*` namespace
- Name describes intent, e.g.:
  - `platform_admin_root_access/0`
  - `org_admin_crud_access/0`
  - `actor_owns_record_access/1`

**2. Macro body:**
- Only emits Ash policy DSL
- No runtime logic: no `Repo`, no `IO.inspect`, no side effects

**3. Quoted AST safety:**
- Return a single `quote do ... end`
- Treat body as if writing inside `policies do`

**4. Compilation safety:**
- Never call policy DSL from inside `def` functions
- For parameters, use macro arguments with `bind_quoted`

### 3.4 When to Use Helper Macros

**Use macros when:**
- Same pattern required across multiple resources
- One place to change convention globally

**Avoid macros when:**
- Logic is resource-specific
- Readability of inline policies is more important

**Guideline:** Start with inline policies. Extract to macro once pattern is stable and repeated.

### 3.5 Common Macro Mistakes

❌ **Policy DSL in `def`:**
```elixir
def platform_admin_root_access do
  policy action_type(:read) do # WRONG
    authorize_if always()
  end
end
```

✅ **Correct:**
```elixir
defmacro platform_admin_root_access do
  quote do
    policy action_type(:read) do
      authorize_if always()
    end
  end
end
```

---

## 4. Checks: Built-ins & Custom

### 4.1 Built-In Checks (Commonly Used)

From official Ash 3.x documentation:

- `always/0` - Always passes
- `never/0` - Never passes
- `actor_present/0`, `actor_absent/0`
- `actor_attribute_equals/2`
  - `actor_attribute_equals(:role, "platform_admin")`
  - `actor_attribute_equals(:active, true)`
- `action/1`, `action_type/1`
  - `action(:read_hidden)`
  - `action_type(:read)`
  - `action_type([:read, :update])`
- `relates_to_actor_via/2`
  - `relates_to_actor_via(:owner)`
  - `relates_to_actor_via([:organization, :owner])`
  - `relates_to_actor_via(:roles, field: :role)`
- `filtering_on/2`, `selecting/1`, `loading/1`

### 4.2 Inline Expression Checks

```elixir
policy action_type(:read) do
  authorize_if expr(public == true)
  authorize_if expr(owner_id == ^actor(:id))
  authorize_if expr(organization_id == ^actor(:organization_id))
end
```

**Rules:**
- Inline expressions are filter checks
- In create policies, inline expressions cannot reference record fields directly
- For complex logic with creates, write a SimpleCheck module

### 4.3 Custom Check Modules

**SimpleCheck Example:**

```elixir
defmodule Voelgoedevents.Policies.Checks.ActorIsPlatformAdmin do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is platform admin"

  @impl true
  def match?(%{role: "platform_admin"}, _context, _opts), do: true
  def match?(_actor, _context, _opts), do: false
end
```

**Usage:**
```elixir
policy action_type(:read) do
  authorize_if Voelgoedevents.Policies.Checks.ActorIsPlatformAdmin
end
```

**FilterCheck Example:**

```elixir
defmodule Voelgoedevents.Policies.Checks.ActorOwnsRecord do
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "actor owns record"

  @impl true
  def filter(actor, _authorizer, _opts) do
    expr(owner_id == ^actor.id)
  end
end
```

### 4.4 Common Check Pitfalls

❌ **Using expressions in create policies that reference fields:**
```elixir
policy action_type(:create) do
  authorize_if expr(status == :active)
end
```
This causes runtime error for creates.

**Fix:** Use SimpleCheck or restrict by actor/args

❌ **Using outdated check modules from Ash 2.x**

Always validate against current Ash 3.x docs.

---

## 5. Multi-Tenant & Admin Patterns (VoelgoedEvents)

### 5.1 Actor Structure (Assumed)

```elixir
%{
  id: actor_id,
  role: "user" | "org_admin" | "platform_admin",
  organization_id: org_id
}
```

**Resource fields:**
- `organization_id` (tenant foreign key)
- Possibly `owner_id` / `created_by_id`

### 5.2 Organization Isolation

**Baseline pattern:**

```elixir
policy action_type(:read) do
  access_type :filter
  authorize_if expr(organization_id == ^actor(:organization_id))
end

policy action_type([:create, :update, :destroy]) do
  access_type :strict
  authorize_if expr(organization_id == ^actor(:organization_id))
end
```

### 5.3 Platform Admin Bypass

Place at the top of `policies do`:

```elixir
bypass actor_attribute_equals(:role, "platform_admin") do
  access_type :strict
  authorize_if always()
end
```

### 5.4 Organization Admin Model

```elixir
policy action_type(:read) do
  access_type :filter
  authorize_if expr(organization_id == ^actor(:organization_id))
end

policy action_type([:create, :update, :destroy]) do
  access_type :strict
  authorize_if expr(
    organization_id == ^actor(:organization_id) and
    ^actor(:role) == "org_admin"
  )
end
```

If regular users should only manage their **own** records:

```elixir
policy action_type([:update, :destroy]) do
  access_type :strict

  # org admin in same org
  authorize_if expr(
    organization_id == ^actor(:organization_id) and
    ^actor(:role) == "org_admin"
  )

  # or record owner in same org
  authorize_if expr(
    organization_id == ^actor(:organization_id) and
    owner_id == ^actor(:id)
  )
end
```

### 5.5 Record Ownership Rules

```elixir
policy action_type(:read) do
  access_type :filter
  authorize_if expr(owner_id == ^actor(:id))
end

policy action_type([:update, :destroy]) do
  access_type :strict
  authorize_if expr(owner_id == ^actor(:id))
end
```

Or using `relates_to_actor_via/2`:

```elixir
policy action_type(:read) do
  access_type :filter
  authorize_if relates_to_actor_via(:owner)
end

policy action_type([:update, :destroy]) do
  access_type :strict
  authorize_if relates_to_actor_via(:owner)
end
```

---

## 6. Structuring Policies Inside Resources

### 6.1 Mandatory Sections

1. All resources with authorization must declare `policies do`
2. Policies must **NOT** be defined inside actions
3. Do not put policy DSL in regular functions

### 6.2 Recommended Resource Layout

```elixir
defmodule Voelgoedevents.Resources.Event do
  use Ash.Resource,
    authorizers: [Ash.Policy.Authorizer]

  # attributes, relationships, actions, etc.

  import Voelgoedevents.Policies.PlatformPolicy, only: [platform_admin_root_access: 0]
  import Voelgoedevents.Policies.OrganizationPolicy, only: [org_scoped_crud: 0]

  policies do
    # 1. Platform admin bypass
    platform_admin_root_access()

    # 2. Organization-scoped access
    org_scoped_crud()

    # 3. Additional resource-specific policies if needed
  end
end
```

---

## 7. Common Pitfalls (Do & Don't)

### ❌ DO NOT

1. Use `action_type/2` (invalid)
2. Call policy DSL from `def` functions
3. Use outdated check names from Ash 2.x
4. Use `:filter` on destructive actions expecting explicit errors
5. Reference data fields in create policy expressions
6. Mix tenant logic inconsistently across resources
7. Use browser storage APIs in apps

### ✅ DO

1. Use `action_type/1` only
2. Use macros for reusable policies
3. Validate against current Ash 3.x docs
4. Use `:filter` for reads, `:strict` for creates/updates/destroys
5. Write SimpleCheck modules for complex create policies
6. Centralize tenant logic in shared macros/checks
7. Always declare `policies do` in resources with authorization

---

## 8. Full Examples

### 8.1 Platform Policy Helper

```elixir
defmodule Voelgoedevents.Policies.PlatformPolicy do
  @moduledoc """
  Platform-wide policies for platform_admin role.
  """

  defmacro platform_admin_root_access do
    quote do
      bypass actor_attribute_equals(:role, "platform_admin") do
        access_type :strict
        authorize_if always()
      end
    end
  end
end
```

### 8.2 Organization Policy Helper

```elixir
defmodule Voelgoedevents.Policies.OrganizationPolicy do
  @moduledoc """
  Default org-scoped CRUD policies.
  """

  defmacro org_scoped_crud do
    quote do
      policy action_type(:read) do
        access_type :filter
        authorize_if expr(organization_id == ^actor(:organization_id))
      end

      policy action_type([:create, :update, :destroy]) do
        access_type :strict
        authorize_if expr(
          organization_id == ^actor(:organization_id) and
          ^actor(:role) == "org_admin"
        )
      end
    end
  end
end
```

### 8.3 Multi-Tenant Ticket Resource

```elixir
policies do
  # 1. Platform admin bypass
  bypass actor_attribute_equals(:role, "platform_admin") do
    access_type :strict
    authorize_if always()
  end

  # 2. Organization-scoped reads
  policy action_type(:read) do
    access_type :filter
    authorize_if expr(organization_id == ^actor(:organization_id))
  end

  # 3. Owners & org admins can update/destroy tickets
  policy action_type([:update, :destroy]) do
    access_type :strict

    # org admin in same org
    authorize_if expr(
      organization_id == ^actor(:organization_id) and
      ^actor(:role) == "org_admin"
    )

    # or ticket owner in same org
    authorize_if expr(
      organization_id == ^actor(:organization_id) and
      owner_id == ^actor(:id)
    )
  end
end
```

### 8.4 Custom Check Module (Ownership + Org Safety)

```elixir
defmodule Voelgoedevents.Policies.Checks.ActorOwnsRecordInOrg do
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "actor owns record in same organization"

  @impl true
  def filter(actor, _authorizer, _opts) do
    expr(
      organization_id == ^actor.organization_id and
      owner_id == ^actor.id
    )
  end
end
```

---

## 9. Implementation Checklist

When adding or modifying policies:

1. ✅ Confirm Ash version and check current docs
2. ✅ Reject any `action_type/2` usage
3. ✅ Ensure each resource:
   - Uses `authorizers: [Ash.Policy.Authorizer]`
   - Declares `policies do ... end`
   - Imports only approved policy macros
4. ✅ Multi-tenancy rules:
   - Enforce `organization_id == actor.organization_id` for tenants
   - Add platform admin bypass first
5. ✅ Access type sanity:
   - `:filter` for reads
   - `:strict` for creates/updates/destroys
6. ✅ Checks:
   - Inline expressions don't reference record fields in create contexts
   - Custom modules under `Voelgoedevents.Policies.Checks`
7. ✅ Macros:
   - Only `defmacro` helpers that emit DSL
   - No runtime logic inside macros
8. ✅ Testing:
   - Use `Ash.can?/3` and policy breakdown logging

---

## 10. References

- [Ash 3.x Policies Guide](https://hexdocs.pm/ash/policies.html)
- [Ash.Policy.Authorizer](https://hexdocs.pm/ash/Ash.Policy.Authorizer.html)
- [Ash.Policy.Check.Builtins](https://hexdocs.pm/ash/Ash.Policy.Check.Builtins.html)
- [Ash HQ](https://ash-hq.org)

---

**This standard is authoritative for all policy-related code in VoelgoedEvents. Any deviation must be documented and justified against the latest official Ash 3.x documentation.**
