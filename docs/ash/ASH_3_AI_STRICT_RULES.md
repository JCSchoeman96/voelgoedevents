# ASH 3.X EXAMPLE-DRIVEN ENTERPRISE RULEBOOK v5.0
## VoelgoedEvents Canonical Coding Standard

**STATUS:** Production-Ready | Example-Heavy | Agent-Executable  
**AUTHORITY:** Overrides all previous Ash docs | Non-Negotiable  
**ENFORCEMENT:** `mix ash.audit` v3+ | CI gates | PR review  
**REFERENCE DOCS:** Ash 3 Official Guides (linked)

---

## PART 0: GOLDEN RULES CHECKLIST

**Copy-paste these into your PR template. All must be ✅.**

- [ ] **0.1** Only Ash 3.x patterns (`use Ash.Domain`, not `use Ash.Api`)
- [ ] **0.2** Every `actor(:field)` wrapped in `expr()`
- [ ] **0.3** Actor passed ONLY to `Ash.create/update/destroy/read`, never to `for_create/for_update/for_destroy`
- [ ] **0.4** Every domain has `authorization do authorizers [Ash.Policy.Authorizer] end`
- [ ] **0.5** Every resource with policies ends with `default_policy :deny`
- [ ] **0.6** Every tenant-scoped resource has `organization_id :uuid, allow_nil?: false`
- [ ] **0.7** Multitenancy triple layer: `FilterByTenant` + `multitenancy do` block + policies
- [ ] **0.8** Actor shape is exactly 6 fields (see Section 4)
- [ ] **0.9** 3-test coverage (authorized, unauthorized, nil actor)
- [ ] **0.10** No direct `Repo` calls in `/lib` (migrations excepted)
- [ ] **0.11** No `use Ash.Api` anywhere in codebase
- [ ] **0.12** `mix compile --warnings-as-errors` passes
- [ ] **0.13** `mix ash.audit` shows zero violations

---

## PART 1: COPY-PASTE CANONICAL PATTERNS

### 1.1 Resource Template (Multi-Tenant Scoped)

```elixir
defmodule Voelgoedevents.Ash.Resources.Ticketing.Event do
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.Ticketing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "events"
    repo Voelgoedevents.Repo
  end

  # ============================================================================
  # ATTRIBUTES
  # ============================================================================
  attributes do
    uuid_primary_key :id

    # TENANT ATTRIBUTE (MANDATORY)
    attribute :organization_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    # ... more attributes ...

    timestamps()
  end

  # ============================================================================
  # MULTITENANCY (LAYER 1: CONFIGURATION)
  # ============================================================================
  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  # ============================================================================
  # RELATIONSHIPS
  # ============================================================================
  relationships do
    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      public? true
    end

    has_many :tickets, Voelgoedevents.Ash.Resources.Ticketing.Ticket do
      public? true
    end
  end

  # ============================================================================
  # ACTIONS
  # ============================================================================
  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      argument :organization_id, :uuid do
        allow_nil? false
        public? true
      end
      change set_attribute(:organization_id, arg(:organization_id))
    end

    update :update do
      primary? true
      change filter_attribute_changes(["organization_id"])
    end
  end

  # ============================================================================
  # POLICIES (LAYER 3: ENFORCEMENT)
  # ============================================================================
  policies do
    policy action_type(:read) do
      authorize_if expr(organization_id == actor(:organization_id))
      authorize_if expr(actor(:is_platform_admin) == true)
    end

    policy action_type(:create) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(
        organization_id == actor(:organization_id) and
        actor(:role) in [:owner, :admin, :staff]
      )
    end

    policy action_type(:update) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(
        organization_id == actor(:organization_id) and
        actor(:role) in [:owner, :admin, :staff]
      )
    end

    policy action_type(:destroy) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(
        organization_id == actor(:organization_id) and
        actor(:role) in [:owner, :admin]
      )
    end

    default_policy :deny
  end

  # ============================================================================
  # LAYER 2: QUERY FILTERING (MULTITENANCY ISOLATION)
  # ============================================================================
  code_interface do
    define_for Voelgoedevents.Ash.Domains.Ticketing
  end
end
```

