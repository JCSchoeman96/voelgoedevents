# JavaScript Guidelines for VoelgoedEvents

## Purpose

This guide defines JavaScript and TypeScript conventions for any custom JS used in VoelgoedEvents. The principle: **minimize custom JS.** Prefer LiveView and Svelte for UI logic; use JS only for hooks, browser integration, and unavoidable client utilities.

## Philosophy: Minimal Custom JavaScript

**Before writing custom JavaScript, ask:**

1. Can LiveView handle it? (Server-driven, real-time) → Use LiveView.
2. Is it a complex interactive component? → Use Svelte.
3. Is it a simple browser/DOM integration? → Use a Phoenix hook or small utility.
4. Does it absolutely need custom JS? → Yes? Then write it here.

**Good use cases for custom JS:**

- ✅ Phoenix hooks for LiveView interactivity (barcode scanner, camera, geolocation).
- ✅ Third-party library integration (maps, payment forms, analytics).
- ✅ Browser APIs (local storage, notifications, permissions).
- ✅ Small utilities that enhance server-rendered templates.

**Bad use cases:**

- ❌ Business logic (pricing, calculations, policies).
- ❌ UI state management (forms, lists, filters).
- ❌ Data fetching and transformation (should be on backend).

## Code Organization

### File Structure

All custom JS lives in the `assets/js/` directory.

```
assets/js/
  app.js                    # Main entry point
  hooks/
    BarcodeScanner.js       # Phoenix hook
    MapViewer.js            # Phoenix hook
  utils/
    api.js                  # API client helpers
    formatting.js           # Format utilities
  components/
    TicketScanner.svelte    # Svelte components
```

### Imports and Organization

```javascript
// Good: Clear imports at the top
import { createApp } from 'vue'; // if using Vue
import { Socket } from 'phoenix';
import { BarcodeScanner } from './hooks/BarcodeScanner';
import { formatDate } from './utils/formatting';

// Setup and initialization
const socket = new Socket('/socket');
socket.connect();

export { socket };
```

## Modern JavaScript Style

### Use ES Modules

All JS should use modern ES module syntax (`import`/`export`).

```javascript
// Good: ES modules
import { ApiClient } from './utils/api';
export function handleEvent(data) {
  ApiClient.send(data);
}

// Avoid: CommonJS or mixed syntax
const ApiClient = require('./utils/api');
module.exports = { handleEvent };
```

### Use `const` and `let`, Not `var`

```javascript
// Good
const EVENT_ID = '123';
let currentTicket = null;

function selectTicket(ticket) {
  currentTicket = ticket; // Rebinding
}

// Avoid
var eventId = '123';
var ticket;
```

### Arrow Functions for Simple Callbacks

```javascript
// Good: Arrow functions for callbacks
const items = [1, 2, 3];
const doubled = items.map(x => x * 2);

// Good: Regular function for complex logic
function processBatch(items) {
  return items
    .filter(item => item.valid)
    .map(item => transform(item))
    .sort((a, b) => a.priority - b.priority);
}

// Avoid: Overly nested arrow functions
const result = items.map(x =>
  fetch(`/api/${x}`).then(r => r.json()).then(d => d.value)
);
// Better: Extract to a function
async function fetchItemValue(itemId) {
  const response = await fetch(`/api/${itemId}`);
  const data = await response.json();
  return data.value;
}

const result = await Promise.all(items.map(fetchItemValue));
```

### Template Literals for Strings

```javascript
// Good: Template literals
const eventId = '123';
const url = `/api/events/${eventId}/tickets`;
const message = `Event ${name} is scheduled for ${date}`;

// Avoid: String concatenation
const url = '/api/events/' + eventId + '/tickets';
const message = 'Event ' + name + ' is scheduled for ' + date;
```

## Phoenix Hooks

Phoenix hooks allow you to write custom JavaScript that responds to LiveView lifecycle events.

### Hook Structure

