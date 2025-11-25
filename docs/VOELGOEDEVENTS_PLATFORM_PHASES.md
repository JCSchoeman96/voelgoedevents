VoelgoedEvents – Full Comprehensive Phase Plan
==============================================

This roadmap defines **the optimal, scalable, vertical-slice-first path** for building the VoelgoedEvents platform using **Ash + Phoenix (PETAL)**.

It is designed to:

*   Protect the MVP from scope creep
    
*   Build a strong, extensible domain base
    
*   Support GA ticketing early
    
*   Integrate your existing scanner app
    
*   Layer on seating, dashboards, integrations, and enterprise features
    

PHASE 0 — Vision, Domain & Guardrails
=====================================

### **Description**

Define _exactly_ what VoelgoedEvents is and what it is not, to prevent chaos later.

### **0.1 Product Vision & Target Segment**

Define:

*   Target user: SA organisers, agencies, venue operators
    
*   Positioning: reliable GA + seated ticketing + offline scanning
    
*   Differentiators: speed, reliability, multi-tenant, seat map strength
    

### **0.2 Core Domain Glossary**

Create /docs/domain/DOMAIN\_MAP.md with:

*   Tenant
    
*   User
    
*   Membership / Role
    
*   Venue
    
*   Event
    
*   TicketType
    
*   Ticket
    
*   Order
    
*   Payment / Refund
    
*   Scan / Device
    
*   SeatingPlan / Section / Row / Seat
    
*   Webhook / Integration records
    

### **0.3 MVP / Non-Goals**

Define:

**MVP includes:**

*   GA events
    
*   Checkout + payments
    
*   Issued QR tickets
    
*   Online + Offline scanning
    
*   Basic organiser dashboards
    

**MVP excludes:**

*   Multi-currency finance
    
*   Advanced seating builder
    
*   Full ERP-grade accounting
    
*   Heavy CMS
    
*   Full organiser mobile app
    

PHASE 1 — Technical Foundation (Ash + Phoenix + Tooling)
========================================================

### **Description**

Set up a clean, disciplined, extensible codebase.

### **1.1 Project Scaffolding**

*   Phoenix + LiveView
    
*   Tailwind
    
*   Ash Framework
    
*   AshPostgres
    
*   AshPhoenix
    
*   AshAuthentication (installed, not fully configured yet)
    

### **1.2 Folder & Domain Layout**

*   lib/voelgoed/ash/domains/\*
    
*   lib/voelgoed/ash/resources/\*
    
*   Empty domain stubs:
    
    *   Accounts, Tenancy, Events,
        
    *   Ticketing, Payments, Scanning,
        
    *   Seating, Analytics, Integrations
        

Create doc: /docs/architecture/01\_foundation.md

### **1.3 Tooling & CI**

*   Add Credo
    
*   Add Dialyzer
    
*   Add test coverage
    
*   Add mix check
    
*   GitHub Actions for CI
    

PHASE 2 — Tenancy, Accounts & RBAC (Ash-First)
==============================================

### **Description**

Establish multi-tenant, secure, RBAC-driven foundation for the rest of the system.

### **2.1 User Auth & Accounts**

*   User resource
    
*   Email, hashed\_password, profile
    
*   Phoenix session auth (AshAuthentication)
    

### **2.2 Tenant Model & Flags**

*   Tenant resource: name, slug, plan, flags
    
*   Document row-based multi-tenancy
    
*   Add TenantFeature if needed
    

### **2.3 Memberships & Roles**

*   UserTenant linking users to tenants
    
*   Roles: owner | admin | staff | viewer | scanner\_only
    
*   Role-based policies in Ash
    

### **2.4 Tenant-Aware Sessions**

*   URL: /t/:tenant\_slug/...
    
*   Plugs to load current\_tenant, current\_user\_membership
    
*   Tenant switcher UI
    

### **2.5 RBAC Guards**

*   Centralised policies or helpers such as:
    
    *   can\_manage\_events?
        
    *   can\_view\_financials?
        
    *   can\_manage\_scanners?
        

PHASE 3 — Core Events & GA Ticketing
====================================

### **Description**

Model events, ticket types, and organiser/admin UI.This creates the **platform backbone**.

