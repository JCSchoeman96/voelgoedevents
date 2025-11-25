# HEEx Template Coding Style Guide

## Purpose

This guide defines HEEx (HTML + Embedded Elixir) syntax rules, best practices, and common patterns for VoelgoedEvents. HEEx is used for all server-rendered templates in Phoenix and LiveView.

Note: This guide covers **template mechanics and correctness**, not styling. See [`tailwind.md`](./tailwind.md) for CSS and styling guidance.

## HEEx Syntax Fundamentals

### Interpolation: `{}` vs `<%= %>`

Use **`{}`** for expressions inside tag attributes and lists. Use **`<%= %>`** for content inside tags.

```heex
<!-- Good: {} for attributes -->
<div class={@class_name}>Content</div>
<img src={@image_url} alt={@alt_text} />
<button disabled={!@is_enabled}>Click</button>

<!-- Good: <%= %> for content -->
<h1><%= @title %></h1>
<p><%= @description %></p>

<!-- Avoid: <%= %> in attributes (works but verbose) -->
<div class="<%= @class_name %>">Content</div>

<!-- Avoid: {} for content (doesn't work) -->
<h1>{@title}</h1>  <!-- ERROR -->
```

### Curly Braces in Content

To output literal `{}` in content, use `phx-no-curly-interpolation` or escape:

```heex
<!-- Good: Escape literal braces in code blocks -->
<code>The syntax is &lt;%= x %&gt;</code>

<!-- Good: phx-no-curly-interpolation for blocks with literal braces -->
<pre phx-no-curly-interpolation>
let obj = {key: "val"}
const arr = [1, 2, 3]
</pre>

<!-- Also good: You can still use <%= %> inside phx-no-curly-interpolation -->
<code phx-no-curly-interpolation>
User: <%= @user.name %>
{ this is literal }
</code>

<!-- Avoid: Unescaped braces (interpreted as interpolation) -->
<code>The syntax is <%= x %></code>
```

### Comments

Use HEEx comments `<%!-- ... --%>` for template-level comments.

```heex
<%!-- This is a template comment, not sent to browser --%>

<!-- This is an HTML comment, sent to browser -->
<p>Content</p>
```

## Conditional Rendering

### Using `if`, `unless`, and `cond`

```heex
<!-- Good: Simple if -->
<%= if @user.admin? do %>
  <button>Delete Event</button>
<% end %>

<!-- Good: unless -->
<%= unless @user.is_banned do %>
  <.link href={~p"/checkout"}>Proceed to Checkout</.link>
<% end %>

<!-- Good: if/else -->
<%= if Enum.empty?(@events) do %>
  <p>No events available.</p>
<% else %>
  <.event_list events={@events} />
<% end %>

<!-- Good: cond for multiple conditions -->
<%= cond do %>
  <% @status == :pending -> %>
    <span class="badge-yellow">Pending</span>
  <% @status == :confirmed -> %>
    <span class="badge-green">Confirmed</span>
  <% @status == :cancelled -> %>
    <span class="badge-red">Cancelled</span>
  <% true -> %>
    <span class="badge-gray">Unknown</span>
<% end %>

<!-- Avoid: Using else if or elsif (INVALID) -->
<%= if condition do %>
  ...
<% else if other_condition %>  <!-- ❌ SYNTAX ERROR -->
  ...
<% end %>

<!-- Always use cond instead -->
<%= cond do %>
  <% condition -> %> ...
  <% condition2 -> %> ...
  <% true -> %> ...
<% end %>
```

## Loops and Iteration

### Using `for` in Templates

```heex
<!-- Good: for expression in template -->
<div class="grid">
  <%= for event <- @events do %>
    <.event_card event={event} />
  <% end %>
</div>

<!-- Good: for with filters -->
<div>
  <%= for ticket <- @tickets, ticket.status == :confirmed do %>
    <p><%= ticket.section %>: <%= ticket.seat_number %></p>
  <% end %>
</div>

<!-- Good: for with index -->
<ol>
  <%= for {item, idx} <- Enum.with_index(@items) do %>
    <li><%= idx + 1 %>. <%= item.name %></li>
  <% end %>
</ol>

<!-- Avoid: Enum.each (side effects in templates, doesn't render) -->
<%= Enum.each(@events, fn event -> %>
  <!-- This doesn't render, and is a side effect -->
<% end) %>

<!-- Avoid: No Enum.each for rendering -->
```

### Using LiveView Streams

For large collections, use streams to avoid re-rendering the entire list:

