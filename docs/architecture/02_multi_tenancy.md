Multi-Tenancy Architecture
==========================

Project: VoelgoedEvents Platform

Document: /docs/architecture/02\_multi\_tenancy.md

1\. Purpose of This Document
----------------------------

This document defines the complete multi-tenant architecture for the VoelgoedEvents platform.

It ensures:

*   Strict tenant isolation
    
*   Consistent organization scoping
    
*   Performance-safe multi-tenant lookups
    
*   Unified Redis/ETS/Postgres patterns
    
*   Correct domain boundaries
    
*   Secure authorization + API behavior
    
*   Predictable behavior under high concurrency (flash sales, scanning, dashboards)
    

This is the **source of truth** for all tenancy decisions across the system.

2\. Multi-Tenancy Model Overview
--------------------------------

The platform uses a **single-database, row-level, organization-scoped multi-tenant design**.

### 2.1 The “organization” as the tenant

Every record **must** reference:

Elixir

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   organization_id   `

This is the central tenant key across all **persistent domains**:

*   Tenancy
    
*   Events & Venues
    
*   Seating
    
*   Ticketing & Pricing
    
*   Payments & Ledger
    
*   Scanning & Devices
    
*   Analytics
    
*   Reporting
    
*   Notifications
    
*   Integrations
    
*   Audit Logging
    
*   Public API Keys
    

The **Ephemeral/Real-Time Domain** mirrors organization\_id in Redis and ETS.

3\. Tenant Isolation Rules (Mandatory)
--------------------------------------

The system enforces **hard isolation** between all organizations:

### 3.1 Hard Boundaries

*   No read across organizations
    
*   No writes across organizations
    
*   No joins between resources from different organizations
    
*   No multi-org queries (except reporting and system analytics, which use stable aggregates)
    
*   No cross-org access keys
    
*   No cross-org scan or ticket validation
    

### 3.2 Derived Identifiers

Everything must be scoped:

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   event_id always implies organization_id  venue_id always implies organization_id  seat_id always implies organization_id  ticket_id always implies organization_id  payment_attempt_id always implies organization_id   `

### 3.3 Controllers and LiveViews

Controllers + LiveViews may never infer tenant implicitly.

They must:

*   Load the organization via slug / domain
    
*   Assign the current org into session
    
*   All domain calls include explicit organization\_id
    

4\. Ash Domain Enforcement
--------------------------

Ash handles multi-tenancy through:

### 4.1 Resource attribute

Every Ash Resource includes:

Elixir

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   attribute :organization_id, :uuid, allow_nil?: false, public?: false   `

### 4.2 Automatic context

Each domain action receives:

Elixir

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   %{organization_id: ...}   `

### 4.3 Filters

Ash policies enforce:

Elixir

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   policy always do    authorize_if expr(organization_id == actor.organization_id)  end   `

### 4.4 Queries must include tenant filters

All read actions automatically include:

Elixir

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   filter organization_id == ^context.organization_id   `

### 4.5 Cross-domain protection

Domains may not call each other without passing explicit org context.

This prevents:

*   Ghost records
    
*   Cross-tenant leakage
    
*   Ambiguous workflows
    

5\. Multi-Tenant Performance Architecture
-----------------------------------------

Multi-tenancy influences all layers of the caching stack.

### 5.1 Hot Layer (ETS — per node)

Stored with namespaced keys:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   tenancy:membership:{user_id}:{org_id}  events:summary:{org_id}  pricing:effective:{org_id}:{ticket_type_id}   `

**Rules:**

*   ETS is node-local, not shared.
    
*   Rehydrated from Redis on node boot.
    
*   Never store data without {org\_id}.
    

### 5.2 Warm Layer (Redis — cluster)

Every key must include {org\_id}.

Redis key examples:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   events:list:org:{org_id}  ticketing:holds:event:{event_id}        // event_id belongs to org  api:rate:{org_id}:{key_id}:{period}  notifications:queue:{org_id}  analytics:event:{org_id}:{event_id}  audit:recent:{org_id}  reporting:queue:{org_id}   `

**Why?** To guarantee:

*   Key-level sharding
    
*   Key-level rate limits
    
*   Key-level eviction boundaries
    
*   Multi-org concurrency safety
    

### 5.3 Cold Layer (Postgres)

Postgres must always enforce:

*   Index on organization\_id
    
*   Composite indexes for tenant-critical access patterns:
    
    *   (organization\_id, event\_id)
        
    *   (organization\_id, slug)
        
    *   (organization\_id, inserted\_at)
        
    *   (organization\_id, status)
        

This is essential for:

*   Event lookups
    
*   Membership checks
    
*   Ticket searches
    
*   Payments queries
    
*   Reporting views
    

6\. Domain-Specific Tenancy Behavior
------------------------------------

### 6.1 Tenancy & Accounts

*   Organizations own all child records.
    
*   Users can belong to multiple organizations.
    
*   Membership determines permissions per organization.
    

### 6.2 Events & Venues

