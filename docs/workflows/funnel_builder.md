# Workflow: Funnel Builder

**Aggregate low-level analytics events into conversion funnel snapshots (views → clicks → cart → checkout → tickets)**

---

## 1. Purpose & Overview

**Funnel Builder** is the analytics aggregation workflow that transforms raw `AnalyticsEvent` records (individual user actions) into high-level funnel snapshots (conversion metrics per stage). It enables business intelligence on customer journey progression, drop-off points, revenue attribution, and performance optimization.

**Why it matters:**

- **Identifies friction:** Where do customers abandon? Seat selection vs checkout vs payment?
- **Measures conversion:** What % of viewers become buyers? Which campaigns convert best?
- **Drives revenue:** Tracks hold → purchase correlation, forecasts revenue based on occupancy
- **Behavioral insights:** Session duration, repeat attempts, geographic patterns, device types
- **Powers optimization:** A/B testing, marketing attribution, pricing strategy validation
- **Compliance & audit:** Complete event trail for business reporting, reconciliation, fraud detection

**Stakeholders:**

- Marketing teams: Campaign performance, channel attribution, cohort analysis
- Operations: Bottleneck identification, real-time occupancy warnings
- Finance: Revenue reconciliation, payment processor disputes, tax/fee breakdown
- Product: Feature usage, UX friction points, performance monitoring
- Leadership: Executive dashboards, KPI tracking, investor reporting

---

## 2. What Is a Funnel?

### Definition

A **funnel** is a multi-stage sequential model that tracks user progression through the event booking journey:

```
Stage 1: Views/Discovery
  └─ User lands on event page or browsing activity

Stage 2: Engagement/Intent
  └─ User selects seat, adds to cart, or interacts with CTA

Stage 3: Checkout Initiation
  └─ User enters checkout flow, payment screen

Stage 4: Payment Processing
  └─ User submits payment, transaction authorized

Stage 5: Transaction Completed
  └─ Tickets issued, confirmation sent

Stage 6: Fulfillment/Entry
  └─ Customer scans ticket, enters venue (optional)

Conversion Rate (Overall): Stage 6 Users / Stage 1 Users × 100%
```

### Funnel Scope

Each funnel is:

- **Per-organization:** Strict multi-tenancy (no cross-org aggregation)
- **Per-event:** Each event has its own funnel (independent metrics)
- **Time-windowed:** Daily, weekly, monthly snapshots (not real-time raw queries)
- **Immutable:** Once calculated, snapshots are frozen (audit trail)

### Funnel Dimensions

Funnels can be sliced by:

- **Campaign/Source:** Direct, organic, paid ad, affiliate, email
- **Coupon:** No coupon, discount code, promo, VIP package
- **Device Type:** Desktop, mobile, tablet, kiosk
- **Geography:** Country, region (if captured)
- **User Segment:** Repeat buyer, first-time, VIP, bulk organizer

---

## 3. Analytics Data Architecture

### Data Flow

```
Customer Action
  ↓
  │ (Real-time)
  ├─→ Event Emission
  │    └─ AnalyticsEvent row created
  │
  ├─→ PubSub Broadcast (instant)
  │    └─ Live dashboards updated (< 100ms)
  │
  └─→ Redis Queue (buffering)
      └─ Events accumulated for batch processing
      
     (Periodic - every 5-60 min)
      ↓
      Aggregation Job (Oban Worker)
      ├─ Read raw AnalyticsEvent records
      ├─ Group by dimensions (org, event, time-window)
      ├─ Calculate metrics (counts, sums, averages)
      └─ Store FunnelSnapshot records
      
     (Durable storage)
      ↓
      FunnelSnapshot
      ├─ Immutable snapshot row
      ├─ Cached for reporting queries
      └─ Exported for BI/data warehouse
```

### Storage Strategy

**Three-tier approach:**

| Layer | Technology | Purpose | Retention |
|-------|-----------|---------|-----------|
| **Hot** | Redis (in-memory) | Real-time counters + live dashboard | 1 day |
| **Warm** | PostgreSQL (AnalyticsEvent) | Raw event audit trail | 90 days |
| **Cold** | Data warehouse (BigQuery/Redshift) | Historical analysis + BI | Indefinite |

