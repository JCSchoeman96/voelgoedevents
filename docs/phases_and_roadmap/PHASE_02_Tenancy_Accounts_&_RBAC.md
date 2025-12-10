## 👥 PHASE 2: Tenancy, Accounts & RBAC

**Goal:** Multi-tenant foundation with user authentication and role-based access control  
**Duration:** 2 weeks  
**Deliverables:** Organization, User, Membership, Role resources; AshAuthentication integration  
**Dependencies:** Completes Phase 1

---

### Phase 2.1: Organization Resource

#### Sub-Phase 2.1.1: Create Organization Resource

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

### Phase 2.2: User Resource

#### Sub-Phase 2.2.1: Create User Resource with AshAuthentication

**Task:** Define User resource with email, hashed_password, integration with AshAuthentication  
**Objective:** Enable user login, session management, and JWT generation  
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

---

### Phase 2.3: Membership & Role Resources

#### Sub-Phase 2.3.1: Create Role Resource

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

#### Sub-Phase 2.3.2: Create Membership Resource

**Task:** Define Membership (join table) linking User, Organization, Role  
**Objective:** Enforce per-organization RBAC  
**Output:**  
- `lib/voelgoedevents/ash/resources/accounts/membership.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_memberships.exs`  
**Note:**  
- Unique constraint: `(user_id, organization_id)` — one role per org
- Cache in ETS for fast RBAC checks (reference Appendix C)
- Attributes: `id`, `user_id`, `organization_id`, `role_id`, `status` (`:active`, `:inactive`), `invited_at`, `joined_at`
- Relationships: `belongs_to :user`, `belongs_to :organization`, `belongs_to :role`
- Policies: Organization owners can invite/remove members

---

### Phase 2.4: Multi-Tenancy Policies

#### Sub-Phase 2.4.1: Create Shared Tenancy Policies

**Task:** Implement reusable policy checks  
**Objective:** Enforce organization scoping on all resources  
**Output:** `lib/voelgoedevents/ash/policies/tenant_policies.ex`  
**Note:**  
- All persistent resources MUST include `organization_id`
- All queries MUST filter by `organization_id` from actor context
- Reference `/docs/architecture/02_multi_tenancy.md`
- Enforce rules from Appendix B (6 Critical Rules)

---

### Phase 2.5: Session & Auth Flow

#### Sub-Phase 2.5.1: Create CurrentUserPlug

**Task:** Implement plug to load current user from session/JWT  
**Objective:** Populate `conn.assigns.current_user` and `conn.assigns.organization_id` for all authenticated requests  
**Output:** `lib/voelgoedevents_web/plugs/current_user_plug.ex`  
**Note:**  
- Extract `user_id` from session
- Load `User` with `memberships` preloaded
- Set `conn.assigns.organization_id` from active membership
- **Never trust `organization_id` from request params** (Appendix B, Rule 1)

---