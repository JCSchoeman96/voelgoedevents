# scaffold_modules.ps1
# Run from the project root (where mix.exs is)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Stop"

########### HELPERS ###########

function Ensure-Dir {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }
}

function Ensure-ElixirModule {
    param(
        [string]$Path,
        [string]$ModuleName,
        [string]$Template,
        [string]$Description
    )

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        Ensure-Dir $dir
    }

    $isNewOrEmpty = $false
    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
        $isNewOrEmpty = $true
    } else {
        $length = (Get-Item $Path).Length
        if ($length -eq 0) {
            $isNewOrEmpty = $true
        }
    }

    if (-not $isNewOrEmpty) {
        Write-Host "Skipping existing non-empty Elixir file: $Path"
        return
    }

    switch ($Template) {
        "ash_domain" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  use Ash.Domain

  # TODO: Add resources for this domain.
  # See docs/domain/*.md for the domain rules.
end
"@
        }
        "ash_resource" {
    $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table "CHANGE_ME"
    repo Voelgoedevents.Repo
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
"@
}
        "ash_policy_helper" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  # TODO: Add common Ash policy helpers and role-based access checks here.
end
"@
        }
        "ash_notifier" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  # This module will be wired as an Ash notifier to broadcast changes
  # to PubSub, caches, and possibly analytics.
  #
  # See docs/workflows/* and docs/architecture/caching_and_performance.md
  # before implementing.
end
"@
        }
        "auth_helper" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  # TODO: Configure AshAuthentication strategies and helpers here.
end
"@
        }
        "workflow" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  @doc """
  Entry point for this workflow.

  Accepts a map of input data and returns {:ok, result} or {:error, reason}.

  See the matching docs/workflows/*.md file for the detailed behaviour.
  """
  @spec call(map()) :: {:ok, map()} | {:error, term()}
  def call(_input) do
    # TODO: implement workflow orchestration.
    :not_implemented
  end
end
"@
        }
        "caching" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  # TODO: Implement cache reads/writes using Redis/ETS/Cachex.
  # See docs/architecture/caching_and_performance.md.
end
"@
        }
        "queue_worker" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    # TODO: implement worker logic.
    :ok
  end
end
"@
        }
        "queue_config" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  # TODO: Centralize Oban configuration and queue definitions here.
end
"@
        }
        "analytics" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  # TODO: Implement analytics queries and report generation.
end
"@
        }
        "contract" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  @enforce_keys []
  defstruct []

  @type t :: %__MODULE__{}
  # TODO: Add typed fields for this contract and use it at API/workflow boundaries.
end
"@
        }
        "plug_helper" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  import Plug.Conn

  # TODO: Add plugs for loading current_user, current_org, and analytics context.
end
"@
        }
        "simple" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"
end
"@
        }
        default {
            throw "Unknown template type: $Template for $Path"
        }
    }

    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "Created Elixir module: $Path"
}

function Ensure-ElixirTestModule {
    param(
        [string]$Path,
        [string]$ModuleName,
        [string]$Template,
        [string]$Description
    )

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        Ensure-Dir $dir
    }

    $isNewOrEmpty = $false
    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
        $isNewOrEmpty = $true
    } else {
        $length = (Get-Item $Path).Length
        if ($length -eq 0) {
            $isNewOrEmpty = $true
        }
    }

    if (-not $isNewOrEmpty) {
        Write-Host "Skipping existing non-empty test file: $Path"
        return
    }

    switch ($Template) {
        "data_case" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  use Voelgoedevents.DataCase, async: true

  describe "placeholder" do
    test "true is true" do
      assert true
    end
  end
end
"@
        }
        "conn_case" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  use VoelgoedeventsWeb.ConnCase, async: true

  describe "placeholder" do
    test "true is true", %{conn: conn} do
      assert conn.status in [nil, 200, 302]
    end
  end
end
"@
        }
        "live_case" {
            $content = @"
defmodule $ModuleName do
  @moduledoc "$Description"

  use VoelgoedeventsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "placeholder liveview" do
    test "true is true", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/")
      assert true
    end
  end
end
"@
        }
        default {
            throw "Unknown test template: $Template for $Path"
        }
    }

    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "Created test module: $Path"
}

