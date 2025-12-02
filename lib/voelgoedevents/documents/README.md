# Document Generation Layer

**Purpose:** Houses the domain-specific logic and templates for generating static, printable documents (e.g., PDF tickets, invoices, receipts).
**Execution Flow:** Rendering logic is defined here, but the heavy rendering operation itself is almost always executed asynchronously via an Oban job (in `queues/`) to avoid blocking web requests.
