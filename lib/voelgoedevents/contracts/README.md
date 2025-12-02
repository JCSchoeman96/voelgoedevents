# Contracts Layer (Elixir Behaviours)

**Purpose:** Defines formal Elixir Behaviours (`@callback` declarations) for clear system decoupling. This ensures component substitutability and testability.
**Value:** By programming to an interface, we can swap out high-latency external dependencies (e.g., `PaymentProvider`, `NotificationService`) without changing core domain logic.
**Architecture:** All adapter modules (in `payments/`, `notifications/`) must implement a behaviour defined here.
