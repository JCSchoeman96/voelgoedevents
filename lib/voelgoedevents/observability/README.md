# Observability Layer (Phase 1.3.9)

**Purpose:** This folder centralizes all code responsible for monitoring, tracing, and metric tracking. It is the single source for understanding application performance in production.
**Core Mission:** To track and report on Service Level Objectives (SLOs) like checkout latency (p99 < 5s) and uptime.
**Key Residents:**
- `SLOTracker`: Manages error budgets and critical business metrics.
- `TelemetryHandler`: Consumes Elixir/Phoenix Telemetry events and sends them to monitoring backends (e.g., Prometheus/Grafana, Datadog).
**Architectural Rule:** Modules here must be **passive collectors**; they should never contain core business logic or directly call Ash/Postgres/Redis for mutation.
