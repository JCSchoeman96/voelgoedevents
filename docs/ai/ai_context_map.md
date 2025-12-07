# ✅ Voelgoedevents — AI Context Map & File/Module Registry

**THE authoritative reference for all AI coding agents**

> **Purpose:**
> This document prevents the AI from hallucinating module names, file paths, atoms, or domain boundaries.
> Any coding agent MUST treat this as the single source of truth for naming, modules, folder layout, and architectural conventions.

---

## ⚠️ CRITICAL RULES FOR ALL AI AGENTS

### 1. Use the correct casing:

```
Voelgoedevents
VoelgoedeventsWeb
```

**Never** use: `VoelgoedEvents` or `VoelgoedEventsWeb`.

### 2. Never invent modules or folders.

Only use paths/modules listed in this document.

### 3. All business logic = Ash (no Phoenix controllers / LiveViews may contain domain logic).

### 4. All real-time + seat-flow logic must use Redis/ETS/Oban patterns defined here.

### 5. All multi-tenancy operations MUST include `organization_id`.

---

## 🏗️ 1. High-Level Application Architecture (Confirmed from Project Code)

| Component | Module                         | File Path                            | Notes                     |
| --------- | ------------------------------ | ------------------------------------ | ------------------------- |
| OTP App   | **Voelgoedevents.Application** | `lib/voelgoedevents/application.ex`  | Supervision tree startup  |
| Repo      | **Voelgoedevents.Repo**        | `lib/voelgoedevents/repo.ex`         | Postgres + Ash Postgres   |
| Mailer    | **Voelgoedevents.Mailer**      | `lib/voelgoedevents/mailer.ex`       | Swoosh mailer plug-in     |
| Endpoint  | **VoelgoedeventsWeb.Endpoint** | `lib/voelgoedevents_web/endpoint.ex` | Phoenix endpoint + socket |
| Router    | **VoelgoedeventsWeb.Router**   | `lib/voelgoedevents_web/router.ex`   | Web routing               |
| Gettext   | **VoelgoedeventsWeb.Gettext**  | `lib/voelgoedevents_web/gettext.ex`  | Localization              |

### ❌ Not Present in Repo:

- `VoelgoedeventsWeb.Presence` _(Do NOT reference this unless you create it.)_

---

## 🏛️ 2. Ash Domains & Resources (All Verified Against Your Repo)

Your project uses a **layered Ash structure**:

```
lib/voelgoedevents/ash/resources/<domain>/*.ex
lib/voelgoedevents/ash/domains/*.ex
```

Below is the full authoritative list.

---

### 🔐 ACCOUNTS DOMAIN (`:accounts`)

| Resource         | Module                                                    | Atom            | File                                            |
| ---------------- | --------------------------------------------------------- | --------------- | ------------------------------------------------------- |
| **Token**        | `Voelgoedevents.Ash.Resources.Accounts.Token`             | `:token`        | `lib/voelgoedevents/ash/resources/accounts/token.ex`             |
| **User**         | `Voelgoedevents.Ash.Resources.Accounts.User`              | `:user`         | `lib/voelgoedevents/ash/resources/accounts/user.ex`              |
| **Role**         | `Voelgoedevents.Ash.Resources.Accounts.Role`              | `:role`         | `lib/voelgoedevents/ash/resources/accounts/role.ex`              |
| **Membership**   | `Voelgoedevents.Ash.Resources.Accounts.Membership`        | `:membership`   | `lib/voelgoedevents/ash/resources/accounts/membership.ex`        |
| **OrganizationSettings** | `Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings` | `:organization_settings` | `lib/voelgoedevents/ash/resources/organizations/organization_settings.ex` |
| **Organization** | `Voelgoedevents.Ash.Resources.Accounts.Organization`      | `:organization` | `lib/voelgoedevents/ash/resources/accounts/organization.ex`      |

**Domain File:**

```
lib/voelgoedevents/ash/domains/accounts_domain.ex
```

---

### 🔑 ACCESS CONTROL DOMAIN (`:access_control`)

