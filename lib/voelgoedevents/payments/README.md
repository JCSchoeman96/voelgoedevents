# Payment Gateway Integration Layer

**Purpose (Phase 4):** Abstraction layer for interacting with external South African payment providers (Yoco, Paystack).
**Boundary:** Handles secure API calls, tokenization, and processing of asynchronous webhooks.
**Rule:** Modules must implement a standard `PaymentProvider` behaviour.
