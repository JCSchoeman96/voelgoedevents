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

Use `if`, `case`, or `cond` to rebind based on conditions. **Always assign the result.**

```elixir
# Good: Assignment of block result
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

# INVALID: Rebinding inside block doesn't persist outside
# ❌ DO NOT DO THIS
if connected?(socket) do
  socket = assign(socket, :val, val)
end
# socket is unchanged here! The rebinding only happens in the if block.

# VALID: Assign the result of the if
socket = if connected?(socket) do
  assign(socket, :val, val)
else
  socket
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
- **Do NOT use index-based access syntax on lists.**

```elixir
# INVALID: Lists don't support bracket access
i = 0
mylist = ["blue", "green"]
mylist[i]  # ❌ ERROR

# VALID: Use Enum.at/2
Enum.at(mylist, i)

# VALID: Use pattern matching
[first | rest] = mylist
first  # "blue"

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
- **Never use map access syntax on structs.** Use dot notation instead.

```elixir
# INVALID: Never use [] on structs
event = %Event{id: 1, name: "Concert"}
event[:id]  # WRONG! Use event.id instead

# VALID: Use dot notation for structs
event.id
event.name

# VALID: Pattern match maps
case event_data do
  %{"name" => name, "date" => date} -> "Event: #{name} on #{date}"
  _ -> "Unknown format"
end

# Avoid: Direct access without validation
event = external_api_response
name = event["name"]  # May raise KeyError

# Better: Pattern match first
case external_api_response do
  %{"name" => name} -> {:ok, name}
  _ -> {:error, "Missing name"}
end
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
  timeout: :infinity  # Use infinity for long operations, else specify milliseconds
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

# DANGEROUS - NEVER DO THIS
def payment_method_from_string(method_string) do
  String.to_atom(method_string)  # MEMORY LEAK RISK
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

## HTTP Client Library

### Always Use `:req` (Req)

- **Always** use the `:req` library for HTTP requests in Phoenix/Elixir projects.
- Req is included by default in modern Phoenix apps.
- **Avoid** `:httpoison`, `:tesla`, `:httpc` (outdated or not recommended).

```elixir
# Good: Using Req
def fetch_external_data(url) do
  case Req.get(url) do
    {:ok, response} -> {:ok, response.body}
    {:error, reason} -> {:error, reason}
  end
end

# Avoid: Other HTTP libraries
# ❌ httpoison
# ❌ tesla
# ❌ httpc
```

## Mix Guidelines

### Help and Debugging

- Read the docs and options before using tasks: `mix help task_name`
- To debug test failures, run specific tests: `mix test test/my_test.exs`
- To run previously failed tests: `mix test --failed`
- **Avoid** `mix deps.clean --all`; it's almost never needed.

```bash
# Get help
mix help test

# Run specific test file
mix test test/my_test.exs

# Run only failed tests
mix test --failed
```

### Using `mix precommit`

- Use the `mix precommit` alias when done with all changes to verify code quality.
- Fixes any pending linting or formatting issues automatically.

```bash
# Before pushing
mix precommit
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

---

*Last updated: 2025-11-25*