| Resource   | Module                                                       | Atom       | File                                                       |
| ---------- | ------------------------------------------------------------ | ---------- | ---------------------------------------------------------- |
| **ApiKey** | `Voelgoedevents.Ash.Resources.AccessControl.ApiKey`          | `:api_key` | `lib/voelgoedevents/ash/resources/access_control/api_key.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/access_control_domain.ex
```

---

### 📝 AUDIT DOMAIN (`:audit`)

| Resource     | Module                                               | Atom         | File                                                    |
| ------------ | ---------------------------------------------------- | ------------ | ------------------------------------------------------- |
| **AuditLog** | `Voelgoedevents.Ash.Resources.Audit.AuditLog`        | `:audit_log` | `lib/voelgoedevents/ash/resources/audit/audit_log.ex`   |

**Domain File:**

```
lib/voelgoedevents/ash/domains/audit_domain.ex
```

---

### 🎟️ TICKETING DOMAIN (`:ticketing`)

| Resource        | Module                                                 | Atom             | File                                                |
| --------------- | ------------------------------------------------------ | ---------------- | --------------------------------------------------- |
| **Ticket**      | `Voelgoedevents.Ash.Resources.Ticketing.Ticket`        | `:ticket`        | `lib/voelgoedevents/ash/resources/ticketing/ticket.ex`        |
| **PricingRule** | `Voelgoedevents.Ash.Resources.Ticketing.PricingRule`   | `:pricing_rule`  | `lib/voelgoedevents/ash/resources/ticketing/pricing_rule.ex` |
| **Coupon**      | `Voelgoedevents.Ash.Resources.Ticketing.Coupon`        | `:coupon`        | `lib/voelgoedevents/ash/resources/ticketing/coupon.ex`        |
| **OrderState**  | `Voelgoedevents.Ash.Resources.Ticketing.OrderState`    | `:order_state`   | `lib/voelgoedevents/ash/resources/ticketing/order_state.ex`   |

**Domain File:**

```
lib/voelgoedevents/ash/domains/ticketing_domain.ex
```

---

### 💺 SEATING DOMAIN (`:seating`)

| Resource   | Module                                        | Atom      | File                                                 |
| ---------- | --------------------------------------------- | --------- | ---------------------------------------------------- |
| **Seat**   | `Voelgoedevents.Ash.Resources.Seating.Seat`   | `:seat`   | `lib/voelgoedevents/ash/resources/seating/seat.ex`   |
| **Block**  | `Voelgoedevents.Ash.Resources.Seating.Block`  | `:block`  | `lib/voelgoedevents/ash/resources/seating/block.ex`  |
| **Layout** | `Voelgoedevents.Ash.Resources.Seating.Layout` | `:layout` | `lib/voelgoedevents/ash/resources/seating/layout.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/seating_domain.ex
```

---

### 📅 EVENTS DOMAIN (`:events`)

| Resource              | Module                                                  | Atom                  | File                                                            |
| --------------------- | ------------------------------------------------------- | --------------------- | --------------------------------------------------------------- |
| **Event**             | `Voelgoedevents.Ash.Resources.Events.Event`             | `:event`              | `lib/voelgoedevents/ash/resources/events/event.ex`              |
| **OccupancySnapshot** | `Voelgoedevents.Ash.Resources.Events.OccupancySnapshot` | `:occupancy_snapshot` | `lib/voelgoedevents/ash/resources/events/occupancy_snapshot.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/events_domain.ex
```

---

### 💳 PAYMENTS DOMAIN (`:payments`)

| Resource          | Module                                                | Atom              | File                                |
| ----------------- | ----------------------------------------------------- | ----------------- | ----------------------------------- |
| **Transaction**   | `Voelgoedevents.Ash.Resources.Payments.Transaction`   | `:transaction`    | `lib/voelgoedevents/ash/resources/payments/transaction.ex`    |
| **Refund**        | `Voelgoedevents.Ash.Resources.Payments.Refund`        | `:refund`         | `lib/voelgoedevents/ash/resources/payments/refund.ex`         |
| **LedgerAccount** | `Voelgoedevents.Ash.Resources.Payments.LedgerAccount` | `:ledger_account` | `lib/voelgoedevents/ash/resources/payments/ledger_account.ex` |
| **JournalEntry**  | `Voelgoedevents.Ash.Resources.Payments.JournalEntry`  | `:journal_entry`  | `lib/voelgoedevents/ash/resources/payments/journal_entry.ex`  |