function Ensure-TsFile {
    param(
        [string]$Path,
        [string]$Description,
        [string]$Kind
    )

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        Ensure-Dir $dir
    }

    $isNewOrEmpty = $false
    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
        $isNewOrEmpty = $true
    } else {
        $length = (Get-Item $Path).Length
        if ($length -eq 0) {
            $isNewOrEmpty = $true
        }
    }

    if (-not $isNewOrEmpty) {
        Write-Host "Skipping existing non-empty TS file: $Path"
        return
    }

    switch ($Kind) {
        "dto" {
            $content = @"
// $Description

export type TODO = Record<string, unknown>;
// TODO: Replace with real DTO definition.
"@
        }
        "analytics_events" {
            $content = @"
// $Description

export type AnalyticsEventName =
  | "page_view"
  | "scroll_depth"
  | "add_to_cart"
  | "view_cart"
  | "start_checkout"
  | "checkout_success";

// TODO: Add strongly typed payloads per event.
"@
        }
        default {
            $content = @"
// $Description
"@
        }
    }

    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "Created TS file: $Path"
}

########### DIRECTORIES ###########

$directories = @(
    "lib/voelgoedevents/ash/domains",
    "lib/voelgoedevents/ash/resources/accounts",
    "lib/voelgoedevents/ash/resources/organizations",
    "lib/voelgoedevents/ash/resources/venues",
    "lib/voelgoedevents/ash/resources/events",
    "lib/voelgoedevents/ash/resources/seating",
    "lib/voelgoedevents/ash/resources/ticketing",
    "lib/voelgoedevents/ash/resources/payments",
    "lib/voelgoedevents/ash/resources/scanning",
    "lib/voelgoedevents/ash/resources/analytics",
    "lib/voelgoedevents/ash/policies",
    "lib/voelgoedevents/ash/support/changes",
    "lib/voelgoedevents/ash/support/calculations",
    "lib/voelgoedevents/ash/support/validations",
    "lib/voelgoedevents/ash/notifiers",

    "lib/voelgoedevents/auth",
    "lib/voelgoedevents/contracts/api",
    "lib/voelgoedevents/contracts/workflows",
    "lib/voelgoedevents/workflows/checkout",
    "lib/voelgoedevents/workflows/ticketing",
    "lib/voelgoedevents/workflows/scanning",
    "lib/voelgoedevents/workflows/analytics",
    "lib/voelgoedevents/caching",
    "lib/voelgoedevents/queues",
    "lib/voelgoedevents/analytics",

    "lib/voelgoedevents_web/plugs",

    "assets/js/types",
    "scanner_pwa/src/lib/types",

    "test/voelgoedevents/ash",
    "test/voelgoedevents/workflows",
    "test/voelgoedevents/caching",
    "test/voelgoedevents_web/controllers",
    "test/voelgoedevents_web/live",
    "test/voelgoedevents_web/features"
)

$directories | ForEach-Object { Ensure-Dir $_ }

########### ELIXIR MODULES ###########

