# General Elixir Coding Style Guide

## Purpose

This guide defines general Elixir coding conventions and best practices for VoelgoedEvents. It covers language-level idioms, naming, structure, error handling, and concurrency patterns that all Elixir code in the project should follow.

## Why This Matters for VoelgoedEvents

VoelgoedEvents is built on Elixir/OTP and the PETAL stack. Elixir's strengths—immutability, pattern matching, concurrency, reliability—are core to the platform's ability to handle high load, real-time updates, and concurrent event ticketing. Writing idiomatic Elixir maximizes these strengths.

## Naming Conventions

### Module Names

- **One module per file.** File path mirrors module hierarchy.
  ```
  lib/voelgoed_events/ticketing/ticket.ex
  → VoelgoedEvents.Ticketing.Ticket
  ```
- **Descriptive, specific names.** Avoid generic names like `Helper`, `Util`, or `Service`.
  ```elixir
  # Good
  VoelgoedEvents.Ticketing.SeatAllocation
  VoelgoedEvents.Payments.InvoiceGenerator
  
  # Avoid
  VoelgoedEvents.Ticketing.Utils
  VoelgoedEvents.Ticketing.Helper
  ```

### Function Names

- **Verb-oriented for action functions.** What does it do?
  ```elixir
  # Good
  def allocate_seat(event_id, user_id, opts \\ [])
  def reserve_ticket(ticket_id, opts \\ [])
  def calculate_total_price(items)
  
  # Avoid
  def seat_allocation(...)
  def ticket_reservation(...)
  ```
- **Predicate functions end in `?`.**
  ```elixir
  def available?(ticket)
  def expired?(event)
  def valid_for_organization?(record, org_id)
  ```
- **Functions that may raise or transform end in `!`.**
  ```elixir
  def allocate_seat!(event_id, user_id)
  def fetch_required_fields!(map)
  ```

### Variable Names

- **Clear and descriptive.**
  ```elixir
  # Good
  def process_payment(order_id, user_id, payment_method) do
    {:ok, charge} = ChargeService.process(order_id, payment_method)
    {:ok, transaction} = Transaction.create(order_id, charge)
    transaction
  end
  
  # Avoid
  def process_payment(oid, uid, pm) do
    {:ok, c} = ChargeService.process(oid, pm)
    {:ok, t} = Transaction.create(oid, c)
    t
  end
  ```
- **Avoid single-letter variables** except in tight `Enum` operations.
  ```elixir
  # Acceptable in tight enums
  Enum.map(events, fn e -> e.name end)
  
  # Better if long
  Enum.map(events, fn event -> event.name end)
  ```

### Constants

- **SCREAMING_SNAKE_CASE for module-level constants.**
  ```elixir
  @max_concurrent_reservations 100
  @ticket_hold_duration_minutes 15
  @payment_timeout_ms 30_000
  ```

## Structure and Organization

### Module Structure

- **`@moduledoc` at the top of every module.**
  ```elixir
  defmodule VoelgoedEvents.Ticketing.SeatAllocation do
    @moduledoc """
    Manages seat allocation and reservation logic for events.
    
    Handles concurrent seat allocation, ensures no double-booking,
    and enforces capacity constraints per section and event.
    """
  ```
- **`@doc` for every public function.**
  ```elixir
  @doc """
  Allocates a seat for a user at an event.
  
  Returns `{:ok, seat}` if allocation succeeds, or `{:error, reason}` if:
  - The seat is already taken
  - The user lacks permission
  - The event is sold out
  """
  def allocate_seat(event_id, user_id, opts \\ [])
  ```
- **Private functions after public ones.** Use `defp` for functions not exported.
  ```elixir
  def public_function(arg) do
    private_helper(arg)
  end
  
  defp private_helper(arg) do
    # ...
  end
  ```

### File Organization

Within a module file:

1. Module declaration and `@moduledoc`
2. Aliases and imports
3. Module attributes (`@behaviour`, `@enforce_keys`, etc.)
4. Public functions (declare first, implement after if using forwards)
5. Private functions
6. Callback implementations (if using protocols or behaviours)