---

## 4. Source Data: AnalyticsEvent

### AnalyticsEvent Resource

```elixir
# lib/voelgoedevents/ash/resources/analytics/analytics_event.ex

defmodule Voelgoedevents.Ash.Resources.Analytics.AnalyticsEvent do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :event_type, :string, allow_nil?: false
    # Enum: :page_view, :seat_selected, :seat_held, :checkout_started,
    #       :checkout_expired, :payment_initiated, :payment_completed,
    #       :ticket_scanned, :add_to_cart, :remove_from_cart

    # Key identifiers
    attribute :organization_id, :uuid, allow_nil?: false
    attribute :event_id, :uuid, allow_nil?: false
    attribute :user_id, :uuid  # Can be null for anonymous users
    attribute :session_id, :uuid, allow_nil?: false

    # Session context
    attribute :device_type, :string  # web, mobile, kiosk
    attribute :country_code, :string  # ISO 3166 (optional)
    attribute :source, :string  # direct, organic, paid, email, affiliate
    attribute :utm_source, :string
    attribute :utm_medium, :string
    attribute :utm_campaign, :string
    attribute :utm_content, :string

    # Event properties (flexible JSON)
    attribute :properties_json, :string  # Serialized JSON blob

    # Timestamp
    attribute :created_at, :datetime, allow_nil?: false

    timestamps()
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  actions do
    create :create do
      validate fn changeset, _context ->
        # Ensure event_type is valid
        event_type = changeset.arguments[:event_type]
        valid_types = [
          "page_view", "seat_selected", "seat_held", "checkout_started",
          "checkout_expired", "payment_initiated", "payment_completed",
          "ticket_scanned", "add_to_cart", "remove_from_cart"
        ]
        if event_type in valid_types do
          changeset
        else
          add_error(changeset, :event_type, "is not a valid event type")
        end
      end
    end

    read :read do
      primary? true
    end

    list :list do
      primary? true
    end
  end

  identities do
    identity :id, [:id]
  end

  postgres do
    table "analytics_events"

    repo Voelgoedevents.Repo

    # Indexes for fast lookups
    create_index "idx_analytics_events_org_created" do
      attribute :organization_id
      attribute :created_at
    end

    create_index "idx_analytics_events_event_created" do
      attribute :event_id
      attribute :created_at
    end

    create_index "idx_analytics_events_type_created" do
      attribute :event_type
      attribute :created_at
    end

    create_index "idx_analytics_events_user_created" do
      attribute :user_id
      attribute :created_at
    end

    create_index "idx_analytics_events_session" do
      attribute :session_id
    end
  end
end
```

### Event Properties Schema

Properties are stored as JSON and vary by event type:

**page_view:**
```json
{
  "page_url": "/events/123",
  "page_title": "Event Name",
  "referrer": "google.com",
  "session_start": "2025-11-26T10:00:00Z"
}
```

**seat_selected:**
```json
{
  "seat_id": "uuid-seat-abc",
  "seat_number": "A-42",
  "section": "General Admission",
  "price_cents": 4500,
  "time_to_select_sec": 45
}
```

**seat_held:**
```json
{
  "seat_id": "uuid-seat-abc",
  "hold_duration_sec": 300,
  "occupancy_percent": 45,
  "quantity": 1
}
```

**checkout_started:**
```json
{
  "checkout_id": "uuid-checkout-123",
  "seat_count": 2,
  "subtotal_cents": 9000,
  "platform_fee_cents": 900,
  "tax_cents": 1350,
  "total_cents": 11250,
  "coupon_code": null,
  "discount_cents": 0,
  "time_to_checkout_sec": 180
}
```

**checkout_expired:**
```json
{
  "checkout_id": "uuid-checkout-123",
  "reason": "timeout",
  "time_in_checkout_sec": 150
}
```

**payment_initiated:**
```json
{
  "processor": "stripe",
  "amount_cents": 11250,
  "payment_method": "card",
  "card_brand": "visa"
}
```

