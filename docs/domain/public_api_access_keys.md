# Public API & Access Keys Domain

## 1. Scope & Responsibility

This domain owns:

- Public API access for partners & integrations.
- Access key management (create, revoke, rotate).
- API rate-limiting & quota enforcement.
- Authentication + authorization for programmatic access.
- Outbound and inbound API traffic policies.

Out of scope:
- Web-focused controller logic (belongs to UI/API delivery layer).
- Notification delivery (Notifications domain).

---

## 2. Core Resources

### **ApiAccessKey**

Fields:
- `id`
- `organization_id`
- `name`
- `key_hash` (plaintext shown only once)
- `scopes` (events.read, tickets.write, etc.)
- `status` (active, revoked)
- `created_at`, `expires_at`

Invariants:
- Keys cannot be retrieved after creation.
- Hash stored using secure hashing (Argon2/PBKDF).

---

### **ApiQuota**

Tracks usage per key.

Fields:
- `key_id`
- `period` (hour/day/month)
- `count`

---

### **ApiLog**

Audit trail for API requests:

- `id`
- `organization_id`
- `key_id`
- `endpoint`
- `method`
- `status_code`
- `duration_ms`
- `inserted_at`

---

## 3. Key Invariants

- API access requires:
  - Valid key
  - Active organization
  - Sufficient quota
- Key scopes must match endpoint permissions.
- Missing or invalid keys → 401.
- Exceeded rate limits → 429.

---

## 4. Performance & Caching Architecture

**Hot (ETS):**
- Access key scope cache for ultra-fast lookups.

**Warm (Redis):**
- Rate limit counters:
  - `api:rate:{key_id}:{period}`
- Quota counters
- Key → org mapping

**Cold (Postgres):**
- Access key records
- API logs

TTL:
- Redis counters: expire at end of window (hour/day)
- ETS caches: 5–15 minutes

---

## 5. Redis Structures

- `api:key:{key_id}:scopes` → Redis **set**
- `api:rate:{key_id}:{per_minute}` → counter
- `api:org:{key_id}` → org_id mapping

---

## 6. Indexing & Query Patterns

Indexes:
- `api_access_keys`: `(organization_id, status)`
- `api_logs`: `(key_id, inserted_at DESC)`

Patterns:
- Validate key:
  - ETS → Redis → fallback DB.
- Rate limit check (atomic):
  - INCR + EXPIRE.

---

## 7. PubSub & Real-time

Topics:
- `api_keys:org:{org_id}`

Broadcast:
- Key created/revoked
- Quota threshold warnings

---

## 8. Error & Edge Cases

- Revoked keys must immediately fail.
- Key rotation must update caches instantly.
- Quota exhaustion must not overload Redis (spread counters by period).

---

## 9. Domain Interactions

- **Integrations** — outgoing webhooks often authenticated via keys.
- **Reporting** — API logs included in reporting if required.
- **Tenancy** — org permissions.

---

## 10. Testing & Observability

Tests:
- Scope enforcement.
- Key rotation flows.
- Rate-limit behavior.

Telemetry:
- 401/403 rates
- Latency per endpoint
- Rate-limit triggers

---

## 11. Future Extensions

- OAuth2 client credentials flow.
- API key tagging & metadata.
- Partner-specific dashboards.