**RULE:** Every resource MUST:
1. ✅ Specify `organization_id` attribute with `allow_nil?: false`
2. ✅ Have `multitenancy do strategy :attribute; attribute :organization_id end`
3. ✅ Have policies with tenant checks: `expr(organization_id == actor(:organization_id))`
4. ✅ End with `default_policy :deny`

---

### 1.2 Domain Template

```elixir
defmodule Voelgoedevents.Ash.Domains.Ticketing do
  use Ash.Domain

  # ============================================================================
  # AUTHORIZATION (MANDATORY)
  # ============================================================================
  authorization do
    authorizers [Ash.Policy.Authorizer]
  end

  # ============================================================================
  # RESOURCES
  # ============================================================================
  resources do
    resource Voelgoedevents.Ash.Resources.Ticketing.Event
    resource Voelgoedevents.Ash.Resources.Ticketing.Ticket
    resource Voelgoedevents.Ash.Resources.Ticketing.Order
  end

  # ============================================================================
  # DEFAULT ACTOR (OPTIONAL: for testing only)
  # ============================================================================
  # Do NOT use in production; always pass actor explicitly
end
```

**RULE:** Every domain MUST have `authorization do authorizers [Ash.Policy.Authorizer] end`.

---

### 1.3 Read Pattern (Canonical Invocation)

```elixir
# ❌ WRONG — Actor on changeset
events = Event
  |> Ash.Query.for_read(:read, %{}, actor: current_user)
  |> Ash.read()

# ✅ CORRECT — Actor on final call only
events = Event
  |> Ash.Query.for_read(:read)
  |> Ash.read(actor: current_user)
```

**Complete Example:**

```elixir
def list_events_for_org(org_id, current_user) do
  Event
  |> Ash.Query.for_read(:read)
  |> Ash.Query.filter(organization_id == ^org_id)
  |> Ash.read(actor: current_user)
  |> case do
    {:ok, events} -> {:ok, events}
    {:error, reason} -> {:error, inspect(reason)}
  end
end

# Invocation:
actor = %{
  user_id: user.id,
  organization_id: org_id,
  role: :staff,
  is_platform_admin: false,
  is_platform_staff: false,
  type: :user
}

{:ok, events} = list_events_for_org(org_id, actor)
```

---

### 1.4 Create Pattern (Canonical Invocation)

```elixir
# ❌ WRONG — Actor on for_create
changeset = Event
  |> Ash.Changeset.for_create(:create, params, actor: current_user)
result = Ash.create(changeset)

# ✅ CORRECT — Actor on Ash.create
changeset = Event
  |> Ash.Changeset.for_create(:create, params)
result = Ash.create(changeset, actor: current_user)
```

**Complete Example:**

```elixir
def create_event(org_id, params, current_user) do
  Event
  |> Ash.Changeset.for_create(:create, Map.put(params, :organization_id, org_id))
  |> Ash.create(actor: current_user)
  |> case do
    {:ok, event} -> {:ok, event}
    {:error, reason} -> {:error, inspect(reason)}
  end
end

# Invocation:
actor = %{
  user_id: user.id,
  organization_id: org_id,
  role: :staff,
  is_platform_admin: false,
  is_platform_staff: false,
  type: :user
}

{:ok, event} = create_event(org_id, %{"name" => "New Event"}, actor)
```

---

### 1.5 Update Pattern (Canonical Invocation)

```elixir
# ❌ WRONG — Actor on for_update
changeset = event
  |> Ash.Changeset.for_update(:update, params, actor: current_user)
result = Ash.update(changeset)

# ✅ CORRECT — Actor on Ash.update
changeset = event
  |> Ash.Changeset.for_update(:update, params)
result = Ash.update(changeset, actor: current_user)
```

**Complete Example:**

```elixir
def update_event(event, params, current_user) do
  event
  |> Ash.Changeset.for_update(:update, params)
  |> Ash.update(actor: current_user)
  |> case do
    {:ok, updated} -> {:ok, updated}
    {:error, reason} -> {:error, inspect(reason)}
  end
end
```