```heex
<!-- Template uses stream -->
<div id="tickets" phx-update="stream">
  <%= for {_id, ticket} <- @streams.tickets do %>
    <div id={\"ticket-#{ticket.id}\"}>
      <p><%= ticket.section %> - <%= ticket.seat_number %></p>
    </div>
  <% end %>
</div>
```

```elixir
# LiveView manages the stream
def mount(_params, _session, socket) do
  {:ok, stream(socket, :tickets, [])}
end

def handle_info({:new_ticket, ticket}, socket) do
  {:noreply, stream_insert(socket, :tickets, ticket, at: 0)}
end
```

## Form Elements and Components

### Using Core Components

- **Always** use `<.form>` component from `core_components.ex` for forms.
- **Always** use `<.input>` component for form fields.
- **Never** use deprecated `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for`.
- **Always** use `<.icon>` component for icons (not Heroicons directly).
- **Always** give forms unique DOM IDs for testing and styling: `id="event-form"`.

```heex
<!-- Good: Using correct form components -->
<.simple_form :let={f} for={@changeset} as={:event} phx-submit="save" id="event-form">
  <.input field={f[:name]} type="text" label="Event Name" />
  <.input field={f[:description]} type="textarea" label="Description" />
  <.input field={f[:date]} type="datetime_local" label="Date & Time" />
  
  <:actions>
    <.button>Create Event</.button>
  </:actions>
</.simple_form>

<!-- Good: Using icon component -->
<.icon name="hero-star-solid" class="w-6 h-6" />
<.icon name="hero-x-mark" class="w-5 h-5" />

<!-- Avoid: Using Heroicons directly (use <.icon> instead) -->
<!-- Don't use Heroicons modules -->

<!-- Avoid: Old form_for (deprecated) -->
<!-- Don't use Phoenix.HTML.form_for -->
```

### Form Input Overriding Classes

If you override default input classes, they replace ALL defaults. Your custom classes must fully style the input:

```heex
<!-- Good: Custom classes fully style the input -->
<.input field={f[:name]} type="text" class="myclass px-2 py-1 rounded-lg" />

<!-- Bad: Partial override loses default styling -->
<.input field={f[:name]} type="text" class="custom-class" />
<!-- Custom classes are the ONLY classes applied. Add all spacing/sizing manually -->
```

### Form Bindings with Ash Changesets

Use `to_form/2` to convert changesets to form structs:

```heex
<.simple_form :let={f} for={@form} as={:ticket} phx-submit="reserve">
  <.input field={f[:email]} type="email" label="Email" />
  
  <!-- Errors are shown automatically by .input component -->
  
  <:actions>
    <.button>Reserve</.button>
  </:actions>
</.simple_form>
```

```elixir
def mount(_params, _session, socket) do
  changeset = Ticket.change(...)
  {:ok, assign(socket, form: to_form(changeset))}
end
```

## Class Lists and Styling

### Using `class={[ ... ]}` Lists

Always use **list syntax `[...]`** for class lists with conditionals. Never use string concatenation.

```heex
<!-- Good: Class list with conditionals -->
<div class={["card", @selected? and "border-blue", @disabled? and "opacity-50"]}>
  Content
</div>

<!-- Good: Using a variable -->
<% status_class = if @status == :confirmed, do: "text-green", else: "text-yellow" %>
<span class={status_class}>
  <%= @status %>
</span>

<!-- Good: Complex conditionals with if expression wrapped in parens -->
<div class={[
  "px-2 text-white",
  @expanded && "py-5",
  if(@highlighted, do: "border-red-500", else: "border-blue-100")
]}>
  Content
</div>

<!-- Avoid: String concatenation for classes -->
<div class={@selected? && "border-blue"}>  <!-- Works but avoid -->
  Content
</div>

<!-- Avoid: Missing [ ] brackets -->
<a class={
  "px-2 text-white",
  @some_flag && "py-5"
}> ...
<!-- Raises compile error on invalid HEEx syntax -->
```

For complex styling, compute the class in the LiveView:

```elixir
def mount(_params, _session, socket) do
  status_class = case socket.assigns.status do
    :pending -> "badge-yellow"
    :confirmed -> "badge-green"
    :cancelled -> "badge-red"
    _ -> "badge-gray"
  end
  
  {:ok, assign(socket, status_class: status_class)}
end
```

```heex
<span class={@status_class}><%= @status %></span>
```

## Component Patterns

### Defining and Using Components

```elixir
# lib/voelgoed_events_web/components/badge.ex
defmodule VoelgoedEventsWeb.Badge do
  use VoelgoedEventsWeb, :html_component

  attr :status, :atom, required: true, values: [:pending, :confirmed, :cancelled]
  slot :inner_block, required: true

  def status_badge(assigns) do
    status_class = case assigns.status do
      :pending -> "bg-yellow-100 text-yellow-800"
      :confirmed -> "bg-green-100 text-green-800"
      :cancelled -> "bg-red-100 text-red-800"
    end
    
    ~H"""
    <span class={["px-3 py-1 rounded-full text-sm font-semibold", status_class]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end
end
```