**payment_completed:**
```json
{
  "checkout_id": "uuid-checkout-123",
  "transaction_id": "txn_stripe_abc123",
  "seat_count": 2,
  "total_cents": 11250,
  "coupon_code": null,
  "discount_cents": 0,
  "platform_fee_cents": 900,
  "tax_cents": 1350,
  "time_to_purchase_sec": 480,
  "revenue_net_cents": 9000
}
```

**ticket_scanned:**
```json
{
  "ticket_id": "uuid-ticket-456",
  "gate_id": "uuid-gate-main",
  "days_before_event": 0,
  "time_from_purchase_sec": 86400
}
```

---

## 5. FunnelSnapshot Resource

### FunnelSnapshot Ash Resource

```elixir
# lib/voelgoedevents/ash/resources/analytics/funnel_snapshot.ex

defmodule Voelgoedevents.Ash.Resources.Analytics.FunnelSnapshot do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  attributes do
    uuid_primary_key :id

    # Scope
    attribute :organization_id, :uuid, allow_nil?: false
    attribute :event_id, :uuid, allow_nil?: false
    attribute :time_period, :string, allow_nil?: false
    # daily, weekly, monthly, lifetime

    # Time window
    attribute :period_start, :datetime, allow_nil?: false
    attribute :period_end, :datetime, allow_nil?: false

    # Funnel stages (counts)
    attribute :stage_1_views, :integer, default: 0
    # Unique sessions/users landing on event page

    attribute :stage_2_cart_add, :integer, default: 0
    # Users who added seats to cart (seat_held event)

    attribute :stage_3_checkout_started, :integer, default: 0
    # Users who initiated checkout (entered payment screen)

    attribute :stage_4_payment_initiated, :integer, default: 0
    # Users who submitted payment form

    attribute :stage_5_payment_completed, :integer, default: 0
    # Users whose payment succeeded (tickets issued)

    attribute :stage_6_ticket_scanned, :integer, default: 0
    # Users who actually entered venue

    # Conversion rates (calculated)
    attribute :conversion_rate_view_to_cart_pct, :float, default: 0.0
    attribute :conversion_rate_cart_to_checkout_pct, :float, default: 0.0
    attribute :conversion_rate_checkout_to_payment_pct, :float, default: 0.0
    attribute :conversion_rate_payment_to_complete_pct, :float, default: 0.0
    attribute :conversion_rate_complete_to_scanned_pct, :float, default: 0.0
    attribute :overall_conversion_rate_pct, :float, default: 0.0

    # Revenue metrics
    attribute :total_revenue_cents, :integer, default: 0
    attribute :avg_order_value_cents, :integer, default: 0
    attribute :total_platform_fees_cents, :integer, default: 0
    attribute :total_discounts_cents, :integer, default: 0
    attribute :net_revenue_cents, :integer, default: 0

    # Drop-off analysis
    attribute :dropoff_view_to_cart_count, :integer, default: 0
    attribute :dropoff_cart_to_checkout_count, :integer, default: 0
    attribute :dropoff_checkout_to_payment_count, :integer, default: 0
    attribute :dropoff_payment_to_complete_count, :integer, default: 0

    # Metadata
    attribute :snapshot_calculated_at, :datetime, allow_nil?: false
    attribute :data_completeness_pct, :float, default: 100.0
    # 100% = all events processed, < 100% = partial

    timestamps()
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  actions do
    create :create do
      validate fn changeset, _context ->
        # Ensure period_start < period_end
        start_dt = changeset.arguments[:period_start]
        end_dt = changeset.arguments[:period_end]

        if start_dt && end_dt && DateTime.compare(start_dt, end_dt) == :gt do
          add_error(changeset, :period_start, "must be before period_end")
        else
          changeset
        end
      end
    end

    read :read do
      primary? true
    end

    list :list do
      primary? true
    end

    update :update do
      primary? true
    end
  end

  postgres do
    table "funnel_snapshots"

    repo Voelgoedevents.Repo

    create_index "idx_funnel_org_event_period" do
      attribute :organization_id
      attribute :event_id
      attribute :period_start
      unique? true
    end

    create_index "idx_funnel_org_created" do
      attribute :organization_id
      attribute :snapshot_calculated_at
    end
  end
end
```

