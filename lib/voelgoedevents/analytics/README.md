# Analytics Service Layer

**Purpose:** Contains the business logic for calculating aggregate metrics, funnels, and complex business reports.
**Rule:** Modules here primarily read from the **Warm Data Tier** (Redis or materialized views in Postgres) and delegate heavy, long-running calculations to the queue workers in `queues/` to prevent API latency spikes.
**Goal:** Avoid peak-time table scans.