```elixir
defmodule VoelgoedEvents.Ticketing.Ticket do
  @moduledoc """
  Represents a ticket resource and related operations.
  """

  # Aliases and imports
  alias VoelgoedEvents.Repo
  import Ecto.Query, only: [where: 3]

  # Module attributes
  @enforce_keys [:event_id, :user_id, :status]
  @status_values ~w(pending confirmed cancelled)

  # Public functions
  def create(event_id, user_id, opts \\ []) do
    # Implementation
  end

  def list_by_event(event_id) do
    # Implementation
  end

  # Private functions
  defp validate_ticket(ticket) do
    # Implementation
  end
end
```

## Immutability and Rebinding

### Correct Pattern Matching and Rebinding

Elixir values are immutable. When you reassign a variable, you're rebinding the name in the local scope.

```elixir
# Good: Clear rebinding
def process_user(user) do
  user = update_in(user, [:email], &String.downcase/1)
  user = put_in(user, [:updated_at], DateTime.utc_now())
  user
end

# Also good: Pipe for clarity
def process_user(user) do
  user
  |> update_in([:email], &String.downcase/1)
  |> put_in([:updated_at], DateTime.utc_now())
end
```

### Conditional Rebinding

Use `if`, `case`, or `cond` to rebind based on conditions. Always assign the result.

```elixir
# Good
def set_discount(price, user) do
  discount = if user.is_vip, do: 0.1, else: 0
  price * (1 - discount)
end

# Good: case for multiple paths
def status_label(status) do
  label = case status do
    :pending -> "Pending Confirmation"
    :confirmed -> "Confirmed"
    :cancelled -> "Cancelled"
    _ -> "Unknown"
  end
  label
end

# Avoid: Not rebinding the result
def bad_example(price, user) do
  if user.is_vip, do: price * 0.9, else: price  # Value lost if not used
end
```

## Pattern Matching

### Use Pattern Matching Liberally

Pattern matching is more readable and safer than guard clauses or conditionals.

```elixir
# Good: Pattern match in function head
def handle_result({:ok, ticket}) do
  ticket
end

def handle_result({:error, reason}) do
  {:error, reason}
end

# Good: Pattern match in case
def process_event(event) do
  case fetch_tickets(event.id) do
    {:ok, tickets} when is_list(tickets) -> render_tickets(tickets)
    {:error, :not_found} -> {:error, "No tickets found"}
    {:error, reason} -> {:error, reason}
  end
end

# Avoid: Conditional instead of pattern matching
def handle_result(result) do
  case result do
    x when is_tuple(x) and elem(x, 0) == :ok -> elem(x, 1)
    # Hard to read, uses positional access
  end
end
```

## Collections: Lists, Maps, and Keyword Lists

### Lists

- Used for ordered, homogeneous collections.
- Use list comprehensions and `Enum` for transformations.

```elixir
# Good: List comprehension
event_names = [for event <- events, do: event.name]

# Good: Enum functions
event_names = Enum.map(events, fn e -> e.name end)

# Avoid: Manually looping
event_names = []
for event <- events do
  event_names = event_names ++ [event.name]  # Inefficient
end
```

### Maps

- Used for key-value data, especially variable structure.
- Prefer atom keys for known structures; string keys for external data.

```elixir
# Good: Atom keys for known structure
event = %{"name" => "Concert", "date" => "2025-12-01"}
event = Map.put(event, "venue", "Downtown Hall")

# Good: Access known structure
case event do
  %{"name" => name, "date" => date} -> "Event: #{name} on #{date}"
  _ -> "Unknown format"
end

# Avoid: Directly accessing external map without pattern matching
event = external_api_response  # Could be missing keys
name = event["name"]  # May raise KeyError if not present
```

### Keyword Lists

- Used for options, configuration, and function arguments where order matters.
- Always use atom keys.

```elixir
# Good: Options as keyword list
def list_events(opts \\ []) do
  limit = Keyword.get(opts, :limit, 10)
  offset = Keyword.get(opts, :offset, 0)
  Repo.all(Event, limit: limit, offset: offset)
end

# Usage
list_events(limit: 20, offset: 40)
```

## Error Handling

### Tagged Tuples as the Standard

Use `{:ok, value}` and `{:error, reason}` consistently. This is idiomatic Elixir and works well with pattern matching.

```elixir
# Good
def allocate_seat(event_id, user_id) do
  with {:ok, event} <- fetch_event(event_id),
       {:ok, user} <- fetch_user(user_id),
       {:ok, seat} <- find_available_seat(event),
       {:ok, allocation} <- Repo.insert(allocation_changeset(seat, user)) do
    {:ok, allocation}
  else
    {:error, :not_found} -> {:error, "Event not found"}
    {:error, :invalid} -> {:error, "Invalid user"}
    {:error, reason} -> {:error, reason}
  end
end

# Usage
case SeatAllocation.allocate_seat(event_id, user_id) do
  {:ok, seat} -> render_confirmation(seat)
  {:error, reason} -> render_error(reason)
end
```

