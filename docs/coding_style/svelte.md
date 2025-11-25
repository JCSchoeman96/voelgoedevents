# Svelte Coding Style Guide

## Purpose

This guide defines how Svelte is used in VoelgoedEvents as an optional client-side frontend framework. Svelte provides enhanced interactivity for complex UX patterns where server-driven LiveView is less suitable.

## Positioning: Svelte Is Frontend Only

### What Svelte Is

- ✅ A **client-side UI framework** for rich, interactive interfaces.
- ✅ Used for **feature-specific components** (e.g., advanced filtering, real-time charts, draggable interfaces).
- ✅ Consumes **backend APIs** provided by Phoenix/LiveView.
- ✅ Drives **client-side state** for interactive behavior.

### What Svelte Is NOT

- ❌ A **domain engine.** Business logic stays on the backend in Ash.
- ❌ A **security layer.** Frontend validation is UX only; Ash enforces constraints.
- ❌ A **database client.** All data comes through APIs.
- ❌ A **replacement for LiveView.** Use LiveView for server-driven, real-time interfaces; Svelte for heavier client interactions.

## When to Choose Svelte vs LiveView

### Use LiveView When

- You need server-driven, real-time updates.
- The interface is relatively simple (forms, lists, displays).
- You want automatic real-time syncing across users.
- Bandwidth/latency is a concern (server-side rendering is efficient).

```elixir
# LiveView example: Real-time event list
defmodule VoelgoedEventsWeb.EventLive.Index do
  use VoelgoedEventsWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(VoelgoedEvents.PubSub, "org:events")
    end
    
    events = VoelgoedEvents.Events.list_events()
    {:ok, assign(socket, events: events)}
  end

  def handle_info({:event_created, event}, socket) do
    {:noreply, assign(socket, events: [event | socket.assigns.events])}
  end
end
```

### Use Svelte When

- You need **heavy client-side interactivity** (dragging, real-time filtering, complex forms).
- You want **instant visual feedback** without server roundtrips.
- The interface has **complex state** that's not synced across users.
- You're building a **specialized tool** (e.g., ticket scanner UI, event organizer dashboard).

```svelte
<!-- Svelte example: Interactive ticket scanner -->
<script>
  let scannedTickets = [];
  let filteredTickets = [];
  let filterText = '';

  $: filteredTickets = scannedTickets.filter(t =>
    t.code.includes(filterText) || t.name.includes(filterText)
  );

  async function handleScan(qrCode) {
    const response = await fetch(`/api/tickets/verify/${qrCode}`);
    const ticket = await response.json();
    scannedTickets = [...scannedTickets, ticket];
  }
</script>

<!-- Real-time filtering, instant updates -->
<input type="text" bind:value={filterText} placeholder="Filter..." />
<div>
  {#each filteredTickets as ticket}
    <p>{ticket.code} - {ticket.name}</p>
  {/each}
</div>
```

## Component Structure

### Component Naming

- **PascalCase** for all components.
- Descriptive, feature-focused names.

```
components/
  TicketScanner.svelte
  ReservationForm.svelte
  EventDetailsPanel.svelte
  AnalyticsDashboard.svelte
```

### Component Template

```svelte
<!-- Good: Clear structure -->
<script>
  // Props
  export let eventId;
  export let onSave = () => {};

  // State
  let tickets = [];
  let loading = false;
  let error = null;

  // Lifecycle
  onMount(async () => {
    await loadTickets();
  });

  // Methods
  async function loadTickets() {
    loading = true;
    try {
      const response = await fetch(`/api/events/${eventId}/tickets`);
      tickets = await response.json();
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  function handleTicketClick(ticket) {
    onSave(ticket);
  }
</script>

<div>
  {#if loading}
    <p>Loading...</p>
  {:else if error}
    <p class="error">{error}</p>
  {:else}
    <ul>
      {#each tickets as ticket}
        <li on:click={() => handleTicketClick(ticket)}>
          {ticket.code}
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .error { color: red; }
</style>
```

## Props and State Management

### Props (Component Inputs)

Use `export` for props. Always document them.

```svelte
<script>
  /**
   * The event ID to fetch tickets for
   * @type {string}
   */
  export let eventId;

  /**
   * Initial list of tickets to display
   * @type {Array}
   */
  export let initialTickets = [];

  /**
   * Callback when a ticket is selected
   * @type {(ticket: any) => void}
   */
  export let onSelect = () => {};

  /**
   * Whether to show admin controls
   * @type {boolean}
   */
  export let isAdmin = false;
</script>

<!-- Usage from parent -->
<TicketList
  eventId={event.id}
  initialTickets={tickets}
  onSelect={handleTicketSelect}
  isAdmin={user.isAdmin}
/>
```

