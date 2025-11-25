# Phoenix + LiveView Coding Style Guide

## Purpose

This guide defines how to write Phoenix and LiveView code in VoelgoedEvents. Phoenix and LiveView serve as **thin I/O layers** only; they parse input, call Ash domain actions, and render results. No business logic lives here.

## Core Principle: Phoenix/LiveView Are I/O Layers Only

- ✅ Parse user input (forms, query parameters, events).
- ✅ Call Ash domain actions with validated input.
- ✅ Assign results to template context.
- ✅ Render templates and push real-time updates.

- ❌ Do not implement business logic.
- ❌ Do not query the database directly.
- ❌ Do not perform calculations or validations that belong in Ash.

## Router and Endpoint Configuration

### Route Organization

Routes should follow vertical slice organization. Group routes by feature/domain.

```elixir
# Good: Routes organized by domain
scope "/", VoelgoedEventsWeb do
  pipe_through :browser

  live_session :default, on_mount: VoelgoedEventsWeb.UserAuth do
    # Public event browsing
    live "/events", EventLive.Index, :index
    live "/events/:id", EventLive.Show, :show

    # Ticketing (requires auth)
    pipe_through :require_user
    live "/cart", CartLive.Index, :index
    live "/checkout", CheckoutLive.Index, :index
    post "/checkout", CheckoutController, :create

    # Admin dashboard
    pipe_through :require_admin
    live "/admin/events", Admin.EventLive.Index, :index
    live "/admin/events/:id", Admin.EventLive.Show, :show
  end
end
```

### Pipeline Design