**Domain File:**

```
lib/voelgoedevents/ash/domains/payments_domain.ex
```

---

### 🧾 FINANCE DOMAIN (`:finance`)

| Resource | Module                                            | Atom       | File                                               |
| -------- | ------------------------------------------------- | ---------- | -------------------------------------------------- |
| **Ledger** | `Voelgoedevents.Ash.Resources.Finance.Ledger`   | `:ledger`  | `lib/voelgoedevents/ash/resources/finance/ledger.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/finance_domain.ex
```

---

### 📱 SCANNING DOMAIN (`:scanning`)

| Resource        | Module                                              | Atom            | File                                                        |
| --------------- | --------------------------------------------------- | --------------- | ----------------------------------------------------------- |
| **Scan**        | `Voelgoedevents.Ash.Resources.Scanning.Scan`        | `:scan`         | `lib/voelgoedevents/ash/resources/scanning/scan.ex`         |
| **ScanSession** | `Voelgoedevents.Ash.Resources.Scanning.ScanSession` | `:scan_session` | `lib/voelgoedevents/ash/resources/scanning/scan_session.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/scanning_domain.ex
```

---

### 🏟️ VENUES DOMAIN (`:venues`)

| Resource  | Module                                      | Atom     | File                                               |
| --------- | ------------------------------------------- | -------- | -------------------------------------------------- |
| **Venue** | `Voelgoedevents.Ash.Resources.Venues.Venue` | `:venue` | `lib/voelgoedevents/ash/resources/venues/venue.ex` |
| **Gate**  | `Voelgoedevents.Ash.Resources.Venues.Gate`  | `:gate`  | `lib/voelgoedevents/ash/resources/venues/gate.ex`  |

**Domain File:**

```
lib/voelgoedevents/ash/domains/venues_domain.ex
```

---

### 📊 ANALYTICS DOMAIN (`:analytics`)

| Resource           | Module                                                  | Atom               | File                                                            |
| ------------------ | ------------------------------------------------------- | ------------------ | --------------------------------------------------------------- |
| **AnalyticsEvent** | `Voelgoedevents.Ash.Resources.Analytics.AnalyticsEvent` | `:analytics_event` | `lib/voelgoedevents/ash/resources/analytics/analytics_event.ex` |
| **FunnelSnapshot** | `Voelgoedevents.Ash.Resources.Analytics.FunnelSnapshot` | `:funnel_snapshot` | `lib/voelgoedevents/ash/resources/analytics/funnel_snapshot.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/analytics_domain.ex
```

---

### 💰 MONETIZATION DOMAIN (`:monetization`)

| Resource      | Module                                                | Atom          | File                                                          |
| ------------- | ----------------------------------------------------- | ------------- | ------------------------------------------------------------- |
| **Donation**  | `Voelgoedevents.Ash.Resources.Monetization.Donation`  | `:donation`   | `lib/voelgoedevents/ash/resources/monetization/donation.ex`   |
| **FeeModel**  | `Voelgoedevents.Ash.Resources.Monetization.FeeModel`  | `:fee_model`  | `lib/voelgoedevents/ash/resources/monetization/fee_model.ex`  |
| **FeePolicy** | `Voelgoedevents.Ash.Resources.Monetization.FeePolicy` | `:fee_policy` | `lib/voelgoedevents/ash/resources/monetization/fee_policy.ex` |

**Domain File:**

```
lib/voelgoedevents/ash/domains/monetization_domain.ex
```

**Goal:** Fee Policy Caching (Tier 1/ETS) for sub-100ms checkout fee calculation.

---

## ⚙️ 3. Workflow Modules (All Confirmed in Repo)

