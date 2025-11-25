# Audit Logging Domain

## 1. Scope & Responsibility

The Audit Logging domain owns:

- Recording all privileged or security-sensitive actions.
- Immutable audit log storage.
- Searching & filtering audit logs.
- Providing cross-domain traceability for support and compliance.
- Ensuring multi-tenant isolation in audit visibility.

Out of scope:
- Application logs (handled by observability layer).
- Non-sensitive event metrics (Analytics domain).

---

## 2. Core Resources

### **AuditLog**

Fields:
- `id`
- `organization_id`
- `actor_user_id`
- `actor_role`
- `event_type`
- `entity_type`
- `entity_id`
- `metadata` JSONB
- `ip_address`
- `user_agent`
- `inserted_at`

Invariants:
- Must be immutable.
- Must never expose data from another organization.
- Metadata must be structured & non-sensitive (no full card data, PII minimization).

---

## 3. Key Invariants

- Audit logs must remain append-only.
- No updates, no deletes (except for retention/archival processes).
- Each log must record actor identity + action + target entity.

---

## 4. Performance & Caching Architecture

**Hot: ETS**
- Recent audit entries for LiveView admin interfaces.

**Warm: Redis**
- Search index caching:
  - Last N log IDs for an organization.
- Rate-limiting auditing for noisy actions.

**Cold: Postgres**
- Canonical append-only audit table.

TTL:
- ETS: 5–10 minutes.
- Redis: 10–60 minutes.

---

## 5. Redis Structures

- `audit:recent:{org_id}` → list (max N entries)
- `audit:rate:{org_id}:{action}` → counter

---

## 6. Indexing & Query Patterns

Critical indexes:
- `(organization_id, inserted_at DESC)`
- `(organization_id, actor_user_id)`
- `(organization_id, event_type)`

Patterns:
- Fetch latest logs: Redis → fallback to Postgres.
- Full filtering always hits Postgres (indexed).

---

## 7. PubSub & Real-time

Topics:
- `audit:org:{org_id}`

Broadcast:
- New audit entry appended.

---

## 8. Error & Edge Cases

- Excessively large metadata must be rejected.
- Sensitive data must be scrubbed before writing.
- Rate limiting must prevent noisy abuse.

---

## 9. Domain Interactions

- **Tenancy** — actor & org context  
- **Ticketing** — logging admin actions  
- **Payments** — logging refunds  
- **Integrations** — audit incoming/outgoing webhook behavior  

---

## 10. Testing & Observability

Tests:
- Ensure immutability (no updates allowed).
- Validate metadata shape.
- Tenant isolation.

Telemetry:
- Audit spam detection
- Write latency

---

## 11. Future Extensions

- Archive to cold storage (S3/Glacier).
- Admin UI for filtering and export.
