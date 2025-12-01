# Workflows Layer

## Purpose

This directory contains the **orchestration layer** for complex, multi-step business transactions that span multiple Ash domains. Workflows coordinate actions across domains (Ticketing, Payments, Seating, Finance) to implement complete business processes.

The `workflows/` directory is where **sagas and multi-domain transactions** live - the glue code that makes the platform's business logic work as a cohesive whole.

---

## What Belongs in Workflows

### **Use Workflows When:**

✅ Transaction spans **multiple Ash domains**  
✅ Multiple steps that must happen **in a specific order**  
✅ Complex **error handling and rollback** required  
✅ Business process involves **external services** (payments, emails)  
✅ Need to **coordinate** between infrastructure, caching, and domain logic

### **DO NOT Use Workflows For:**

❌ Simple CRUD operations (use Ash actions directly)  
❌ Single-domain operations (put in Ash resource changes)  
❌ Direct database access (use Ash queries)  
❌ Infrastructure operations (use infrastructure layer)  
❌ Caching logic (use caching layer)

---

## Architecture: Workflows as Orchestrators

```
┌─────────────────────────────────────────────────────────────────┐
│                     User Request (LiveView)                      │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
              ┌──────────────────────────────┐
              │  Workflow (Orchestrator)     │ ◄─── YOU ARE HERE
              │  e.g., CompleteCheckout      │
              └──────────────┬───────────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ Ash Domain 1 │  │ Ash Domain 2 │  │ Infrastructure│
    │ (Ticketing)  │  │ (Payments)   │  │ (Redis/Email) │
    └──────┬───────┘  └──────┬───────┘  └──────┬────────┘
           │                 │                  │
           ▼                 ▼                  ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │   Postgres   │  │   Postgres   │  │ External API │
    └──────────────┘  └──────────────┘  └──────────────┘
```

**Key Principle:** Workflows **orchestrate but don't implement** domain logic or data access.

---

## Prime Example: Checkout Workflow

### **StartCheckout Workflow**

**File:** `workflows/checkout/start_checkout.ex`

**What it orchestrates:**

1. Validate cart items (via Ticketing domain)
2. Calculate fees (via Finance domain - Phase 21)
3. Create pending order (via Ticketing domain)
4. Reserve seats if applicable (via Seating domain)
5. Hold reservation in Redis (via Infrastructure/Caching)
6. Return payment session URL (via Payments domain)

**Code structure:**

```elixir
defmodule Voelgoedevents.Workflows.Checkout.StartCheckout do
  @moduledoc """
  Orchestrates the checkout initiation process.

  This workflow spans multiple domains:
  - Ticketing: Validate items, create order
  - Finance: Calculate fees and donations
  - Seating: Reserve seats (if applicable)
  - Payments: Create payment session
  - Infrastructure: Hold reservations in Redis
  """

  alias Voelgoedevents.Ash.Resources.Ticketing.Order
  alias Voelgoedevents.Ash.Resources.Seating.Seat
  alias Voelgoedevents.Workflows.Finance.CalculateFees
  alias Voelgoedevents.Infrastructure.DistributedLock

  def execute(cart_items, organization_id, event_id, opts \\ []) do
    donation_cents = Keyword.get(opts, :donation_cents, 0)

    # Step 1: Calculate fees (Finance domain)
    fees = CalculateFees.calculate(cart_items, organization_id, event_id, donation_cents)

   # Step 2: Reserve seats if needed (Seating domain + DLM)
    with {:ok, seat_reservations} <- maybe_reserve_seats(cart_items),

         # Step 3: Create order (Ticketing domain)
         {:ok, order} <- create_order(fees, cart_items, organization_id),

         # Step 4: Create payment session (Payments domain)
         {:ok, payment_session} <- create_payment_session(order, fees) do

      {:ok, %{
        order: order,
        payment_url: payment_session.url,
        expires_at: payment_session.expires_at
      }}
    else
      {:error, reason} ->
        # Rollback seat reservations on failure
        rollback_seat_reservations(cart_items)
        {:error, reason}
    end
  end

  # Private orchestration functions...
  defp maybe_reserve_seats(cart_items) do
    seat_items = Enum.filter(cart_items, & &1.seat_id)

    if Enum.any?(seat_items) do
      # Use DLM from infrastructure layer
      DistributedLock.with_lock("checkout:seats", fn ->
        # Call Seating domain actions
        Enum.reduce_while(seat_items, {:ok, []}, fn item, {:ok, acc} ->
          case Seat.reserve(item.seat_id) do
            {:ok, reservation} -> {:cont, {:ok, [reservation | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
      end)
    else
      {:ok, []}
    end
  end

  defp create_order(fees, cart_items, organization_id) do
    # Use Ash action - NO raw SQL
    Order.create(%{
      organization_id: organization_id,
      subtotal_cents: fees.subtotal_cents,
      platform_fee_cents: fees.platform_fee_cents,
      processor_fee_cents: fees.processor_fee_cents,
      donation_cents: fees.donation_cents,
      total_cents: fees.total_cents,
      status: :pending
    })
  end
end
```

