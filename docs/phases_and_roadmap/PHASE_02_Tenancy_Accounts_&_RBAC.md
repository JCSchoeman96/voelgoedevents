# 👥 PHASE 2: Tenancy, Accounts & RBAC (REFACTORED)

**Goal:** Multi-tenant foundation with user authentication and role-based access control  
**Duration:** 2 weeks  
**Deliverables:** Organization, User, Membership, Role resources; AshAuthentication integration; platform flags (`is_platform_staff`, `is_platform_admin`); AuditLog resource; membership caching (ETS + Redis) & full actor context plumbing  
**Dependencies:** Completes Phase 1

---

## Phase 2.1: Organization Resource

### Sub-Phase 2.1.1: Create Organization Resource

**Task:** Define Organization resource with name, slug, status, settings  
**Objective:** Establish tenant boundary for all domain resources  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/organization.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_organizations.exs`  

**Note:**  
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C)
- Reference `/docs/domain/tenancy_accounts.md` for complete specification
- Enforce multi-tenancy per Appendix B (all resources must include `organization_id`)
- Attributes: `id`, `name`, `slug` (unique), `status` (`:active`, `:suspended`, `:archived`), `settings` (map), timestamps
- Actions: `create`, `read`, `update`, `archive`
- Policies: Only super admins can create organizations (MVP: single org only)

---

## Phase 2.2: User Resource

### Sub-Phase 2.2.1: Create User Resource with AshAuthentication

**Task:** Define User resource with email, hashed_password, platform flags, and AshAuthentication integration  
**Objective:** Enable user login, session management, JWT generation, and platform staff management  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/user.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_users.exs`  

**Note:**  
- Use `AshAuthentication.Strategy.Password` for email/password auth
- Tokens stored in `user_tokens` table (AshAuthentication convention)
- Reference `/docs/domain/tenancy_accounts.md`
- Apply policies: users belong to organizations, never cross-org access
- Attributes: `id`, `email` (CiString, unique), `hashed_password` (sensitive), `confirmed_at`, `first_name`, `last_name`, `status`, timestamps
- Relationships: `has_many :memberships`, `many_to_many :organizations` (through Membership)
- **Platform-level flags:**
  - `is_platform_staff` (boolean, default: false) – User is a VoelgoedEvents support staff member
  - `is_platform_admin` (boolean, default: false) – User is a VoelgoedEvents super admin
- These flags are used by RBAC per `/docs/domain/rbac_and_platform_access.md` to distinguish platform staff and super admins from regular tenant users.

---

## Phase 2.3: Membership, Role & Audit Resources

### Sub-Phase 2.3.1: Create Role Resource

**Task:** Define Role resource with predefined roles  
**Objective:** Support RBAC for multi-tenant access control  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/role.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_roles.exs`  

**Note:**  
- Roles: `:owner`, `:admin`, `:staff`, `:viewer`, `:scanner_only`
- Roles are system-defined (not user-created in MVP)
- Seed roles in `priv/repo/seeds.exs`
- Attributes: `id`, `name` (atom), `display_name`, `permissions` (list of atoms)

---

### Sub-Phase 2.3.2: Create Membership Resource

**Task:** Define Membership (join table) linking User, Organization, Role with caching  
**Objective:** Enforce per-organization RBAC with high-speed lookups  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/membership.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_memberships.exs`  

**Note:**  
- Unique constraint: `(user_id, organization_id)` — one role per org
- **Caching Strategy:**
  - Hot cache: ETS for fast RBAC checks during request handling
    - Key: `{user_id, org_id}`
    - Value: `{role, is_platform_staff, status}`
    - TTL: 30–60 seconds (reference Appendix C)
  - Warm cache: Redis for cross-node consistency
    - Keys: `tenancy:membership:{user_id}:{org_id}`
    - Values: `{role, is_platform_staff, status}` (serialized)
    - TTLs per `/docs/domain/rbac_and_platform_access.md` (warm layer, 10–30 min)
- Attributes: `id`, `user_id`, `organization_id`, `role_id`, `status` (`:active`, `:inactive`), `invited_at`, `joined_at`
- Relationships: `belongs_to :user`, `belongs_to :organization`, `belongs_to :role`
- Policies: Organization owners can invite/remove members

---

### Sub-Phase 2.3.3: Create AuditLog Resource