---

## 6. Funnel Aggregation Process

### Phase 1: Event Capture (Real-Time)

**Where events are created:**

- **Ticketing workflow events:** After `start_checkout`, `reserve_seat`, `complete_checkout`, `process_scan`
- **Marketing events:** Page views, ad clicks, form submissions
- **Session events:** Session start, session end, user login

**Example: Emit event after checkout completion**

```elixir
# In lib/voelgoedevents/workflows/complete_checkout.ex

def complete_checkout(checkout_id) do
  # ... checkout logic ...
  
  # After Ticket records created successfully:
  {:ok, {tickets, checkout}} = Ash.Repo.transaction(fn ->
    # Create Ticket records, update Checkout status, etc.
  end)
  
  # Emit analytics event (fire-and-forget, don't block)
  Ticketing.Analytics.Events.payment_completed(%{
    organization_id: checkout.organization_id,
    event_id: checkout.event_id,
    user_id: checkout.user_id,
    session_id: session_id_from_conn(conn),
    properties_json: Jason.encode!(%{
      checkout_id: checkout.id,
      transaction_id: payment_result.transaction_id,
      seat_count: length(tickets),
      total_cents: checkout.total_cents,
      coupon_code: checkout.coupon_code,
      platform_fee_cents: checkout.platform_fee_cents,
      tax_cents: checkout.tax_cents,
      time_to_purchase_sec: calculate_session_duration()
    })
  })
end
```

### Phase 2: Event Persistence (Immediate)

**Store AnalyticsEvent records asynchronously:**

```elixir
# lib/voelgoedevents/analytics/events.ex

defmodule Voelgoedevents.Analytics.Events do
  def payment_completed(attrs) do
    # Enrich with context
    enriched = Map.merge(attrs, %{
      event_type: "payment_completed",
      created_at: DateTime.utc_now(),
      device_type: get_device_type(attrs),
      source: get_utm_source(attrs),
      utm_source: get_utm_param(:source),
      utm_medium: get_utm_param(:medium),
      utm_campaign: get_utm_param(:campaign),
      country_code: get_country_code(attrs)
    })

    # Async: Fire-and-forget (don't block business logic)
    Task.Supervisor.start_child(
      Voelgoedevents.TaskSupervisor,
      fn -> create_event_async(enriched) end
    )
  end

  defp create_event_async(attrs) do
    case Ash.create(AnalyticsEvent, attrs) do
      {:ok, event} ->
        # Broadcast to PubSub for live dashboard
        Phoenix.PubSub.broadcast(
          Voelgoedevents.PubSub,
          "analytics:#{attrs.organization_id}:#{attrs.event_id}",
          {:analytics_event, event}
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to create analytics event: #{inspect(reason)}")
        :error
    end
  end
end
```

### Phase 3: Periodic Aggregation (Oban Worker)

**Aggregate AnalyticsEvents into FunnelSnapshot records:**

