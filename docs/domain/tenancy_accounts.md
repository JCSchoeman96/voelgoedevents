<!-- docs/domain/tenancy_accounts.md -->

# Tenancy & Accounts Domain

## 1. Scope & Responsibility

The Tenancy & Accounts domain owns:

- Organizations (tenants)
- Users (platform-level identities)
- Organization memberships and roles (RBAC)
- Basic tenant configuration (branding, settings, limits)

It is responsible for:

- Multi-tenant isolation and scoping (`organization_id`)
- Who can see/do what, in which organization
- Authentication linkage (auth provider data is referenced here, but auth implementation lives elsewhere if needed)
- Providing a stable identity model for all other domains

Out of scope:

- Payments and billing (belongs to Payments & Ledger)
- Event-specific configuration (belongs to Events & Venues)
- Notification preferences and channels (belongs to Notifications & Delivery)

### Actor Construction for System Flows

All Ash calls operating on tenant data must supply either:

1.  A **user actor** with `organization_id`, constructed via `Voelgoedevents.Tenancy.Actor.user_actor/2`.
2.  A **system actor** with explicit `organization_id` for jobs and maintenance, constructed via `Voelgoedevents.Tenancy.Actor.system_actor/2`.

---

## 2. Core Resources

**Organization**

- Core fields:
  - `id`
  - `name`
  - `slug` (unique, human-friendly identifier; used in URLs)
  - `status` (active, suspended, trial, closed)
  - `settings` (JSONB: branding, default locale, feature flags)
  - `created_at`, `updated_at`
- Invariants:
  - `slug` is globally unique.
  - `status` controls whether organization can create events/sell tickets.
  - Deletion is soft-only (must not orphan critical data like events, payments).

**User**

- Core fields:
  - `id`
  - `email` (unique)
  - `password_hash` or external auth reference
  - `name`
  - `status` (active, disabled)
  - `created_at`, `updated_at`
- Invariants:
  - `email` is unique across platform.
  - Users can exist without organization membership (e.g. invited but not yet accepted).

**Membership**

- Fields:
  - `id`
  - `user_id`
  - `organization_id`
  - `role` (owner, admin, manager, support, read_only, etc.)
  - `invited_by_user_id` (optional)
  - `invited_at`, `accepted_at`
- Invariants:
  - A user can have multiple memberships (multi-tenant user).
  - Each `(user_id, organization_id)` pair is unique.
  - At least one active membership with `role = owner` must exist per active organization.

**Role / Permission Policy**

- Conceptual rather than a heavy table:
  - Map roles → capabilities (e.g. manage_events, manage_payments, view_analytics).
  - Can be a static config or an Ash resource if you want dynamic roles in future.

---

## 3. Key Invariants

- All domain data referencing an organization must use `organization_id` and respect tenancy boundaries.
- Membership determines access:
  - No membership → no access to that organization’s data.
  - Role governs which actions are allowed.
- Cross-tenant leakage is never allowed:
  - Queries must always be scoped by `organization_id`.
  - UI and LiveViews must never fetch data without an org scope.
- There must always be at least one owner per active organization.

---

## 4. Performance & Caching Strategy

Data temperature & storage:

- **Hot (ETS/Cachex):**
  - Per-request membership check of `(user_id, organization_id, role)`:
    - Short TTL: 30–120 seconds.
  - Frequently-used organization settings (branding, feature flags).
- **Warm (Redis):**
  - User’s organization memberships list (for quick org-switch UIs).
  - Organization-level configuration that is read-heavy, write-light.
  - TTL: 15–60 minutes; refresh on access or change.
- **Cold (Postgres):**
  - Canonical storage for all entities.
  - Source of truth for security decisions (cache is an optimization, never authority).

Cache invalidation triggers:

- When membership is created/updated/deleted:
  - Invalidate ETS membership cache key for `(user_id, organization_id)`.
  - Invalidate Redis list of organizations for that user.
- When organization settings change:
  - Invalidate organization settings in ETS + Redis.

---

## 5. Redis Structures

Suggested key patterns (names are illustrative — keep them consistent):

- Membership-by-user:
  - `tenancy:user_orgs:{user_id}` → Redis **list** or **set** of `organization_id`.
- Membership role lookup:
  - `tenancy:membership:{user_id}:{org_id}` → Redis **hash**
    - Fields: `role`, `status`, `updated_at`.
- Organization settings:
  - `tenancy:org_settings:{org_id}` → Redis **hash**
    - Fields: `branding`, `defaults`, `feature_flags` (compact JSON strings if needed).

Consider HyperLogLog or other structures only if you want aggregate “active users per org” metrics; otherwise that lands better in Analytics.

---

## 6. Indexing & Query Patterns

Critical indexes:

- `users`:
  - Unique index on `email`.
  - Optional composite indexes for external auth IDs if used.
- `organizations`:
  - Unique index on `slug`.
  - Index on `status` if you query by active/suspended frequently.
- `memberships`:
  - Unique composite index on `(user_id, organization_id)`.
  - Index on `organization_id`.
  - Index on `(organization_id, role)` for admin/owner lookups.

Common query patterns:

- Load all organizations for a user:
  - Use Redis list → fallback to Postgres query `WHERE user_id = ?`.
- Check if user is owner/admin of a given organization:
  - Use ETS/Cachex + Redis → fallback to Postgres by `(user_id, organization_id)`.

---

## 7. PubSub & Real-time

Topics:

- `tenancy:org:{org_id}`:
  - Broadcast when organization settings change.
- `tenancy:user:{user_id}`:
  - Broadcast when memberships change (added, removed, role change).

Usage:

- LiveViews that show organization switcher or settings subscribe to relevant topics.
- On membership updates:
  - Tell LiveViews to refetch membership from ETS/Redis (not Postgres directly, unless cache miss).

---

## 8. Error & Edge Cases

- User removed from organization while they’re active:
  - Active sessions should be invalidated or their access gracefully downgraded.
  - LiveView should handle 403/401 from domain layer and redirect to an org selector.
- Last owner demotion/removal:
  - Must be rejected by domain rules.
- Organization suspended:
  - Domain operations must reject actions that create new events, ticket types, etc.
  - Read-only for existing data may still be allowed (configurable).

---

## 9. Interactions with Other Domains

- **Events & Venues**:
  - Every event/venue references `organization_id`.
  - Tenancy defines who can create/edit events.
- **Payments & Ledger**:
  - Payout configurations, billing contact belong to an organization.
- **Analytics & Reporting**:
  - All metrics grouped by `organization_id`.
- **Public API & Access Keys**:
  - API keys bound to an organization; permissions derived from tenancy roles.

---

## 10. Testing & Observability

- Tests:
  - Multi-tenant isolation tests (no cross-org leaks).
  - Membership-based access tests for common flows (create event, manage pricing, view reports).
- Observability:
  - Emit events for membership changes, org status changes.
  - Attach `organization_id` and `user_id` to logs and telemetry for correlation.

---

## 11. Open Questions / Future Extensions

- Should roles be fully dynamic (DB-driven) or static configuration?
- Will we support cross-organization users with special “partner” access?
- Do we need per-organization feature flagging (likely yes; settings should support this).