### **3.1 Venue & Event Resources**

*   Venue (capacity, timezone)
    
*   Event (slug, schedule, capacity, status)
    

### **3.2 GA Ticket Types**

*   TicketType resource
    
*   GA: inventory-based
    
*   Soft/hard capacity checks
    
*   Sales window
    
*   Active/inactive states
    

### **3.3 Public Event Flow (Stub Checkout)**

*   /e/:event\_slug page
    
*   User chooses ticket quantity
    
*   Create unpaid Order stub
    

### **3.4 Organiser Event Management**

LiveView pages for:

*   List events
    
*   Create/edit events
    
*   CRUD venues
    
*   Only accessible by admin/staff
    

PHASE 4 — Orders, Payments & Ticket Issuance (MVP)
==================================================

### **Description**

Enable real transactions, real orders, real QR tickets.This completes the MVP sales loop.

### **4.1 Order & Ticket Resources**

*   Order: pending → paid → canceled/expired
    
*   Ticket: issued → revoked/refunded
    
*   Add identity fields:
    
    *   public\_id
        
    *   secure\_token (or signed blob)
        

### **4.2 Payment Abstraction**

*   Payment provider behavior
    
*   First adapter: Stripe/Yoco/PayFast
    
*   Actions:
    
    *   begin\_checkout
        
    *   verify\_webhook
        
    *   mark\_paid / mark\_failed
        

### **4.3 QR Payload Design**

Document in:/docs/architecture/04\_ticket\_identity.md

*   Versioned QR format
    
*   Public URL + token OR signed payload
    
*   Durable, non-guessable
    

### **4.4 Ticket Issuance Workflow**

After payment:

*   Issue tickets
    
*   Generate QR
    
*   Save ticket identity
    
*   Mark order as paid
    
*   Notify user (email)
    

### **4.5 Ticket Email Delivery**

*   Swoosh
    
*   HTML + QR (image or link)
    
*   Background job via Oban
    

PHASE 5 — Scanning Backend (Integrate Existing Scanner)
=======================================================

### **Description**

Build backend scanning endpoints compatible with your current scanner.

### **5.1 Scanning Domain**

*   Scan resource
    
*   ScanDevice resource
    
*   Device-level permissions
    
*   Every scan is logged
    

### **5.2 Document Existing Scanner Contract**

Create:/docs/architecture/05\_scanner\_contract.md

Capture:

*   QR format
    
*   Required API endpoints
    
*   Response shapes
    
*   Offline/online expectations
    

### **5.3 Online Scan Endpoint**

POST /api/scan/validate:

*   Authenticate device
    
*   Decode QR
    
*   Validate ticket
    
*   Mark used if success
    
*   Return scanner-compatible response
    

### **5.4 Offline Sync Endpoint**

POST /api/scan/sync:

*   Batch upload
    
*   Process in timestamp order
    
*   Identify conflicts
    
*   Return per-scan results
    

### **5.5 Scan Monitoring UI**

*   Show recent scans
    
*   Check-in counts
    
*   Gate/device analytics
    

PHASE 6 — Organiser Admin & Dashboards
======================================

### **Description**

Provide a professional, multi-tenant organiser dashboard.

### **6.1 Admin Shell**

Navigation:

*   Events
    
*   Venues
    
*   Ticket Types
    
*   Orders
    
*   Scanning
    
*   Reports
    
*   Settings
    

Role-aware visibility.

### **6.2 Event Dashboards**

Real-time metrics:

*   Tickets sold
    
*   Revenue
    
*   Check-ins
    
*   Remaining capacity
    

Auto-refresh via LiveView.

### **6.3 Tenant-Wide Reporting**

*   Revenue summaries
    
*   Performance by event
    
*   Attendance/no-show rates
    
*   CSV export
    

### **6.4 Operational Workflows**

*   Refund order
    
*   Revoke ticket
    
*   Resend ticket email
    
*   Audit logging
    

PHASE 7 — Seating Engine (Domain Layer)
=======================================

### **Description**

Add seat-aware events _before_ building a fancy editor.

### **7.1 Seating Domain Resources**

*   SeatingPlan
    
*   SeatingSection
    