```elixir
# lib/voelgoedevents/queues/worker_analytics_funnel.ex

defmodule Voelgoedevents.Queues.WorkerAnalyticsFunnel do
  use Oban.Worker,
    queue: :analytics,
    max_attempts: 3,
    unique: [period: 300]  # Max once per 5 minutes per org+event+period

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"organization_id" => org_id, "event_id" => event_id}}) do
    Logger.info("Aggregating funnel for org=#{org_id}, event=#{event_id}")

    # Calculate funnel for today
    period = :daily
    period_start = DateTime.utc_now() |> DateTime.shift(hour: -24)
    period_end = DateTime.utc_now()

    # Query aggregates
    funnel_data = calculate_funnel_aggregates(org_id, event_id, period_start, period_end)

    # Upsert FunnelSnapshot
    case Ash.create_or_update(FunnelSnapshot, funnel_data) do
      {:ok, snapshot} ->
        Logger.info("Funnel snapshot created: #{snapshot.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create funnel snapshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_funnel_aggregates(org_id, event_id, period_start, period_end) do
    # Query each funnel stage from AnalyticsEvent

    stage_1_views = count_events(org_id, event_id, "page_view", period_start, period_end)
    stage_2_cart = count_events(org_id, event_id, "seat_held", period_start, period_end)
    stage_3_checkout = count_events(org_id, event_id, "checkout_started", period_start, period_end)
    stage_4_payment_init = count_events(org_id, event_id, "payment_initiated", period_start, period_end)
    stage_5_payment_complete = count_events(org_id, event_id, "payment_completed", period_start, period_end)
    stage_6_scanned = count_events(org_id, event_id, "ticket_scanned", period_start, period_end)

    # Calculate conversion rates
    conv_1_to_2 = if stage_1_views > 0, do: (stage_2_cart / stage_1_views) * 100, else: 0
    conv_2_to_3 = if stage_2_cart > 0, do: (stage_3_checkout / stage_2_cart) * 100, else: 0
    conv_3_to_4 = if stage_3_checkout > 0, do: (stage_4_payment_init / stage_3_checkout) * 100, else: 0
    conv_4_to_5 = if stage_4_payment_init > 0, do: (stage_5_payment_complete / stage_4_payment_init) * 100, else: 0
    conv_5_to_6 = if stage_5_payment_complete > 0, do: (stage_6_scanned / stage_5_payment_complete) * 100, else: 0
    overall_conv = if stage_1_views > 0, do: (stage_5_payment_complete / stage_1_views) * 100, else: 0

    # Revenue metrics
    {total_revenue, avg_order_value, total_fees, total_discounts} =
      calculate_revenue_metrics(org_id, event_id, period_start, period_end)

    %{
      organization_id: org_id,
      event_id: event_id,
      time_period: :daily,
      period_start: period_start,
      period_end: period_end,
      stage_1_views: stage_1_views,
      stage_2_cart_add: stage_2_cart,
      stage_3_checkout_started: stage_3_checkout,
      stage_4_payment_initiated: stage_4_payment_init,
      stage_5_payment_completed: stage_5_payment_complete,
      stage_6_ticket_scanned: stage_6_scanned,
      conversion_rate_view_to_cart_pct: conv_1_to_2,
      conversion_rate_cart_to_checkout_pct: conv_2_to_3,
      conversion_rate_checkout_to_payment_pct: conv_3_to_4,
      conversion_rate_payment_to_complete_pct: conv_4_to_5,
      conversion_rate_complete_to_scanned_pct: conv_5_to_6,
      overall_conversion_rate_pct: overall_conv,
      total_revenue_cents: total_revenue,
      avg_order_value_cents: avg_order_value,
      total_platform_fees_cents: total_fees,
      total_discounts_cents: total_discounts,
      net_revenue_cents: total_revenue - total_fees,
      dropoff_view_to_cart_count: stage_1_views - stage_2_cart,
      dropoff_cart_to_checkout_count: stage_2_cart - stage_3_checkout,
      dropoff_checkout_to_payment_count: stage_3_checkout - stage_4_payment_init,
      dropoff_payment_to_complete_count: stage_4_payment_init - stage_5_payment_complete,
      snapshot_calculated_at: DateTime.utc_now()
    }
  end

  defp count_events(org_id, event_id, event_type, period_start, period_end) do
    query = """
    SELECT COUNT(DISTINCT session_id) as unique_count
    FROM analytics_events
    WHERE organization_id = $1
      AND event_id = $2
      AND event_type = $3
      AND created_at >= $4
      AND created_at < $5
    """

    {:ok, result} =
      Ash.query(AnalyticsEvent)
      |> Ash.Query.select(:id)
      |> Ash.read()

    # Fallback to raw SQL if needed
    {:ok, %{rows: [[count]]}} =
      Ecto.Adapters.SQL.query(
        Voelgoedevents.Repo,
        query,
        [org_id, event_id, event_type, period_start, period_end]
      )

    count || 0
  end

  defp calculate_revenue_metrics(org_id, event_id, period_start, period_end) do
    query = """
    SELECT
      SUM((properties_json->>'total_cents')::BIGINT) as total_revenue,
      AVG((properties_json->>'total_cents')::BIGINT)::BIGINT as avg_order_value,
      SUM((properties_json->>'platform_fee_cents')::BIGINT) as total_fees,
      SUM((properties_json->>'discount_cents')::BIGINT) as total_discounts
    FROM analytics_events
    WHERE organization_id = $1
      AND event_id = $2
      AND event_type = 'payment_completed'
      AND created_at >= $3
      AND created_at < $4
    """

    {:ok, %{rows: [[total_revenue, avg_order_value, total_fees, total_discounts]]}} =
      Ecto.Adapters.SQL.query(
        Voelgoedevents.Repo,
        query,
        [org_id, event_id, period_start, period_end]
      )

    {
      total_revenue || 0,
      avg_order_value || 0,
      total_fees || 0,
      total_discounts || 0
    }
  end
end
```