### Clear Error Messages

Error reasons should be specific enough to debug.

```elixir
# Good: Descriptive atoms and strings
{:error, :seat_already_taken}
{:error, :insufficient_funds}
{:error, "Event not found for organization #{org_id}"}

# Avoid: Generic reasons
{:error, :failed}
{:error, :error}
```

### Use `with` for Sequential Operations

`with` is ideal for pipelines that may fail at any step.

```elixir
def process_ticket_purchase(order_id, user_id, payment_info) do
  with {:ok, order} <- fetch_order(order_id),
       {:ok, _} <- validate_user_owns_order(order, user_id),
       {:ok, charge} <- process_payment(order, payment_info),
       {:ok, transaction} <- record_transaction(order, charge),
       {:ok, _} <- send_confirmation_email(order, charge) do
    {:ok, transaction}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

### Raising Exceptions for True Exceptions

Raise only for conditions that should never happen in normal operation.

```elixir
# Good: Raise for programming errors, guard bugs
def fetch_organization_id_from_context!(context) do
  context[:organization_id] || raise "Organization ID missing from context"
end

# Good: Raise for database integrity violations detected at runtime
def enforce_single_active_registration!(user_id) do
  count = Repo.aggregate(Registration, :count, where: [user_id: user_id, active: true])
  count <= 1 || raise "Multiple active registrations found for user #{user_id}"
end

# Avoid: Raising for expected, recoverable errors
def allocate_seat(event_id, user_id) do
  available_seat(event_id) || raise "No seats available"  # Should return {:error, ...}
end
```

## Concurrency Guidelines

### Use `Task.async_stream` for Concurrent Enumerations

When processing many items concurrently:

```elixir
# Good: Concurrent stream processing
def sync_all_events_to_cache(organization_id) do
  events = Repo.all(Event, organization_id: organization_id)
  
  Task.async_stream(events, fn event ->
    {:ok, _} = ETS.put_event(event)
    {:ok, _} = Redis.put_event(event)
    event.id
  end)
  |> Stream.run()
  
  {:ok, length(events)}
end
```

### Respect Process Limits

If spawning many tasks, set appropriate concurrency limits.

```elixir
# Good: Limit to 10 concurrent tasks
Task.async_stream(
  items,
  fn item -> process_item(item) end,
  max_concurrency: 10,
  timeout: 30_000
)
```

### Use GenServer or Supervisor for Long-Lived Processes

For background jobs, caching, or state management, use OTP patterns.

```elixir
# Pattern: GenServer for a cache
defmodule VoelgoedEvents.EventCache do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_event(event_id) do
    GenServer.call(__MODULE__, {:get, event_id})
  end

  def handle_call({:get, event_id}, _from, state) do
    {:reply, Map.get(state, event_id), state}
  end
end
```

## Safety and Correctness

### Never Use `String.to_atom/1` on User Input

Atoms are not garbage collected. User-supplied data converted to atoms can exhaust memory.

```elixir
# Good: Validate against known atoms
def payment_method_from_string(method_string) do
  case method_string do
    "credit_card" -> :credit_card
    "bank_transfer" -> :bank_transfer
    "wallet" -> :wallet
    _ -> {:error, "Invalid payment method"}
  end
end

# Avoid: NEVER do this with user input
def payment_method_from_string(method_string) do
  String.to_atom(method_string)  # DANGEROUS
end
```

### Use Struct Dot Notation, Not Map Access

For structs, prefer field access over map-style access.

```elixir
# Good
event = %Event{id: 1, name: "Concert"}
event.id
event.name

# Avoid
event[:id]  # Works but not idiomatic for structs
event["id"]  # Won't work; structs use atoms
```

### Pattern Match Instead of Checking Keys

```elixir
# Good
def handle_payment(%{"status" => "completed", "amount" => amount}) do
  {:ok, amount}
end

def handle_payment(%{"status" => status}) do
  {:error, "Payment status: #{status}"}
end

# Avoid
def handle_payment(data) do
  if Map.has_key?(data, "status") and data["status"] == "completed" do
    {:ok, data["amount"]}
  else
    {:error, "Invalid payment data"}
  end
