# Ash Framework Coding Style Guide

## Purpose

This guide defines how to write Ash Framework code in VoelgoedEvents. **Ash is the canonical domain engine.** All business logic—ticketing, seat allocation, payments, policies, multi-tenancy enforcement—flows through Ash resources and actions.

## Critical Principle: Ash Is the Only Domain Engine

**No business logic outside Ash.**

- ❌ Do not implement business logic in Phoenix controllers or LiveViews.
- ❌ Do not implement business logic in services or helper functions.
- ❌ Do not execute direct `Repo.insert/update/delete` outside Ash.
- ✅ All business logic lives in Ash resources, actions, validations, calculations, and policies.

The reason: Ash enforces multi-tenancy, validation, authorization, and consistency at the domain layer. Bypassing Ash bypasses these guarantees.

## Resource Design

### Resource Organization

- **One resource per aggregate root** in your domain model.
- **Domain-focused naming**: `Ticketing.Ticket`, `Payments.Transaction`, `Events.Venue`, not generic names.

```elixir
# Good
defmodule VoelgoedEvents.Ticketing.Ticket do
  use Ash.Resource

  @doc "Represents a ticket, the primary aggregate in the ticketing domain."
  # ...
end

# Avoid
defmodule VoelgoedEvents.Ticket do
  # Ambiguous; which domain owns this?
end
```

### Attributes

- Use descriptive, domain-relevant attribute names.
- Always include `organization_id` for multi-tenancy scoping.
- Use appropriate types: `:string`, `:integer`, `:boolean`, `:uuid`, `:datetime_utc`, `:atom`, etc.
- Add documentation to attributes.

```elixir
defmodule VoelgoedEvents.Ticketing.Ticket do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    
    # Multi-tenancy: required on every resource
    attribute :organization_id, :uuid do
      allow_nil? false
    end

    # Domain attributes
    attribute :event_id, :uuid do
      allow_nil? false
    end

    attribute :section, :string do
      allow_nil? false
      description "Seating section (e.g., 'vip', 'general', 'balcony')"
    end

    attribute :seat_number, :integer do
      allow_nil? false
      description "Seat identifier within the section"
    end

    attribute :status, :atom do
      allow_nil? false
      description "Ticket status: :available, :reserved, :confirmed, :cancelled"
    end

    attribute :price_cents, :integer do
      allow_nil? false
      description "Price in cents (currency-agnostic storage)"
    end

    timestamps()
  end
end
```

### Relationships

- Use relationships to model domain aggregates clearly.
- Always include a relationship to the owning organization.

```elixir
relationships do
  # Tenant relationship
  belongs_to :organization, VoelgoedEvents.Accounts.Organization do
    allow_nil? false
  end

  # Domain relationships
  belongs_to :event, VoelgoedEvents.Events.Event do
    allow_nil? false
  end

  belongs_to :user, VoelgoedEvents.Accounts.User do
    allow_nil? true  # Unconfirmed tickets may not have a user yet
  end

  has_many :transactions, VoelgoedEvents.Payments.Transaction do
    description "Payment transactions related to this ticket"
  end
end
```

### Calculations

Use calculations for derived values that don't need to be persisted.

```elixir
calculations do
  calculate :is_available, :boolean, expr(status == :available)
  
  calculate :status_label, :string, expr(
    case(
      status,
      do: [
        available: "Available",
        reserved: "Reserved (Hold)",
        confirmed: "Confirmed",
        cancelled: "Cancelled"
      ]
    )
  )

  calculate :display_price, :string, expr(
    fragment("format('$%.2f', ?::numeric / 100)", price_cents)
  )
end
```

## Actions: The Domain Interface

### Action Types and Usage

Ash provides several action types. Use each correctly:

- **`:create`** – Inserts a new record. Use for ticket creation, order placement, etc.
- **`:read`** – Queries records. Use for fetching tickets, events, users.
- **`:update`** – Modifies existing records. Use for status transitions, price changes.
- **`:destroy`** – Deletes records. Use sparingly (prefer soft deletes with status changes).
- **`:action`** – Custom business logic, no automatic DB operation. Use for complex workflows.

### Naming Actions

Action names should be verbs that describe the intent, not just the operation.

```elixir
# Good: Clear intent
actions do
  create :create do
    description "Create a new ticket in :available status"
  end

  create :reserve_for_user do
    description "Reserve a ticket for a user, moving it from :available to :reserved"
    argument :user_id, :uuid, required: true
  end

  read :list_by_event do
    description "List all tickets for a given event"
    argument :event_id, :uuid, required: true
    filter expr(event_id == ^arg(:event_id))
  end

  update :confirm_reservation do
    description "Confirm a reserved ticket, moving it to :confirmed status"
    require_atomic? false
  end

  destroy :cancel do
    description "Cancel a ticket, moving it to :cancelled status"
  end
end
```

### Action Arguments

- Always use arguments for inputs to custom actions.
- Document each argument clearly.