---

### 1.6 Destroy Pattern (Canonical Invocation)

```elixir
# ❌ WRONG — Actor on for_destroy
changeset = event
  |> Ash.Changeset.for_destroy(:destroy, actor: current_user)
result = Ash.destroy(changeset)

# ✅ CORRECT — Actor on Ash.destroy
changeset = event
  |> Ash.Changeset.for_destroy(:destroy)
result = Ash.destroy(changeset, actor: current_user)
```

---

### 1.7 Actor Injection from Phoenix (Plug Context)

```elixir
# lib/voelgoedevents_web/plugs/set_actor.ex
defmodule VoelgoedeventsWeb.Plugs.SetActor do
  def init(opts), do: opts

  def call(conn, _opts) do
    # Get current user from session (Phoenix standard)
    user = Guardian.Plug.current_resource(conn)

    actor = case user do
      nil ->
        # Public/unauthenticated actor (rare; most resources deny this)
        %{
          user_id: "anonymous",
          organization_id: nil,
          role: :public,
          is_platform_admin: false,
          is_platform_staff: false,
          type: :user
        }

      user ->
        # Authenticated user — fetch org_id and role from user record
        %{
          user_id: user.id,
          organization_id: user.current_org_id,
          role: user.role_in_current_org,
          is_platform_admin: user.is_platform_admin,
          is_platform_staff: user.is_platform_staff,
          type: :user
        }
    end

    Plug.Conn.assign(conn, :current_actor, actor)
  end
end

# lib/voelgoedevents_web/controllers/events_controller.ex
defmodule VoelgoedeventsWeb.EventsController do
  def index(conn, _params) do
    actor = conn.assigns.current_actor

    {:ok, events} = Voelgoedevents.Ash.Domains.Ticketing
      |> Ash.Query.filter(Event, organization_id == ^actor.organization_id)
      |> Ash.read(actor: actor)

    json(conn, %{events: events})
  end
end
```

---

## PART 2: BANNED PATTERNS WITH REWRITES

### 2.1 use Ash.Api (FOREVER BANNED)

❌ **CATASTROPHIC WRONG:**
```elixir
defmodule Voelgoedevents.Api.Ticketing do
  use Ash.Api
  resources [Ticket, Order]
end

Voelgoedevents.Api.Ticketing.read(Ticket, actor: user)
```

✅ **CORRECT:**
```elixir
defmodule Voelgoedevents.Ash.Domains.Ticketing do
  use Ash.Domain
  authorization do
    authorizers [Ash.Policy.Authorizer]
  end
  resources do
    resource Ticket
    resource Order
  end
end

Ticket |> Ash.read(actor: user)
```

**CI Check:**
```bash
rg "use Ash\.Api" lib/voelgoedevents --type elixir
# EXPECTED: zero matches
```

---

### 2.2 Actor on Changeset (WRONG, ALWAYS)

❌ **WRONG:**
```elixir
Ticket
|> Ash.Changeset.for_create(:create, %{code: "A1"}, actor: user)
|> Ash.create()
```

✅ **CORRECT:**
```elixir
Ticket
|> Ash.Changeset.for_create(:create, %{code: "A1"})
|> Ash.create(actor: user)
```

**Why:** Policy evaluation happens at the `Ash.create/2` level, not the changeset level. Passing actor early is ignored.

**CI Check:**
```bash
rg "for_(create|update|destroy)\([^)]*,\s*actor:" lib/voelgoedevents/ash --type elixir
# EXPECTED: zero matches
```

---

### 2.3 Bare actor() in Policies (NOT ALLOWED)

❌ **WRONG:**
```elixir
policy action_type(:read) do
  authorize_if actor(:id) != nil
end
```

✅ **CORRECT:**
```elixir
policy action_type(:read) do
  authorize_if expr(actor(:id) != nil)
end
```

**CI Check:**
```bash
rg "(authorize_if|forbid_if|authorize_unless|forbid_unless).*actor\(" lib/voelgoedevents/ash --type elixir
# Must show ONLY inside expr(...) — manual review of regex captures
```

