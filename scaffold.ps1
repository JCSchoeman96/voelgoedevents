# scaffold.ps1
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

function Get-CommentPrefix {
    param([string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".ex"  { return "# " }
        ".exs" { return "# " }
        ".js"  { return "// " }
        ".ts"  { return "// " }
        ".yaml" { return "# " }
        ".yml"  { return "# " }
        ".md"  { return "" }
        default { return "# " } # safe default
    }
}

function Ensure-File-With-Header {
    param(
        [string]$Path,
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

    if ($isNewOrEmpty) {
        $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

        if ($ext -eq ".json") {
            $json = @"
{
  "__comment": "$Description"
}
"@
            Set-Content -Path $Path -Value $json -Encoding UTF8
        }
        elseif ($ext -eq ".md") {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
            $content = "# $name`r`n`r`n$Description`r`n"
            Set-Content -Path $Path -Value $content -Encoding UTF8
        }
        else {
            $prefix = Get-CommentPrefix -Path $Path
            $header = "$prefix$Description`r`n`r`n"
            Set-Content -Path $Path -Value $header -Encoding UTF8
        }

        Write-Host "Created file with header: $Path"
    } else {
        Write-Host "Skipping existing non-empty file: $Path"
    }
}

########### 1) DIRECTORIES ###########

$directories = @(
    # Docs
    "docs",
    "docs/architecture",
    "docs/domain",
    "docs/workflows",
    "docs/api",
    "docs/integration",
    "docs/ai",
    "docs/project",

    # Ash & domain under lib/voelgoedevents
    "lib/voelgoedevents/ash",
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

    # Other backend structures
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

    # Web layer is already there but we might extend subdirs
    "lib/voelgoedevents_web/live/event",
    "lib/voelgoedevents_web/live/checkout",
    "lib/voelgoedevents_web/live/admin",
    "lib/voelgoedevents_web/live/seating",
    "lib/voelgoedevents_web/plugs",

    # Assets
    "assets/js/hooks",
    "assets/js/types",
    "assets/css",

    # Scanner PWA (future)
    "scanner_pwa/src/lib/api",
    "scanner_pwa/src/lib/stores",
    "scanner_pwa/src/lib/types",
    "scanner_pwa/src/lib/components",

    # Schemas
    "schemas",

    # Tests
    "test/support",
    "test/voelgoedevents/ash",
    "test/voelgoedevents/workflows",
    "test/voelgoedevents/caching",
    "test/voelgoedevents_web/controllers",
    "test/voelgoedevents_web/live",
    "test/voelgoedevents_web/features"
)

$directories | ForEach-Object { Ensure-Dir $_ }

########### 2) FILES ###########

$files = @(
    # --- Docs: architecture ---
    @{ Path = "docs/architecture/overview.md";               Desc = "High-level overview of Voelgoedevents architecture."; },
    @{ Path = "docs/architecture/backend.md";                Desc = "Backend architecture: Ash domains, workflows, queues, caching."; },
    @{ Path = "docs/architecture/frontend.md";               Desc = "Frontend architecture: LiveView, PWA, shared TS types."; },
    @{ Path = "docs/architecture/data_flow_ticketing.md";    Desc = "Detailed data flow for ticket purchase and checkout."; },
    @{ Path = "docs/architecture/data_flow_scanning.md";     Desc = "Detailed data flow for scanning (online + offline)."; },
    @{ Path = "docs/architecture/caching_and_performance.md";Desc = "Caching strategy, Redis/ETS usage, TTL, and performance notes."; },
    @{ Path = "docs/architecture/security_and_policies.md";  Desc = "Security model: tenancy, roles, Ash policies."; },
    @{ Path = "docs/architecture/type_safety.md";            Desc = "Global type safety strategy for backend, frontend, and contracts."; },

    # --- Docs: domain ---
    @{ Path = "docs/domain/domain_map.md";        Desc = "Canonical Voelgoedevents domain map."; },
    @{ Path = "docs/domain/tenancy.md";           Desc = "Tenancy domain: Organization, Membership, Role."; },
    @{ Path = "docs/domain/accounts.md";          Desc = "Accounts domain: User, authentication, sessions."; },
    @{ Path = "docs/domain/venues.md";            Desc = "Venues domain: Venue, Gate."; },
    @{ Path = "docs/domain/events.md";            Desc = "Events domain: Event, OccupancySnapshot."; },
    @{ Path = "docs/domain/seating.md";           Desc = "Seating domain: Layout, Block, Seat."; },
    @{ Path = "docs/domain/ticketing.md";         Desc = "Ticketing domain: Ticket, PricingRule, Coupon."; },
    @{ Path = "docs/domain/payments.md";          Desc = "Payments domain: Transaction, Refund, LedgerAccount, JournalEntry."; },
    @{ Path = "docs/domain/scanning.md";          Desc = "Scanning domain: Scan, ScanSession, device handling."; },
    @{ Path = "docs/domain/analytics.md";         Desc = "Analytics domain: AnalyticsEvent, FunnelSnapshot."; },
    @{ Path = "docs/domain/integrations.md";      Desc = "Integrations domain: webhooks, API keys, exports."; },
    @{ Path = "docs/domain/invariants_global.md"; Desc = "Global invariants: no overselling, ledger consistency, tenant isolation."; },

    # --- Docs: workflows ---
    @{ Path = "docs/workflows/start_checkout.md";     Desc = "Workflow spec for start_checkout."; },
    @{ Path = "docs/workflows/complete_checkout.md";  Desc = "Workflow spec for complete_checkout."; },
    @{ Path = "docs/workflows/reserve_seat.md";       Desc = "Workflow spec for reserve_seat."; },
    @{ Path = "docs/workflows/release_seat.md";       Desc = "Workflow spec for release_seat."; },
    @{ Path = "docs/workflows/process_scan.md";       Desc = "Workflow spec for process_scan."; },
    @{ Path = "docs/workflows/offline_scan_sync.md";  Desc = "Workflow spec for offline scan sync."; },
    @{ Path = "docs/workflows/funnel_builder.md";     Desc = "Workflow spec for building funnel snapshots."; },
    @{ Path = "docs/workflows/seat_hold_registry.md"; Desc = "Conceptual doc for seat hold registry & TTL."; },

    # --- Docs: API ---
    @{ Path = "docs/api/public_api.md";          Desc = "Public API surface (external consumers)."; },
    @{ Path = "docs/api/internal_api.md";        Desc = "Internal API endpoints for web app and PWA."; },
    @{ Path = "docs/api/scanner_api.md";         Desc = "Scanner API endpoints and contracts."; },
    @{ Path = "docs/api/webhook_api.md";         Desc = "Webhook delivery format and endpoint behaviour."; },
    @{ Path = "docs/api/contracts_reference.md"; Desc = "Mapping between endpoints, contract modules, schemas, and TS types."; },

    # --- Docs: Integration ---
    @{ Path = "docs/integration/payment_providers.md";    Desc = "Payment provider integration strategy."; },
    @{ Path = "docs/integration/crm_integrations.md";     Desc = "CRM integration plans."; },
    @{ Path = "docs/integration/marketing_analytics.md";  Desc = "Marketing/GA4/GTM strategy if used."; },
    @{ Path = "docs/integration/webhook_delivery.md";     Desc = "Webhook delivery pipeline, retries, DLQ."; },
    @{ Path = "docs/integration/exporting_data.md";       Desc = "Data export flows (CSV/JSON)."; },

    # --- Docs: AI ---
    @{ Path = "docs/ai/agent_rules.md";           Desc = "Rules and expectations for AI coding agents in this repo."; },
    @{ Path = "docs/ai/coding_guidelines.md";     Desc = "Coding guidelines for Elixir, Ash, LiveView, and PWA."; },
    @{ Path = "docs/ai/type_safety_standards.md"; Desc = "Strict type safety standards for all generated code."; },
    @{ Path = "docs/ai/file_navigation.md";       Desc = "How AI agents should navigate files and directories."; },
    @{ Path = "docs/ai/prompts_examples.md";      Desc = "Sample prompts for common coding tasks in this project."; },

    # --- Docs: Project ---
    @{ Path = "docs/project/roadmap.md";            Desc = "Phase-based roadmap for Voelgoedevents."; },
    @{ Path = "docs/project/release_process.md";    Desc = "Release and deployment process."; },
    @{ Path = "docs/project/testing_strategy.md";   Desc = "Overall test strategy (unit, integration, E2E)."; },
    @{ Path = "docs/project/environment_setup.md";  Desc = "Environment setup and onboarding guide."; },
    @{ Path = "docs/project/glossary.md";           Desc = "Glossary of domain terms and abbreviations."; },

    # --- Schemas ---
    @{ Path = "schemas/openapi.yaml";             Desc = "OpenAPI specification for HTTP APIs."; },
    @{ Path = "schemas/analytics.schema.json";    Desc = "JSON Schema for analytics events payloads."; },
    @{ Path = "schemas/checkout.schema.json";     Desc = "JSON Schema for checkout request/response."; }
)

$files | ForEach-Object {
    Ensure-File-With-Header -Path $_.Path -Description $_.Desc
}

Write-Host "Scaffolding completed."
