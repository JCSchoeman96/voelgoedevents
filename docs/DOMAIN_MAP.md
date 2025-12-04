**VoelgoedEvents Domain Map**
=========================================================

_A complete domain architecture reference for the VoelgoedEvents PETAL/Ash platform._

**Table of Contents**
=====================

*   Introduction
*   Domain Structure Overview
1.  Tenancy & Accounts
2.  Access Control
3.  Events & Venues
4.  Seating
5.  Ticketing & Pricing
6.  Payments & Ledger
7.  Finance
8.  Monetization
9.  Scanning & Devices
10. Analytics, Funnels & Marketing
11. Integrations & Webhooks (Roadmap)
12. Reporting (Roadmap)
13. Notifications & Delivery (Roadmap)
14. Audit Logging
15. Public API & Access Keys (Roadmap)
16. Ephemeral Domains (Non-Persistent)
17. Global Invariants

**Introduction**
================

This domain map defines the **official, authoritative domain architecture** for the VoelgoedEvents platform.It describes:

*   Persistent Ash Resources
*   Domain boundaries
*   Invariants
*   Supporting ephemeral systems
*   Cross-domain relationships
*   Future-facing extensions

It is designed to support:

*   Multi-tenant SaaS
*   Real-time scanning
*   Complex seating
*   High-performance ticketing
*   Financial correctness
*   Strong type-safety

**Domain Structure Overview**
=============================

The VoelgoedEvents platform is organized into **implemented Ash domains**, **roadmap domains**, and **one shared ephemeral domain**.

**Implemented Ash Domains**
---------------------------

1.  **Tenancy & Accounts**

2.  **Access Control**

3.  **Events & Venues**

4.  **Seating**

5.  **Ticketing & Pricing**

6.  **Payments & Ledger**

7.  **Finance**

8.  **Monetization**

9.  **Scanning & Devices**

10. **Analytics, Funnels & Marketing**

11. **Audit Logging**


**Roadmap Domains (Not Yet Implemented in Ash)**
------------------------------------------------

12. **Integrations & Webhooks**

13. **Reporting**

14. **Notifications & Delivery**

15. **Public API & Access Keys** (beyond existing API key resource)


**Ephemeral Domains (Non-Persistent)**
--------------------------------------

1.  **Caching, Holds, Realtime State, Workflows**
    

**1\. Tenancy & Accounts**
==========================

**1.1 Organization (Tenant)**
-----------------------------

**Resource:** organizations/organization.exRepresents a tenant using the system.

**Key fields**

*   id
    
*   name
    
*   slug (unique)
    
*   status: active | suspended | closed
    
*   plan: enum
    
*   settings: JSONB
    
*   timestamps
    

**Relationships**

*   has\_many memberships
    
*   has\_many venues
    
*   has\_many events
    
*   has\_many ledger\_accounts
    
*   has\_many payout\_settings
    

**Invariants**

*   slug unique globally
    
*   org status gates all event/ticketing operations
    

**1.2 User**
------------

Global identity.

**Fields**

*   id
    
*   email (unique)
    
*   hashed\_password
    
*   name
    
*   status
    
*   last\_login\_at
    

**Relationships**

*   has\_many memberships
    
*   has\_many audit\_logs
    

**1.3 Role**
------------

Defines role names per org.

**Examples**

*   owner
    
*   admin
    
*   staff
    
*   viewer
    
*   scanner\_only
    

**1.4 Membership**
------------------

Links users to organizations.

**Invariants**

*   Unique (user\_id, organization\_id)
    
*   At least one owner per organization
    

**2\. Access Control**
======================

Machine-to-machine credentials that grant scoped access to tenant resources.

**2.1 ApiKey**
--------------

Represents a tenant-scoped API key for integrations and automation.

**Fields**

*   id

*   name (human-friendly label)

*   key_hash (hashed secret, never stored in plaintext)

*   organization_id

*   permissions (array of scoped abilities)

*   inserted_at / updated_at

**Relationships**

*   belongs_to organization

**Invariants**

*   Key material is only stored as a hash; secrets are shown once on creation.

*   All keys are organization-scoped and must not be reused across tenants.


**3\. Events & Venues**
=======================

**3.1 Venue**
-------------

Physical location of events.

**Key fields**

*   organization\_id
    
*   name
    
*   address fields
    
*   capacity
    
*   timezone
    
*   settings JSONB
    

**Relationships**

*   has\_many events
    
*   has\_many gates
    
*   has\_many venue\_sections
    

**3.2 VenueSection / Zone**
---------------------------

Used for navigation, reporting, scanning dashboards.

