VoelgoedEvents
==============

**The Ultimate Multi-Tenant, Real-Time, PETAL-Based Events Platform**

🚀 Overview
-----------

VoelgoedEvents is a **full-stack, high-performance, multi-tenant events management platform**, designed for:

*   Event organizers
    
*   Ticketing companies
    
*   Venues and promoters
    
*   Scanning & entry operations
    
*   Integration partners
    

Built using the **PETAL stack** (Phoenix, Elixir, Tailwind, Ash, LiveView), the platform delivers:

*   Real-time seat maps
    
*   Flash-sale-safe ticketing
    
*   Multi-tenant isolation & RBAC
    
*   High-throughput scanning
    
*   Live dashboards
    
*   Seamless checkout & payments
    
*   Notifications & messaging
    
*   Reporting & analytics
    
*   Public API & integrations
    

This repository contains the **entire platform**, including source code, architecture documentation, and the rules used by human developers and AI coding agents.

🧠 Architecture Philosophy
--------------------------

VoelgoedEvents revolves around **five architectural pillars**, each enforced across the entire platform:

### **1\. PETAL Stack**

*   **Phoenix** → Delivery surface (HTTP, LiveView, WebSockets)
    
*   **Elixir/OTP** → Concurrency, distributed systems, fault tolerance
    
*   **TailwindCSS** → UI styling
    
*   **Ash Framework** → Domain modeling & business logic
    
*   **LiveView** → Real-time UI with minimal JS
    

### **2\. Vertical Slice Architecture**

Every feature is implemented as a **self-contained vertical slice**, including:

*   UI
    
*   Domain orchestration
    
*   Caching & persistence
    
*   Real-time handlers (PubSub)
    
*   Background jobs
    
*   Observability
    
*   Tests
    
*   Local documentation
    

No horizontal service layers.No coupling between slices.Slices can be built in isolation and deployed safely.

### **3\. Domain-Driven Design (Ash Domains)**

Business logic lives purely inside **Ash Resources, Domains, Actions, and Policies**, ensuring:

*   Invariants
    
*   Authorizations
    
*   Correctness
    
*   Testability
    
*   No business logic in LiveViews or controllers
    

### **4\. Multi-Layer Caching**

To support 100k+ concurrent users and flash-sale workloads:

*   **ETS** → Hot data (microsecond reads)
    
*   **Redis** → Warm ephemeral state (holds, bitmaps, counters)
    
*   **Postgres** → Cold durable storage (source of truth)
    

### **5\. Event-Driven System**

The platform is reactive:

*   **Domain Events** (Ash changes)
    
*   **PubSub Events** (LiveView updates)
    
*   **Redis Streams & Counters** (analytics, scanning)
    
*   **Workflow Events** (Oban jobs)
    

📚 Documentation Index (Start Here)
-----------------------------------

VoelgoedEvents includes a complete **documentation system** that guides architecture, development, AI agent behavior, and workflows.

### **1\. Platform-Level Docs**

*   /docs/platform\_overview.md
    
    *   High-level system explanation
        
*   /docs/project\_overview.md
    
    *   How to work with the repository
        

### **2\. Architecture Suite**

Defined under /docs/architecture/:

*   01\_foundation.md
    
*   02\_multi\_tenancy.md
    
*   03\_caching\_and\_realtime.md
    
*   04\_vertical\_slices.md
    
*   05\_eventing\_model.md
    
*   06\_jobs\_and\_async.md
    
*   07\_security\_and\_auth.md
    
*   08\_cicd\_and\_deployment.md
    
*   09\_scaling\_and\_resilience.md
    

**Start with:** /docs/architecture/README.md

### **3\. Domain Reference**

The **DOMAIN MAP** is your authoritative overview:

▶ **/docs/DOMAIN\_MAP.md** ← **Start here to understand every domain**

Each domain has a dedicated spec in /docs/domain/, including:

*   Tenancy & Accounts
    
*   Events & Venues
    
*   Seating
    
*   Ticketing & Pricing
    
*   Payments & Ledger
    
*   Scanning & Devices
    
*   Analytics
    
*   Notifications
    
*   Integrations & Webhooks
    
*   Reporting
    
*   Audit Logging
    
*   Public API
    
*   Ephemeral Real-Time State (Redis/ETS)
    

### **4\. Workflows**

In /docs/workflows/:

*   Checkout flow
    
*   Seating builder
    
*   Scanning (online/offline sync)
    
*   Refund flow
    
*   Notification flow
    
*   Webhook delivery
    
*   Event lifecycle
    
