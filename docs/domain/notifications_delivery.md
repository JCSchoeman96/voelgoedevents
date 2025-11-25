# Notifications & Delivery Domain

## 1. Scope & Responsibility

The Notifications & Delivery domain owns:

- Email, SMS, push, WhatsApp delivery.
- Notification templates & localization.
- Delivery queue, retry, and status tracking.
- Triggering notifications from events (purchase, refund, reminder).

Out of scope:
- Marketing segmentation (Analytics domain).
- webhook-based integrations (Integrations domain).

---

## 2. Core Resources

### **NotificationTemplate**

Fields:
- `id`
- `organization_id`
- `name`
- `channel` (email, sms, push)
- `subject` (email only)
- `body_template`
- `locale`
- `variables` JSONB

Invariants:
- Templates must render safely (no missing variables).

---

### **Notification**

A queued notification ready for delivery.

Fields:
- `id`
- `organization_id`
- `user_id` / `recipient`
- `channel`
- `payload` JSONB (rendered)
- `status` (queued, sending, delivered, failed)
- `attempts`
- `next_retry_at`
- `created_at`

---

### **DeliveryProviderConfig**

Fields:
- `organization_id`
- `provider` (SendGrid, AWS SES, Twilio)
- `credentials` (encrypted)
- `settings` JSONB

---

## 3. Key Invariants

- Delivery must be idempotent.
- Hard failures must move to dead-letter.
- Soft failures must retry with backoff.
- Sensitive user data must not appear in logs.

---

## 4. Performance & Caching Architecture

**Hot (ETS):**
- Provider configs cached per organization.
- Recently delivered notifications.

**Warm (Redis):**
- Delivery queue:
  - `notifications:queue:{org_id}` → list of notification IDs
- Rate limiting counters:
  - `notifications:rate:{org_id}:{channel}`

**Cold (Postgres):**
- Notifications history.
- Templates.

TTL:
- ETS: 5–15 minutes
- Redis rate limits: 1–24 hours depending on policy

---

## 5. Redis Structures

- `notifications:queue:{org_id}` → Redis **list**
- `notifications:rate:{org_id}:{channel}` → Redis **counter**
- `notifications:provider:{org_id}:{channel}` → Redis **hash**

---

## 6. Indexing & Query Patterns

Indexes:
- Notifications: `(organization_id, status)`
- Templates: `(organization_id, name)`
- Provider configs: `(organization_id, provider)`

Patterns:
- Worker:
  - Pop from Redis queue → deliver → update DB.

---

## 7. PubSub & Real-time

Topics:
- `notifications:org:{org_id}`

Broadcasts:
- Delivery success/failure
- Notification created

---

## 8. Error & Edge Cases

- SMS provider downtime → automatic backoff.
- Bounced emails → update user contact status.
- Invalid template vars → fail fast.

---

## 9. Domain Interactions

- **Ticketing** — purchase confirmations, seat confirmations  
- **Payments** — refund/chargeback notifications  
- **Integrations** — external system alerts  
- **Reporting** — scheduled report delivery  

---

## 10. Testing & Observability

Tests:
- Template rendering
- Provider integration mocks
- Retry behavior

Telemetry:
- Bounce rates
- Delivery latency
- Provider error codes

---

## 11. Future Extensions

- Multi-lingual templates
- End-user notification preferences
- Push token management