---

### 2.4 Missing Organization ID in Tenant-Scoped Resources

❌ **WRONG:**
```elixir
attributes do
  uuid_primary_key :id
  attribute :name, :string
  # Missing :organization_id!
end
```

✅ **CORRECT:**
```elixir
attributes do
  uuid_primary_key :id

  attribute :organization_id, :uuid do
    allow_nil? false
    public? true
  end

  attribute :name, :string
end

multitenancy do
  strategy :attribute
  attribute :organization_id
end
```

**CI Check:**
```bash
# For each resource in lib/voelgoedevents/ash/resources:
# 1. Must have organization_id attribute
# 2. Must have multitenancy do block
# 3. Must have policy with org_id == actor(:organization_id)
rg "attribute :organization_id" lib/voelgoedevents/ash/resources --type elixir
# EXPECTED: every resource that needs it
```

---

### 2.5 Missing default_policy :deny

❌ **WRONG:**
```elixir
policies do
  policy action_type(:read) do
    authorize_if expr(organization_id == actor(:organization_id))
  end
  # No default_policy — defaults to ALLOW!
end
```

✅ **CORRECT:**
```elixir
policies do
  policy action_type(:read) do
    authorize_if expr(organization_id == actor(:organization_id))
  end

  default_policy :deny
end
```

**CI Check:**
```bash
# For each resource with "policies do" block:
# Must end with "default_policy :deny"
rg "policies do" lib/voelgoedevents/ash/resources --type elixir -A 50 | \
  grep -c "default_policy :deny"
# EXPECTED: >= number of "policies do" blocks
```

---

### 2.6 authorize?: false Bypass (Dangerous)

❌ **WRONG (without explicit justification):**
```elixir
policy action_type(:public_read) do
  authorize_if always()  # ANYONE can do this; justification missing
end
```

✅ **CORRECT (with marker and comment):**
```elixir
# ALLOW-MARKER-001: Public ticket search (anyone can see events)
# Justification: Events are marketing materials, safe for unauthenticated reads
# Expiry: None (foundational)
policy action_type(:public_read) do
  authorize_if always()
end
```

**Allowed Markers:**
- `ALLOW-MARKER-001` through `ALLOW-MARKER-099` (reserved for platform-wide public actions)
- `ALLOW-MARKER-INTERNAL-001` (internal workflows, checked infrequently)
- Each marker requires a comment block with Justification, Expiry, and Risk

**CI Check:**
```bash
rg "authorize_if.*always\(\)" lib/voelgoedevents/ash --type elixir -B 3
# EXPECTED: Each preceded by "ALLOW-MARKER-*" comment
```

---

## PART 3: MULTITENANCY RULES (3-LAYER ENFORCEMENT)

### 3.1 Layer 1: Resource Attribute (Mandatory)

```elixir
attributes do
  uuid_primary_key :id

  # REQUIRED: organization_id with allow_nil? false
  attribute :organization_id, :uuid do
    allow_nil? false
    public? true
  end
end
```

**Rule:** Every tenant-scoped resource MUST have this exact attribute.

---

### 3.2 Layer 2: Multitenancy Block (Configuration)

```elixir
multitenancy do
  strategy :attribute
  attribute :organization_id
end
```

**Rule:** Enables Ash's automatic tenant filtering in queries and changesets.

**Verification:**
```bash
rg "multitenancy do" lib/voelgoedevents/ash/resources --type elixir
# EXPECTED: for every resource with organization_id attribute
```

---

### 3.3 Layer 3: Policy Enforcement (Explicit Checks)

```elixir
policies do
  policy action_type(:read) do
    # Explicit tenant check — redundant but required
    authorize_if expr(organization_id == actor(:organization_id))
  end

  policy action_type(:create) do
    forbid_if expr(is_nil(actor(:organization_id)))
    authorize_if expr(
      actor(:organization_id) == organization_id and
      actor(:role) in [:owner, :admin]
    )
  end

  default_policy :deny
end
```

