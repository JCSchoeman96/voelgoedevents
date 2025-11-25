# Security & Authentication Architecture  
VoelgoedEvents Platform  
**Document: `/docs/architecture/07_security_and_auth.md`**

---

## 1. Purpose of This Document

This document defines the **security, authentication, and authorization architecture** for the VoelgoedEvents platform.

It establishes:

- Identity model (users, devices, API clients)  
- Authentication flows (web, API, scanners, integrations)  
- Authorization & RBAC model (per-organization)  
- Session & token handling  
- Secrets & credential management  
- Rate limiting, abuse prevention, and input validation  
- Multi-tenant isolation in security-critical paths  
- Secure use of Redis, ETS, PubSub, and jobs  

This is the **source of truth** for all security-related decisions across domains and vertical slices.

---

## 2. Threat Model Overview

Key threats the platform must defend against:

- Cross-tenant data leakage  
- Unauthorized access to events / tickets / reports  
- Credential stuffing & brute-force attacks  
- Token theft (XSS, CSRF, storage leaks)  
- Replay attacks on QR codes / tickets  
- Malicious or compromised scanners/devices  
- Abuse of public APIs (DDoS / scraping)  
- Webhook forgery (fake PSP or partner calls)  
- Insider misuse of admin capabilities  

Constraints:

- Multi-tenant architecture with strong isolation  
- Heavy real-time operations (scanning, seat maps)  
- High-frequency anonymous or semi-anonymous traffic (marketing pages)  
- Integrations with third-party PSPs and providers  

---

## 3. Identity Types

There are 4 primary identity types in the platform:

1. **End User (Customer)**  
   - Buys tickets, receives notifications, gets QR codes.  
2. **Organization User (Operator/Admin)**  
   - Manages events, pricing, seating, reporting.  
3. **Device Identity (Scanner / Kiosk / POS)**  
   - Performs check-in scans, attendance tracking.  
4. **API Client (External Integration / Partner)**  
   - Uses the public API with access keys.

Each identity type has distinct authentication and authorization flows.

---

## 4. Authentication Model

### 4.1 End Users (Customers)

- Standard user accounts or “magic link” style flows (implementation choice).  
- Critical invariants:
  - Email uniqueness platform-wide.  
  - Passwords (if used) are hashed using Argon2 or equivalent.  
  - Sessions are tenant-agnostic (user may belong to multiple orgs) but **all operations still require org context**.

Session model:

- HTTP-only, secure cookies.  
- Session contains:
  - `user_id`  
  - Current `organization_id` (if scoped into a tenant context)  
  - Versioning info for invalidation (e.g. `session_version`)  

### 4.2 Organization Users (Operators/Admins)

- Same underlying `User` identity model as end users.  
- Differentiated by **Tenancy & Accounts** membership and roles.  
- Authentication identical to end users, but their **role & org membership** determine:
  - Which domains/actions they can access.  
  - Which features are visible in the UI.  
  - What is allowed via public API keys they create/manage.

### 4.3 Device Authentication (Scanner / Kiosk)

- Devices are provisioned per organization.  
- Each device receives:
  - A device identifier (`device_id`)  
  - A device token or key, stored securely in device app storage.  
- Device token must:
  - Be scoped to `organization_id`  
  - Have limited privileges (e.g. scanning-only)  
  - Have a reasonable rotation/expiry policy  

Device sessions:

- Devices authenticate to a device-scoped endpoint.  
- Session time is longer-lived but still revocable.  
- All device actions are logged with `device_id`, `org_id`, and IP.

### 4.4 API Clients (Public API & Access Keys)

- See `/docs/domain/public_api_access_keys.md`.  
- Each API client gets:
  - A public identifier (key id)  
  - A secret (shown once, hashed server-side)  
  - Scopes (e.g., `events.read`, `tickets.read`, `tickets.write`)  
- API keys:
  - Sent via `Authorization: Bearer <token>` or `x-api-key` header.  
  - Always mapped to an `organization_id`.  
  - Subject to rate limits and quotas.  

---

## 5. Authorization & RBAC

### 5.1 Role-based Access Control