**What this demonstrates:**

- ✅ Orchestrates multiple domains (Ticketing, Finance, Seating, Payments)
- ✅ Uses Ash actions for data operations
- ✅ Uses infrastructure layer for distributed locking
- ✅ Handles errors and rollback
- ✅ NO raw SQL or direct Redis calls

### **CompleteCheckout Workflow**

**File:** `workflows/checkout/complete_checkout.ex`

**What it orchestrates:**

1. Verify payment (via Payments domain)
2. Mark order as paid (via Ticketing domain)
3. Finalize seat reservations (via Seating domain with DLM)
4. Issue tickets (via Ticketing domain)
5. Record financial journal entries (via Finance domain)
6. Create donation records if applicable (via Finance domain)
7. Queue ticket email (via Infrastructure/Oban)
8. Invalidate caches (via Caching layer)
9. Broadcast events (via Phoenix.PubSub)

**Code structure:**

```elixir
defmodule Voelgoedevents.Workflows.Checkout.CompleteCheckout do
  @moduledoc """
  Orchestrates the checkout completion process after successful payment.

  This is a critical saga that must maintain atomicity.
  """

  def execute(order_id, payment_id) do
    # Use Ecto.Multi for atomicity across domains
    Ecto.Multi.new()
    |> Ecto.Multi.run(:verify_payment, fn _repo, _changes ->
      verify_payment(payment_id)
    end)
    |> Ecto.Multi.run(:mark_order_paid, fn _repo, %{verify_payment: payment} ->
      Order.mark_as_paid(order_id, payment.id)
    end)
    |> Ecto.Multi.run(:finalize_seats, fn _repo, %{mark_order_paid: order} ->
      finalize_seat_reservations(order)
    end)
    |> Ecto.Multi.run(:issue_tickets, fn _repo, %{mark_order_paid: order} ->
      Ticket.issue_for_order(order)
    end)
    |> Ecto.Multi.run(:record_financials, fn _repo, %{mark_order_paid: order} ->
      record_journal_entries(order)
    end)
    |> Ecto.Multi.run(:create_donation, fn _repo, %{mark_order_paid: order} ->
      maybe_create_donation_record(order)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, results} ->
        # Post-transaction operations (can fail without rollback)
        queue_ticket_email(results.issue_tickets)
        invalidate_caches(results.mark_order_paid)
        broadcast_order_completed(results.mark_order_paid)

        {:ok, results}

      {:error, _step, reason, _changes} ->
        # Rollback already happened via Ecto.Multi
        {:error, reason}
    end
  end

  defp finalize_seat_reservations(order) do
    # Use DLM to ensure atomic seat finalization
    DistributedLock.with_lock("order:#{order.id}:seats", fn ->
      # Call Seating domain actions
      Seat.finalize_reservations_for_order(order.id)
    end)
  end

  defp record_journal_entries(order) do
    # Call Finance domain workflow
    Voelgoedevents.Workflows.Finance.RecordSale.execute(order)
  end
end
```

---

## Workflow Organization

### **Recommended Structure**

```
workflows/
├── README.md (this file)
├── checkout/
│   ├── start_checkout.ex       # Initiate checkout process
│   ├── complete_checkout.ex    # Finalize after payment
│   └── cancel_checkout.ex      # Handle cancellation/expiry
├── ticketing/
│   ├── issue_tickets.ex        # Generate QR codes, send emails
│   ├── revoke_ticket.ex        # Handle refunds
│   └── transfer_ticket.ex      # Ticket ownership transfer
├── seating/
│   ├── reserve_seats.ex        # Hold seats during checkout
│   ├── release_seats.ex        # Release expired holds
│   └── finalize_seats.ex       # Mark seats as sold
├── payments/
│   ├── process_payment.ex      # Handle payment webhooks
│   ├── refund_order.ex         # Process refunds
│   └── verify_payment.ex       # Verify payment status
├── finance/
│   ├── calculate_fees.ex       # Fee calculation (Phase 21)
│   ├── record_sale.ex          # Journal entries
│   ├── process_settlement.ex   # Settlement workflow
│   └── initiate_payout.ex      # Bank transfers
├── scanning/
│   ├── process_scan.ex         # Validate and record scan
│   ├── offline_sync.ex         # Sync offline scans
│   └── determine_access_state.ex # Check-in/out logic
└── analytics/
    ├── track_funnel_event.ex   # Marketing attribution
    └── aggregate_metrics.ex    # Dashboard calculations
```