**Rule:** Layer 1 + Layer 2 + Layer 3 = defense in depth.

---

### 3.4 Actor's organization_id Must Match Resource's organization_id

```elixir
# ❌ WRONG: Tenant leakage risk
actor = %{
  user_id: user1.id,
  organization_id: org_2.id,  # User belongs to org_2
  role: :staff
  # ...
}

Event
|> Ash.Query.for_read(:read)
|> Ash.read(actor: actor)  # Must filter to org_2 only

# ✅ CORRECT: Tenant isolation enforced
actor = %{
  user_id: user1.id,
  organization_id: org_1.id,  # User's actual org
  role: :staff
  # ...
}

Event
|> Ash.Query.for_read(:read)
|> Ash.read(actor: actor)  # Filters to org_1 only
```

**Rule:** If `actor(:organization_id)` doesn't match the resource's `organization_id`, policies must deny.

---

## PART 4: RBAC RULES

### 4.1 Canonical Actor Shape (6 Fields Only)

```elixir
actor = %{
  user_id: "550e8400-e29b-41d4-a716-446655440000" | "system",
  organization_id: "550e8400-e29b-41d4-a716-446655440001" | nil,
  role: :owner | :admin | :staff | :viewer | :scanner_only | :system,
  is_platform_admin: false | true,
  is_platform_staff: false | true,
  type: :user | :system | :device | :api_key
}
```

**Mandatory Rules:**
- All 6 fields MUST be present in every actor
- `user_id` is UUID or string "system" (never nil)
- `organization_id` is UUID or nil (nil only for platform operations)
- `role` MUST be one of the 6 atoms above
- `is_platform_admin` and `is_platform_staff` are booleans (never nil)
- `type` MUST be one of 4 atoms above

**Policy Assumption:** Every policy can safely access all 6 fields without nil checks (except `organization_id` which can be nil for platform actors).

---

### 4.2 Role × Action Matrix (From RBAC Matrix)

**✅ IMPLEMENTED (Enforce Now):**
- `:owner` — full control within org
- `:admin` — events, members, reporting
- `:staff` — events, day-to-day
- `:viewer` — read-only
- `:scanner_only` — scanning only
- `:system` — background jobs

**Policy Example for Event Create:**

```elixir
policy action_type(:create) do
  forbid_if expr(is_nil(actor(:id)))
  forbid_if expr(actor(:type) not in [:user, :system])
  
  # System actors (background) can create only if organization_id provided
  authorize_if expr(
    actor(:type) == :system and
    not is_nil(actor(:organization_id)) and
    actor(:is_platform_admin) == true
  )

  # Regular users: owner, admin, staff
  authorize_if expr(
    actor(:type) == :user and
    organization_id == actor(:organization_id) and
    actor(:role) in [:owner, :admin, :staff]
  )

  default_policy :deny
end
```

---

### 4.3 Platform Admin vs Platform Staff

**is_platform_admin: true**
- VoelgoedEvents employee only
- Can access ANY organization's data
- Can create/destroy orgs
- Rare; used for support/debugging

**is_platform_staff: true**
- Support team; can VIEW cross-org data
- Cannot MUTATE unless they have a tenant role in that org
- Example: support viewing a customer's orders (read-only)

```elixir
# ❌ WRONG: is_platform_staff allows mutation
policy action_type(:update) do
  authorize_if expr(actor(:is_platform_staff) == true)
end

# ✅ CORRECT: is_platform_staff + tenant role required
policy action_type(:update) do
  authorize_if expr(
    actor(:is_platform_staff) == true and
    organization_id == actor(:organization_id) and
    actor(:role) in [:owner, :admin]
  )
end
```

---

## PART 5: SECURITY POSTURE

### 5.1 Forbid Patterns

Use `forbid_if` to explicitly reject dangerous conditions BEFORE checking authorization:

```elixir
policies do
  # FORBID FIRST (deny dangerous states)
  policy action_type(:sensitive_update) do
    forbid_if expr(is_nil(actor(:id)))  # Unauthenticated
    forbid_if expr(actor(:type) == :device)  # Devices can't do this
    forbid_if expr(
      actor(:role) not in [:owner, :admin] and
      context[:bypass_auth] == true  # Explicit bypass markers
    )

    # AUTHORIZE SECOND (allow safe states)
    authorize_if expr(
      organization_id == actor(:organization_id) and
      actor(:role) in [:owner, :admin]
    )

    default_policy :deny
  end
end
```

**Rule:** Check `forbid_if` conditions before `authorize_if`. This prevents accidental authorizations.

---

### 5.2 No Direct Repo Calls in /lib

❌ **WRONG:**
```elixir
# lib/voelgoedevents/services/event_service.ex
defmodule EventService do
  def get_event(id, _actor) do
    Voelgoedevents.Repo.get(Event, id)  # BANNED — bypasses policies
  end
end
```

✅ **CORRECT:**
```elixir
defmodule EventService do
  def get_event(id, actor) do
    Event
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read(actor: actor)
    |> case do
      {:ok, [event]} -> {:ok, event}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

**Exception:** Migrations only.

```bash
rg "\.Repo\.(get|all|one|insert|update|delete)" lib/voelgoedevents --type elixir
# EXPECTED: zero matches (except priv/repo/migrations)
```

---

### 5.3 Testing: 3-Case Pattern (Mandatory)

Every resource action MUST have 3 tests:

```elixir
defmodule Voelgoedevents.Ash.Resources.Ticketing.EventTest do
  use ExUnit.Case, async: true

  # Case 1: Authorized actor
  test "create event as staff in org" do
    org = setup_org()
    user = setup_user(org, :staff)
    actor = build_actor(user, org)

    assert {:ok, event} = Event
      |> Ash.Changeset.for_create(:create, %{"name" => "My Event"})
      |> Ash.create(actor: actor)
  end

  # Case 2: Unauthorized actor
  test "reject event creation from different org" do
    org1 = setup_org()
    org2 = setup_org()
    user = setup_user(org1, :viewer)
    actor = build_actor(user, org1)

    # Try to create event in org2 (not allowed)
    assert {:error, %Ash.Error.Forbidden{}} = Event
      |> Ash.Changeset.for_create(:create, %{
        "name" => "Event in org2",
        "organization_id" => org2.id
      })
      |> Ash.create(actor: actor)
  end

  # Case 3: Nil actor (edge case)
  test "reject event creation with nil actor" do
    assert {:error, %Ash.Error.Forbidden{}} = Event
      |> Ash.Changeset.for_create(:create, %{"name" => "Event"})
      |> Ash.create(actor: nil)
  end

  # Helpers
  defp build_actor(user, org) do
    %{
      user_id: user.id,
      organization_id: org.id,
      role: user.role_in_org,
      is_platform_admin: false,
      is_platform_staff: false,
      type: :user
    }
  end