Usage in templates:

```heex
<.status_badge status={:confirmed}>
  Confirmed
</.status_badge>

<.status_badge status={ticket.status}>
  <%= String.capitalize(Atom.to_string(ticket.status)) %>
</.status_badge>
```

## Template Logic Best Practices

### Precompute Complex Logic in LiveView

Don't put complex logic or multiple operations in templates. Compute in the LiveView and assign the result.

```elixir
# BAD: Complex logic in template
<%= if Enum.any?(@users, fn u -> u.role == :admin and u.active? end) do %>
  <!-- Content -->
<% end %>

# GOOD: Compute in LiveView
def mount(_params, _session, socket) do
  has_active_admin = Enum.any?(socket.assigns.users, fn u ->
    u.role == :admin and u.active?
  end)
  
  {:ok, assign(socket, has_active_admin: has_active_admin)}
end

# Template
<%= if @has_active_admin do %>
  <!-- Content -->
<% end %>
```

### Keep Templates Dumb

Templates should focus on rendering, not computing. Use components and helpers for repeated patterns.

```heex
<!-- Good: Simple, direct rendering -->
<div class="grid">
  <%= for event <- @events do %>
    <article>
      <h3><%= event.name %></h3>
      <p><%= event.description %></p>
      <.link href={~p"/events/#{event.id}"}>View</.link>
    </article>
  <% end %>
</div>

<!-- Avoid: Logic in template -->
<%= for event <- Enum.filter(@events, fn e -> e.published? end) do %>
  <% formatted_date = format_date(event.date) %>
  <% price = calculate_price(event.price, @discount) %>
  <article>...</article>
<% end %>
<!-- Better: Compute in LiveView, assign results, render in template -->
```

## Safety and Accessibility

### Escaping User Input

HEEx automatically escapes user input for HTML injection protection.

```heex
<!-- Automatically escaped -->
<p><%= @user.bio %></p>

<!-- If you must render HTML (rare), use raw_html/1 -->
<p><%= raw_html(@content) %></p>

<!-- Use components for interactive content -->
<.markdown_viewer content={@markdown_text} />
```

### Form Accessibility

```heex
<!-- Good: Proper labels and ARIA -->
<label for="email">Email Address</label>
<input type="email" id="email" name="email" aria-required="true" />

<!-- Good: Error messages linked to input -->
<label for="quantity">Quantity</label>
<input type="number" id="quantity" name="quantity" aria-describedby="qty-error" />
<span id="qty-error" class="text-red-600">Minimum quantity is 1</span>

<!-- Good: Use semantic HTML -->
<section>
  <h2>Event Details</h2>
  <article><!-- ticket or event card --></article>
</section>
```

## Anti-Patterns to Avoid

### ❌ Avoid Direct Data Access Without Guards

```heex
<!-- BAD: May raise KeyError if keys don't exist -->
<p><%= @data[:name] %></p>
<p><%= @data.nested.field %></p>

<!-- GOOD: Pattern match or check before access -->
<%= if Map.has_key?(@data, :name) do %>
  <p><%= @data[:name] %></p>
<% end %>

<!-- GOOD: Use a component that handles the case -->
<.field_display data={@data} field={:name} default="No name" />
```

### ❌ Avoid Inline Script Tags

```heex
<!-- BAD: Inline JavaScript (hard to test, debug) -->
<script>
  document.getElementById("btn").addEventListener("click", function() {
    // ...
  });
</script>

<!-- GOOD: Use LiveView event handlers -->
<button phx-click="button_clicked">Click me</button>

<!-- GOOD: Use a hook for complex interactions -->
<div id="map" phx-hook="GoogleMap"></div>
```

### ❌ Avoid Mixing Logic and Presentation

```heex
<!-- BAD: Many cases in template -->
<%= cond do %>
  <% @status == :pending and @tries < 3 -> %>
  <% @status == :pending and @tries >= 3 -> %>
  <% @status == :completed and @success? -> %>
  <% @status == :completed and !@success? -> %>
  <!-- 10 more conditions... -->
<% end %>

<!-- GOOD: Precomputed derived status in LiveView -->
def mount(_params, _session, socket) do
  display_status = compute_display_status(socket.assigns)
  {:ok, assign(socket, display_status: display_status)}
end

# Template renders one status
<.status_display status={@display_status} />
```

---

*Last updated: 2025-11-25*