---

## Critical Rules for Workflows

### ✅ **DO:**

1. **Use Ash Actions for data operations**

   ```elixir
   # ✅ Correct
   Order.create(%{status: :pending})
   Seat.reserve(seat_id)
   ```

2. **Use Ash Queries for reads**

   ```elixir
   # ✅ Correct
   Order
   |> Ash.Query.filter(status == :pending)
   |> Ash.Query.filter(created_at < ago(30, :minute))
   |> Ash.read!()
   ```

3. **Use Infrastructure layer for external systems**

   ```elixir
   # ✅ Correct
   DistributedLock.with_lock("resource", fn -> ... end)
   RedisClient.command(["SET", key, value])
   ```

4. **Use Ecto.Multi for atomic transactions**

   ```elixir
   # ✅ Correct
   Ecto.Multi.new()
   |> Ecto.Multi.run(:step1, fn _repo, _changes -> ... end)
   |> Ecto.Multi.run(:step2, fn _repo, %{step1: result} -> ... end)
   |> Repo.transaction()
   ```

5. **Handle errors and rollback**
   ```elixir
   # ✅ Correct
   case CompleteCheckout.execute(order_id) do
     {:ok, result} -> ...
     {:error, reason} -> rollback_and_notify(reason)
   end
   ```

### ❌ **DO NOT:**

1. **Use raw SQL**

   ```elixir
   # ❌ Wrong - use Ash queries
   Repo.query("SELECT * FROM orders WHERE status = 'pending'")
   ```

2. **Use Ecto schemas directly**

   ```elixir
   # ❌ Wrong - use Ash resources
   Repo.insert(%Order{status: :pending})
   ```

3. **Put business logic in workflows**

   ```elixir
   # ❌ Wrong - this belongs in Ash resource change
   def calculate_ticket_price(ticket_type) do
     # Complex pricing logic doesn't belong here
   end
   ```

4. **Access infrastructure directly (bypass abstractions)**

   ```elixir
   # ❌ Wrong - use Infrastructure.RedisClient
   {:ok, conn} = Redix.start_link()
   Redix.command(conn, ["SET", key, value])
   ```

5. **Make workflows too granular**
   ```elixir
   # ❌ Wrong - this should just be an Ash action
   defmodule UpdateOrderStatus do
     def execute(order_id, status) do
       Order.update(order_id, %{status: status})
     end
   end
   ```

---

## When to Use Workflows vs Ash Actions

| Scenario                                            | Use Workflow? | Use Ash Action?                |
| --------------------------------------------------- | ------------- | ------------------------------ |
| Update single field on one resource                 | ❌            | ✅ Yes                         |
| Create order with line items                        | ❌            | ✅ Yes (managed relationships) |
| Complete checkout (order + payment + seats + email) | ✅ Yes        | ❌                             |
| Calculate dynamic price                             | ❌            | ✅ Yes (calculation)           |
| Process payment and issue tickets                   | ✅ Yes        | ❌                             |
| Validate seat reservation                           | ❌            | ✅ Yes (validation)            |
| Sync offline scans + resolve conflicts              | ✅ Yes        | ❌                             |

**Rule of Thumb:** If it crosses domain boundaries or involves 3+ steps, use a workflow.

---

## Error Handling Patterns

### **1. Early Return on Validation**

```elixir
def execute(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, order} <- create_order(validated),
       {:ok, payment} <- process_payment(order) do
    {:ok, %{order: order, payment: payment}}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

### **2. Ecto.Multi for Atomicity**

```elixir
def execute(order_id) do
  Ecto.Multi.new()
  |> Ecto.Multi.run(:step1, fn _repo, _changes -> step1() end)
  |> Ecto.Multi.run(:step2, fn _repo, %{step1: result} -> step2(result) end)
  |> Repo.transaction()
  |> case do
    {:ok, results} -> {:ok, results}
    {:error, _failed_step, reason, _changes} -> {:error, reason}
  end
end
```

### **3. Compensating Transactions (Saga Pattern)**

```elixir
def execute(order_id) do
  with {:ok, seats} <- reserve_seats(order_id),
       {:ok, payment} <- charge_customer(order_id),
       {:ok, tickets} <- issue_tickets(order_id) do
    {:ok, tickets}
  else
    {:error, :payment_failed} ->
      # Compensate: Release seats
      release_seats(order_id)
      {:error, :payment_failed}

    {:error, reason} ->
      {:error, reason}
  end