| Workflow          | Module                                               | File Path                                                    |
| ----------------- | ---------------------------------------------------- | ------------------------------------------------------------ |
| Start Checkout    | `Voelgoedevents.Workflows.Checkout.StartCheckout`    | `lib/voelgoedevents/workflows/checkout/start_checkout.ex`    |
| Complete Checkout | `Voelgoedevents.Workflows.Checkout.CompleteCheckout` | `lib/voelgoedevents/workflows/checkout/complete_checkout.ex` |
| Reserve Seat      | `Voelgoedevents.Workflows.Ticketing.ReserveSeat`     | `lib/voelgoedevents/workflows/ticketing/reserve_seat.ex`     |
| Release Seat      | `Voelgoedevents.Workflows.Ticketing.ReleaseSeat`     | `lib/voelgoedevents/workflows/ticketing/release_seat.ex`     |
| Process Scan      | `Voelgoedevents.Workflows.Scanning.ProcessScan`      | `lib/voelgoedevents/workflows/scanning/process_scan.ex`      |
| Funnel Builder    | `Voelgoedevents.Workflows.Analytics.FunnelBuilder`   | `lib/voelgoedevents/workflows/analytics/funnel_builder.ex`   |

All verified.

---

## ⚡ 4. Caching Modules (Confirmed)

| Cache          | Module                                  | Backend    | File                                            |
| -------------- | --------------------------------------- | ---------- | ----------------------------------------------- |
| SeatCache      | `Voelgoedevents.Caching.SeatCache`      | ETS/Cachex | `lib/voelgoedevents/caching/seat_cache.ex`      |
| PricingCache   | `Voelgoedevents.Caching.PricingCache`   | Cachex     | `lib/voelgoedevents/caching/pricing_cache.ex`   |
| OccupancyCache | `Voelgoedevents.Caching.OccupancyCache` | Redis      | `lib/voelgoedevents/caching/occupancy_cache.ex` |
| RateLimiter    | `Voelgoedevents.Caching.RateLimiter`    | Redis      | `lib/voelgoedevents/caching/rate_limiter.ex`    |

---

## 🔌 5. Web Layer — Confirmed Modules

| Component         | Module                                    | File                                                    |
| ----------------- | ----------------------------------------- | ------------------------------------------------------- |
| CurrentOrgPlug    | `VoelgoedeventsWeb.Plugs.CurrentOrgPlug`  | `lib/voelgoedevents_web/plugs/current_org_plug.ex`      |
| CurrentUserPlug   | `VoelgoedeventsWeb.Plugs.CurrentUserPlug` | `lib/voelgoedevents_web/plugs/current_user_plug.ex`     |
| AnalyticsPlug     | `VoelgoedeventsWeb.Plugs.AnalyticsPlug`   | `lib/voelgoedevents_web/plugs/analytics_plug.ex`        |
| Checkout LiveView | `VoelgoedeventsWeb.CheckoutLive`          | `lib/voelgoedevents_web/live/checkout/checkout_live.ex` |

---

## 👷 6. Oban Workers (Verified)

| Worker             | Module                                        | File                                                   |
| ------------------ | --------------------------------------------- | ------------------------------------------------------ |
| Send Email         | `Voelgoedevents.Queues.WorkerSendEmail`       | `lib/voelgoedevents/queues/worker_send_email.ex`       |
| Generate PDF       | `Voelgoedevents.Queues.WorkerGeneratePdf`     | `lib/voelgoedevents/queues/worker_generate_pdf.ex`     |
| Cleanup Seat Holds | `Voelgoedevents.Queues.WorkerCleanupHolds`    | `lib/voelgoedevents/queues/worker_cleanup_holds.ex`    |
| Analytics Export   | `Voelgoedevents.Queues.WorkerAnalyticsExport` | `lib/voelgoedevents/queues/worker_analytics_export.ex` |

---

## 🧩 7. Status Atoms (Canonical)

### Tickets

```elixir
:available
:reserved
:sold
:cancelled
:checked_in
```

### Payments