### Reactive Declarations

Use `$:` for computed values and side effects.

```svelte
<script>
  let eventId;
  let tickets = [];
  
  // Reactive: selectedTicket updates when tickets or current selection changes
  $: selectedTicket = tickets.find(t => t.id === selectedId);
  
  // Reactive: Trigger API call when eventId changes
  $: if (eventId) {
    loadTickets(eventId);
  }
  
  // Reactive: Combine calculations
  $: totalPrice = tickets.reduce((acc, t) => acc + t.price, 0);
</script>
```

### Stores for Shared State

Use Svelte stores for state that needs to be shared across components.

```javascript
// stores/ticketStore.js
import { writable } from 'svelte/store';

export const selectedTickets = writable([]);
export const currentEvent = writable(null);

export function addToCart(ticket) {
  selectedTickets.update(tickets => [...tickets, ticket]);
}

export function removeFromCart(ticketId) {
  selectedTickets.update(tickets => tickets.filter(t => t.id !== ticketId));
}
```

```svelte
<!-- Usage in component -->
<script>
  import { selectedTickets, addToCart } from '../stores/ticketStore';
</script>

<div>
  <p>Items in cart: {$selectedTickets.length}</p>
  <button on:click={() => addToCart(ticket)}>Add to Cart</button>
</div>
```

## API Integration

### Fetching Data from Backend

Always use Ash-provided APIs. Document endpoints clearly.

```svelte
<script>
  let tickets = [];
  let error = null;

  async function fetchTickets(eventId) {
    try {
      const response = await fetch(`/api/events/${eventId}/tickets`, {
        headers: {
          'Content-Type': 'application/json',
          // Include auth token if needed
          'Authorization': `Bearer ${authToken}`
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      tickets = await response.json();
    } catch (e) {
      error = e.message;
    }
  }

  onMount(() => fetchTickets(eventId));
</script>
```

### Posting Data Back

```svelte
<script>
  async function handleReservation(event) {
    event.preventDefault();

    const body = {
      tickets: selectedTicketIds,
      email: formData.email,
      phone: formData.phone
    };

    try {
      const response = await fetch('/api/reservations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });

      if (response.ok) {
        const { reservationId } = await response.json();
        onReservationSuccess(reservationId);
      } else {
        const { error } = await response.json();
        showError(error.message);
      }
    } catch (e) {
      showError('Network error: ' + e.message);
    }
  }
</script>

<form on:submit={handleReservation}>
  <!-- Form fields -->
  <button type="submit">Reserve</button>
</form>
```

## Styling in Svelte

### Scoped Styles

All styles in a `.svelte` file are scoped to that component by default.

```svelte
<script>
  export let status;
</script>

<div class="badge">
  {status}
</div>

<style>
  .badge {
    display: inline-block;
    padding: 0.5rem 1rem;
    border-radius: 9999px;
    font-weight: 600;
  }

  .badge :global(.highlight) {
    background: yellow;
  }
</style>
```

### Using Tailwind with Svelte

Tailwind works seamlessly in Svelte components.

```svelte
<script>
  let count = 0;

  function increment() {
    count++;
  }
</script>

<div class="flex flex-col items-center gap-4 p-6">
  <h1 class="text-3xl font-bold">Counter</h1>
  <p class="text-gray-600">Current: {count}</p>
  <button
    class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition"
    on:click={increment}
  >
    Increment
  </button>
</div>
```

### Conditional Classes

```svelte
<script>
  let isActive = false;
</script>

<div class="container" class:active={isActive} class:disabled={disabled}>
  <!-- Content -->
</div>

<style>
  .container {
    padding: 1rem;
  }

  .container.active {
    background: blue;
    color: white;
  }

  .container.disabled {
    opacity: 0.5;
  }
</style>
```

## Event Handling and Interactivity

### DOM Event Handlers

```svelte
<script>
  function handleClick() {
    console.log('Clicked');
  }

  function handleInput(event) {
    console.log('Input value:', event.target.value);
  }

  function handleSubmit(event) {
    event.preventDefault();
    console.log('Form submitted');
  }
</script>

<button on:click={handleClick}>Click me</button>
<input on:input={handleInput} />
<form on:submit={handleSubmit}>
  <input type="text" />
  <button type="submit">Submit</button>
</form>
```

