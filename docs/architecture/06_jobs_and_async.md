Jobs & Async Architecture
VoelgoedEvents Platform Document: /docs/architecture/06_jobs_and_async.md

1. Purpose of This Document
This document defines the asynchronous job and background processing architecture of the VoelgoedEvents platform.

It establishes:

How and when to use async jobs (Oban)

Queue naming and multi-tenant scoping rules

Interaction with Redis, ETS, and Postgres

Idempotency and exactly/at-least-once behavior

Backoff, retries, and dead-letter handling

How async workflows integrate into vertical slices

Observability requirements for jobs

Flash-sale and high-load safety guarantees

This is the source of truth for all background processing and async workflow design.

2. Why Async Jobs?
VoelgoedEvents must support:

Flash-sale level spikes

Heavy operations (report generation, exports)

PSP webhook handling and reconciliation

Notification delivery (email/SMS/WhatsApp)

Webhook retries

Offline scanning sync

Cache rebuilds and materialized view refreshes

These tasks cannot run in HTTP/LiveView request cycles without:

Breaking latency budgets

Overloading the system

Creating poor UX

Risking timeouts

Async jobs allow:

Controlled concurrency

Backpressure and throttling

Retry with backoff

Durable workflows

Isolation from UI spikes

3. Core Components
The async system uses:

Oban for durable job storage and execution

Redis for queues, dedupe keys, and lock tokens where needed

Postgres as the durable metadata store for jobs

ETS for hot job-related state (recent job results, idempotency buffers)

Telemetry for job-level observability

3.1 Oban
Primary job runner

Jobs persisted in Postgres

Supports queues, priorities, retries, backoff

3.2 Redis
Used for:

Additional queues (e.g. ephemeral pre-queues)

Deduplication keys (webhooks, notifications)

Distributed locks (rare, but allowed)

3.3 ETS
Caches recent job results

Stores local job execution metadata for quick access

4. When to Use an Async Job
You must use a job for:

Anything that might take > 100ms consistently under load

External network calls (PSP, email/SMS providers, external APIs)

Operations requiring retry behavior

High-frequency tasks that must be rate limited

Periodic tasks (cron-style)

Writes that are “eventually consistent” by design (e.g. analytics aggregation)

You must NOT use a job for:

The core transactional path of seat holds and ticket issuance (these must be synchronous & atomic)

Purely local calculations that complete in < 10ms

Pre-check logic that affects whether a user can proceed in the current request

5. Queue & Worker Design
5.1 Queue Naming & Multi-Tenancy
Queues must be semantic and support multi-tenancy.

Recommended queue naming:

payments

notifications

integrations

reporting

analytics

scanning

maintenance

Tenant scoping is per job payload, not per queue. Each job must include organization_id in its args.

5.2 Worker Modules
Each worker must:

Live in its slice or relevant domain subdirectory

Be idempotent

Validate tenant context

Handle retry and error logic

Emit telemetry events

Example naming:

VoelgoedEvents.Workers.Payments.ReconcileChargeWorker

VoelgoedEvents.Workers.Notifications.SendEmailWorker

VoelgoedEvents.Workers.Reporting.GenerateEventReportWorker

VoelgoedEvents.Workers.Ticketing.ReleaseExpiredHoldsWorker

6. Job Payload Rules
Job arguments must:

Include organization_id

Include primary IDs (e.g. event_id, ticket_order_id)

Never include sensitive secrets directly (tokens, card data)

Be small and serializable

Reference persisted data rather than embedding full entities

Correct pattern:

JSON

{
  "organization_id": "org_123",
  "event_id": "evt_abc",
  "ticket_order_id": "ord_456"
}
Incorrect pattern:

JSON

{
  "full_order_payload": { ... giant nested structure ... },
  "psp_secret": "raw-secret"
}
7. Idempotency & Retries
7.1 At-Least-Once Execution
Oban jobs adhere to at-least-once semantics. Workers must be idempotent.

Idempotency strategies:

Check existing records before insert/update

Use Redis dedupe key where needed

Use unique keys in Postgres (ON CONFLICT DO NOTHING)

Use ledger checks for financial transactions

7.2 Retry Policy
Default rules:

Use exponential backoff (e.g. 1s, 5s, 30s, 5m, 30m, 1h)

Cap max attempts (3–10 depending on importance)

Fatal errors → move to dead-letter queue

Domain-specific policies:

Payment reconciliation: higher retries, longer backoff

Notifications: moderate retries, backoff with jitter

