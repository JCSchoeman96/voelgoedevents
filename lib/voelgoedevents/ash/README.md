# ASH Domain Root

**Purpose (Single Source of Truth - SOT):** This is the top-level Ash domain namespace. It houses all Ash resources, domains, calculations, changes, policies, and preparations.
**Constraint:** All business data validation, access control, and persistence logic MUST be defined here or referenced via extensions. This layer enforces the multi-tenancy and security invariants.
**Note:** Modules here define the 'what' (data model/rules); the 'how' (workflows, infrastructure) is handled by other folders.