```elixir
:pending
:completed
:failed
:refunded
```

### Scanning

```elixir
:valid
:duplicate
:invalid_token
:wrong_gate
```

---

## 🧱 8. Naming Conventions

### Modules = PascalCase

```
Voelgoedevents.Ash.Resources.Seating.Seat
```

### Files = snake_case

```
seat.ex
pricing_rule.ex
occupancy_snapshot.ex
```

### Folders & Layers

```
lib/voelgoedevents/ash/resources/<domain>/<resource>.ex
lib/voelgoedevents/ash/domains/<domain>_domain.ex
lib/voelgoedevents/workflows/<slice>/<workflow>.ex
```

### NEVER create custom new folder structures

Stick to the above exactly.

---

## 🎯 9. Testing Modules

| Type           | Module                       |
| -------------- | ---------------------------- |
| Data case      | `Voelgoedevents.DataCase`    |
| Web case       | `VoelgoedeventsWeb.ConnCase` |
| LiveView tests | `Phoenix.LiveViewTest`       |

---

## 📋 10. OTP/Actor Architecture (From Corrected OTP Guide)

### Supervision Tree Modules

> **Current status:** No supervisor modules exist yet. The `lib/voelgoedevents/supervisors/` folder only contains a README placeholder.

### Actor Modules

| Actor           | Module                                  | File                                            | Restart Strategy |
| --------------- | --------------------------------------- | ----------------------------------------------- | ---------------- |
| EventServer     | `Voelgoedevents.Actors.EventServer`     | `lib/voelgoedevents/actors/event_server.ex`     | `:permanent`     |
| CheckoutSession | `Voelgoedevents.Actors.CheckoutSession` | `lib/voelgoedevents/actors/checkout_session.ex` | `:transient`     |
| HoldMonitor     | `Voelgoedevents.Actors.HoldMonitor`     | `lib/voelgoedevents/actors/hold_monitor.ex`     | `:permanent`     |
| EventMonitor    | `Voelgoedevents.Actors.EventMonitor`    | `lib/voelgoedevents/actors/event_monitor.ex`    | `:permanent`     |

### Cache Singletons

| Cache           | Module                                  | File                                               |
| --------------- | --------------------------------------- | -------------------------------------------------- |
| Seat Cache      | `Voelgoedevents.Caching.SeatCache`      | `lib/voelgoedevents/caching/seat_cache.ex`         |
| Pricing Cache   | `Voelgoedevents.Caching.PricingCache`   | `lib/voelgoedevents/caching/pricing_cache.ex`      |
| Occupancy Cache | `Voelgoedevents.Caching.OccupancyCache` | `lib/voelgoedevents/caching/occupancy_cache.ex`    |
| Rate Limiter    | `Voelgoedevents.Caching.RateLimiter`    | `lib/voelgoedevents/caching/rate_limiter.ex`       |

### Registry Modules

| Registry           | Module                             | Type         |
| ------------------ | ---------------------------------- | ------------ |
| Main Registry      | `Voelgoedevents.Registry`          | `:unique`    |
| Broadcast Registry | `Voelgoedevents.BroadcastRegistry` | `:duplicate` |

---

## 🔄 11. Key Architecture Patterns (For AI Agents)

### Write-Through Pattern (Redis + ETS)

```elixir
# ✅ CORRECT: Write to Redis first (durable), then ETS (hot cache)

# When state changes:
1. Write to Redis (system of record)
   Redix.command(Voelgoedevents.Redis, ["SET", key, value])

2. Update ETS (L1 cache)
   :ets.insert(:occupancy_cache, {key, value})

3. Update process memory (L2 cache)
   state = %{state | occupancy: value}

4. Broadcast via PubSub
   Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, topic, message)
```

### Hydration on Startup