Webhooks: higher retries with extended window

Analytics: low urgency, can be dropped if repeatedly failing

8. Dead Letter Queue (DLQ)
Jobs that repeatedly fail move into a DLQ.

Patterns:

DLQ flagged via job metadata/tag

DLQ monitored via dashboard

Manual or automated remediation tasks may re-enqueue DLQ jobs

DLQ usage examples:

Permanently failing webhooks due to misconfigured endpoints

Notifications where user contact detail is invalid

Misconfigured external integrations

9. Integrating Jobs with Vertical Slices
Each vertical slice must:

Define its job types

Provide worker modules

Document job flow in /docs/workflows/* or slice-local docs

Ensure tenant context is always present

Example: Checkout & Payment Finalization Slice

Jobs include:

CapturePaymentWorker

SendOrderConfirmationWorker

UpdateAnalyticsFunnelWorker

SyncTicketToIntegrationWorker

Flow:

User completes checkout

Sync: ticket issued, ledger entry written

Jobs enqueued:

Capture payment (if authorized earlier)

Send notifications

Trigger webhooks

Update analytics

10. Interaction with Caching & Redis
Jobs often:

Update Redis structures (availability, counters, queues)

Rebuild ETS caches on node restart

Refresh materialized view caches

Rules:

Always write-through from job → Redis → ETS

Never assume ETS is correct without Redis/DB comparison if risk is high

For high-value jobs (e.g. release holds), job must:

Update ZSET

Update bitmap

Emit PubSub event

11. Periodic Jobs (Cron-Style)
Periodic tasks include:

Seat hold expiration sweeps (if needed in addition to ZSET)

Ledger reconciliation

Analytics compaction / rollups

Report generation

Performance metrics aggregation

Cache cleanup and backfill

Implementation:

Use Oban crontab or similar scheduler

Cron jobs must:

Be tenant-aware

Page through tenants if needed

Avoid long transactions

12. Job Priorities & Backpressure
Queues and jobs can have priority:

High: time-sensitive (seat holds, payments, scanning sync)

Medium: notifications, webhooks

Low: reports, analytics, cache maintenance

Backpressure strategies:

Limit number of concurrent workers per queue

Use queue weights to protect critical queues

Monitor queue depth and job age

Under extreme load, the system must:

Protect critical queues (payments, ticketing)

Allow reporting and analytics jobs to lag

13. Failure Modes & Resilience
Common failure modes:

External provider downtime (PSP, email, SMS)

Network partitions

Redis unavailability

Postgres resource contention

Required safeguards:

Timeouts on all external calls

Circuit-breaking and fallback for critical providers

Clear logging when a job fails due to non-retryable reasons

Idempotent logic to allow safe replay after issues are resolved

14. Observability & Metrics
Every worker must emit telemetry:

job_started

job_succeeded

job_failed

Duration metrics

Queue depth and job age

Metrics to track:

Jobs per minute by type

Failure rate per worker

Average + p95 + p99 job execution time

Queue latency (time from enqueue to start)

DLQ growth over time

All metrics MUST be tagged by:

organization_id (where applicable)

queue

worker

event_id / resource_id when useful

15. Security & Compliance Considerations
Jobs must:

Obey tenant isolation rules

Never leak data across organizations

Avoid logging secrets or PII

Use encrypted credentials from config, not hard-coded tokens

Ensure GDPR/POPIA-compliant data handling in long-lived jobs

Deleting an organization (soft delete) implies:

No new jobs for that org

Long-lived jobs must detect org inactivity and abort gracefully

16. Example Job Flows
16.1 Example: Payment Reconciliation
PSP sends webhook

Integrations slice enqueues ReconcilePaymentWebhookWorker

Worker:

Validates signature

Loads organization and payment attempt

Updates ledger

Emits domain events (payment.captured, payment.refunded)

Enqueues follow-up notifications and analytics jobs

16.2 Example: Seat Hold Expiration
Redis ZSET contains expiration timestamps

Periodic worker ReleaseExpiredHoldsWorker runs

Worker:

Reads batch of expired holds

Updates availability bitmap

Publishes real-time event

Logs telemetry

17. Summary
The VoelgoedEvents async architecture is built on:

Oban for durable jobs

Redis for ephemeral queues & locks

ETS for hot job state

At-least-once semantics with strict idempotency rules

Tenant-aware job payloads and behaviors

Queue-based backpressure to protect critical paths

Observability as a first-class concern

All vertical slices and domain implementations that use background processing must follow the rules and patterns defined in this document.