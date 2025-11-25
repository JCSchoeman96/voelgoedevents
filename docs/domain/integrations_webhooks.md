# Integrations & Webhooks Domain

## 1. Scope & Responsibility

This domain owns:

- Incoming webhooks from payment providers (Stripe, PayFast, etc.)
- Outgoing webhooks to partner systems
- Event-driven integration triggers
- Retry mechanisms & dead-letter queues
- API client credentials & throttling (Public API domain links here)

Out of scope:

- Rendering public API responses (Public API domain)
- Financial bookkeeping (Payments & Ledger)

---

## 2. Core Resources

### **IncomingWebhook**

Fields:
- `id`
- `source` (stripe, payfast, etc.)
- `payload` JSONB
- `signature`
- `processed_at`
- `status` (pending, succeeded, failed)
- `retry_count`

Invariants:
- Must be idempotent.
- Never deleted (audit).

---

### **OutgoingWebhook**

Fields:
- `id`
- `organization_id`
- `target_url`
- `event_type`
- `payload`
- `attempts`
- `next_retry_at`
- `status`

Invariants:
- Must follow exponential backoff.
- Max retries after which it enters dead-letter.

---

### **IntegrationConfig**

Fields:
- `organization_id`
- `provider`
- `settings` JSONB (API keys, URLs, etc.)
- `status`

---

## 3. Performance Architecture

**Hot (ETS):**
- Mapping of providers and keys for fast lookups.

**Warm (Redis):**
- Outgoing webhook queue:
  - `integrations:queue:{org_id}` → Redis **list**
- Incoming webhook dedup storage:
  - `integrations:incoming:{psp}:{event_id}` → Redis **string**

**Cold (Postgres):**
- Webhook logs and statuses.

---

## 4. Redis Structures

- `webhook:incoming:dedupe:{unique_key}` → short TTL (1–10 minutes)
- `webhook:outgoing:queue:{org_id}` → list of webhook IDs
- `webhook:outgoing:attempt:{id}` → metadata for retry workers

---

## 5. Indexing & Query Patterns

Indexes:
- `(source, created_at)` for incoming webhooks.
- `(organization_id, event_type)` for outgoing hooks.
- `(status, next_retry_at)` for retry workers.

Patterns:
- Worker pulls from Redis → loads DB record → attempts delivery.

---

## 6. PubSub & Real-time

Topics:
- `integrations:outgoing:{org_id}`
- `integrations:incoming:{psp}`

Broadcast:
- Delivery successes/failures
- Integration status changes

---

## 7. Error & Edge Cases

- Provider signature mismatch → reject + alert.
- Massive retry storms → circuit-breaker needed.
- Partner downtime → backoff + dead-letter queue.

---

## 8. Domain Interactions

- **Payments** — PSP webhooks.
- **Reporting** — external export hooks.
- **Public API** — authentication & rate-limits.
- **Ticketing** — downstream partner inventory systems (optional).

---

## 9. Testing & Observability

Tests:
- Deduping.
- Retry logic.
- Signature verification.

Telemetry:
- Webhook latency.
- Failure count.
- Queue depth.

---

## 10. Open Questions

- Should outgoing hooks support transformation templates?
- Should we support OAuth-based partner integrations?