```elixir
# ✅ CRITICAL: All actors MUST load state from Redis on init/1

def init({event_id, org_id}) do
  # Try Redis first (fast)
  case load_state_from_redis(event_id, org_id) do
    {:ok, occupancy} ->
      {:ok, %{occupancy: occupancy}, {:continue, :schedule_refresh}}

    # Fallback to DB (heavy)
    {:error, :redis_empty} ->
      occupancy = rebuild_from_db(event_id, org_id)
      save_to_redis(event_id, org_id, occupancy)
      {:ok, %{occupancy: occupancy}, {:continue, :schedule_refresh}}
  end
end
```

### Multi-Tenancy Enforcement

```elixir
# ✅ ALWAYS include organization_id in all queries

# For Ash reads:
Ash.read!(Resource, filter: [organization_id: org_id])

# For direct queries:
"SELECT * FROM resources WHERE organization_id = $1"

# For Actor lookups:
Registry.lookup(Voelgoedevents.Registry, {:event, event_id, org_id})
```

---

## ⚠️ 12. Common Mistakes to Avoid

### ❌ DON'T

```elixir
# Wrong module casing
VoelgoedEvents.Workflows.ReserveSeat
VoelgoedEventsWeb.Router

# Wrong folder structure
lib/voelgoedevents/workflows/reserve_seat.ex  (wrong, should be in slice)
lib/workflows/reserve_seat.ex  (way wrong)

# State only in memory
GenServer: {:ok, state}  (missing Redis write)

# Missing organization_id
Ash.read(Ticket, filter: [user_id: user_id])  (WRONG!)

# Inventing modules
Voelgoedevents.Services.TicketService
Voelgoedevents.Helpers.SeatHelper
```

### ✅ DO

```elixir
# Correct module casing
Voelgoedevents.Workflows.Ticketing.ReserveSeat
VoelgoedeventsWeb.Router

# Correct folder structure
lib/voelgoedevents/workflows/ticketing/reserve_seat.ex

# Write-through pattern
Redix.command(Voelgoedevents.Redis, ["SET", key, value])
:ets.insert(:occupancy_cache, {key, value})
state = %{state | occupancy: value}

# Multi-tenant query
Ash.read(Ticket, filter: [user_id: user_id, organization_id: org_id])

# Use only verified modules
Voelgoedevents.Workflows.Ticketing.ReserveSeat
Voelgoedevents.Caching.OccupancyCache

# Always load the Ash policy guide when editing policies:
# docs/coding_style/ash_policies.md
```

---

## 📖 13. References to Technical Documentation

### Workflow Documentation

- `reserve_seat.md` - Reserve seat with 5-min hold
- `start_checkout.md` - Pricing pipeline
- `complete_checkout.md` - Payment + accounting
- `process_scan.md` - Venue entry (online)
- `offline_sync.md` - Venue entry (batch)
- `release_seat.md` - TTL cleanup
- `seat_hold_registry.md` - Cache architecture
- `funnel_builder.md` - Analytics + conversions

### OTP Documentation

- `otp_architecture_voelgoed_final.md` - Production-ready OTP guide
  - Hydration strategy (crash recovery)
  - Partitioning for mega-events
  - Idle hibernation (memory optimization)

### Configuration

- `config/config.exs` - Application config
- `config/dev.exs` - Development config
- `config/test.exs` - Test config
- `config/prod.exs` - Production config

### Policy Documentation
- `coding_style/ash_policies.md` – Canonical Ash 3.x policy guidelines. Includes allowed checks, rule structure, bypass handling, `action_type/1`, and multi-tenant access patterns.

---

## 🚀 16. Deployment Checklist for AI Agents

Before implementing ANY feature:

---

## 🛠️ 15. Infrastructure & Support Modules (Verified)

### 🏗️ Infrastructure Layer

| Module              | File                                            | Purpose                                                 |
| ------------------- | ----------------------------------------------- | ------------------------------------------------------- | -------------------- |
| **Redis**           | `Voelgoedevents.Infrastructure.Redis`           | `lib/voelgoedevents/infrastructure/redis.ex`            | Redis client wrapper |
| **CircuitBreaker**  | `Voelgoedevents.Infrastructure.CircuitBreaker`  | `lib/voelgoedevents/infrastructure/circuit_breaker.ex`  | Resilience wrapper   |
| **DistributedLock** | `Voelgoedevents.Infrastructure.DistributedLock` | `lib/voelgoedevents/infrastructure/distributed_lock.ex` | DLM implementation   |
| **RepoPoolConfig**  | `Voelgoedevents.Infrastructure.RepoPoolConfig`  | `lib/voelgoedevents/infrastructure/repo_pool_config.ex` | Dual-pool config     |