```javascript
// assets/js/hooks/BarcodeScanner.js
export const BarcodeScanner = {
  mounted() {
    console.log('Barcode scanner hook mounted');
    
    // Initialize any third-party libraries
    this.scanner = new Instascan.Scanner({ video: document.getElementById('preview') });
    this.scanner.addListener('scan', (content) => this.handleScan(content));
    this.scanner.start();
  },

  handleScan(content) {
    // Send scanned code to LiveView
    this.pushEvent('barcode_scanned', { code: content });
  },

  destroyed() {
    // Cleanup
    if (this.scanner) {
      this.scanner.stop();
    }
  }
};
```

### Using Hooks in LiveView

```heex
<!-- Template -->
<div id="scanner" phx-hook="BarcodeScanner">
  <video id="preview"></video>
</div>

<script>
  // In your app.js
  import { BarcodeScanner } from './hooks/BarcodeScanner';

  let Hooks = { BarcodeScanner };
  let liveSocket = new LiveSocket('/live', Socket, { hooks: Hooks });
</script>
```

### Hook Lifecycle

```javascript
export const MyHook = {
  // Called when the element is inserted into the DOM
  mounted() {
    console.log('Hook mounted');
  },

  // Called when the element receives new attribute values
  updated() {
    console.log('Element updated');
  },

  // Called when the element is removed from the DOM
  destroyed() {
    console.log('Hook destroyed');
  },

  // Method to push an event to the LiveView
  pushEvent(event, payload) {
    // Handled by Phoenix automatically
  },

  // Method to receive messages from the LiveView
  handleEvent(event, payload) {
    console.log(`Received event: ${event}`, payload);
  }
};
```

## API Client Helpers

### Simple API Utilities

```javascript
// assets/js/utils/api.js
export class ApiClient {
  static async get(url, options = {}) {
    return this.request('GET', url, null, options);
  }

  static async post(url, data, options = {}) {
    return this.request('POST', url, data, options);
  }

  static async put(url, data, options = {}) {
    return this.request('PUT', url, data, options);
  }

  static async delete(url, options = {}) {
    return this.request('DELETE', url, null, options);
  }

  static async request(method, url, data, options = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers
    };

    const config = {
      method,
      headers,
      ...options
    };

    if (data) {
      config.body = JSON.stringify(data);
    }

    const response = await fetch(url, config);

    if (!response.ok) {
      const error = new Error(`HTTP ${response.status}`);
      error.status = response.status;
      throw error;
    }

    return await response.json();
  }
}
```

Usage in components or hooks:

```javascript
import { ApiClient } from './utils/api';

// In a hook or Svelte component
const tickets = await ApiClient.get(`/api/events/${eventId}/tickets`);

const reservation = await ApiClient.post('/api/reservations', {
  tickets: selectedIds,
  email: userEmail
});
```

## Formatting and Utility Functions

### Date and Time Utilities

```javascript
// assets/js/utils/formatting.js
export function formatDate(date, format = 'MMM DD, YYYY') {
  // Use a library like date-fns or dayjs, or native Intl API
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  }).format(new Date(date));
}

export function formatCurrency(cents, currency = 'USD') {
  const dollars = cents / 100;
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency
  }).format(dollars);
}

export function formatTime(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}
```

## DOM Manipulation

### Using Modern DOM APIs

```javascript
// Good: Modern DOM APIs
function highlightElement(id) {
  const el = document.getElementById(id);
  if (el) {
    el.classList.add('highlight');
  }
}

function clearErrors() {
  document.querySelectorAll('.error').forEach(el => {
    el.remove();
  });
}

// Avoid: jQuery (not needed in modern browsers)
$('#element').addClass('highlight');
$('.error').remove();
```

### Event Delegation

```javascript
// Good: Event delegation
document.addEventListener('click', (event) => {
  if (event.target.matches('.delete-btn')) {
    handleDelete(event.target.dataset.id);
  }

  if (event.target.matches('.edit-btn')) {
    handleEdit(event.target.dataset.id);
  }
});

// Avoid: Attaching listeners to many elements
document.querySelectorAll('.delete-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    // Each button gets its own listener
  });
});
```

## Error Handling

### Handle Errors Gracefully