**Fields**

*   venue\_id
    
*   name
    
*   code
    

**3.3 Gate**
------------

Entry control.

**Fields**

*   venue\_id
    
*   name
    
*   code
    
*   settings JSONB
    

**3.4 Event**
-------------

Represents an individual event instance.

**Fields**

*   organization\_id
    
*   venue\_id
    
*   name
    
*   slug
    
*   description
    
*   start\_at, end\_at
    
*   status
    
*   max\_capacity
    
*   settings JSONB
    

**Relationships**

*   has\_many tickets
    
*   has\_many pricing\_rules
    
*   has\_many coupons
    
*   has\_many layouts
    
*   has\_many occupancy\_snapshots
    
*   has\_many scan\_sessions
    

**3.5 EventSeries (Future)**
----------------------------

Multi-day linked events.

**4\. Seating**
===============

Designed using hierarchical graph architecture.

**4.1 Layout**
--------------

Versioned seating layouts.

**Fields**

*   event\_id
    
*   name
    
*   version
    
*   status
    
*   metadata (canvas/grid/etc.)
    

**4.2 Section**
---------------

Logical top-level grouping in a layout.

**4.3 Block**
-------------

Seating area within a section.

**Fields**

*   layout\_id
    
*   name
    
*   code
    
*   display\_order
    
*   settings JSONB
    

**4.4 Seat**
------------

Individual seat.

**Fields**

*   block\_id
    
*   label
    
*   row\_label
    
*   section\_label
    
*   position\_x, position\_y
    
*   status
    
*   base\_price\_cents
    

**4.5 StandingArea**
--------------------

For GA standing zones.

**4.6 NonSeatingElement**
-------------------------

Obstacles, stage, pillars, mixers, etc.

**5\. Ticketing & Pricing**
===========================

**5.1 Ticket**
--------------

Represents a single purchased ticket.

**Fields**

*   event\_id
    
*   seat\_id (nullable)
    
*   public\_id
    
*   secure\_token
    
*   ticket\_type
    
*   status:reserved | sold | refunded | canceled | voided | transferred | expired
    
*   price\_cents
    
*   currency
    
*   metadata
    

**5.2 PricingRule**
-------------------

Defines pricing logic.

**Fields**

*   event\_id
    
*   scope
    
*   rule\_type
    
*   value
    
*   active\_from / until
    
*   conditions JSONB
    

**5.3 TicketGroup**
-------------------

Bundle/pack of tickets.

**5.4 Coupon**
--------------

Promo codes.

**5.5 TicketTransfer (Future)**
-------------------------------

Transfer one ticket to another user.

**5.6 Add-On (Future)**
-----------------------

Merch or perks.

**6\. Payments & Ledger**
=========================

**6.1 Transaction**
-------------------

Represents a checkout attempt.

**Fields**

*   status:initiated | pending | succeeded | failed
    
*   amount
    
*   provider
    
*   metadata JSONB
    

**6.2 Refund**
--------------

Refund action referencing transaction or ticket set.

**6.3 LedgerAccount**
---------------------

Double-entry account.

**6.4 JournalEntry**
--------------------

Debits/credits per event.

**6.5 Payout**
--------------

Settlement to organizer.

**Fields**

*   organization\_id
    
*   amount
    
*   status
    
*   payout\_reference
    

**6.6 PaymentMethod**
---------------------

Store minimal provider tokens (PCI-light).

**7\. Finance**
===============

Double-entry bookkeeping container for balanced journal lines shared with the payments domain.

**7.1 Ledger**
--------------

Top-level ledger container for a tenant.

**Fields**

*   id

*   organization_id

*   name (e.g., "Main Operational Ledger")

*   currency (default :ZAR)

*   active (boolean)

*   inserted_at / updated_at

**Relationships**

*   belongs_to organization

**Invariants**

*   Ledgers are tenant-scoped; journal entries must balance per ledger and currency.


**8\. Monetization**
====================

Configuration for platform and organizer fees plus optional donations applied during checkout.

**8.1 FeeModel**
---------------

Defines a reusable fee structure (e.g., platform + organizer split).

**8.2 FeePolicy**
-----------------

Concrete fee rules bound to a fee model (rates, caps, who pays).

**8.3 Donation**
----------------

Tracks optional donations collected alongside ticket purchases.

**Invariants**

*   All monetization resources are organization-scoped.


**9\. Scanning & Devices**
==========================

**9.1 Scan**
------------

Each scan attempt.

**Fields**

*   ticket\_id
    
*   gate\_id
    
*   scan\_session\_id
    