**Task:** Define AuditLog resource to track sensitive changes (RBAC, financial, platform overrides)  
**Objective:** Provide immutable, queryable audit trail for all high-privilege operations  
**Output:**  
- `lib/voelgoedevents/ash/resources/audit/audit_log.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_audit_logs.exs`  

**Note:**  
- Attributes: `id`, `organization_id`, `actor_id`, `actor_type` (`:user`, `:system`), `action`, `resource_type`, `resource_id`, `origin`, `changes` (JSONB), `inserted_at`
- Origin examples: `:user` (normal user action), `:platform_support` (platform staff with tenant consent), `:super_admin_override` (super admin override), `:system` (background job)
- Policies:
  - Read: `:owner` and `:admin` within the same `organization_id` (read-only access to audit trails)
  - Write: Only via system actions, extensions, and Ash resource policies (never direct user writes)
- Immutable: No update or destroy actions allowed
- Align with `/docs/domain/rbac_and_platform_access.md` Phase 2 deliverables

---

## Phase 2.4: Multi-Tenancy Policies

### Sub-Phase 2.4.1: Create Shared Tenancy Policies

**Task:** Implement reusable policy checks  
**Objective:** Enforce organization scoping on all resources  
**Output:** `lib/voelgoedevents/ash/policies/tenant_policies.ex`  

**Note:**  
- All persistent resources MUST include `organization_id`
- All queries MUST filter by `organization_id` from actor context
- Reference `/docs/architecture/02_multi_tenancy.md`
- Enforce rules from Appendix B (6 Critical Rules)

---

## Phase 2.5: Session & Auth Flow

### Sub-Phase 2.5.1: Create CurrentUserPlug

**Task:** Implement plug to load full actor context from session/JWT  
**Objective:** Populate actor context with all 6 required fields for Ash policies  
**Output:** `lib/voelgoedevents_web/plugs/current_user_plug.ex`  

**Note:**  
- Extract `user_id` from session
- Load `User` with `memberships` preloaded
- Determine active membership for current organization
- **Populate full actor context** (used by Ash policies) with:
  - `user_id` (from session, never from request params)
  - `organization_id` (from active membership, never from request params)
  - `role` (from Membership.role)
  - `is_platform_staff` (from User.is_platform_staff)
  - `is_platform_admin` (from User.is_platform_admin)
  - `type` (always `:user` for web requests)
- Set `conn.assigns.current_user` to this full actor context
- Also set `conn.assigns.organization_id` for backward compatibility
- **Never trust `organization_id` from request params** (Appendix B, Rule 1, and `/docs/domain/rbac_and_platform_access.md`)
- Use membership cache (ETS/Redis) to speed up lookups per Sub-Phase 2.3.2

---

## Phase 2 Alignment with RBAC Docs

All resources in Phase 2 are defined in:
- **Role & Permission Mappings:** `/docs/domain/rbac_and_platform_access.md` §4–§5
- **Actor Shape & Types:** `/docs/domain/rbac_and_platform_access.md` §3 and `/docs/ash/ASH_3_RBAC_MATRIX.md`
- **Multi-Tenant Policy Rules:** `/docs/domain/rbac_and_platform_access.md` §12.9

Ensure Phase 2 implementation aligns with these canonical docs for:
- Actor shape consistency (6 fields, exact role list)
- Platform flag semantics (is_platform_staff, is_platform_admin)
- Membership caching layer (ETS hot + Redis warm)
- AuditLog immutability and origin tracking

### Authentication Rate Limiting (Implemented)

Phase 2 includes request-level authentication rate limiting to protect
login and password reset endpoints from brute-force attacks.

Implemented characteristics:

- Rate limiting is scoped to:
  - IP
  - Email
  - Email + IP combination
- Keys are explicitly namespaced:
  - vge:rl:auth:login:*
  - vge:rl:auth:reset:*
- Login rate limits apply ONLY to:
  - POST /auth/user/password/sign_in
- Invalid routes (e.g. POST /auth/log_in) do NOT burn rate limits
- Limits are configurable via application config:
  - Defaults for production
  - Lowered thresholds in test for deterministic regression testing
- All rate-limit behavior is enforced before Ash authentication actions

This behavior is protected by regression tests:
- test/voelgoedevents_web/rate_limit_login_regression_test.exs