### Component Events

Emit custom events from child components.

```svelte
<!-- Child component: TicketSelector.svelte -->
<script>
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  function selectTicket(ticketId) {
    dispatch('select', { ticketId });
  }
</script>

<button on:click={() => selectTicket(123)}>
  Select Ticket
</button>

<!-- Parent component -->
<TicketSelector on:select={(e) => handleTicketSelect(e.detail.ticketId)} />
```

## Async Data and Loading States

### Loading, Success, Error States

```svelte
<script>
  let data = null;
  let loading = false;
  let error = null;

  async function loadData() {
    loading = true;
    error = null;

    try {
      const response = await fetch('/api/data');
      if (!response.ok) throw new Error('Failed to load');
      data = await response.json();
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }
</script>

{#if loading}
  <p>Loading...</p>
{:else if error}
  <p class="error">{error}</p>
{:else if data}
  <p>{data.name}</p>
{:else}
  <p>No data</p>
{/if}

<button on:click={loadData}>Reload</button>
```

## Integration with Phoenix/LiveView

### Embedding Svelte in LiveView

You can embed a Svelte component in a LiveView template.

```heex
<!-- LiveView template -->
<div id="scanner-root" phx-hook="MountSvelte"></div>

<script>
  // Phoenix hook that mounts the Svelte component
  Hooks.MountSvelte = {
    mounted() {
      import('../js/components/TicketScanner.svelte').then(({ default: Component }) => {
        new Component({
          target: this.el,
          props: {
            eventId: this.el.dataset.eventId
          }
        });
      });
    }
  };
</script>
```

### Communication Between Svelte and LiveView

```svelte
<!-- Svelte component talking to LiveView -->
<script>
  export let liveViewSocket;

  function sendToLiveView(data) {
    // Assuming you've passed the LiveView socket reference
    liveViewSocket.send('svelte_event', { payload: data });
  }
</script>

<button on:click={() => sendToLiveView({ action: 'scan', code: '12345' })}>
  Send to LiveView
</button>
```

## Performance Considerations

### Bundle Size

Svelte compiles to small, efficient JavaScript. Still, be mindful of:

- ✅ Use `<script context="module">` for shared code across instances.
- ✅ Lazy-load components with dynamic imports when appropriate.
- ✅ Avoid importing large libraries; prefer backend-provided data.

```svelte
<!-- Good: Lazy-load a heavy component -->
<script>
  let ComponentLibrary;

  async function openAdvancedEditor() {
    ComponentLibrary = (await import('./AdvancedEditor.svelte')).default;
  }
</script>

{#if ComponentLibrary}
  <svelte:component this={ComponentLibrary} />
{:else}
  <button on:click={openAdvancedEditor}>Open Editor</button>
{/if}
```

### Avoid Over-Engineering

Not every interaction needs Svelte. Use LiveView for most CRUD and form-driven UIs. Use Svelte only for complex client-side interactions.

## Anti-Patterns to Avoid

### ❌ Do Not Implement Business Logic in Svelte

```svelte
<!-- BAD: Calculating prices in Svelte -->
<script>
  function calculateTotal(items) {
    // Complex pricing logic, discounts, taxes, etc.
    return items.reduce((acc, item) => {
      const discounted = item.price * (1 - item.discount / 100);
      const taxed = discounted * 1.1;
      return acc + taxed;
    }, 0);
  }
</script>

<!-- GOOD: Get total from backend -->
<script>
  async function getOrderTotal() {
    const response = await fetch('/api/orders/calculate-total', {
      method: 'POST',
      body: JSON.stringify({ items: selectedItems })
    });
    return await response.json();
  }
</script>
```

### ❌ Do Not Skip Backend Validation

```svelte
<!-- BAD: Only validating on client -->
<script>
  function validateEmail(email) {
    return email.includes('@');
  }

  async function submitForm() {
    if (!validateEmail(email)) {
      error = 'Invalid email';
      return;
    }
    // Submit...
  }
</script>

<!-- GOOD: Validate on backend (client validation is UX only) -->
<script>
  async function submitForm() {
    try {
      const response = await fetch('/api/reservations', {
        method: 'POST',
        body: JSON.stringify({ email, items: selectedItems })
      });

      if (!response.ok) {
        const { errors } = await response.json();
        error = errors.email || 'Validation failed';
        return;
      }

      // Success...
    } catch (e) {
      error = 'Network error';
    }
  }
</script>
```

---

*Last updated: 2025-11-25*