```elixir
create :reserve_for_user do
  argument :user_id, :uuid do
    allow_nil? false
    description "User ID requesting the ticket"
  end

  argument :hold_duration_minutes, :integer do
    allow_nil? true
    description "How long the hold is valid (default: 15 minutes)"
  end

  # Implementation changes (below)
end
```

### Changes: Implementing Business Logic

Changes transform data before validation and persistence. Use changes for:

- Setting computed fields
- Enforcing domain invariants
- Interacting with external services
- Emitting events

```elixir
create :reserve_for_user do
  argument :user_id, :uuid, required: true
  
  change set_attribute(:status, :reserved)
  change set_attribute(:user_id, arg(:user_id))
  
  change fn changeset, _context ->
    # Custom logic: set hold expiration
    hold_duration = Keyword.get(changeset.context, :hold_duration_minutes, 15)
    expires_at = DateTime.add(DateTime.utc_now(), hold_duration * 60)
    Ash.Changeset.force_change_attribute(changeset, :expires_at, expires_at)
  end

  change after_action(fn _changeset, record, _context ->
    # Emit an event after successful creation
    {:ok, _} = PubSub.broadcast("ticketing:events", {:ticket_reserved, record})
    {:ok, record}
  end)
end
```

### Validations: Enforcing Constraints

Validations run after changes and before persistence. Use for domain rules.

```elixir
validations do
  validate string_length(:section, min: 1, max: 50)
  
  validate numericality(:seat_number, min: 1)
  
  validate numericality(:price_cents, min: 0)
  
  validate one_of(:status, [:available, :reserved, :confirmed, :cancelled])

  validate fn changeset ->
    # Custom: Prevent overbooking by checking total reserved + confirmed
    organization_id = Ash.Changeset.get_attribute(changeset, :organization_id)
    event_id = Ash.Changeset.get_attribute(changeset, :event_id)
    section = Ash.Changeset.get_attribute(changeset, :section)

    if organization_id && event_id && section do
      reserved_count = Ticket
        |> Ash.Query.filter(organization_id == ^organization_id)
        |> Ash.Query.filter(event_id == ^event_id)
        |> Ash.Query.filter(section == ^section)
        |> Ash.Query.filter(status in [:reserved, :confirmed])
        |> Ash.read!()
        |> length()

      capacity = fetch_section_capacity(event_id, section)

      if reserved_count >= capacity do
        Ash.Changeset.add_error(changeset, :section, "Section is at capacity")
      else
        changeset
      end
    else
      changeset
    end
  end
end
```

## Policies: Authorization

Policies enforce who can perform which actions on which records.

### Policy Structure

- One policy per resource (usually).
- Use `:actor` to reference the current user/context.
- Scope all read actions to the actor's organization.

```elixir
defmodule VoelgoedEvents.Ticketing.Ticket.Policy do
  use Ash.Policy.Guide

  policies do
    # Anyone can read tickets for their organization
    policy action_type(:read) do
      authorize_if expr(organization_id == actor(:organization_id))
    end

    # Only ticket owners can update their own tickets
    policy action_type(:update) do
      authorize_if expr(
        organization_id == actor(:organization_id) and
        user_id == actor(:id)
      )
    end

    # Admins of the organization can cancel tickets
    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Fail-closed: unknown actions are denied by Ash Policy Authorizer semantics
  end
end
```

### Multi-Tenancy in Policies

**Every resource must enforce organization isolation in policies.**

```elixir
defmodule VoelgoedEvents.Events.Event.Policy do
  use Ash.Policy.Guide

  policies do
    # Only read events for your organization
    policy action_type(:read) do
      authorize_if expr(organization_id == actor(:organization_id))
    end

    # Fail-closed: unknown actions are denied by Ash Policy Authorizer semantics
  end
end
```

## Advanced Patterns

### Atomicity and Concurrency

For critical operations (e.g., seat allocation), ensure atomicity:

```elixir
# Use transactions for multi-resource operations
def allocate_and_confirm(user_id, event_id, organization_id) do
  Ash.Changeset.new(Ticket)
    |> Ash.Changeset.set_context(%{transaction?: true})
    |> Ash.Changeset.call_action(:reserve_for_user, %{user_id: user_id})
    |> case do
      {:ok, ticket} -> confirm_reservation(ticket)
      error -> error
    end
end
```

### Using Aggregates for Performance

Aggregates fetch computed values without loading full records.

```elixir
# In a resource:
aggregates do
  count :available_count, :available_filter do
    description "Count of available tickets (for display)"
  end
end

# In a query:
Ticket
  |> Ash.Query.filter(event_id == ^event_id)
  |> Ash.Query.select([:id, :available_count])
  |> Ash.read!()
```

### Calculations with Expressions

Use Ash expressions for server-side computations:

```elixir
calculations do
  calculate :percentage_sold, :float, expr(
    fragment("CAST(? AS FLOAT) / ? * 100", confirmed_count, total_count)
  )
end
```

### Embedded Domains

For nested or composite data (e.g., order line items), use embedded resources:

```elixir
defmodule VoelgoedEvents.Orders.LineItem do
  use Ash.Resource, embedded?: true

  attributes do
    attribute :ticket_id, :uuid
    attribute :quantity, :integer
    attribute :unit_price_cents, :integer
  end
end

defmodule VoelgoedEvents.Orders.Order do
  use Ash.Resource

  attributes do
    # ...
    attribute :line_items, {:array, VoelgoedEvents.Orders.LineItem} do
      description "Items in this order"
    end
  end
end
```

## Integration with Caching and Events

Ash resources emit events that drive the caching layer.

### After-Action Events

```elixir
update :confirm_reservation do
  change after_action(fn _changeset, record, _context ->
    # Emit event so caching layer updates ETS/Redis
    PubSub.broadcast("ticketing", {:ticket_confirmed, record})
    {:ok, record}
  end)
end
```

### Caching Reads

For frequently accessed data, cache query results:

```elixir
read :by_event_section do
  argument :event_id, :uuid, required: true
  argument :section, :string, required: true

  filter expr(event_id == ^arg(:event_id) and section == ^arg(:section))

  change after_action(fn _changeset, records, _context ->
    # Cache in ETS and Redis
    {:ok, _} = ETS.put_tickets(arg(:event_id), arg(:section), records)
    {:ok, records}
  end)
end
```

## Common Patterns: Complete Example

Here's a complete Ash resource implementing domain logic for ticket reservations:

```elixir
defmodule VoelgoedEvents.Ticketing.Reservation do
  use Ash.Resource

  @moduledoc """
  Represents a ticket reservation: a temporary hold on a seat.
  
  Lifecycle:
  1. Create a reservation (:reserved status) with a hold expiration time
  2. Confirm the reservation (:confirmed status, becomes a permanent ticket)
  3. Or cancel the reservation, releasing the seat back to available
  
  Multi-tenancy: All reservations are scoped to an organization.
  Concurrency: Uses distributed locks via Redis to prevent double-booking.
  """

  defmodule Changes.SetHoldExpiration do
    @moduledoc "Sets the hold expiration time (default: 15 min from now)"
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      hold_duration = Keyword.get(changeset.context[:options] || [], :hold_duration_minutes, 15)
      expires_at = DateTime.add(DateTime.utc_now(), hold_duration * 60)
      Ash.Changeset.force_change_attribute(changeset, :expires_at, expires_at)
    end
  end

  defmodule Changes.EmitReservedEvent do
    use Ash.Resource.Change

    def after_action(changeset, record, _context) do
      PubSub.broadcast("ticketing", {:reservation_created, record})
      {:ok, record}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end

    attribute :event_id, :uuid do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :section, :string do
      allow_nil? false
    end

    attribute :seat_number, :integer do
      allow_nil? false
    end

    attribute :status, :atom do
      allow_nil? false
      default :reserved
    end

    attribute :price_cents, :integer do
      allow_nil? false
    end

    attribute :expires_at, :datetime_utc do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, VoelgoedEvents.Accounts.Organization do
      allow_nil? false
    end

    belongs_to :event, VoelgoedEvents.Events.Event do
      allow_nil? false
    end

    belongs_to :user, VoelgoedEvents.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :is_expired, :boolean, expr(expires_at < now())
  end

  actions do
    create :create do
      argument :hold_duration_minutes, :integer do
        allow_nil? true
      end

      change set_attribute(:status, :reserved)
      change Changes.SetHoldExpiration
      change Changes.EmitReservedEvent
    end

    read :list_by_event do
      argument :event_id, :uuid, required: true
      filter expr(event_id == ^arg(:event_id) and status == :reserved)
    end

    read :list_active_by_user do
      argument :user_id, :uuid, required: true
      filter expr(user_id == ^arg(:user_id) and status == :reserved and not is_expired)
    end

    update :confirm do
      change set_attribute(:status, :confirmed)
      change after_action(fn _cs, record, _ctx ->
        PubSub.broadcast("ticketing", {:reservation_confirmed, record})
        {:ok, record}
      end)
    end

    destroy :release do
      change after_action(fn _cs, record, _ctx ->
        PubSub.broadcast("ticketing", {:reservation_released, record})
        {:ok, record}
      end)
    end
  end

  validations do
    validate numericality(:seat_number, min: 1)
    validate numericality(:price_cents, min: 0)

    validate fn changeset ->
      if Ash.Changeset.changing_attribute?(changeset, :expires_at) do
        expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)
        if DateTime.compare(expires_at, DateTime.utc_now()) in [:eq, :lt] do
          Ash.Changeset.add_error(changeset, :expires_at, "must be in the future")
        else
          changeset
        end
      else
        changeset
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(organization_id == actor(:organization_id))
    end

    policy action_type(:update) do
      authorize_if expr(
        organization_id == actor(:organization_id) and
        user_id == actor(:id)
      )
    end

    policy action_type(:destroy) do
      authorize_if expr(
        organization_id == actor(:organization_id) and
        user_id == actor(:id)
      )
    end
  end
end
```

---

*Last updated: 2025-11-25*