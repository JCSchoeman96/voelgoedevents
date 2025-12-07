# Ash Policy Patterns (Ash 3.x)

This document defines the standard patterns for implementing policies in VoelgoedEvents, ensuring compliance with Ash 3.x and multi-tenancy requirements.

## 1. Multi-Tenancy Enforcement

All resources (except system-wide configs) must strictly enforce tenant isolation.

### Pattern: `authorize_if` with Organization Check

Use `authorize_if(expr(...))` to ensure the actor is accessing records within their own organization context. This often relies on `FilterByTenant` preparation, but policies explicitly define permissions.

**Usage:** Access Control Logic
**Reference:** [Ash Policy Expressions](https://hexdocs.pm/ash/Ash.Policy.Authorizer.html#module-policy-expressions)

```elixir
# Example from Voelgoedevents.Ash.Resources.Accounts.User
policy action_type([:read, :update]) do
  # Deny if requesting membership data outside actor's organization
  forbid_if expr(not exists(memberships, organization_id == actor(:organization_id)))
  authorize_if always()
end
```

### Pattern: Argument Matching

For creation or actions where the record doesn't exist yet, validate arguments against the actor's context.

```elixir
# Example from Voelgoedevents.Ash.Resources.Accounts.User
policy action(:create) do
  # Prevent creating users for other organizations
  forbid_if expr(arg(:organization_id) != actor(:organization_id))
  authorize_if always()
end
```

## 2. Authentication & Actor Context

Policies must handle authenticated vs. anonymous access gracefully.

### Pattern: `is_nil(actor(:id))`

Use `is_nil(actor(:id))` to detect unauthorized (anonymous) access.

> [!IMPORTANT]
> Do not use `actor == nil` or `is_nil(actor)`. Always check `is_nil(actor(:id))` for consistent SQL translation.

```elixir
# Example from Voelgoedevents.Ash.Resources.Accounts.Organization
policy action(:update) do
  # Must be logged in
  forbid_if expr(is_nil(actor(:id)))
  authorize_if always()
end
```

## 3. Resource vs. Action Policies

### Resource-Level Policies

Apply to specific action types across the entire resource. Good for blanket rules like "always allow reading public data" or "deny everything by default".

```elixir
# Example from Voelgoedevents.Ash.Resources.Accounts.Organization
policy action_type(:read) do
  # Public reading allowed (filtered by tenant elsewhere)
  authorize_if always()
end
```

### Action-Level Policies

Apply to specific named actions. Use this for action-specific business rules.

```elixir
# Example from Voelgoedevents.Ash.Resources.Accounts.Organization
policy action(:archive) do
  # Specific rules for the archive action
  forbid_if expr(is_nil(actor(:id)))
  authorize_if always()
end
```

## 4. Platform Administration

Platform admins bypass standard checks via `PlatformPolicy`.

```elixir
# Standard inclusion in all resources
policies do
  PlatformPolicy.platform_admin_root_access()
  # ... other policies
end
```