*   direction: in | out
    
*   result
    
*   scanned\_at
    
*   metadata JSONB
    

**9.2 ScanSession**
-------------------

Grouping of scans per device/gate.

**9.3 Device**
--------------

Represents scanner device identity.

**9.4 GateAssignment**
----------------------

Assign devices to gates.

**9.5 InOutEvent**
------------------

Direct tracking of enter/exit actions.

**9.6 ScanRateStats**
---------------------

Real-time performance metrics.

**10. Analytics, Funnels & Marketing**
======================================

**10.1 AnalyticsEvent**
----------------------

Raw activity stream.

**Events include**

*   page\_view
    
*   scroll\_depth
    
*   add\_to\_cart
    
*   view\_cart
    
*   start\_checkout
    
*   checkout\_success
    
*   scan\_success
    

**10.2 FunnelSnapshot**
----------------------

Precomputed analytics.

**10.3 MarketingAttribution**
----------------------------

Stores UTM/referrer info.

**10.4 Campaign**
----------------

Marketing campaigns.

**10.5 VisitSession**
--------------------

Tracking anonymous → identified user flow.

**10.6 EmailEvent**
------------------

Open/click tracking.

**11. Integrations & Webhooks**
===============================

_Roadmap: domain not yet implemented in Ash; retained for future PSP/CRM connectors and webhook handling._

**11.1 WebhookEndpoint**
-----------------------

User-configured outbound webhooks.

**11.2 WebhookEvent**
--------------------

Payload to be delivered.

**11.3 WebhookDeliveryLog**
--------------------------

Store attempts & retries.

**11.4 IntegrationProvider**
---------------------------

External systems like:

*   Stripe
    
*   PayFast
    
*   Mailgun
    
*   SendGrid
    

**12. Reporting**
=================

_Roadmap: heavy read models and exports are not yet modeled in Ash; this section captures intended reporting scope._

**12.1 EventReport**
-------------------

Tickets sold / revenue / attendance.

**12.2 FinancialReport**
-----------------------

Ledger-based summaries.

**12.3 GateReport**
------------------

Gate performance.

**12.4 RefundReport**
--------------------

Summary of refunds.

**13. Notifications & Delivery**
=================================

_Roadmap: notification channels and delivery pipelines are not yet implemented; template/delivery resources remain planned._

**13.1 Notification**
---------------------

Represents a user/org notification.

**13.2 DeliveryAttempt**
------------------------

Email/SMS/Webhook delivery.

**13.3 Template**
-----------------

Reusable templates for email/PDF.

**13.4 TicketDelivery**
-----------------------

Email/PDF ticket issuing.

**14. Audit Logging**
======================

Required for security & seating builder.

**14.1 AuditLog**
-----------------

Record any user/system action.

**14.2 ChangeSetLog**
---------------------

Per-resource diffs.

**14.3 UserActionLog**
----------------------

High-level actions.

**15. Public API & Access Keys**
=================================

_Roadmap: Public REST surface is not yet built; this section tracks intended API-facing resources beyond current API key support and clarifies reuse of the Access Control ApiKey resource._

**15.1 ApiKey (shared)**
------------------------

Programmatic access key authenticated and owned by the Access Control domain; no duplicate resource is created here.

**15.2 ApiRequestLog**
----------------------

Audit for API usage.

**15.3 RateLimitRule**
----------------------

Per API key rate control.

**16. Ephemeral Domains (Non-Persistent)**
===========================================

Includes:

*   **SeatAvailabilityCache**
    
*   **PricingCache**
    
*   **OccupancyCache**
    
*   **RateLimiter**
    
*   **SeatHoldRegistry**
    
*   **Workflow Contracts**
    
*   **DTOs** (request/response)
    
*   **OpenAPI / JSON Schemas**
    
*   **Realtime Presence (Phoenix PubSub)**
    

These do **not** write to the DB; they accelerate workflows.

**17. Global Invariants**
==========================

1.  **Multi-tenant boundaries**
    
    *   Every record must have organization\_id (except global ones).
        
2.  **Financial correctness**
    
    *   All journal entries must balance.
        
    *   No partial ledger writes.
        
3.  **Ticket integrity**
    
    *   No double-selling.
        
    *   No conflicting seat assignments.
        
4.  **Scanning safety**
    
    *   A ticket cannot be scanned for the wrong event.
        
    *   Re-scans must be idempotent and recorded.
        
5.  **Analytics truth**
    
    *   DB state is the source of truth.
        
    *   GA is optional and downstream.
        
6.  **Cache is not authority**
    
    *   Redis/ETS performance layer only.