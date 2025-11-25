**VoelgoedEvents Domain Map**
=========================================================

_A complete domain architecture reference for the VoelgoedEvents PETAL/Ash platform._

**Table of Contents**
=====================

1.  Introduction
2.  Domain Structure Overview
3.  Tenancy & Accounts
4.  Events & Venues
5.  Seating
6.  Ticketing & Pricing
7.  Payments & Ledger
8.  Scanning & Devices
9.  Analytics, Funnels & Marketing
10.  Integrations & Webhooks
11.  Reporting
12.  Notifications & Delivery
13.  Audit Logging
14.  Public API & Access Keys
15.  Ephemeral Domains (Non-Persistent)
16.  Global Invariants

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

The VoelgoedEvents platform is organized into **12 persistent domains** and **one shared ephemeral domain**.

**Persistent Domains (Ash Resources)**
--------------------------------------

1.  **Tenancy & Accounts**
    
2.  **Events & Venues**
    
3.  **Seating**
    
4.  **Ticketing & Pricing**
    
5.  **Payments & Ledger**
    
6.  **Scanning & Devices**
    
7.  **Analytics, Funnels & Marketing**
    
8.  **Integrations & Webhooks**
    
9.  **Reporting**
    
10.  **Notifications & Delivery**
    
11.  **Audit Logging**
    
12.  **Public API & Access Keys**
    

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
    

**2\. Events & Venues**
=======================

**2.1 Venue**
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
    

**2.2 VenueSection / Zone**
---------------------------

Used for navigation, reporting, scanning dashboards.

**Fields**

*   venue\_id
    
*   name
    
*   code
    

**2.3 Gate**
------------

Entry control.

**Fields**

*   venue\_id
    
*   name
    
*   code
    
*   settings JSONB
    

**2.4 Event**
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
    

**2.5 EventSeries (Future)**
----------------------------

Multi-day linked events.

**3\. Seating**
===============

Designed using hierarchical graph architecture.

**3.1 Layout**
--------------

Versioned seating layouts.

**Fields**

*   event\_id
    
*   name
    
*   version
    
*   status
    
*   metadata (canvas/grid/etc.)
    

**3.2 Section**
---------------

Logical top-level grouping in a layout.

**3.3 Block**
-------------

Seating area within a section.

**Fields**

*   layout\_id
    
*   name
    
*   code
    
*   display\_order
    
*   settings JSONB
    

**3.4 Seat**
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
    

**3.5 StandingArea**
--------------------

For GA standing zones.

**3.6 NonSeatingElement**
-------------------------

Obstacles, stage, pillars, mixers, etc.

**4\. Ticketing & Pricing**
===========================

**4.1 Ticket**
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
    

**4.2 PricingRule**
-------------------

Defines pricing logic.

**Fields**

*   event\_id
    
*   scope
    
*   rule\_type
    
*   value
    
*   active\_from / until
    
*   conditions JSONB
    

**4.3 TicketGroup**
-------------------

Bundle/pack of tickets.

**4.4 Coupon**
--------------

Promo codes.

**4.5 TicketTransfer (Future)**
-------------------------------

Transfer one ticket to another user.

**4.6 Add-On (Future)**
-----------------------

Merch or perks.

**5\. Payments & Ledger**
=========================

**5.1 Transaction**
-------------------

Represents a checkout attempt.

**Fields**

*   status:initiated | pending | succeeded | failed
    
*   amount
    
*   provider
    
*   metadata JSONB
    

**5.2 Refund**
--------------

Refund action referencing transaction or ticket set.

**5.3 LedgerAccount**
---------------------

Double-entry account.

**5.4 JournalEntry**
--------------------

Debits/credits per event.

**5.5 Payout**
--------------

Settlement to organizer.

**Fields**

*   organization\_id
    
*   amount
    
*   status
    
*   payout\_reference
    

**5.6 PaymentMethod**
---------------------

Store minimal provider tokens (PCI-light).

**6\. Scanning & Devices**
==========================

**6.1 Scan**
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
    

**6.2 ScanSession**
-------------------

Grouping of scans per device/gate.

**6.3 Device**
--------------

Represents scanner device identity.

**6.4 GateAssignment**
----------------------

Assign devices to gates.

**6.5 InOutEvent**
------------------

Direct tracking of enter/exit actions.

**6.6 ScanRateStats**
---------------------

Real-time performance metrics.

**7\. Analytics, Funnels & Marketing**
======================================

**7.1 AnalyticsEvent**
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
    

**7.2 FunnelSnapshot**
----------------------

Precomputed analytics.

**7.3 MarketingAttribution**
----------------------------

Stores UTM/referrer info.

**7.4 Campaign**
----------------

Marketing campaigns.

**7.5 VisitSession**
--------------------

Tracking anonymous → identified user flow.

**7.6 EmailEvent**
------------------

Open/click tracking.

**8\. Integrations & Webhooks**
===============================

**8.1 WebhookEndpoint**
-----------------------

User-configured outbound webhooks.

**8.2 WebhookEvent**
--------------------

Payload to be delivered.

**8.3 WebhookDeliveryLog**
--------------------------

Store attempts & retries.

**8.4 IntegrationProvider**
---------------------------

External systems like:

*   Stripe
    
*   PayFast
    
*   Mailgun
    
*   SendGrid
    

**9\. Reporting**
=================

**9.1 EventReport**
-------------------

Tickets sold / revenue / attendance.

**9.2 FinancialReport**
-----------------------

Ledger-based summaries.

**9.3 GateReport**
------------------

Gate performance.

**9.4 RefundReport**
--------------------

Summary of refunds.

**10\. Notifications & Delivery**
=================================

**10.1 Notification**
---------------------

Represents a user/org notification.

**10.2 DeliveryAttempt**
------------------------

Email/SMS/Webhook delivery.

**10.3 Template**
-----------------

Reusable templates for email/PDF.

**10.4 TicketDelivery**
-----------------------

Email/PDF ticket issuing.

**11\. Audit Logging**
======================

Required for security & seating builder.

**11.1 AuditLog**
-----------------

Record any user/system action.

**11.2 ChangeSetLog**
---------------------

Per-resource diffs.

**11.3 UserActionLog**
----------------------

High-level actions.

**12\. Public API & Access Keys**
=================================

**12.1 ApiKey**
---------------

Programmatic access key.

**12.2 ApiRequestLog**
----------------------

Audit for API usage.

**12.3 RateLimitRule**
----------------------

Per API key rate control.

**13\. Ephemeral Domains (Non-Persistent)**
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

**14\. Global Invariants**
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