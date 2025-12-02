# Chaos Engineering Layer (Phase 11.4)

**Purpose:** This folder contains modules and utilities designed to simulate failure modes in controlled testing environments (staging/test suites).
**Core Mission:** To proactively test system resilience against network latency, external service outages, and high resource contention.
**Key Residents:**
- `LatencyInjector`: Used to wrap external calls (e.g., to Payment Providers, Redis) to simulate network slowdowns.
- `ErrorInjector`: Used to simulate external API failures (e.g., HTTP 500s).
**Architectural Rule:** Modules in this folder **MUST NEVER** be used in production runtime code. Their sole purpose is to wrap code in test environments.