### Phase 4: Schedule Aggregation Jobs

```elixir
# config/config.exs

config :voelgoedevents, Oban,
  crons: [
    # Aggregate funnels every hour
    aggregate_daily_funnels: [
      schedule: "0 * * * *",  # Every hour
      job: {Voelgoedevents.Queues.WorkerAnalyticsFunnel, []},
      tags: ["analytics", "funnel"]
    ]
  ]
```

---

## 7. Key Metrics in FunnelSnapshot

### Stage Counts

| Metric | Meaning | Source Event |
|--------|---------|--------------|
| `stage_1_views` | Unique sessions landing on event page | `page_view` |
| `stage_2_cart_add` | Sessions where seats were held | `seat_held` |
| `stage_3_checkout_started` | Sessions where checkout began | `checkout_started` |
| `stage_4_payment_initiated` | Sessions where payment form submitted | `payment_initiated` |
| `stage_5_payment_completed` | Sessions where payment succeeded | `payment_completed` |
| `stage_6_ticket_scanned` | Sessions where tickets actually scanned | `ticket_scanned` |

### Conversion Rates

| Metric | Formula | Insight |
|--------|---------|---------|
| `conversion_rate_view_to_cart_pct` | (stage_2 / stage_1) × 100 | % of viewers who selected seats |
| `conversion_rate_cart_to_checkout_pct` | (stage_3 / stage_2) × 100 | % of seat-holders who proceeded |
| `conversion_rate_checkout_to_payment_pct` | (stage_4 / stage_3) × 100 | % of checkout-starters who paid |
| `conversion_rate_payment_to_complete_pct` | (stage_5 / stage_4) × 100 | % of payment-initiated with success |
| `overall_conversion_rate_pct` | (stage_5 / stage_1) × 100 | End-to-end conversion: viewers → buyers |

### Drop-Off Analysis

| Metric | Formula | Insight |
|--------|---------|---------|
| `dropoff_view_to_cart_count` | stage_1 - stage_2 | Users who didn't select seats |
| `dropoff_cart_to_checkout_count` | stage_2 - stage_3 | Users who didn't proceed to payment |
| `dropoff_checkout_to_payment_count` | stage_3 - stage_4 | Users who abandoned at payment form |
| `dropoff_payment_to_complete_count` | stage_4 - stage_5 | Users whose payment failed |

### Revenue Metrics

| Metric | Meaning |
|--------|---------|
| `total_revenue_cents` | Sum of all completed purchase amounts |
| `avg_order_value_cents` | Mean value per transaction |
| `total_platform_fees_cents` | Sum of platform commission |
| `total_discounts_cents` | Sum of coupon/discount amounts |
| `net_revenue_cents` | total_revenue - platform_fees |

---

## 8. Performance & Storage Strategy

### Raw Events vs Aggregated Snapshots

**Why not query raw events directly?**