*   An event always belongs to a single organization.
    
*   A venue always belongs to a single organization.
    

### 6.3 Seating

*   Layouts are organization-scoped.
    
*   Seat IDs, zones, sections, etc. cannot cross organizations.
    

### 6.4 Ticketing & Pricing

*   Ticket types scoped by organization via event.
    
*   Inventory never crosses org boundaries.
    
*   Price rules MUST be org-scoped.
    

### 6.5 Payments & Ledger

*   Ledger entries are strictly org-scoped.
    
*   PSP configurations are per organization.
    
*   Refunds MUST match the same organization.
    

### 6.6 Scanning & Devices

*   Devices must be tied to org\_id.
    
*   No cross-org validation.
    
*   Offline sync data segregated by org.
    

### 6.7 Analytics

*   Event metrics grouped by organization.
    
*   Funnel events stored with org\_id always.
    

### 6.8 Reporting

*   All materialized views use (organization\_id, date) keys.
    
*   Scheduled reports run per org.
    

### 6.9 Notifications

*   Templates belong to organization.
    
*   Rate limits per org/channel.
    
*   Delivery providers are configured per org.
    

### 6.10 Audit Logging

*   Logs must only show entries from the current organization.
    
*   No global audit search.
    

### 6.11 Public API

*   API keys belong to organization.
    
*   Rate limits must be (org\_id + key\_id) scoped.
    

### 6.12 Ephemeral Domain

All ephemeral keys stored in Redis must be encoded with organization context:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   availability:{org_id}:{event_id}  holds:{org_id}:{event_id}  scan:{org_id}:{ticket_id}  rate_limit:{org_id}:{key_id}  queue:{org_id}   `

7\. Tenant Context In Web & API
-------------------------------

### 7.1 Determining Organization

In delivery layer:

1.  Extract org slug from URL
    
2.  Load organization (cached in Redis/ETS)
    
3.  Assign org into session / socket
    
4.  Pass into all domain calls
    

### 7.2 Example Pathing

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   /:org/events  /:org/events/:event_slug  /:org/api/v1/...   `

Friendly URLs must map to org slugs.

8\. Real-Time Tenancy
---------------------

PubSub channels must include org context:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   events:org:{org_id}  ticketing:org:{org_id}  analytics:org:{org_id}  scanning:org:{org_id}  notifications:org:{org_id}  api_keys:org:{org_id}  audit:org:{org_id}  reporting:org:{org_id}   `

**Rules:**

*   No global broadcasts
    
*   Every LiveView subscribes to exactly one organization
    
*   Super-admin dashboards are the **ONLY** allowed global listeners
    

9\. Tenant-Scoped Redis Naming Convention
-----------------------------------------

### General Rule

Every Redis key must be:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   ::org:{org_id}:entity:{id}   `

### Examples

**Ticketing**

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   ticketing:holds:org:{org_id}:event:{event_id}  ticketing:inventory:org:{org_id}:type:{ticket_type_id}   `

**Scanning**

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   scan:org:{org_id}:ticket:{ticket_id}  scan:org:{org_id}:gate:{gate_id}   `

**Analytics**

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   analytics:org:{org_id}:event:{event_id}:live   `

**Notifications**

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   notifications:queue:org:{org_id}  notifications:rate:org:{org_id}:{channel}   `

**This prevents:**

*   Key collisions
    
*   Cross-tenant state leakage
    
*   Shard imbalance in Redis clusters
    
*   Incorrect cache hydration
    

10\. Data Residency & Migration Strategy
----------------------------------------

### 10.1 Moving an organization between clusters

Not supported initially.

If supported later:

*   Tenancy requires partition-per-org extraction
    
*   All Redis + Postgres keys must migrate atomically
    
*   Domain events must rebuild ephemeral caches
    

### 10.2 Deleting an organization

Soft delete only:

*   Archive or mask PII
    
*   Retain ledger
    
*   Retain audit logs
    
*   Retain reporting history
    
*   Strict compliance rules apply.
    

11\. Testing Tenant Isolation
-----------------------------

Tests must validate:

*   \[ \] Fetching foreign-org data is rejected
    
*   \[ \] Cross-org LiveView access forbidden
    
*   \[ \] Redis keys do not mix org data
    
*   \[ \] API keys restricted correctly
    
*   \[ \] Scan validations reject cross-org tickets
    
*   \[ \] Materialized views are scoped
    
*   \[ \] All domain actions require org context
    
*   \[ \] Organizations cannot “bleed” through joins
    

12\. Summary
------------

The platform uses:

*   Single-database row-level multi-tenancy
    
*   Strict organization scoping
    
*   Domain-enforced isolation via Ash
    
*   Redis & ETS encoded with organization context
    
*   PubSub topics scoped per organization
    
*   Tenant-safe performance architecture
    
*   Zero-tolerance for cross-tenant leakage
    

This document defines all multi-tenant rules that downstream architecture, domain, workflow, and vertical slice docs must adhere to.