### 🧪 Chaos & Observability

| Module               | File                                            | Purpose                                                 |
| -------------------- | ----------------------------------------------- | ------------------------------------------------------- | ---------------- |
| **LatencyInjector**  | `Voelgoedevents.Chaos.LatencyInjector`          | `lib/voelgoedevents/chaos/latency_injector.ex`          | Chaos testing    |
| **SloTracker**       | `Voelgoedevents.Observability.SloTracker`       | `lib/voelgoedevents/observability/slo_tracker.ex`       | SLO monitoring   |
| **TelemetryHandler** | `Voelgoedevents.Observability.TelemetryHandler` | `lib/voelgoedevents/observability/telemetry_handler.ex` | Telemetry events |

### 🔐 Auth Support

| Module            | File                                |
| ----------------- | ----------------------------------- | ------------------------------------------- |
| **AshAuth**       | `Voelgoedevents.Auth.AshAuth`       | `lib/voelgoedevents/auth/ash_auth.ex`       |
| **PipelinePlugs** | `Voelgoedevents.Auth.PipelinePlugs` | `lib/voelgoedevents/auth/pipeline_plugs.ex` |
| **UserTokens**    | `Voelgoedevents.Auth.UserTokens`    | `lib/voelgoedevents/auth/user_tokens.ex`    |

### 🧠 Domain Logic Support

| Category          | Module                                        | File                                                  |
| ----------------- | --------------------------------------------- | ----------------------------------------------------- |
| **Finance**       | `Voelgoedevents.Finance.SettlementCalculator` | `lib/voelgoedevents/finance/settlement_calculator.ex` |
| **Notifications** | `Voelgoedevents.Notifications.Dispatcher`     | `lib/voelgoedevents/notifications/dispatcher.ex`      |
| **Pricing**       | `Voelgoedevents.Pricing.PriceCalculator`      | `lib/voelgoedevents/pricing/price_calculator.ex`      |
| **Search**        | `Voelgoedevents.Search.SearchEngine`          | `lib/voelgoedevents/search/search_engine.ex`          |
| **Uploads**       | `Voelgoedevents.Uploads.UploadConfig`         | `lib/voelgoedevents/uploads/upload_config.ex`         |
| **I18n**          | `Voelgoedevents.I18n.Translator`              | `lib/voelgoedevents/i18n/translator.ex`               |

---

- [ ] Confirm file naming matches (snake_case)
- [ ] Check Ash domain is correct (`:domain_name`)
- [ ] Ensure multi-tenancy (`organization_id`)
- [ ] Implement write-through pattern (Redis → ETS → memory)
- [ ] Use Registry for process lookup (NOT global atoms)
- [ ] Test crash recovery (kill actor, verify state restored from Redis)
- [ ] Monitor latency (partition if > 100ms for events > 10k seats)
- [ ] Update telemetry/metrics
- [ ] Add comprehensive logging

---

## ✅ 17. Final Validation

**This document is the SINGLE SOURCE OF TRUTH.**

If an AI agent or engineer:

1. Uses a module name NOT in this document → ❌ REJECT
2. Creates a folder structure NOT in this document → ❌ REJECT
3. Invents helper/service modules → ❌ REJECT
4. Forgets `organization_id` → ❌ REJECT
5. References this document to validate → ✅ ACCEPT

**All new AI agents MUST load this document FIRST before any coding task.**

---

**Last Updated:** 2025-11-26  
**Status:** AUTHORITATIVE - All paths verified against actual codebase. Phase 1 Foundation Complete. Structural scaffolding for Chaos/Observability is complete.  
**Accuracy:** 100% - No hallucinated modules or paths