end
```

## Module Documentation

### Write Complete Module Docs

Every module should have a clear, concise `@moduledoc`.

```elixir
defmodule VoelgoedEvents.Ticketing.ReservationEngine do
  @moduledoc """
  Manages ticket reservations, holds, and confirmations.
  
  Responsibilities:
  - Reserve tickets for a user with a time-limited hold
  - Confirm reservations (convert hold to confirmed ticket)
  - Cancel holds and release reserved tickets back to inventory
  - Enforce capacity and per-user limits
  
  Multi-tenancy: All operations are scoped to an organization_id.
  Concurrency: Uses distributed locks (Redis) to prevent double-booking.
  """
end
```

### Document Behavioral Expectations

Especially for public functions that have side effects or preconditions.

```elixir
@doc """
Confirms a reserved ticket, converting it from hold to confirmed status.

Preconditions:
- The hold must not be expired (checked internally)
- The user must own the hold (enforced by policies)
- Payment must be confirmed

Returns:
- `{:ok, ticket}` if confirmation succeeds
- `{:error, :hold_expired}` if the hold has expired
- `{:error, :already_confirmed}` if the ticket is already confirmed
- `{:error, reason}` for other failures

Side effects:
- Emits `:ticket_confirmed` event to PubSub
- Sends confirmation email to user
"""
def confirm_reservation(hold_id, opts \\ []) do
  # Implementation
end
```

## Code Examples: Complete Pattern

Here's a complete, idiomatic Elixir module following these guidelines:

```elixir
defmodule VoelgoedEvents.Ticketing.SeatAvailability do
  @moduledoc """
  Checks and manages seat availability for events.
  
  Provides real-time views of seat inventory, capacity, and
  allocates available seats for ticket purchases.
  """

  alias VoelgoedEvents.{Repo, Events.Event, Ticketing.Seat}
  import Ecto.Query

  @seats_per_page 50
  @cache_ttl_seconds 60

  @doc """
  Fetches the count of available seats for an event, organized by section.

  Returns a map:
  ```
  %{
    "vip" => 45,
    "general" => 120,
    "balcony" => 78
  }
  ```

  The result is cached for #{@cache_ttl_seconds} seconds.
  """
  def available_seats_by_section(event_id) do
    case fetch_from_cache(event_id) do
      {:ok, data} -> data
      :miss -> compute_and_cache_availability(event_id)
    end
  end

  @doc """
  Allocates the first available seat of a given section for a user.

  Returns `{:ok, seat}` if a seat is found and allocated, or
  `{:error, :no_seats_available}` if the section is full.
  """
  def allocate_seat_in_section(event_id, section) do
    with {:ok, event} <- fetch_event(event_id),
         :ok <- verify_event_open_for_sales(event),
         {:ok, seat} <- find_and_reserve_seat(event_id, section) do
      {:ok, seat}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp compute_and_cache_availability(event_id) do
    availability = event_id
      |> query_seat_counts_by_section()
      |> Repo.all()
      |> Enum.map(fn {section, count} -> {section, count} end)
      |> Enum.into(%{})

    cache_availability(event_id, availability)
    availability
  end

  defp query_seat_counts_by_section(event_id) do
    from s in Seat,
      where: s.event_id == ^event_id and s.status == :available,
      group_by: s.section,
      select: {s.section, count(s.id)}
  end

  defp fetch_event(event_id) do
    case Repo.get(Event, event_id) do
      %Event{} = event -> {:ok, event}
      nil -> {:error, :event_not_found}
    end
  end

  defp verify_event_open_for_sales(%Event{status: :published}) do
    :ok
  end

  defp verify_event_open_for_sales(_event) do
    {:error, :event_not_open_for_sales}
  end

  defp find_and_reserve_seat(event_id, section) do
    case Repo.get_by(Seat, event_id: event_id, section: section, status: :available) do
      %Seat{} = seat -> {:ok, seat}
      nil -> {:error, :no_seats_available}
    end
  end

  defp fetch_from_cache(event_id) do
    case ETS.lookup(:availability_cache, event_id) do
      [{_key, data}] -> {:ok, data}
      [] -> :miss
    end
  end

  defp cache_availability(event_id, data) do
    ETS.insert(:availability_cache, {event_id, data})
  end
end
```

---

*Last updated: 2025-11-25*