end
```

**Rule:** 3 tests minimum for every action with authorization.

---

## PART 6: QUICK TROUBLESHOOTING

| Error | Cause | Fix |
|-------|-------|-----|
| `Ash.Error.Forbidden` on read/create/update/destroy | Policy denies actor | Check: 1) actor has correct fields, 2) organization_id matches, 3) role is authorized, 4) `default_policy :deny` is last |
| `Actor is not of a type that can be used` | Actor is missing fields or wrong type | Actor MUST have all 6 fields; check actor map construction |
| `undefined function actor/1` | Bare `actor()` outside `expr()` | Wrap in `expr(actor(:field))` |
| `Policy list syntax error` | Using Ash 2.x `policy [...]` syntax | Use Ash 3.x `policy action_type(...) do...end` |
| `organization_id mismatch` | Actor org doesn't match resource org | Verify actor's `organization_id` == resource's `organization_id` |
| `No valid policies` | `default_policy :deny` is missing | Add `default_policy :deny` as last policy |
| Tests pass locally, fail in CI | `mix ash.audit` catching violations | Run `mix ash.audit` locally before push |
| Multitenancy leak (org1 sees org2's data) | Missing Layer 2 or Layer 3 | Add `multitenancy do` + policies with org checks |

---

## PART 7: COMPLIANCE CHECKLIST (Pre-PR)

**All items must be ✅ before merge:**

### Architecture Verification
- [ ] Domain has `authorization do authorizers [Ash.Policy.Authorizer] end`
- [ ] Resource has `organization_id, :uuid, allow_nil?: false`
- [ ] Multitenancy block present: `strategy :attribute; attribute :organization_id`

### Syntax Verification
- [ ] No `use Ash.Api`
- [ ] No actor on `for_create/for_update/for_destroy`
- [ ] All actor references inside `expr()`
- [ ] All policies end with `default_policy :deny`
- [ ] Policy syntax is `policy action_type(...) do...end` (not lists)

### Testing Checklist
- [ ] 3 tests per action (authorized, unauthorized, nil actor)
- [ ] All tests pass: `mix test`
- [ ] Cover all roles in RBAC matrix for this resource

### Security Review
- [ ] No `Repo.` calls in `/lib`
- [ ] No `authorize?: false` without `ALLOW-MARKER-*` comment
- [ ] No bare actor() in policies
- [ ] Policies check tenant isolation (`organization_id == actor(:organization_id)`)
- [ ] `forbid_if` conditions checked before `authorize_if`

### Compliance Review
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix ash.audit` shows zero violations
- [ ] All CI checks pass

---

## PART 8: REFERENCES & LINKS

**Official Ash 3 Guides (Read These):**
- [Actors & Authorization](https://hexdocs.pm/ash/actors-and-authorization.html)
- [Policies](https://hexdocs.pm/ash/policies.html)
- [Policy Authorizer](https://hexdocs.pm/ash/Ash.Policy.Authorizer.html)
- [Expressions / expr()](https://hexdocs.pm/ash/expressions.html)
- [Multitenancy](https://hexdocs.pm/ash/multitenancy.html)
- [Ash.Query](https://hexdocs.pm/ash/Ash.Query.html)
- [Ash.Changeset](https://hexdocs.pm/ash/Ash.Changeset.html)
- [Ash.Resource](https://hexdocs.pm/ash/Ash.Resource.html)
- [Ash.Domain](https://hexdocs.pm/ash/Ash.Domain.html)

**VoelgoedEvents Docs:**
- `/docs/domain/rbac_and_platform_access.md` — Business RBAC rules
- `/docs/ash/ASH_3_RBAC_MATRIX.md` — Role × Action matrix
- `MASTER_BLUEPRINT.md` — Architecture overview
- `ai_context_map.md` — Module paths

---

## PART 9: ENFORCEMENT & CI

### 9.1 CI Pipeline Must Run (Every PR)

```bash
#!/bin/bash
set -e

echo "🔍 Checking Ash 3.x compliance..."

# 1. No Ash.Api
rg "use Ash.Api" lib/voelgoedevents --type elixir && {
  echo "❌ FAIL: use Ash.Api found"
  exit 1
}

# 2. No actor on changeset
rg "for_(create|update|destroy)\([^)]*,\s*actor:" lib/voelgoedevents/ash --type elixir && {
  echo "❌ FAIL: actor on changeset found"
  exit 1
}

# 3. Compile
mix compile --warnings-as-errors || exit 1

# 4. Full audit
mix ash.audit || exit 1

# 5. Tests
mix test || exit 1

echo "✅ All checks passed"
```

### 9.2 ash.audit Roadmap (Future Automated Checks)

These checks should eventually be enforced by `mix ash.audit`:
- [ ] Every resource with policies has `default_policy :deny`
- [ ] Every tenant-scoped resource has `organization_id` with `allow_nil?: false`
- [ ] Every domain has `authorization do...authorizers [Ash.Policy.Authorizer] end`
- [ ] No bare `actor()` outside `expr()`
- [ ] Every action has 3 tests (minimum)
- [ ] No `Repo.` calls in `/lib` (except migrations)

---

**Status:** ✅ PRODUCTION-READY — Copy examples, follow rules, pass checklist.
