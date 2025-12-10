## ✅ PHASE 1: Technical Foundation

**Goal:** Clean, disciplined, extensible codebase with high-concurrency primitives  
**Duration:** 1.5 weeks  
**Deliverables:** Configured tools, CI pipeline, foundation docs, ETS/Redis/Oban setup  
**Dependencies:** Completes Phase 0

---

### Phase 1.1: Project Scaffolding

#### Sub-Phase 1.1.1: Verify Dependencies

**Task:** Check `mix.exs` contains all required dependencies with correct versions  
**Objective:** Ensure correct versions of Ash, Phoenix, Oban, Redis, etc.  
**Output:** Verified `mix.exs`  
**Note:**  
- **Status:** COMPLETE (verified from GitHub)
- Required versions:
  - Elixir: `~> 1.17`
  - Phoenix: `~> 1.7`
  - Ash: `~> 3.0`
  - AshPostgres: `~> 2.0`
  - AshPhoenix: `~> 2.0`
  - AshAuthentication: `~> 4.0`
  - AshStateMachine: `~> 0.2`
  - Oban: `~> 2.17`
  - AshOban: `~> 0.2`
  - Redix: `~> 1.5`
  - Cachex: `~> 3.6`
  - Swoosh: `~> 1.16`

---

### Phase 1.2: Folder & Domain Layout

#### Sub-Phase 1.2.1: Validate Folder Structure

**Task:** Verify Standard Ash Layout exists and matches `/docs/INDEX.md` Section 4.1  
**Objective:** Ensure all code follows canonical folder structure  
**Output:** Folder structure audit report  
**Note:**  
- **Status:** COMPLETE (folders exist, empty)
- Never create custom folders like `lib/voelgoedevents/ticketing/ash/`
- Always use Standard Ash Layout: `lib/voelgoedevents/ash/resources/ticketing/`
- Reference `/docs/ai/ai_context_map.md` for authoritative module registry

---

#### Sub-Phase 1.2.2: Create Foundation Architecture Document

**Task:** Document PETAL stack rationale, Ash philosophy, caching tiers, DLM requirements  
**Objective:** Provide architectural context for all future implementation  
**Output:** `/docs/architecture/01_foundation.md`  
**Note:**  
- Must align with existing architecture docs in `/docs/architecture/`
- Link to `/docs/PROJECT_GUIDE.md` Section 2 (Tech Stack)
- Define DLM pattern (Redlock or Redis SET NX EX)
- Reference Appendix C for caching model details

---

### Phase 1.3: Tooling & CI

#### Sub-Phase 1.3.1: Add Credo

**Task:** Configure Credo for code quality enforcement  
**Objective:** Maintain consistent code style across all contributions  
**Output:** `.credo.exs`  
**Note:**  
- Use strict mode
- Max cyclomatic complexity: 10
- Enforce module documentation

---

#### Sub-Phase 1.3.2: Add Dialyzer

**Task:** Configure Dialyxir for static type analysis  
**Objective:** Catch type errors early  
**Output:** `mix.exs` updated with `:dialyxir` dependency  
**Note:**  
- Add to `:dev` and `:test` only
- Dependency: `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`

---

#### Sub-Phase 1.3.3: Add ExCoveralls

**Task:** Configure test coverage reporting  
**Objective:** Track code coverage across domains  
**Output:** `mix.exs` updated, `.coveralls.json` created  
**Note:**  
- Target: 80% coverage minimum for MVP
- Dependency: `{:excoveralls, "~> 0.18", only: :test}`

---

#### Sub-Phase 1.3.4: Configure GitHub Actions CI

**Task:** Create `.github/workflows/ci.yml` for automated testing  
**Objective:** Ensure all PRs pass tests, Credo, Dialyzer before merge  
**Output:** `.github/workflows/ci.yml`  
**Note:**  
- Run on `push` to `main` and all PRs
- Cache Mix deps and PLT files
- Steps: checkout → setup Elixir → deps.get → compile → credo → test → dialyzer

---

### Phase 1.4: Core Infrastructure Modules

#### Sub-Phase 1.4.1: Initialize ETS Tables for Hot Cache

**Task:** Create `lib/voelgoedevents/infrastructure/ets_registry.ex`  
**Objective:** Initialize per-node ETS tables for hot-path caching  
**Output:** `lib/voelgoedevents/infrastructure/ets_registry.ex`  
**Note:**  
- Tables: `:seat_holds_hot`, `:recent_scans`, `:pricing_cache`, `:rbac_cache`
- Start under `Voelgoedevents.Application` supervision tree
- Reference `/docs/architecture/03_caching_and_realtime.md` Section 3.1 (Hot Layer)

---

#### Sub-Phase 1.4.2: Configure Redis Connection Pool

**Task:** Set up Redix connection pool in `config/config.exs`  
**Objective:** Enable warm-layer caching and distributed state  
**Output:**  
- Updated `config/config.exs`
- `lib/voelgoedevents/infrastructure/redis.ex`  
**Note:**  
- Pool size: 10 connections
- Reference `/docs/architecture/03_caching_and_realtime.md` Section 3.2 (Warm Layer)

---

#### Sub-Phase 1.4.3: Initialize Phoenix PubSub

**Task:** Verify Phoenix.PubSub is configured in supervision tree  
**Objective:** Enable real-time event broadcasting for LiveView and analytics  
**Output:** Verified `lib/voelgoedevents/application.ex`  
**Note:**  
- **Status:** Should already exist in Phoenix 1.7 scaffold
- Name: `Voelgoedevents.PubSub`
- Adapter: `Phoenix.PubSub.PG2` (default)

---

#### Sub-Phase 1.4.4: Configure Oban Job Queue

**Task:** Add Oban to supervision tree and create queue configuration  
**Objective:** Enable background job processing for cleanup, emails, reports  
**Output:**  
- `lib/voelgoedevents/queues/oban_config.ex`
- Updated `lib/voelgoedevents/application.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_add_oban_jobs_table.exs`  
**Note:**  
- Use AshOban for Ash resource integration
- Queues: `:default`, `:mailers`, `:analytics`, `:cleanup`, `:webhooks`
- Reference `/docs/architecture/06_jobs_and_async.md`

---

### Phase 1.5: Distributed Lock Manager (DLM) Setup

#### Sub-Phase 1.5.1: Implement Redlock-Based DLM

**Task:** Create `lib/voelgoedevents/infrastructure/distributed_lock.ex`  
**Objective:** Prevent race conditions in seat holds, checkout, payment capture  
**Output:** `lib/voelgoedevents/infrastructure/distributed_lock.ex`  
**Note:**  
- Use Redis `SET key value NX EX seconds` pattern (simplified Redlock)
- Lock TTL: 10 seconds (must be short to prevent deadlocks)
- Implement `acquire/2` and `release/2` functions
- Use Lua script for safe release (only lock holder can release)
- Reference `/docs/architecture/01_foundation.md` Section on DLM

---