```javascript
// Good: Try/catch and error messages
export async function loadTickets(eventId) {
  try {
    const tickets = await ApiClient.get(`/api/events/${eventId}/tickets`);
    return tickets;
  } catch (error) {
    if (error.status === 404) {
      console.error('Event not found');
    } else if (error.status === 403) {
      console.error('Unauthorized');
    } else {
      console.error('Failed to load tickets:', error);
    }
    throw error;
  }
}

// Good: Async/await
async function processReservation(reservationId) {
  try {
    const result = await ApiClient.post('/api/reservations/confirm', {
      reservationId
    });
    notifyUser('Reservation confirmed');
    return result;
  } catch (error) {
    notifyUser(`Error: ${error.message}`);
  }
}
```

## Browser APIs

### Using Permissions and Notifications

```javascript
// assets/js/hooks/Notifications.js
export const NotificationHook = {
  mounted() {
    this.requestPermission();
  },

  requestPermission() {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
  },

  handleEvent('send_notification', (payload) => {
    if (Notification.permission === 'granted') {
      new Notification(payload.title, {
        body: payload.message,
        icon: '/icon.png'
      });
    }
  })
};
```

### Geolocation

```javascript
// Get user location for local events
export async function getUserLocation() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('Geolocation not supported'));
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          lat: position.coords.latitude,
          lng: position.coords.longitude
        });
      },
      (error) => {
        reject(error);
      }
    );
  });
}
```

## Common Pitfalls

### ❌ Do Not Hardcode Magic Numbers

```javascript
// BAD
const timeout = 5000;
const maxRetries = 3;

// GOOD
const RETRY_TIMEOUT_MS = 5000;
const MAX_RETRY_ATTEMPTS = 3;

export function retryRequest(fn, maxAttempts = MAX_RETRY_ATTEMPTS) {
  // ...
}
```

### ❌ Do Not Leave Console Logs in Production

```javascript
// Development: useful for debugging
console.log('Event data:', eventData);

// Before pushing to production, remove or use a logger
if (isDevelopment()) {
  console.log('Event data:', eventData);
}
```

### ❌ Do Not Trust Client-Side Validation Alone

```javascript
// Bad: Only validating on client
function validateEmail(email) {
  return email.includes('@');
}

if (!validateEmail(email)) {
  showError('Invalid email');
  return;
}

// Good: Always validate on backend (client validation is UX only)
async function submitForm(email) {
  try {
    const response = await ApiClient.post('/api/subscribe', { email });
    // Server validates and returns errors if any
  } catch (error) {
    showError(error.message);
  }
}
```

### ❌ Do Not Mutate Global State

```javascript
// BAD: Global state mutation
window.appState = { userId: 123 };
function getUserId() {
  return window.appState.userId;
}

// GOOD: Encapsulate state
const state = { userId: null };
export function setUserId(id) {
  state.userId = id;
}
export function getUserId() {
  return state.userId;
}
```

## Performance Tips

### Debouncing and Throttling

```javascript
// Debounce: Wait for user to finish typing before searching
export function debounce(fn, delay) {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
}

const searchEvents = debounce(async (query) => {
  const results = await ApiClient.get(`/api/events/search?q=${query}`);
  displayResults(results);
}, 300);

// Usage
input.addEventListener('input', (e) => {
  searchEvents(e.target.value);
});

// Throttle: Limit how often a function runs (e.g., scroll handlers)
export function throttle(fn, delay) {
  let lastRun = 0;
  return (...args) => {
    const now = Date.now();
    if (now - lastRun >= delay) {
      fn(...args);
      lastRun = now;
    }
  };
}

window.addEventListener('scroll', throttle(() => {
  updateScrollPosition();
}, 100));
```

### Lazy Loading

```javascript
// Lazy-load a heavy script only when needed
async function loadPaymentProcessor() {
  return import('./plugins/stripe-loader');
}

document.getElementById('checkout-btn').addEventListener('click', async () => {
  const { StripeProcessor } = await loadPaymentProcessor();
  StripeProcessor.init();
});
```

---

*Last updated: 2025-11-25*