*   SeatingRow
    
*   SeatingSeat
    
*   Optional SeatGroup / Zone
    

### **7.2 Ticketing Integration**

Extend TicketType:

*   kind: :general\_admission | :assigned\_seating
    
*   For assigned seating:
    
    *   capacity = seats
        
    *   no manual numeric inventory
        

Extend Ticket:

*   seat\_id
    
*   seat\_label, row\_label, section\_label
    

### **7.3 Reservation & Issuing Logic**

*   Hold seats during checkout
    
*   Release seats if checkout expires
    
*   Lock seats when ticket issued
    
*   Strict concurrency checks
    

### **7.4 Seating Plan Locking Rules**

*   Draft → Published → Locked
    
*   Hard constraints once seats sold
    
*   Only safe edits allowed
    

PHASE 8 — Seating Builder (LiveView UI)
=======================================

### **Description**

A visual editor that strengthens VoelgoedEvents’ competitive position.

### **8.1 Backend Builder API**

Batch operations:

*   Create section/rows/seats
    
*   Auto-number seats
    
*   Update XY positions
    
*   Bulk delete/modify
    

### **8.2 Seating Builder LiveView**

Visual canvas:

*   Sections
    
*   Rows
    
*   Seats (clickable boxes)
    
*   Drag/zoom (lightweight)
    

Tools:

*   Add section/row
    
*   Bulk seat creation
    
*   Toggle seat status
    
*   Assign zones/ticket types
    

### **8.3 Customer Seat Selection**

Public seat map UI:

*   Color-coded zones
    
*   Seat hover/select
    
*   “Continue to checkout”
    

Caching hot seat availability.

### **8.4 Seating as Add-On**

Feature flag:

*   Tenants with :seating\_maps can create seating
    
*   Others only see GA UI
    

PHASE 9 — Integrations, Webhooks & Public API
=============================================

### **Description**

Enterprise features to plug into external tools.

### **9.1 Webhook Engine**

Resources:

*   WebhookEndpoint
    
*   WebhookEvent
    
*   DeliveryAttempt
    

Events:

*   order.paid
    
*   ticket.issued
    
*   ticket.scanned
    

Delivery:

*   Retry with backoff
    
*   Signing
    
*   Dead-letter queue
    

### **9.2 Public REST API**

*   Versioned endpoints: /api/v1/...
    
*   API keys per tenant
    
*   Read-first endpoints:
    
    *   Events
    *   Tickets
    *   Orders
    *   Scans

Rate limits + logs.

### **9.3 Optional Connectors**

*   Accounting export (API/CSV)
*   Marketing export (CRM sync)
*   Calendar/iCal feeds

PHASE 10 — Hardening: Security, Observability & Performance
===========================================================

### **Description**

Make VoelgoedEvents “production solid”.

### **10.1 Security & Auditing**

*   AuditLog resource:
    *   Role changes
    *   Refunds
    *   Manual overrides
    *   Seating plan changes
*   Strong Ash policies
*   Rate limiting on sensitive endpoints

### **10.2 Observability**

*   Telemetry events for:
    
    *   Orders
    *   Payments
    *   Ticket issuing
    *   Scans

Dashboards (e.g., Grafana).

### **10.3 Performance**

*   Index all hot paths
*   Preload and batch Ash queries
*   Caching for:
    *   Event pages
    *   Seating maps
    *   Dashboard counters

Load-test:

*   Ticket drops
*   Peak scanning

PHASE 11 — Mobile / Svelte Apps (Optional Future)
=================================================

### **Description**

Extend VoelgoedEvents into a mobile-first experience.

### **11.1 Scanner PWA Upgrade**

*   SvelteKit
*   Capacitor for camera APIs
*   Improved offline queue
*   Sync conflict UX

### **11.2 Organiser Mobile App**

*   Event dashboards
*   Quick scan & lookup
*   Ticket details
*   Push notifications (optional) 

### **11.3 Mobile Observability**

*   Crash/error tracking
*   Versioned API contract
*   Minimal analytics


End of Phase Plan
=================

This roadmap takes you from “blank repo” → “GA sales and scanning MVP” → “enterprise-ready, seated ticketing platform.”