RBAC is enforced per organization via the **Tenancy & Accounts** domain:

- Roles examples:
  - `owner`  
  - `admin`  
  - `manager`  
  - `support`  
  - `read_only`  

Permissions are expressed as capabilities, e.g.:

- `manage_events`  
- `manage_seating`  
- `manage_ticketing`  
- `manage_payments`  
- `view_reports`  
- `manage_integrations`  

Actions in Ash resources are protected:

- Through **policies** that check:
  - `actor.user_id`  
  - `actor.roles` within `organization_id`  
  - Optional additional checks (e.g. event ownership)  

### 5.2 Ash Policy Layer (Mandatory)

Resources must include policies like:

- User must belong to `organization_id` of resource.  
- User must have appropriate role for destructive actions.  
- Sensitive operations like refunds require `owner` or `admin`.  

### 5.3 Cross-Domain Authorization

Domains do not directly inspect roles of other domains.  
Authorization is centralized in:

- Tenancy/RBAC layer, exposed as a **policy service**  
- Common authorizer modules that Ash can reference  

Slices consult domain actions that already enforce policies.  
They **never** evaluate roles on their own.

---

## 6. Sessions, Tokens & State

### 6.1 Web Sessions

- Stored as secure, HTTP-only cookies.  
- Optionally signed and encrypted by Phoenix.  
- Must include:
  - `user_id`  
  - Current `organization_id` (or `nil` until tenant context is chosen)  
  - Anti-replay/versioning fields (e.g., `session_version`)  

Security rules:

- CSRF tokens for all mutating operations (forms & JS).  
- Session invalidation on password change, role change, or membership revocation.  
- Idle timeout + absolute session timeout.  

### 6.2 JWT / Token Usage

JWTs, if used, are **only** for:

- Public API  
- Device-level access  
- Short-lived, signed, verifiable tokens for specific flows (e.g. magic link)

Rules:

- Short-lived (minutes) for magic links; hours for API tokens (if not key-based).  
- Embedded data must be minimal (no secrets).  
- Must always include `organization_id` when used in tenant-sensitive operations.  
- Must be signed with strong keys and algorithms (HS512 or ES256/RS256).  

### 6.3 Ticket QR Tokens

Ticket QR data:

- Must **not** contain raw PII.  
- Should contain:
  - Ticket ID or code  
  - Event ID  
  - Signature or MAC to prevent tampering  

Validation:

- Scanner calls backend with QR token → backend validates signature & data.  
- No direct “decode and trust” on device.  
- QR must be single-use or multi-use per configured rules (re-entry, etc.).  

---

## 7. Multi-Tenant Security

Multi-tenancy is a **security boundary**, not just a data model.

Rules:

- Every request must be associated with a single `organization_id`.  
- UI routing must not reveal cross-tenant data (e.g., sequential IDs).  
- All domain actions must be scoped by org policies.  
- Redis keys must include `{org_id}` to avoid cross-data leakage.  
- PubSub topics must include `{org_id}`.  

Admin-level “global” views exist only for platform operators and must:

- Be protected behind a separate super-admin role.  
- Use separate infrastructure (optional).  

---

## 8. Input Validation & Sanitization

All external inputs (web, API, webhook, device) must be:

- Sanitized  
- Validated  
- Normalized  

Rules:

- Use strong validation in Ash changesets and at boundaries.  
- Reject unknown or invalid fields early.  
- Enforce size limits (for payloads, strings, lists).  
- Use allow-lists for enums and statuses.  
- HTML inputs sanitized at render time or stored as structured content.

---

## 9. Rate Limiting & Abuse Prevention

Rate limiting is enforced via **Redis counters** and sometimes ETS.

Areas to protect:

- Login & authentication attempts  
- Public API endpoints  
- Scanning endpoints under high load  
- Webhook processing (to protect from noisy partners)  

Key patterns:

- `auth:rate:user:{user_id}`  
- `auth:rate:ip:{ip}`  
- `api:rate:org:{org_id}:key:{key_id}:{period}`  
- `scan:rate:org:{org_id}:device:{device_id}`  

Abuse handling:

- Return `429 Too Many Requests` on limit breach.  
- Track IP, org, and key in metrics.  
- Consider dynamic blocking for extreme abuse cases.  

---

## 10. Secrets & Credential Management

Sensitive information includes:

- PSP keys (Stripe, PayFast, etc.)  
- Email/SMS provider credentials  
- API keys / access tokens  
- Encryption keys  
- Device tokens  

Rules:

- Never store secrets in plain text in DB.  
- Use encrypted fields or external secret stores.  
- Never log secrets or tokens.  
- Use environment variables / dedicated secret-management systems for infrastructure-level secrets.  
- Rotate keys regularly and support rollover.  

---

## 11. Secure Use of Redis, ETS & PubSub

### 11.1 Redis

- MUST be deployed in a secure network (not publicly accessible).  
- Use authentication and TLS (where supported).  
- Key names must not reveal sensitive information (no raw emails, secrets, etc.).  
- Expire keys properly to avoid unbounded growth.  
- Keep serialization simple and safe (JSON, Erlang term with versioning).  

### 11.2 ETS

- Accessible only inside the BEAM VM.  
- Never store secrets in ETS.  
- Use ETS for caching IDs, flags, derived information—not credentials.  

### 11.3 PubSub

- Events must not include secrets or PII beyond what is necessary for the UI.  
- Topic names must do not include sensitive data.  
- Tenant scoping is mandatory for all normal topics.  

---

## 12. Scanning & Device Security

Scanning is high-risk because it operates at the edge and is often physical.

Requirements:

- Devices must authenticate to the backend via device token.  
- Device actions are limited to scanning-related operations only.  
- All scans are validated server-side.  
- QR tokens must be:
  - Signed or MAC’ed.  
  - Short-lived or limited by event state.  
- Duplicate scans must be caught in Redis/ETS with low-latency checks.  
- Radio/clock anomalies handled via server timestamps.  

Logging:

- Device ID, organization_id, event_id, IP, user agent.  
- Scan outcomes (accepted, duplicate, invalid, mismatched event, expired).  

---

## 13. Webhook Security

Webhooks from external providers (PSPs, partners):

- Must be validated:
  - IP allowlist (if possible).  
  - Signature checking with shared secret or public key.  
- Payloads must be:
  - Parsed safely.  
  - Validated against schemas.  

Outgoing webhooks:

- Must not include sensitive personal or payment info beyond what is necessary.  
- Must be signed or include secure tokens if recipients require verification.  

All webhook handling must be **idempotent** and **tenant-aware**.

---

## 14. Logging, Auditing & Compliance

### 14.1 Logging

Application logs must:

- Include `organization_id` where relevant.  
- Never contain:
  - Passwords.  
  - Secrets or tokens.  
  - Full card numbers or sensitive financial data.  

### 14.2 Audit Logging

Sensitive actions must create **AuditLog** entries:

- Role changes  
- Membership additions/removals  
- Price changes  
- Refunds / chargebacks  
- Payout configuration changes  
- Integration key updates  
- Public API key management  

Audit logs are:

- Immutable  
- Tenant-scoped  
- Long-lived (archived, not deleted)  

---

## 15. Secure Development Practices

Developers and AI agents must:

- Treat all input as hostile.  
- Use Ash changesets and policies for safety.  
- Always enforce tenant isolation.  
- Avoid “temporary bypasses” of security rules.  
- Write tests for:
  - Unauthorized access attempts.  
  - Cross-tenant access attempts.  
  - Privilege escalation attempts.  

Security should be included in:

- Code reviews  
- Architecture reviews  
- Slice design  
- Background job design  

---

## 16. Summary

The VoelgoedEvents security and auth architecture is built on:

- Strong, multi-tenant-aware identity and access control  
- Ash-based authorization with RBAC per organization  
- Secure session & token handling  
- Proper protection of secrets and credentials  
- Rate limiting & abuse prevention via Redis counters  
- Secure QR and scanning design  
- Webhook authenticity verification  
- Immutable audit logging and thorough observability  

Every domain, vertical slice, and integration must align with the rules and principles in this document to ensure a secure, scalable, and compliant platform.