Use `pipe_through` to chain middleware. Keep pipelines focused.

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, {VoelgoedEventsWeb.LayoutView, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end

pipeline :require_user do
  plug :ensure_authenticated
end

pipeline :require_admin do
  plug :ensure_authenticated
  plug :ensure_admin_role
end
```

## LiveView Structure

### LiveView Organization

- **One LiveView per page or significant UI section.**
- **Thin controllers** – if a controller exists, it should route to a LiveView, not render a template.

```elixir
# File structure
lib/voelgoed_events_web/live/
  event_live/
    index.ex          # LiveView for event listing
    index.html.heex   # Template
    show.ex           # LiveView for event detail
    show.html.heex    # Template

  checkout_live/
    index.ex          # Checkout process
    index.html.heex
```

### LiveView Module Structure

```elixir
defmodule VoelgoedEventsWeb.EventLive.Index do
  use VoelgoedEventsWeb, :live_view

  @moduledoc """
  Lists events for the current organization.
  
  Real-time updates: When events are created/updated, all viewers
  see the list refresh automatically via PubSub.
  """

  # 1. Callbacks
  def mount(_params, _session, socket) do
    {:ok, assign(socket, events: [])}
  end

  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  def handle_event("select_event", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/events/#{id}")}
  end

  # 2. Private helpers
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Events")
    |> fetch_events()
  end

  defp fetch_events(socket) do
    organization_id = socket.assigns.current_user.organization_id
    events = VoelgoedEvents.Events.list_events(organization_id)
    assign(socket, :events, events)
  end
end
```

### Mount Patterns

#### Pattern 1: Fetch Data in Mount

For pages that don't need streaming or real-time updates:

```elixir
def mount(_params, _session, socket) do
  organization_id = socket.assigns.current_user.organization_id
  
  events = VoelgoedEvents.Events.list_events(organization_id)
  
  {:ok, assign(socket, events: events)}
end
```

#### Pattern 2: Mount with PubSub Subscription

For pages that need real-time updates:

```elixir
def mount(_params, _session, socket) do
  organization_id = socket.assigns.current_user.organization_id
  
  if connected?(socket) do
    # Subscribe to organization-scoped events
    Phoenix.PubSub.subscribe(VoelgoedEvents.PubSub, "org:#{organization_id}:events")
  end
  
  events = VoelgoedEvents.Events.list_events(organization_id)
  
  {:ok, assign(socket, events: events)}
end
```

#### Pattern 3: Mount with Async Operations

For expensive operations, use `start_async`:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    socket = start_async(socket, :load_events, fn ->
      VoelgoedEvents.Events.list_events(socket.assigns.current_user.organization_id)
    end)
    
    {:ok, assign(socket, loading: true)}
  else
    {:ok, socket}
  end
end

def handle_async(:load_events, {:ok, events}, socket) do
  {:noreply, assign(socket, events: events, loading: false)}
end

def handle_async(:load_events, {:exit, _reason}, socket) do
  {:noreply, assign(socket, loading: false, error: "Failed to load events")}
end
```

## LiveView Callbacks

### `handle_event/3` – User Interactions

Handle form submissions, button clicks, and other user events.

```elixir
def handle_event("submit_form", %{"form" => params}, socket) do
  organization_id = socket.assigns.current_user.organization_id
  
  case VoelgoedEvents.Ticketing.reserve_ticket(organization_id, params) do
    {:ok, ticket} ->
      socket = socket
        |> put_flash(:info, "Ticket reserved successfully")
        |> assign(ticket: ticket)
      
      {:noreply, socket}
    
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, reason)}
  end
end

def handle_event("cancel_reservation", %{"id" => id}, socket) do
  organization_id = socket.assigns.current_user.organization_id
  
  case VoelgoedEvents.Ticketing.cancel_reservation(organization_id, id) do
    {:ok, _} ->
      {:noreply, put_flash(socket, :info, "Reservation cancelled")}
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Error: #{reason}")}
  end
end
```

### `handle_info/2` – PubSub and Messages

Handle messages from PubSub broadcasts and other processes.

```elixir
def handle_info({:ticket_confirmed, ticket}, socket) do
  # Update local list in real-time
  events = socket.assigns.events
    |> Enum.map(fn e ->
      if e.id == ticket.event_id do
        update_in(e, [:available_seats], &(&1 - 1))
      else
        e
      end
    end)
  
  {:noreply, assign(socket, events: events)}
end

def handle_info({:event_updated, event}, socket) do
  events = Enum.map(socket.assigns.events, fn e ->
    if e.id == event.id, do: event, else: e
  end)
  
  {:noreply, assign(socket, events: events)}
end
```

## LiveView Streams

Use streams for large collections to avoid re-rendering the entire list.

```elixir
def mount(_params, _session, socket) do
  {:ok, stream(socket, :tickets, [])}
end

def handle_info({:tickets_loaded, tickets}, socket) do
  {:noreply, stream(socket, :tickets, tickets)}
end

def handle_event("add_ticket", %{"ticket_id" => id}, socket) do
  ticket = VoelgoedEvents.Tickets.fetch_ticket(id)
  {:noreply, stream_insert(socket, :tickets, ticket, at: 0)}
end

def handle_event("remove_ticket", %{"ticket_id" => id}, socket) do
  {:noreply, stream_delete_by_dom_id(socket, :tickets, "ticket-#{id}")}
end
```

## Multi-Tenancy in LiveView

**Every LiveView must enforce organization isolation.**

```elixir
def mount(_params, session, socket) do
  # Always get organization_id from session (set during login)
  organization_id = session["organization_id"]
  
  unless organization_id do
    {:error, "Missing organization context"}
  end
  
  socket = assign(socket, organization_id: organization_id)
  
  events = VoelgoedEvents.Events.list_events(organization_id)
  {:ok, assign(socket, events: events)}
end

# In all event handlers, always use organization_id
def handle_event("create_event", %{"form" => params}, socket) do
  organization_id = socket.assigns.organization_id
  
  case VoelgoedEvents.Events.create_event(organization_id, params) do
    {:ok, event} -> {:noreply, assign(socket, event: event)}
    {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
  end
end
```

## Layouts and Components

### Layout Usage

All pages should use a consistent layout (or a small set of layouts).

```elixir
# Layouts are configured at the router level
def put_root_layout(conn, _opts) do
  put_root_layout(conn, {VoelgoedEventsWeb.LayoutView, :root})
end

# In a specific LiveView, you can choose a different layout
def mount(_params, _session, socket) do
  {:ok, assign(socket, layout: {VoelgoedEventsWeb.LayoutView, :event_detail})}
end
```

The layout wraps all page content and provides navigation, flash messages, etc.

```heex
<!-- lib/voelgoed_events_web/components/layouts/app.html.heex -->
<header>
  <nav>
    <.link href={~p"/"}>Home</.link>
    <.link href={~p"/events"}>Events</.link>
  </nav>
</header>

<main class="p-4">
  <.flash kind={:info} flash={@flash} />
  <.flash kind={:error} flash={@flash} />
  
  <%= @inner_content %>
</main>

<footer>
  <p>&copy; 2025 VoelgoedEvents</p>
</footer>
```

### Reusable Components

Use LiveView components for reusable UI patterns.

```elixir
# lib/voelgoed_events_web/components/event_card.ex
defmodule VoelgoedEventsWeb.EventCard do
  use VoelgoedEventsWeb, :html_component

  @doc "Renders a card for an event with key details"
  def event_card(assigns) do
    ~H"""
    <article class="border rounded p-4">
      <h3><%= @event.name %></h3>
      <p><%= @event.description %></p>
      <p>Date: <%= format_date(@event.date) %></p>
      <p>Available: <%= @event.available_seats %></p>
      
      <.link href={~p"/events/#{@event.id}"}>View Details</.link>
    </article>
    """
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
end

# Usage in a LiveView
<.event_card event={event} />
```

## Form Handling

### Using `<form>` with `handle_event`

```heex
<form phx-submit="submit_form" phx-change="validate_form">
  <input type="text" name="title" placeholder="Event Title" required />
  <input type="email" name="organizer_email" placeholder="Email" required />
  
  <button type="submit">Create Event</button>
</form>
```

```elixir
def handle_event("validate_form", %{"title" => title, "organizer_email" => email}, socket) do
  # Real-time validation: check if email is valid, title is unique, etc.
  # Assign errors if any
  {:noreply, socket}
end

def handle_event("submit_form", %{"title" => title, "organizer_email" => email}, socket) do
  organization_id = socket.assigns.organization_id
  
  case VoelgoedEvents.Events.create_event(organization_id, %{
    title: title,
    organizer_email: email
  }) do
    {:ok, event} ->
      {:noreply,
        socket
        |> put_flash(:info, "Event created successfully")
        |> push_navigate(to: ~p"/events/#{event.id}")}
    
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, reason)}
  end
end
```

## Forbidden Patterns

### ❌ Do Not Query the Database Directly

```elixir
# BAD: Direct Repo access
def handle_event("fetch_events", _params, socket) do
  events = Repo.all(Event)  # NO!
  {:noreply, assign(socket, events: events)}
end

# GOOD: Use Ash actions
def handle_event("fetch_events", _params, socket) do
  organization_id = socket.assigns.organization_id
  events = VoelgoedEvents.Events.list_events(organization_id)
  {:noreply, assign(socket, events: events)}
end
```

### ❌ Do Not Put Business Logic in LiveView

```elixir
# BAD: Pricing logic in LiveView
def handle_event("calculate_total", %{"items" => items}, socket) do
  total = Enum.reduce(items, 0, fn item, acc ->
    price = item["price"] * item["qty"] * (1 - item["discount"])
    acc + price
  end)
  {:noreply, assign(socket, total: total)}
end

# GOOD: Call Ash to calculate
def handle_event("calculate_total", %{"items" => items}, socket) do
  organization_id = socket.assigns.organization_id
  {:ok, total} = VoelgoedEvents.Orders.calculate_order_total(organization_id, items)
  {:noreply, assign(socket, total: total)}
end
```

### ❌ Do Not Skip Multi-Tenancy Checks

```elixir
# BAD: No organization scoping
def handle_event("delete_event", %{"id" => event_id}, socket) do
  VoelgoedEvents.Events.delete_event(event_id)  # Could delete anyone's event!
  {:noreply, socket}
end

# GOOD: Always pass organization_id
def handle_event("delete_event", %{"id" => event_id}, socket) do
  organization_id = socket.assigns.organization_id
  VoelgoedEvents.Events.delete_event(organization_id, event_id)
  {:noreply, socket}
end
```

## Navigation and Redirects

### Using `push_navigate` and `push_patch`

```elixir
# Push a new route (updates browser history)
push_navigate(socket, to: ~p"/events/#{event.id}")

# Patch the current route (doesn't push to history, updates params)
push_patch(socket, to: ~p"/events?sort=date")

# Redirect (for POST/PUT/DELETE)
push_redirect(socket, to: ~p"/events")
```

---

*Last updated: 2025-11-25*