# Queues Layer (Oban Workers)

**Purpose (Async Tier):** Dedicated modules for Oban background workers. This layer handles asynchronous, long-running, and high-latency tasks.
**Constraint:** Any task that could potentially push API latency over 100ms or be safely retried must be offloaded here.
**Examples:** `WorkerSendEmail`, `WorkerGeneratePDF`, `WorkerCleanupHolds`, long-running analytics exports.