$modules = @(
    # Domains
    @{ Path = "lib/voelgoedevents/ash/domains/core_domain.ex";        Module = "Voelgoedevents.Ash.Domains.CoreDomain";        Template = "ash_domain"; Desc = "Ash domain aggregating core shared resources."; },
    @{ Path = "lib/voelgoedevents/ash/domains/accounts_domain.ex";    Module = "Voelgoedevents.Ash.Domains.AccountsDomain";    Template = "ash_domain"; Desc = "Ash domain for users, roles, and memberships."; },
    @{ Path = "lib/voelgoedevents/ash/domains/venues_domain.ex";      Module = "Voelgoedevents.Ash.Domains.VenuesDomain";      Template = "ash_domain"; Desc = "Ash domain for venues and gates."; },
    @{ Path = "lib/voelgoedevents/ash/domains/events_domain.ex";      Module = "Voelgoedevents.Ash.Domains.EventsDomain";      Template = "ash_domain"; Desc = "Ash domain for events and occupancy snapshots."; },
    @{ Path = "lib/voelgoedevents/ash/domains/seating_domain.ex";     Module = "Voelgoedevents.Ash.Domains.SeatingDomain";     Template = "ash_domain"; Desc = "Ash domain for seating layouts, blocks, and seats."; },
    @{ Path = "lib/voelgoedevents/ash/domains/ticketing_domain.ex";   Module = "Voelgoedevents.Ash.Domains.TicketingDomain";   Template = "ash_domain"; Desc = "Ash domain for tickets, pricing rules, and coupons."; },
    @{ Path = "lib/voelgoedevents/ash/domains/payments_domain.ex";    Module = "Voelgoedevents.Ash.Domains.PaymentsDomain";    Template = "ash_domain"; Desc = "Ash domain for transactions, refunds, and ledger entries."; },
    @{ Path = "lib/voelgoedevents/ash/domains/scanning_domain.ex";    Module = "Voelgoedevents.Ash.Domains.ScanningDomain";    Template = "ash_domain"; Desc = "Ash domain for scanning events and sessions."; },
    @{ Path = "lib/voelgoedevents/ash/domains/analytics_domain.ex";   Module = "Voelgoedevents.Ash.Domains.AnalyticsDomain";   Template = "ash_domain"; Desc = "Ash domain for analytics events and funnel snapshots."; },

    # Accounts resources
    @{ Path = "lib/voelgoedevents/ash/resources/accounts/user.ex";          Module = "Voelgoedevents.Ash.Resources.Accounts.User";          Template = "ash_resource"; Desc = "Ash resource: User accounts."; },
    @{ Path = "lib/voelgoedevents/ash/resources/accounts/role.ex";          Module = "Voelgoedevents.Ash.Resources.Accounts.Role";          Template = "ash_resource"; Desc = "Ash resource: Role definitions (admin, organizer, staff, etc.)."; },
    @{ Path = "lib/voelgoedevents/ash/resources/accounts/membership.ex";    Module = "Voelgoedevents.Ash.Resources.Accounts.Membership";    Template = "ash_resource"; Desc = "Ash resource: Membership linking users to organizations."; },

    # Organizations
    @{ Path = "lib/voelgoedevents/ash/resources/organizations/organization.ex"; Module = "Voelgoedevents.Ash.Resources.Organizations.Organization"; Template = "ash_resource"; Desc = "Ash resource: Organization/tenant."; },

    # Venues
    @{ Path = "lib/voelgoedevents/ash/resources/venues/venue.ex";     Module = "Voelgoedevents.Ash.Resources.Venues.Venue";     Template = "ash_resource"; Desc = "Ash resource: Venue details."; },
    @{ Path = "lib/voelgoedevents/ash/resources/venues/gate.ex";      Module = "Voelgoedevents.Ash.Resources.Venues.Gate";      Template = "ash_resource"; Desc = "Ash resource: Entry gates for scanning."; },

    # Events
    @{ Path = "lib/voelgoedevents/ash/resources/events/event.ex";                 Module = "Voelgoedevents.Ash.Resources.Events.Event";                 Template = "ash_resource"; Desc = "Ash resource: Event aggregate root."; },
    @{ Path = "lib/voelgoedevents/ash/resources/events/occupancy_snapshot.ex";    Module = "Voelgoedevents.Ash.Resources.Events.OccupancySnapshot";    Template = "ash_resource"; Desc = "Ash resource: Periodic occupancy snapshots for dashboards."; },

    # Seating
    @{ Path = "lib/voelgoedevents/ash/resources/seating/block.ex";    Module = "Voelgoedevents.Ash.Resources.Seating.Block";    Template = "ash_resource"; Desc = "Ash resource: Seating block/section."; },
    @{ Path = "lib/voelgoedevents/ash/resources/seating/seat.ex";     Module = "Voelgoedevents.Ash.Resources.Seating.Seat";     Template = "ash_resource"; Desc = "Ash resource: Individual seat."; },
    @{ Path = "lib/voelgoedevents/ash/resources/seating/layout.ex";   Module = "Voelgoedevents.Ash.Resources.Seating.Layout";   Template = "ash_resource"; Desc = "Ash resource: Seating layout version."; },

    # Ticketing
    @{ Path = "lib/voelgoedevents/ash/resources/ticketing/ticket.ex";        Module = "Voelgoedevents.Ash.Resources.Ticketing.Ticket";        Template = "ash_resource"; Desc = "Ash resource: Ticket with state machine."; },
    @{ Path = "lib/voelgoedevents/ash/resources/ticketing/pricing_rule.ex";  Module = "Voelgoedevents.Ash.Resources.Ticketing.PricingRule";  Template = "ash_resource"; Desc = "Ash resource: Pricing rules."; },
    @{ Path = "lib/voelgoedevents/ash/resources/ticketing/coupon.ex";        Module = "Voelgoedevents.Ash.Resources.Ticketing.Coupon";        Template = "ash_resource"; Desc = "Ash resource: Coupon codes."; },

    # Payments
    @{ Path = "lib/voelgoedevents/ash/resources/payments/transaction.ex";     Module = "Voelgoedevents.Ash.Resources.Payments.Transaction";     Template = "ash_resource"; Desc = "Ash resource: Payment transaction."; },
    @{ Path = "lib/voelgoedevents/ash/resources/payments/refund.ex";          Module = "Voelgoedevents.Ash.Resources.Payments.Refund";          Template = "ash_resource"; Desc = "Ash resource: Refunds."; },
    @{ Path = "lib/voelgoedevents/ash/resources/payments/ledger_account.ex";  Module = "Voelgoedevents.Ash.Resources.Payments.LedgerAccount";  Template = "ash_resource"; Desc = "Ash resource: Ledger accounts."; },
    @{ Path = "lib/voelgoedevents/ash/resources/payments/journal_entry.ex";   Module = "Voelgoedevents.Ash.Resources.Payments.JournalEntry";   Template = "ash_resource"; Desc = "Ash resource: Double-entry journal entries."; },

    # Scanning
    @{ Path = "lib/voelgoedevents/ash/resources/scanning/scan.ex";          Module = "Voelgoedevents.Ash.Resources.Scanning.Scan";          Template = "ash_resource"; Desc = "Ash resource: Scan event."; },
    @{ Path = "lib/voelgoedevents/ash/resources/scanning/scan_session.ex";  Module = "Voelgoedevents.Ash.Resources.Scanning.ScanSession";  Template = "ash_resource"; Desc = "Ash resource: Scan session."; },

    # Analytics
    @{ Path = "lib/voelgoedevents/ash/resources/analytics/analytics_event.ex";   Module = "Voelgoedevents.Ash.Resources.Analytics.AnalyticsEvent";   Template = "ash_resource"; Desc = "Ash resource: First-party analytics events."; },
    @{ Path = "lib/voelgoedevents/ash/resources/analytics/funnel_snapshot.ex";   Module = "Voelgoedevents.Ash.Resources.Analytics.FunnelSnapshot";   Template = "ash_resource"; Desc = "Ash resource: Funnel aggregates."; },

    # Policies & support
    @{ Path = "lib/voelgoedevents/ash/policies/common_policies.ex";   Module = "Voelgoedevents.Ash.Policies.CommonPolicies";   Template = "ash_policy_helper"; Desc = "Common Ash policy helpers."; },
    @{ Path = "lib/voelgoedevents/ash/policies/tenant_policies.ex";   Module = "Voelgoedevents.Ash.Policies.TenantPolicies";   Template = "ash_policy_helper"; Desc = "Tenant isolation and multi-tenant policies."; },

    @{ Path = "lib/voelgoedevents/ash/support/changes/seat_hold_change.ex";       Module = "Voelgoedevents.Ash.Support.Changes.SeatHoldChange";       Template = "simple"; Desc = "Change module stub for seat hold logic."; },
    @{ Path = "lib/voelgoedevents/ash/support/changes/pricing_change.ex";         Module = "Voelgoedevents.Ash.Support.Changes.PricingChange";         Template = "simple"; Desc = "Change module stub for pricing rules."; },
    @{ Path = "lib/voelgoedevents/ash/support/changes/transaction_change.ex";     Module = "Voelgoedevents.Ash.Support.Changes.TransactionChange";     Template = "simple"; Desc = "Change module stub for transaction updates."; },
    @{ Path = "lib/voelgoedevents/ash/support/calculations/price_calculations.ex";      Module = "Voelgoedevents.Ash.Support.Calculations.PriceCalculations";      Template = "simple"; Desc = "Price calculation helpers stub."; },
    @{ Path = "lib/voelgoedevents/ash/support/calculations/occupancy_calculations.ex";  Module = "Voelgoedevents.Ash.Support.Calculations.OccupancyCalculations";  Template = "simple"; Desc = "Occupancy calculation helpers stub."; },
    @{ Path = "lib/voelgoedevents/ash/support/validations/event_validations.ex";        Module = "Voelgoedevents.Ash.Support.Validations.EventValidations";        Template = "simple"; Desc = "Event validation helpers stub."; },
    @{ Path = "lib/voelgoedevents/ash/support/validations/seating_validations.ex";      Module = "Voelgoedevents.Ash.Support.Validations.SeatingValidations";      Template = "simple"; Desc = "Seating validation helpers stub."; },

    @{ Path = "lib/voelgoedevents/ash/notifiers/ash_notifier.ex";    Module = "Voelgoedevents.Ash.Notifiers.AshNotifier";    Template = "ash_notifier"; Desc = "Notifier stub for reacting to Ash changes."; },

    # Auth helpers
    @{ Path = "lib/voelgoedevents/auth/ash_auth.ex";        Module = "Voelgoedevents.Auth.AshAuth";        Template = "auth_helper"; Desc = "AshAuthentication configuration entry point."; },
    @{ Path = "lib/voelgoedevents/auth/user_tokens.ex";     Module = "Voelgoedevents.Auth.UserTokens";     Template = "simple";      Desc = "Stub for user token generation/verification."; },
    @{ Path = "lib/voelgoedevents/auth/pipeline_plugs.ex";  Module = "Voelgoedevents.Auth.PipelinePlugs";  Template = "plug_helper"; Desc = "Stub for auth-related Plug helpers."; },

    # Workflows
    @{ Path = "lib/voelgoedevents/workflows/checkout/start_checkout.ex";    Module = "Voelgoedevents.Workflows.Checkout.StartCheckout";    Template = "workflow"; Desc = "Workflow: start checkout."; },
    @{ Path = "lib/voelgoedevents/workflows/checkout/complete_checkout.ex"; Module = "Voelgoedevents.Workflows.Checkout.CompleteCheckout"; Template = "workflow"; Desc = "Workflow: complete checkout."; },
    @{ Path = "lib/voelgoedevents/workflows/ticketing/reserve_seat.ex";     Module = "Voelgoedevents.Workflows.Ticketing.ReserveSeat";     Template = "workflow"; Desc = "Workflow: reserve seat."; },
    @{ Path = "lib/voelgoedevents/workflows/ticketing/release_seat.ex";     Module = "Voelgoedevents.Workflows.Ticketing.ReleaseSeat";     Template = "workflow"; Desc = "Workflow: release seat."; },
    @{ Path = "lib/voelgoedevents/workflows/scanning/process_scan.ex";      Module = "Voelgoedevents.Workflows.Scanning.ProcessScan";      Template = "workflow"; Desc = "Workflow: process scan."; },
    @{ Path = "lib/voelgoedevents/workflows/analytics/funnel_builder.ex";   Module = "Voelgoedevents.Workflows.Analytics.FunnelBuilder";   Template = "workflow"; Desc = "Workflow: build funnel snapshots."; },

    # Caching
    @{ Path = "lib/voelgoedevents/caching/seat_cache.ex";       Module = "Voelgoedevents.Caching.SeatCache";       Template = "caching"; Desc = "Seat availability cache stub."; },
    @{ Path = "lib/voelgoedevents/caching/pricing_cache.ex";    Module = "Voelgoedevents.Caching.PricingCache";    Template = "caching"; Desc = "Pricing rules cache stub."; },
    @{ Path = "lib/voelgoedevents/caching/occupancy_cache.ex";  Module = "Voelgoedevents.Caching.OccupancyCache";  Template = "caching"; Desc = "Occupancy cache stub."; },
    @{ Path = "lib/voelgoedevents/caching/rate_limiter.ex";     Module = "Voelgoedevents.Caching.RateLimiter";     Template = "caching"; Desc = "Rate limiter stub."; },

    # Queues / workers
    @{ Path = "lib/voelgoedevents/queues/oban_config.ex";             Module = "Voelgoedevents.Queues.ObanConfig";             Template = "queue_config"; Desc = "Central Oban configuration stub."; },
    @{ Path = "lib/voelgoedevents/queues/worker_send_email.ex";       Module = "Voelgoedevents.Queues.WorkerSendEmail";       Template = "queue_worker"; Desc = "Oban worker stub for sending emails."; },
    @{ Path = "lib/voelgoedevents/queues/worker_generate_pdf.ex";     Module = "Voelgoedevents.Queues.WorkerGeneratePdf";     Template = "queue_worker"; Desc = "Oban worker stub for generating PDFs."; },
    @{ Path = "lib/voelgoedevents/queues/worker_cleanup_holds.ex";    Module = "Voelgoedevents.Queues.WorkerCleanupHolds";    Template = "queue_worker"; Desc = "Oban worker stub for cleaning up seat holds."; },
    @{ Path = "lib/voelgoedevents/queues/worker_analytics_export.ex"; Module = "Voelgoedevents.Queues.WorkerAnalyticsExport"; Template = "queue_worker"; Desc = "Oban worker stub for exporting analytics."; },

    # Analytics helpers
    @{ Path = "lib/voelgoedevents/analytics/funnels.ex";  Module = "Voelgoedevents.Analytics.Funnels";  Template = "analytics"; Desc = "Analytics funnels query helpers stub."; },
    @{ Path = "lib/voelgoedevents/analytics/reports.ex";  Module = "Voelgoedevents.Analytics.Reports";  Template = "analytics"; Desc = "Analytics report generation stub."; },

    # Contracts: API
    @{ Path = "lib/voelgoedevents/contracts/api/checkout_contract.ex";   Module = "Voelgoedevents.Contracts.Api.CheckoutContract";   Template = "contract"; Desc = "API contract stub for checkout endpoints."; },
    @{ Path = "lib/voelgoedevents/contracts/api/ticket_contract.ex";     Module = "Voelgoedevents.Contracts.Api.TicketContract";     Template = "contract"; Desc = "API contract stub for ticket endpoints."; },
    @{ Path = "lib/voelgoedevents/contracts/api/event_contract.ex";      Module = "Voelgoedevents.Contracts.Api.EventContract";      Template = "contract"; Desc = "API contract stub for event endpoints."; },
    @{ Path = "lib/voelgoedevents/contracts/api/analytics_contract.ex";  Module = "Voelgoedevents.Contracts.Api.AnalyticsContract";  Template = "contract"; Desc = "API contract stub for analytics endpoints."; },

    # Contracts: Workflows
    @{ Path = "lib/voelgoedevents/contracts/workflows/checkout_contract.ex"; Module = "Voelgoedevents.Contracts.Workflows.CheckoutContract"; Template = "contract"; Desc = "Workflow contract stub for checkout."; },
    @{ Path = "lib/voelgoedevents/contracts/workflows/scan_contract.ex";     Module = "Voelgoedevents.Contracts.Workflows.ScanContract";     Template = "contract"; Desc = "Workflow contract stub for scanning."; },

    # Web plugs
    @{ Path = "lib/voelgoedevents_web/plugs/current_user_plug.ex";   Module = "VoelgoedeventsWeb.Plugs.CurrentUserPlug";   Template = "plug_helper"; Desc = "Plug stub for loading current_user."; },
    @{ Path = "lib/voelgoedevents_web/plugs/current_org_plug.ex";    Module = "VoelgoedeventsWeb.Plugs.CurrentOrgPlug";    Template = "plug_helper"; Desc = "Plug stub for loading current organization."; },
    @{ Path = "lib/voelgoedevents_web/plugs/analytics_plug.ex";      Module = "VoelgoedeventsWeb.Plugs.AnalyticsPlug";      Template = "plug_helper"; Desc = "Plug stub for attaching analytics context."; }
)

