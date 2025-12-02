# Notification Service Layer

**Purpose:** Contains the domain logic for constructing, translating (using `i18n/`), and dispatching messages (email, SMS, push).
**Rule:** Modules here focus on *what* to send; the actual transport mechanism is delegated to provider adapters via a contract (see `contracts/`) and executed via Oban workers (in `queues/`).