```
Raw AnalyticsEvent queries:
  - 1 million events per day (1k events/minute average)
  - 90-day retention = 90 million rows
  - Query: SELECT COUNT(DISTINCT user_id) WHERE event_type='payment_completed' AND created_at > ?
  - Without indexes: FULL TABLE SCAN = 90M rows scanned
  - Result latency: 30+ seconds
  - Problem: Dashboards time out, reports take too long

Aggregated FunnelSnapshot queries:
  - 1 snapshot per event per day = 100s of snapshots
  - Query: SELECT * FROM funnel_snapshots WHERE event_id=? AND period_start > ?
  - Result latency: < 100ms
  - Benefit: Instant dashboard updates, fast reports
```

### Data Retention

```
AnalyticsEvent (raw):
  - Retention: 90 days (SSD storage, cost-effective)
  - Purpose: Debugging, fraud detection, detailed audit
  - Action after 90d: Archive to data warehouse, delete from prod

FunnelSnapshot (aggregated):
  - Retention: Indefinite (small volume, high value)
  - Purpose: Historical analysis, trend detection, YoY comparison
  - Backup: Daily export to BigQuery/Redshift (BI tool source)
```

### Query Performance Targets

| Query Type | Target Latency | Storage |
|------------|----------------|---------|
| Real-time dashboard (current hour) | < 100ms | Redis cache |
| Daily funnel (last 24h) | < 500ms | PostgreSQL (FunnelSnapshot) |
| Weekly report (last 7d) | < 1s | PostgreSQL (FunnelSnapshot) |
| Monthly breakdown | < 2s | PostgreSQL (aggregated views) |
| Historical trend (12 months) | < 5s | Data warehouse query |

### Caching Strategy

**Redis cache for live dashboard:**

```elixir
# Cache current hour metrics in Redis (TTL: 1 hour)
cache_key = "voelgoed:funnel:#{org_id}:#{event_id}:current_hour"
cache_value = %{
  current_views: stage_1_count,
  current_conversions: stage_5_count,
  conversion_rate: overall_conv_pct,
  last_updated: DateTime.utc_now()
}

Redix.command!(:redis, [
  "SET",
  cache_key,
  Jason.encode!(cache_value),
  "EX",
  3600  # TTL: 1 hour
])
```

---

## 9. Multi-Tenancy Enforcement

### Organization Isolation

**Critical rules:**

1. **All AnalyticsEvent records include `organization_id`**
   ```elixir
   # ✅ CORRECT
   AnalyticsEvent.create!(%{
     organization_id: org_id,  # ← MANDATORY
     event_id: event_id,
     event_type: "payment_completed"
   })
   ```

2. **All FunnelSnapshot records scoped by org**
   ```elixir
   # ✅ CORRECT
   FunnelSnapshot
   |> Ash.Query.filter(organization_id: org_id)
   |> Ash.read!()

   # ❌ WRONG
   FunnelSnapshot
   |> Ash.read!()  # No org filter = could read cross-org!
   ```

3. **All aggregation queries filtered by org_id**
   ```elixir
   # In aggregation job
   where organization_id = $1 AND event_id = $2 AND created_at >= $3

   # Parameters: [org_id, event_id, period_start]
   ```

4. **Multitenancy strategy enforced in Ash**
   ```elixir
   multitenancy do
     strategy :attribute
     attribute :organization_id
   end
   ```

---

## 10. Integration Points

### With Ticketing Workflows

**complete_checkout → payment_completed event**

```
complete_checkout.ex:
  ├─ Tickets created
  ├─ Checkout marked paid
  └─ 🔊 Emit Analytics.Events.payment_completed()
      └─ AnalyticsEvent created
      └─ FunnelSnapshot updated next job run
```

**process_scan → ticket_scanned event**

```
process_scan.md:
  ├─ Scan record created
  ├─ Ticket status → :scanned
  └─ 🔊 Emit Analytics.Events.ticket_scanned()
      └─ AnalyticsEvent created (fulfillment tracking)
```

### With Real-Time Dashboards

**Live dashboard subscribes to PubSub:**