$modules | ForEach-Object {
    Ensure-ElixirModule -Path $_.Path -ModuleName $_.Module -Template $_.Template -Description $_.Desc
}

########### TEST MODULES ###########

$testModules = @(
    @{ Path = "test/voelgoedevents/ash/accounts_test.exs";        Module = "Voelgoedevents.Ash.AccountsTest";        Template = "data_case"; Desc = "Basic tests for accounts domain."; },
    @{ Path = "test/voelgoedevents/ash/events_test.exs";          Module = "Voelgoedevents.Ash.EventsTest";          Template = "data_case"; Desc = "Basic tests for events domain."; },
    @{ Path = "test/voelgoedevents/ash/seating_test.exs";         Module = "Voelgoedevents.Ash.SeatingTest";         Template = "data_case"; Desc = "Basic tests for seating domain."; },
    @{ Path = "test/voelgoedevents/ash/ticketing_test.exs";       Module = "Voelgoedevents.Ash.TicketingTest";       Template = "data_case"; Desc = "Basic tests for ticketing domain."; },
    @{ Path = "test/voelgoedevents/ash/payments_test.exs";        Module = "Voelgoedevents.Ash.PaymentsTest";        Template = "data_case"; Desc = "Basic tests for payments domain."; },
    @{ Path = "test/voelgoedevents/ash/analytics_test.exs";       Module = "Voelgoedevents.Ash.AnalyticsTest";       Template = "data_case"; Desc = "Basic tests for analytics domain."; },

    @{ Path = "test/voelgoedevents/workflows/checkout_workflow_test.exs"; Module = "Voelgoedevents.Workflows.CheckoutWorkflowTest"; Template = "data_case"; Desc = "Basic tests for checkout workflows."; },
    @{ Path = "test/voelgoedevents/workflows/scanning_workflow_test.exs"; Module = "Voelgoedevents.Workflows.ScanningWorkflowTest"; Template = "data_case"; Desc = "Basic tests for scanning workflows."; },

    @{ Path = "test/voelgoedevents/caching/seat_cache_test.exs";  Module = "Voelgoedevents.Caching.SeatCacheTest";  Template = "data_case"; Desc = "Basic tests for seat cache behaviour."; },

    @{ Path = "test/voelgoedevents_web/controllers/page_controller_test.exs"; Module = "VoelgoedeventsWeb.PageControllerTest"; Template = "conn_case"; Desc = "Controller tests stub for page controller."; },
    @{ Path = "test/voelgoedevents_web/live/event_live_test.exs";            Module = "VoelgoedeventsWeb.EventLiveTest";      Template = "live_case"; Desc = "LiveView tests stub for event views."; },
    @{ Path = "test/voelgoedevents_web/live/checkout_live_test.exs";         Module = "VoelgoedeventsWeb.CheckoutLiveTest";   Template = "live_case"; Desc = "LiveView tests stub for checkout views."; }
)