end
```

---

## Testing Workflows

### **1. Test Happy Path**

```elixir
defmodule Voelgoedevents.Workflows.Checkout.CompleteCheckoutTest do
  test "successfully completes checkout" do
    order = insert(:order, status: :pending)
    payment = insert(:payment, order_id: order.id, status: :succeeded)

    assert {:ok, result} = CompleteCheckout.execute(order.id, payment.id)

    # Verify all steps succeeded
    assert result.mark_order_paid.status == :paid
    assert length(result.issue_tickets) > 0
  end
end
```

### **2. Test Error Scenarios**

```elixir
test "rolls back on payment verification failure" do
  order = insert(:order, status: :pending)
  invalid_payment_id = Ecto.UUID.generate()

  assert {:error, :payment_not_found} = CompleteCheckout.execute(order.id, invalid_payment_id)

  # Verify rollback
  assert Repo.reload!(order).status == :pending
end
```

### **3. Test Compensating Transactions**

```elixir
test "releases seats when payment fails" do
  cart_items = [%{seat_id: seat.id, ticket_type_id: ticket_type.id}]

  # Mock payment failure
  expect(PaymentMock, :charge, fn _order -> {:error, :card_declined} end)

  assert {:error, :payment_failed} = StartCheckout.execute(cart_items, org_id, event_id)

  # Verify seats were released
  assert Repo.reload!(seat).status == :available
end
```

### **4. Use Mocks for External Dependencies**

```elixir
import Mox

setup :verify_on_exit!

test "queues email after successful checkout" do
  expect(MailerMock, :send_ticket_email, fn _tickets -> :ok end)

  assert {:ok, _result} = CompleteCheckout.execute(order.id, payment.id)
end
```

---

## Performance Considerations

### **1. Avoid N+1 Queries**

```elixir
# ❌ Bad - N+1 queries
def issue_tickets(order) do
  Enum.map(order.line_items, fn item ->
    ticket_type = TicketType.get!(item.ticket_type_id)  # N queries
    create_ticket(item, ticket_type)
  end)
end

# ✅ Good - preload associations
def issue_tickets(order) do
  order = Ash.load!(order, line_items: :ticket_type)
  Enum.map(order.line_items, fn item ->
    create_ticket(item, item.ticket_type)
  end)
end
```

### **2. Use Background Jobs for Non-Critical Steps**

```elixir
def execute(order_id) do
  # Critical path - must complete in request
  with {:ok, order} <- mark_order_paid(order_id),
       {:ok, tickets} <- issue_tickets(order) do

    # Non-critical - queue for background
    Oban.insert(SendTicketEmailWorker.new(%{order_id: order.id}))
    Oban.insert(UpdateAnalyticsWorker.new(%{order_id: order.id}))

    {:ok, order}
  end
end
```

---

## Common Workflow Patterns

### **1. Reservation Pattern**

Hold resource temporarily, finalize or release:

```elixir
# Hold
Workflows.Seating.ReserveSeats.execute(seat_ids)

# Finalize
Workflows.Seating.FinalizeSeats.execute(reservation_id)

# Release (on timeout or cancellation)
Workflows.Seating.ReleaseSeats.execute(reservation_id)
```

### **2. Saga Pattern**

Multi-step transaction with compensating actions:

```elixir
with {:ok, step1} <- action1(),
     {:ok, step2} <- action2(),
     {:ok, step3} <- action3() do
  {:ok, step3}
else
  {:error, reason} ->
    compensate_step2()
    compensate_step1()
    {:error, reason}
end
```

### **3. Event-Driven Pattern**

Workflow triggers events for other systems:

```elixir
def execute(order_id) do
  with {:ok, order} <- process_order(order_id) do
    # Publish event
    Phoenix.PubSub.broadcast(
      Voelgoedevents.PubSub,
      "orders",
      {:order_completed, order}
    )

    {:ok, order}
  end
end
```

---

## References

- **Roadmap Phase 4.4:** Ticket Issuance Workflow
- **Roadmap Phase 5.4:** Offline Sync Workflow
- **Roadmap Phase 21.3.2:** StartCheckout Workflow (Fee Calculation)
- **Infrastructure README:** `/lib/voelgoedevents/infrastructure/README.md`
- **Caching README:** `/lib/voelgoedevents/caching/README.md`

---

**Maintained By:** VoelgoedEvents Platform Team  
**Last Updated:** December 1, 2025  
**Status:** Active - Critical for business process orchestration