```elixir
# In analytics dashboard LiveView

def mount(%{"event_id" => event_id}, session, socket) do
  org_id = session["org_id"]

  # Subscribe to analytics updates
  Phoenix.PubSub.subscribe(
    Voelgoedevents.PubSub,
    "analytics:#{org_id}:#{event_id}"
  )

  # Load current funnel snapshot
  funnel = Ash.read_one!(FunnelSnapshot, organization_id: org_id, event_id: event_id)

  {:ok, assign(socket, funnel: funnel, org_id: org_id, event_id: event_id)}
end

def handle_info({:analytics_event, event}, socket) do
  # Real-time event received, update UI
  {:noreply, push_event(socket, "analytics_updated", event)}
end
```

### With Data Warehouse Export

**Worker exports to BigQuery/Redshift:**

```elixir
# lib/voelgoedevents/queues/worker_analytics_export.ex

defmodule Voelgoedevents.Queues.WorkerAnalyticsExport do
  use Oban.Worker, queue: :analytics, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"date" => date}}) do
    # Export FunnelSnapshots from 'date' to BigQuery
    snapshots = Ash.read!(FunnelSnapshot, filter: [
      snapshot_calculated_at: {:>= , Date.from_iso8601!(date) |> DateTime.new!}
    ])

    # Transform to BigQuery schema
    rows = Enum.map(snapshots, &to_bq_row/1)

    # Upload batch
    {:ok, _job} = BigQuery.insert_all("voelgoed.funnel_snapshots", rows)

    :ok
  end

  defp to_bq_row(snapshot) do
    %{
      organization_id: snapshot.organization_id,
      event_id: snapshot.event_id,
      period_start: snapshot.period_start,
      stage_1_views: snapshot.stage_1_views,
      stage_5_payment_completed: snapshot.stage_5_payment_completed,
      overall_conversion_rate: snapshot.overall_conversion_rate_pct,
      total_revenue: snapshot.total_revenue_cents / 100,
      # ... other fields
    }
  end
end
```

---

## 11. Usage: Dashboard & Reporting

### Analytics Dashboard Endpoints

**Get current funnel for event:**

```
GET /api/organizations/:org_id/events/:event_id/funnel?period=daily

Response:
{
  "funnel_snapshot": {
    "stage_1_views": 1000,
    "stage_2_cart_add": 450,
    "stage_3_checkout_started": 320,
    "stage_4_payment_initiated": 280,
    "stage_5_payment_completed": 265,
    "overall_conversion_rate_pct": 26.5,
    "total_revenue_cents": 2397500,
    "avg_order_value_cents": 9038
  }
}
```

**Get historical trends:**

```
GET /api/organizations/:org_id/events/:event_id/funnel/trends?start_date=2025-01-01&end_date=2025-11-26

Response:
[
  {
    "date": "2025-01-01",
    "overall_conversion_rate_pct": 22.3,
    "total_revenue_cents": 1500000
  },
  {
    "date": "2025-01-02",
    "overall_conversion_rate_pct": 24.1,
    "total_revenue_cents": 1750000
  },
  ...
]
```

### Report Templates

**Marketing Performance Report:**
- By campaign/source (UTM attribution)
- Conversion rates by channel
- Revenue per channel (ROAS)
- Cost per acquisition (if ad spend available)

**Event Health Report:**
- Daily conversion trends
- Drop-off points + recommendations
- Occupancy correlation with bookings
- Revenue forecast (if event not started)

**Cohort Analysis:**
- Repeat buyer rate
- Lifetime value by acquisition date
- Retention metrics

---

## 12. Future Enhancements

- **Attribution modeling:** Multi-touch attribution (first-click, last-click, linear)
- **Predictive analytics:** Forecast revenue/occupancy based on current funnel
- **Segmentation:** Auto-identify high-value customer segments
- **Anomaly detection:** Alert on unusual drop-offs (e.g., payment processor down)
- **A/B testing integration:** Tie feature flags to funnel metrics
- **Real-time alerts:** Slack/email if conversion rate drops > 20%
- **Competitor benchmarking:** Compare metrics to industry standards
- **Geographic heatmaps:** Visualize bookings by region/timezone

---

**END OF FUNNEL BUILDER WORKFLOW**