*   Reporting lifecycle
    

### **5\. AI Agent Rules**

All AI coding agents adhere to /docs/AGENTS.md. This document defines:

*   TOON prompt structure
    
*   Vertical slice rules
    
*   Architectural restrictions
    
*   Caching mandates
    
*   Domain purity
    
*   File path conventions
    
*   Safety rules
    
*   Planning vs. implementation phases
    

**Agents MUST load this file before generating code.**

🔥 Key Platform Features
------------------------

### **Event Management**

*   Event creation, scheduling, publishing
    
*   Team and roles per organization
    

### **Seating Plans**

*   Reserved seating + general admission
    
*   Interactive visual builder
    
*   Real-time availability
    

### **Ticketing**

*   Ticket types & price rules
    
*   Discount codes, bundles
    
*   Zero-oversell guarantees
    

### **Checkout & Payments**

*   End-to-end order workflow
    
*   PSP integrations
    
*   Refunds & reconciliation
    

### **Scanning**

*   Online + offline scanning
    
*   Fast duplicate detection
    
*   Gate analytics
    

### **Notifications**

*   Email, SMS, WhatsApp
    
*   Template system per organization
    
*   Rate limits
    

### **Analytics & Reporting**

*   Real-time event dashboards
    
*   Scheduled reports
    
*   CSV/PDF exports
    

### **Integrations**

*   Public REST API
    
*   Webhooks
    
*   PSP providers
    

🧱 Repository Structure
-----------------------

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   /lib    /voelgoedevents          → Domains, vertical slices, business logic    /voelgoedevents_web      → Phoenix & LiveView delivery  /config                    → App configuration  /priv                      → Migrations, seeds  /docs                      → Documentation system    /architecture            → Architecture specs    /domain                  → Domain definitions    /workflows               → Flow documentation    AGENTS.md                → AI agent rules    platform_overview.md    project_overview.md    DOMAIN_MAP.md  /test                      → Tests for domains & slices  /assets                    → JS, Tailwind, static assets   `

🛠 Requirements
---------------

*   Elixir & Erlang
    
*   Phoenix & LiveView
    
*   Ash Framework
    
*   Postgres
    
*   Redis
    
*   Oban
    
*   TailwindCSS
    
*   Node.js (for asset building)
    

⚙️ Getting Started
------------------

See: **/docs/project\_overview.md**

It covers:

*   Installation
    
*   Environment setup
    
*   Running Phoenix
    
*   Running Redis
    
*   Database migrations
    
*   Oban workers
    
*   Test strategy
    
*   Vertical slice workflow
    

🧪 Testing
----------

The system uses:

*   Domain tests
    
*   Slice integration tests
    
*   Performance tests
    
*   Real-time tests
    
*   Tenancy & security tests
    

Details in /docs/project\_overview.md.

🛡 Security & Compliance
------------------------

VoelgoedEvents enforces:

*   Multi-tenant isolation
    
*   RBAC per organization
    
*   Signed QR codes
    
*   Device authentication
    
*   Rate limiting
    
*   Audit logging
    
*   PII protection
    

See: /docs/architecture/07\_security\_and\_auth.md

📦 Deployment
-------------

Supports:

*   Zero-downtime releases
    
*   Blue/green & canary deployments
    
*   Kubernetes or bare-metal clusters
    
*   Automated migrations
    
*   Redis/Postgres clustering
    

See: /docs/architecture/08\_cicd\_and\_deployment.md

📈 Scaling & Performance
------------------------

Designed for:

*   100k+ concurrent users
    
*   Flash-sale traffic
    
*   Sub-100ms API latency
    
*   Sub-150ms real-time propagation
    
*   Zero overselling
    
*   High-throughput scanning
    

Performance model in: /docs/architecture/09\_scaling\_and\_resilience.md

🤝 Contributing
---------------

VoelgoedEvents uses:

*   Vertical slices
    
*   Domain-first development
    
*   TOON micro-prompts
    
*   Performance-aware design
    
*   Architecture guardrails enforced by docs
    

Start with: /docs/project\_overview.md

📄 License
----------

_(Add your license here)_

✨ Summary
---------

VoelgoedEvents is a **world-class event technology platform**, combining:

*   PETAL
    
*   Ash Domain Architecture
    
*   Multi-tenant isolation
    
*   Real-time UI
    
*   Event-driven workflows
    
*   High-performance caching
    
*   Vertical slices
    
*   Distributed systems engineering
    

This README is your **top-level entry point**.Start exploring /docs/ for deeper insights into how the platform is built.