$testModules | ForEach-Object {
    Ensure-ElixirTestModule -Path $_.Path -ModuleName $_.Module -Template $_.Template -Description $_.Desc
}

########### TYPESCRIPT FILES ###########

$tsFiles = @(
    @{ Path = "assets/js/types/Event.ts";          Desc = "Event DTO used by LiveView and JS hooks."; Kind = "dto"; },
    @{ Path = "assets/js/types/Seat.ts";           Desc = "Seat DTO used by LiveView and JS hooks."; Kind = "dto"; },
    @{ Path = "assets/js/types/Ticket.ts";         Desc = "Ticket DTO used by LiveView and JS hooks."; Kind = "dto"; },
    @{ Path = "assets/js/types/Checkout.ts";       Desc = "Checkout request/response Types."; Kind = "dto"; },
    @{ Path = "assets/js/types/AnalyticsEvents.ts";Desc = "Analytics events type definitions for the web app."; Kind = "analytics_events"; },

    @{ Path = "scanner_pwa/src/lib/types/Scan.ts";    Desc = "Scanner PWA: scan request/response types."; Kind = "dto"; },
    @{ Path = "scanner_pwa/src/lib/types/Session.ts"; Desc = "Scanner PWA: session / device / gate types."; Kind = "dto"; },
    @{ Path = "scanner_pwa/src/lib/types/Tickets.ts"; Desc = "Scanner PWA: minimal ticket view types."; Kind = "dto"; }
)

$tsFiles | ForEach-Object {
    Ensure-TsFile -Path $_.Path -Description $_.Desc -Kind $_.Kind
}

Write-Host "Module scaffolding completed."
