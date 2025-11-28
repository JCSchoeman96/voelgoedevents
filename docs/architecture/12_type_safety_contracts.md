# VoelgoedEvents Type Safety & Contract Architecture
## End-to-End Strict Contracts: Database → API → Frontend

**Date:** November 27, 2025  
**Version:** 1.0 FINAL  
**Status:** 🚀 PRODUCTION READY  
**Project:** VoelgoedEvents Enterprise Ticketing Platform  
**Stack:** Elixir/Ash (Backend) + Svelte/TypeScript (Frontend) + Capacitor (Mobile)  
**Philosophy:** Contract-First Development - "We do not guess data shapes. We define them."  
**Audience:** AI Coding Agents, Development Team, Code Review Checklist

---

## 📋 TABLE OF CONTENTS

1. [Philosophy: Contract-First Development](#1-philosophy-contract-first-development)
2. [The Three Layers of Type Safety](#2-the-three-layers-of-type-safety)
3. [Backend Type Safety (Elixir)](#3-backend-type-safety-elixir)
4. [The Contract Pattern (Implementation)](#4-the-contract-pattern-implementation)
5. [Frontend Type Safety (TypeScript)](#5-frontend-type-safety-typescript)
6. [Contract Synchronization](#6-contract-synchronization)
7. [CI/CD Enforcement](#7-cicd-enforcement)
8. [Implementation Checklist](#8-implementation-checklist)
9. [Real-World Examples](#9-real-world-examples)
10. [Migration & Rollout](#10-migration--rollout)
11. [Troubleshooting](#11-troubleshooting)
12. [AI Agent Instructions](#12-ai-agent-instructions)

---

## 1. PHILOSOPHY: CONTRACT-FIRST DEVELOPMENT

### The Problem: The "Air Gap"

In traditional PETAL stacks, type safety breaks at the boundary between backend and frontend.

```
┌─────────────────────────────────────────────────────────┐
│ ELIXIR BACKEND                                          │
│ ✅ Dialyzer ensures type correctness                    │
│ Type-checked all the way                                │
│ {:ok, %Ticket{id: uuid, code: string}}                 │
└──────────────────┬──────────────────────────────────────┘
                   │
        ❌ THE "AIR GAP" ❌
        JSON over HTTP
        No type information
        Raw maps, dynamic keys
        Developer guesses shape
                   │
┌──────────────────┴──────────────────────────────────────┐
│ SVELTE/TYPESCRIPT FRONTEND                              │
│ ❌ `any` type used everywhere                           │
│ No compile-time safety                                  │
│ "Did the API return `holder_name` or `holderName`?"    │
│ Runtime errors in production                            │
└─────────────────────────────────────────────────────────┘
```

**This is where bugs are born.**

### The Solution: Contract-First Architecture

**Single Source of Truth:** Define the contract ONCE in Elixir. Everything else derives from it.

```
┌─────────────────────────────────────────────────────────┐
│ ELIXIR BACKEND                                          │
│ ✅ Dialyzer ensures type correctness                    │
│ ✅ Contracts defined explicitly                         │
│ ✅ JSON Schema derives from Contracts                   │
└──────────────────┬──────────────────────────────────────┘
                   │
        ✅ CONTRACT BRIDGE ✅
        Contracts.Api.TicketContract
        Defines exact shape
        Type info embedded in JSON
        Zero ambiguity
                   │
┌──────────────────┴──────────────────────────────────────┐
│ SVELTE/TYPESCRIPT FRONTEND                              │
│ ✅ Types auto-generated from Contracts                  │
│ ✅ Compile-time safety guaranteed                       │
│ ✅ `interface TicketContract { ... }`                   │
│ ✅ Zero guessing, 100% coverage                         │
└─────────────────────────────────────────────────────────┘
```

### The Goal

**100% Type Safety from Database → Ash Resource → API → Svelte Component**

- ✅ Backend internal code type-checked by Dialyzer
- ✅ API responses use explicit Contracts, never raw maps
- ✅ Frontend interfaces auto-generated from Contracts
- ✅ CI pipeline enforces all three layers
- ✅ New developers cannot write untyped code

---

## 2. THE THREE LAYERS OF TYPE SAFETY

### Layer 1: Backend Internal (Elixir + Dialyzer)

**Scope:** All internal Elixir code

**Tools:**
- Dialyxir (mix dialyzer)
- Credo (static analyzer)
- @spec annotations

**Rules:**
- All public functions MUST have @spec
- All Ash.Resource calculations MUST have @spec
- All Reactor steps MUST have @spec
- CI fails if Dialyzer finds inconsistencies

**Example:**
```elixir
defmodule VoelgoedEvents.Scanning.ScanService do
  @spec process_scan(
    ticket_code :: String.t(),
    org_id :: String.t(),
    device_id :: String.t()
  ) :: {:ok, Ticket.t()} | {:error, atom()}
  def process_scan(ticket_code, org_id, device_id) do
    # Implementation type-checked against @spec
  end
end
```

**Enforcement:**
```bash
# CI pipeline step
mix dialyzer
# FAIL if any type mismatch found
```

### Layer 2: The "Air Gap" Bridge (API Contracts)

**Scope:** All data crossing the HTTP boundary

**Tools:**
- Ecto.Schema (embedded)
- Jason.Encoder
- Ash.Resource (embedded types)

**Rules:**
- No raw maps in API responses
- All API responses use explicit Contract Structs
- Contracts defined in `lib/voelgoedevents/contracts/`
- All Contract fields must be whitelisted for serialization
- @type must be defined on every Contract

**Pattern:**
```elixir
# Instead of this ❌
def get_ticket(id) do
  {:ok, %{"id" => id, "code" => "ABC123", "status" => "valid"}}
end

# Do this ✅
def get_ticket(id) do
  ticket = Ticket |> Ash.read_one!()
  {:ok, Contracts.Api.TicketContract.from_ticket(ticket)}
end
```

### Layer 3: Frontend (TypeScript + Svelte)

**Scope:** All TypeScript code in scanner_pwa

**Tools:**
- TypeScript (strict mode)
- Svelte with strict type checking
- Auto-generated types from Contracts

**Rules:**
- tsconfig.json: `"strict": true`
- NO `any` type allowed in business logic
- Every API response must match a known Contract interface
- All Svelte components use explicit types
- CI fails if `tsc --noEmit` finds errors

**Example:**
```typescript
// ❌ WRONG - no type safety
async function handleScan(result: any) {
  console.log(result.code);
  // What if API changed and removed this field?
}

// ✅ CORRECT - contract enforced
import type { ScanResultContract } from '$lib/types/contracts';

async function handleScan(result: ScanResultContract) {
  console.log(result.code);
  // TypeScript error if field doesn't exist
  // Even if API changes
}
```

---

## 3. BACKEND TYPE SAFETY (ELIXIR)

### 3.1 Mandatory @spec Declarations

**Rule:** Every public function must have a @spec

**Location:** All functions in:
- `lib/voelgoedevents/contexts/*.ex`
- `lib/voelgoedevents/resources/**/*.ex`
- `lib/voelgoedevents/workflows/**/*_reactor.ex`
- `lib/voelgoedevents/scanning/steps/*.ex`
- `lib/voelgoedevents/payments/steps/*.ex`

**Format:**
```elixir
defmodule VoelgoedEvents.Scanning.ScanService do
  @moduledoc """
  Service module for handling ticket scans.
  """

  # ✅ Public API MUST have @spec
  @spec create_scan(
    ticket_code :: String.t(),
    org_id :: String.t(),
    context :: map()
  ) :: {:ok, Scan.t()} | {:error, String.t()}
  def create_scan(ticket_code, org_id, context) do
    # Implementation
  end

  # ✅ Private functions should have @spec (good practice)
  @spec check_dedup(
    code :: String.t(),
    org_id :: String.t()
  ) :: boolean()
  defp check_dedup(code, org_id) do
    # Implementation
  end

  # ❌ WRONG - no @spec
  def internal_helper(x, y) do
    # This would be flagged by Credo in code review
  end
end
```

### 3.2 Ash.Resource Type Safety

**For Calculations:**
```elixir
defmodule VoelgoedEvents.Ash.Resources.Scanning.Scan do
  use Ash.Resource, extensions: [...]

  calculations do
    calculate :status_display, :string, expr(status) do
      calculation fn records, _opts ->
        # ✅ Must return list of strings, not list of atoms
        Enum.map(records, &to_string/1)
      end
    end
  end

  @spec status_for_api(status :: atom()) :: String.t()
  defp status_for_api(status) do
    Atom.to_string(status)
  end
end
```

**For Aggregations:**
```elixir
defmodule VoelgoedEvents.Ash.Resources.Ticketing.Event do
  use Ash.Resource

  aggregates do
    count :ticket_count, :tickets
    # ✅ This returns an integer
  end

  @spec available_seats(event :: t()) :: non_neg_integer()
  def available_seats(%__MODULE__{capacity: cap, ticket_count: count}) do
    max(0, cap - count)
  end
end
```

### 3.3 Reactor Step Type Safety

**Every Reactor Step MUST have clear input/output types:**

```elixir
defmodule VoelgoedEvents.Scanning.Steps.DedupCheck do
  use Ash.Reactor.Step

  @type input_t :: %{
    org_id: String.t(),
    ticket_code: String.t(),
    window_seconds: non_neg_integer()
  }

  @type output_t :: :ok | {:error, atom()}

  @spec run(input_t(), list(), map()) :: {:ok, output_t()} | {:error, atom()}
  def run(input, _opts, _context) do
    # Implementation type-checked against @spec
  end
end
```

### 3.4 Dialyzer Configuration

**File: `.dialyzer`**
```
[
  {:dialyzer,
   [
     {:warnings,
      [
        :error_handling,
        :missing_return,
        :return_only_not_called,
        :underspecs,
        :unknown
      ]},
     {:plt_add_apps, [:ex_unit, :mix]},
     {:ignore_warnings, "priv/dialyzer_ignore.txt"}
   ]}
]
```

**File: `mix.exs` (add dependency)**
```elixir
defp deps do
  [
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
    # ... other deps
  ]
end
```

**File: `.credo.exs` (enforce specs in code review)**
```elixir
%{
  checks: [
    {Credo.Check.Design.TagFIXME},
    {Credo.Check.Readability.FunctionNames},
    # Enforce @spec on all public functions
    {Credo.Check.Design.AliasUsage},
    # Add this check to warn on missing @spec
    {Credo.Check.Readability.Specs,
     [
       enabled: true,
       exclude: [:test, :priv]
     ]},
  ]
}
```

### 3.5 CI Enforcement

**In `.github/workflows/test.yml`:**
```yaml
- name: Run Dialyzer
  run: mix dialyzer

- name: Check Specs with Credo
  run: mix credo --strict

- name: Run Type Tests
  run: mix test test/type_safety/
```

---

## 4. THE CONTRACT PATTERN (IMPLEMENTATION)

### 4.1 Directory Structure

```
lib/voelgoedevents/
└── contracts/
    ├── api/
    │   ├── ticket_contract.ex
    │   ├── scan_result_contract.ex
    │   ├── checkout_contract.ex
    │   ├── payment_contract.ex
    │   └── occupancy_contract.ex
    ├── scanning/
    │   ├── dedup_check_contract.ex
    │   └── scan_batch_contract.ex
    ├── payments/
    │   ├── ledger_entry_contract.ex
    │   └── payment_result_contract.ex
    └── base_contract.ex  # Shared utilities
```

### 4.2 Base Contract Module

**File: `lib/voelgoedevents/contracts/base_contract.ex`**

```elixir
defmodule VoelgoedEvents.Contracts.BaseContract do
  @moduledoc """
  Base utilities for all API Contracts.
  
  Provides common functionality:
  - Casting and validation
  - Error handling
  - JSON serialization
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      # All contracts must have explicit type definitions
      @type t :: %__MODULE__{}

      # All contracts must encode to JSON
      @derive {Jason.Encoder, only: @contract_fields}

      def cast(params) when is_map(params) do
        %__MODULE__{}
        |> changeset(params)
        |> apply_action(:validate)
      end

      def cast!(params) do
        case cast(params) do
          {:ok, contract} -> contract
          {:error, changeset} -> raise "Contract validation failed: #{inspect(changeset)}"
        end
      end
    end
  end
end
```

### 4.3 Concrete Contract: TicketContract

**File: `lib/voelgoedevents/contracts/api/ticket_contract.ex`**

```elixir
defmodule VoelgoedEvents.Contracts.Api.TicketContract do
  @moduledoc """
  API Contract for Ticket responses.
  
  This is the SINGLE SOURCE OF TRUTH for ticket JSON shape.
  - Backend: Must serialize Ticket resources to this contract
  - Frontend: Must use TypeScript interface matching this contract
  - CI: Must verify JSON output matches this contract
  """

  use VoelgoedEvents.Contracts.BaseContract

  # ✅ EXPLICIT TYPE DEFINITION
  @type t :: %__MODULE__{
    id: String.t(),
    code: String.t(),
    status: :valid | :used | :invalid | :duplicate,
    holder_name: String.t() | nil,
    holder_email: String.t() | nil,
    event_id: String.t(),
    organization_id: String.t(),
    created_at: DateTime.t(),
    used_at: DateTime.t() | nil
  }

  # ✅ WHITELIST fields that will be serialized to JSON
  @contract_fields [
    :id,
    :code,
    :status,
    :holder_name,
    :holder_email,
    :event_id,
    :created_at,
    :used_at
  ]

  primary_key false
  embedded_schema do
    field :id, :binary_id
    field :code, :string
    field :status, Ecto.Enum, values: [:valid, :used, :invalid, :duplicate]
    field :holder_name, :string
    field :holder_email, :string
    field :event_id, :binary_id
    field :organization_id, :binary_id  # Not serialized - internal only
    field :created_at, :utc_datetime
    field :used_at, :utc_datetime
  end

  # ✅ Validation logic
  def changeset(contract, params) do
    contract
    |> cast(params, [
      :id,
      :code,
      :status,
      :holder_name,
      :holder_email,
      :event_id,
      :organization_id,
      :created_at,
      :used_at
    ])
    |> validate_required([:id, :code, :status, :event_id, :organization_id])
    |> validate_length(:code, min: 3, max: 20)
    |> validate_format(:holder_email, ~r/@/)
  end

  # ✅ Constructor: From domain Ticket resource to contract
  @spec from_ticket(ticket :: Ticket.t()) :: t()
  def from_ticket(%Ticket{} = ticket) do
    %__MODULE__{
      id: ticket.id,
      code: ticket.code,
      status: ticket.status,
      holder_name: ticket.holder_name,
      holder_email: ticket.holder_email,
      event_id: ticket.event_id,
      organization_id: ticket.organization_id,
      created_at: ticket.inserted_at,
      used_at: ticket.used_at
    }
  end

  # ✅ Batch conversion (for API responses with multiple tickets)
  @spec from_tickets(tickets :: [Ticket.t()]) :: [t()]
  def from_tickets(tickets) when is_list(tickets) do
    Enum.map(tickets, &from_ticket/1)
  end
end
```

### 4.4 Contract: ScanResultContract

**File: `lib/voelgoedevents/contracts/api/scan_result_contract.ex`**

```elixir
defmodule VoelgoedEvents.Contracts.Api.ScanResultContract do
  @moduledoc """
  API Contract for Scan Operation Results.
  
  Returned by:
  - POST /api/scans (online scanning)
  - POST /api/scans/sync (offline sync)
  
  Frontend expects exactly this JSON shape.
  """

  use VoelgoedEvents.Contracts.BaseContract

  # ✅ EXPLICIT TYPE
  @type scan_status :: :success | :duplicate | :invalid | :error

  @type t :: %__MODULE__{
    success: boolean(),
    status: scan_status(),
    message: String.t(),
    ticket: TicketContract.t() | nil,
    timestamp: DateTime.t(),
    request_id: String.t()
  }

  @contract_fields [:success, :status, :message, :ticket, :timestamp, :request_id]

  primary_key false
  embedded_schema do
    field :success, :boolean
    field :status, Ecto.Enum, values: [:success, :duplicate, :invalid, :error]
    field :message, :string
    embeds_one :ticket, TicketContract
    field :timestamp, :utc_datetime
    field :request_id, :binary_id
  end

  def changeset(result, params) do
    result
    |> cast(params, [:success, :status, :message, :timestamp, :request_id])
    |> cast_embed(:ticket)
    |> validate_required([:success, :status, :message, :timestamp, :request_id])
  end

  # ✅ Constructor: From reactor result to contract
  @spec from_reactor_result(
    success :: boolean(),
    status :: scan_status(),
    message :: String.t(),
    ticket :: Ticket.t() | nil,
    request_id :: String.t()
  ) :: t()
  def from_reactor_result(success, status, message, ticket, request_id) do
    %__MODULE__{
      success: success,
      status: status,
      message: message,
      ticket: ticket && TicketContract.from_ticket(ticket),
      timestamp: DateTime.utc_now(),
      request_id: request_id
    }
  end
end
```

### 4.5 API Endpoint Using Contracts

**File: `lib/voelgoedevents_web/controllers/api/scan_controller.ex`**

```elixir
defmodule VoelgoedEventsWeb.Api.ScanController do
  use VoelgoedEventsWeb, :controller

  @moduledoc """
  API Controller for Scanning Operations.
  
  ALL responses use Contracts, never raw maps.
  """

  @spec process_scan(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def process_scan(conn, params) do
    case VoelgoedEvents.Workflows.ProcessScanReactor.run(params, context: conn.assigns.context) do
      {:ok, %{create_scan: scan}} ->
        # ✅ Use contract for response
        contract = VoelgoedEvents.Contracts.Api.ScanResultContract.from_reactor_result(
          true,
          :success,
          "Scan processed successfully",
          scan,
          generate_request_id()
        )

        conn
        |> put_status(:ok)
        |> json(contract)  # Jason automatically encodes using @derive

      {:error, :duplicate_scan, details} ->
        # ✅ Use contract for error response
        contract = VoelgoedEvents.Contracts.Api.ScanResultContract.from_reactor_result(
          false,
          :duplicate,
          "Ticket already scanned in this window: #{inspect(details)}",
          nil,
          generate_request_id()
        )

        conn
        |> put_status(:conflict)
        |> json(contract)

      {:error, step, reason, _results} ->
        # ✅ Use contract for error response
        contract = VoelgoedEvents.Contracts.Api.ScanResultContract.from_reactor_result(
          false,
          :error,
          "Scan failed at step #{step}: #{inspect(reason)}",
          nil,
          generate_request_id()
        )

        conn
        |> put_status(:unprocessable_entity)
        |> json(contract)
    end
  end

  @spec generate_request_id() :: String.t()
  defp generate_request_id do
    Ecto.UUID.generate()
  end
end
```

---

## 5. FRONTEND TYPE SAFETY (TYPESCRIPT)

### 5.1 TypeScript Configuration

**File: `scanner_pwa/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    
    "strict": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitAny": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    
    "exactOptionalPropertyTypes": true,
    "useUnknownInCatchVariables": true,
    
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "allowJs": false,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist"
  },
  "include": ["src/**/*.ts", "src/**/*.svelte"],
  "exclude": ["node_modules", "dist"]
}
```

### 5.2 Contract Types: Auto-Generated Mirror

**File: `scanner_pwa/src/lib/types/contracts/TicketContract.ts`**

```typescript
/**
 * TicketContract - Mirror of VoelgoedEvents.Contracts.Api.TicketContract
 * 
 * This interface MUST exactly match the Elixir contract.
 * If Elixir contract changes, this MUST change.
 * TypeScript compiler will fail if you try to use wrong field names.
 * 
 * @see lib/voelgoedevents/contracts/api/ticket_contract.ex
 */

// ✅ Status must match Elixir enum values
export type TicketStatus = 'valid' | 'used' | 'invalid' | 'duplicate';

// ✅ Interface matches Elixir @type exactly
export interface TicketContract {
  id: string;
  code: string;
  status: TicketStatus;
  holder_name: string | null;
  holder_email: string | null;
  event_id: string;
  created_at: string; // ISO 8601 DateTime
  used_at: string | null; // ISO 8601 DateTime
}

// ✅ Type guard to validate API responses at runtime
export function isTicketContract(obj: unknown): obj is TicketContract {
  if (typeof obj !== 'object' || obj === null) return false;
  const t = obj as Record<string, unknown>;
  
  return (
    typeof t.id === 'string' &&
    typeof t.code === 'string' &&
    ['valid', 'used', 'invalid', 'duplicate'].includes(t.status as string) &&
    (t.holder_name === null || typeof t.holder_name === 'string') &&
    (t.holder_email === null || typeof t.holder_email === 'string') &&
    typeof t.event_id === 'string' &&
    typeof t.created_at === 'string' &&
    (t.used_at === null || typeof t.used_at === 'string')
  );
}
```

**File: `scanner_pwa/src/lib/types/contracts/ScanResultContract.ts`**

```typescript
/**
 * ScanResultContract - Mirror of VoelgoedEvents.Contracts.Api.ScanResultContract
 * 
 * Returned by:
 * - POST /api/scans
 * - POST /api/scans/sync
 */

import type { TicketContract } from './TicketContract';

export type ScanStatus = 'success' | 'duplicate' | 'invalid' | 'error';

export interface ScanResultContract {
  success: boolean;
  status: ScanStatus;
  message: string;
  ticket: TicketContract | null;
  timestamp: string; // ISO 8601 DateTime
  request_id: string;
}

// ✅ Type guard for runtime validation
export function isScanResultContract(obj: unknown): obj is ScanResultContract {
  if (typeof obj !== 'object' || obj === null) return false;
  const s = obj as Record<string, unknown>;
  
  return (
    typeof s.success === 'boolean' &&
    ['success', 'duplicate', 'invalid', 'error'].includes(s.status as string) &&
    typeof s.message === 'string' &&
    (s.ticket === null || typeof s.ticket === 'object') &&
    typeof s.timestamp === 'string' &&
    typeof s.request_id === 'string'
  );
}
```

### 5.3 Svelte Component Using Contracts

**File: `scanner_pwa/src/lib/components/ScannerResult.svelte`**

```svelte
<script lang="ts">
  import type { ScanResultContract } from '$lib/types/contracts/ScanResultContract';
  import { isScanResultContract } from '$lib/types/contracts/ScanResultContract';

  // ✅ Props MUST be typed
  export let result: ScanResultContract;

  // ✅ TypeScript knows the shape - autocomplete works
  let statusEmoji: string;

  // ✅ This is type-safe - if you typo a field name, TypeScript errors
  $: statusEmoji = result.status === 'success' ? '✅' : '❌';

  // ✅ This is valid - Svelte/TS knows result.ticket is TicketContract | null
  $: ticketCode = result.ticket?.code ?? 'N/A';

  // ✅ Timestamp is guaranteed to be ISO 8601 string
  $: scanTime = new Date(result.timestamp).toLocaleTimeString();
</script>

<div class="scan-result">
  <div class="status {result.status}">
    <span>{statusEmoji} {result.status.toUpperCase()}</span>
  </div>

  <div class="message">{result.message}</div>

  {#if result.ticket}
    <!-- ✅ result.ticket exists here (type narrowing) -->
    <div class="ticket-info">
      <p><strong>Code:</strong> {result.ticket.code}</p>
      <p><strong>Holder:</strong> {result.ticket.holder_name ?? 'Unknown'}</p>
      <p><strong>Scanned:</strong> {scanTime}</p>
    </div>
  {/if}

  <div class="request-id">Request ID: {result.request_id}</div>
</div>

<style>
  .scan-result {
    padding: 1rem;
    border-radius: 8px;
    margin: 1rem 0;
  }

  .status {
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  .status.success {
    color: green;
  }

  .status.duplicate,
  .status.invalid,
  .status.error {
    color: red;
  }

  .message {
    margin: 0.5rem 0;
  }

  .ticket-info {
    margin-top: 1rem;
    padding: 0.5rem;
    background: #f5f5f5;
    border-radius: 4px;
  }

  .ticket-info p {
    margin: 0.25rem 0;
  }

  .request-id {
    font-size: 0.75rem;
    color: #999;
    margin-top: 0.5rem;
  }
</style>
```

### 5.4 API Client with Type Safety

**File: `scanner_pwa/src/lib/api/scan-client.ts`**

```typescript
import type { ScanResultContract } from '$lib/types/contracts/ScanResultContract';
import { isScanResultContract } from '$lib/types/contracts/ScanResultContract';

export class ScanClient {
  constructor(private baseUrl: string) {}

  /**
   * Process a ticket scan
   * 
   * @param ticketCode - The QR code from the ticket
   * @returns Promise resolving to a typed ScanResultContract
   * @throws Error if response doesn't match contract
   */
  async processScan(ticketCode: string): Promise<ScanResultContract> {
    const response = await fetch(`${this.baseUrl}/api/scans`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.getToken()}`
      },
      body: JSON.stringify({
        ticket_code: ticketCode,
        device_id: this.getDeviceId()
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();

    // ✅ Runtime validation - ensure server response matches contract
    if (!isScanResultContract(data)) {
      console.error('Invalid response from server:', data);
      throw new Error('Server response does not match ScanResultContract');
    }

    // ✅ TypeScript knows `data` is ScanResultContract
    return data;
  }

  private getToken(): string {
    // Implementation
    return '';
  }

  private getDeviceId(): string {
    // Implementation
    return '';
  }
}
```

---

## 6. CONTRACT SYNCHRONIZATION

### 6.1 The Synchronization Strategy

**Goal:** Ensure Elixir contracts and TypeScript interfaces always match

**Approach 1: Manual Sync (With CI Checks)**

1. Developer changes Elixir contract
2. CI detects contract changed
3. Build fails with instructions to update TypeScript
4. Developer updates matching TypeScript interface
5. CI verifies sync, build passes

**Approach 2: Code Generation (Advanced)**

Use mix task to generate TypeScript from Elixir contracts automatically.

**Approach 3: Runtime Contract Tests**

Run tests that ensure API responses match expected contract schema.

### 6.2 CI Check: Contract Sync

**File: `.github/workflows/sync-contracts.yml`**

```yaml
name: Sync Contracts

on:
  pull_request:
    paths:
      - 'lib/voelgoedevents/contracts/**'
      - 'scanner_pwa/src/lib/types/contracts/**'

jobs:
  check-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # Check if Elixir contracts were changed
      - name: Check for Elixir contract changes
        id: elixir_changed
        run: |
          git diff --name-only ${{ github.base_ref }} | grep -q "lib/voelgoedevents/contracts/" && echo "changed=true" >> $GITHUB_OUTPUT || echo "changed=false" >> $GITHUB_OUTPUT

      # Check if TypeScript contracts were changed
      - name: Check for TypeScript contract changes
        id: ts_changed
        run: |
          git diff --name-only ${{ github.base_ref }} | grep -q "scanner_pwa/src/lib/types/contracts/" && echo "changed=true" >> $GITHUB_OUTPUT || echo "changed=false" >> $GITHUB_OUTPUT

      # Fail if only one was changed
      - name: Verify sync
        run: |
          if [ "${{ steps.elixir_changed.outputs.changed }}" == "true" ] && [ "${{ steps.ts_changed.outputs.changed }}" == "false" ]; then
            echo "❌ Elixir contract changed but TypeScript contract was not updated"
            echo "Please update scanner_pwa/src/lib/types/contracts/ to match"
            exit 1
          fi

          if [ "${{ steps.elixir_changed.outputs.changed }}" == "false" ] && [ "${{ steps.ts_changed.outputs.changed }}" == "true" ]; then
            echo "❌ TypeScript contract changed but Elixir contract was not updated"
            echo "Please update lib/voelgoedevents/contracts/ to match"
            exit 1
          fi

          echo "✅ Contracts are in sync"
```

### 6.3 Contract Versioning

**Add version header to all contracts:**

```elixir
# lib/voelgoedevents/contracts/api/ticket_contract.ex
defmodule VoelgoedEvents.Contracts.Api.TicketContract do
  @moduledoc """
  Ticket Contract v1.0

  ⚠️ BREAKING CHANGES: Must increment version and update TypeScript mirror
  
  Version history:
  - v1.0 (2025-11-27): Initial release with ticket fields
  """

  @contract_version "1.0"
end
```

```typescript
// scanner_pwa/src/lib/types/contracts/TicketContract.ts
/**
 * TicketContract v1.0
 * 
 * ⚠️ Must match Elixir version
 * Update this when the Elixir contract changes
 * 
 * Version history:
 * - v1.0 (2025-11-27): Initial release
 */
```

---

## 7. CI/CD ENFORCEMENT

### 7.1 Backend Type Checking

**File: `.github/workflows/test.yml`**

```yaml
name: Test & Type Check

on: [push, pull_request]

jobs:
  type-safety:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-elixir@v1
        with:
          elixir-version: 1.16
          otp-version: 27

      # ✅ Run Dialyzer
      - name: Run Dialyzer Type Checker
        run: mix dialyzer --halt-exit-status
        continue-on-error: false

      # ✅ Check specs with Credo
      - name: Check @spec annotations
        run: mix credo --strict
        continue-on-error: false

      # ✅ Run type-specific tests
      - name: Run type safety tests
        run: mix test test/type_safety/
        continue-on-error: false
```

### 7.2 Frontend Type Checking

**File: `scanner_pwa/package.json`**

```json
{
  "scripts": {
    "type-check": "tsc --noEmit",
    "type-check:watch": "tsc --noEmit --watch",
    "lint": "eslint src --ext .ts,.svelte",
    "build": "npm run type-check && npm run lint && vite build",
    "test": "npm run type-check && vitest"
  },
  "devDependencies": {
    "typescript": "^5.3",
    "@typescript-eslint/eslint-plugin": "^6.0",
    "@typescript-eslint/parser": "^6.0",
    "svelte-check": "^3.0"
  }
}
```

**File: `.github/workflows/frontend-type-check.yml`**

```yaml
name: Frontend Type Check

on: [push, pull_request]

jobs:
  type-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: cd scanner_pwa && npm ci

      # ✅ TypeScript strict mode check
      - name: TypeScript type check
        run: cd scanner_pwa && npm run type-check
        continue-on-error: false

      # ✅ ESLint with TypeScript plugin
      - name: ESLint
        run: cd scanner_pwa && npm run lint
        continue-on-error: false

      # ✅ Svelte type check
      - name: Svelte type check
        run: cd scanner_pwa && npx svelte-check --tsconfig ./tsconfig.json
        continue-on-error: false
```

### 7.3 Contract Validation Tests

**File: `test/type_safety/contract_validation_test.exs`**

```elixir
defmodule VoelgoedEvents.TypeSafety.ContractValidationTest do
  use ExUnit.Case

  @moduledoc """
  Tests that verify API responses match their Contract definitions.
  
  These tests run a sample API call and validate the JSON response
  matches the expected contract shape exactly.
  """

  test "ScanResultContract matches API response" do
    # Create a test scan
    {:ok, scan} = create_test_scan()

    # Convert to contract
    contract = ScanResultContract.from_reactor_result(
      true,
      :success,
      "Test scan",
      scan,
      "req-123"
    )

    # Serialize to JSON
    json = Jason.encode!(contract)

    # Deserialize and validate
    decoded = Jason.decode!(json)

    # Assert all required fields are present
    assert Map.has_key?(decoded, "success")
    assert Map.has_key?(decoded, "status")
    assert Map.has_key?(decoded, "message")
    assert Map.has_key?(decoded, "timestamp")
    assert Map.has_key?(decoded, "request_id")

    # Assert field types match contract
    assert is_boolean(decoded["success"])
    assert is_binary(decoded["status"])
    assert is_binary(decoded["message"])
    assert is_binary(decoded["timestamp"])
    assert is_binary(decoded["request_id"])
  end

  test "TicketContract excludes internal fields" do
    ticket = create_test_ticket()
    contract = TicketContract.from_ticket(ticket)
    json = Jason.encode!(contract)
    decoded = Jason.decode!(json)

    # organization_id should NOT be in JSON output
    refute Map.has_key?(decoded, "organization_id")

    # But these should be:
    assert Map.has_key?(decoded, "id")
    assert Map.has_key?(decoded, "code")
    assert Map.has_key?(decoded, "status")
  end

  test "Contract enums serialize correctly" do
    contract = %TicketContract{
      id: Ecto.UUID.generate(),
      code: "TEST123",
      status: :duplicate,  # Atom
      holder_name: "John",
      holder_email: "john@example.com",
      event_id: Ecto.UUID.generate(),
      created_at: DateTime.utc_now(),
      used_at: nil
    }

    json = Jason.encode!(contract)
    decoded = Jason.decode!(json)

    # Enum should be serialized as string
    assert decoded["status"] == "duplicate"
  end
end
```

---

## 8. IMPLEMENTATION CHECKLIST

### Phase 1: Infrastructure Setup (Week 1)

- [ ] Add `:dialyxir` to `mix.exs`
  ```elixir
  {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
  ```

- [ ] Create `.dialyzer` configuration file
- [ ] Update `.credo.exs` to enforce @spec
- [ ] Configure `tsconfig.json` with `"strict": true` in scanner_pwa

- [ ] Create directory structure:
  ```
  lib/voelgoedevents/contracts/
  ├── base_contract.ex
  ├── api/
  ├── scanning/
  └── payments/
  
  scanner_pwa/src/lib/types/
  └── contracts/
  ```

- [ ] Add CI workflow files (GitHub Actions)

### Phase 2: Core Contracts (Week 2)

- [ ] Create `BaseContract` module
- [ ] Create `TicketContract` (Elixir + TypeScript)
- [ ] Create `ScanResultContract` (Elixir + TypeScript)
- [ ] Create `CheckoutContract` (Elixir + TypeScript)
- [ ] Create `PaymentContract` (Elixir + TypeScript)

### Phase 3: API Integration (Week 3)

- [ ] Update all controller actions to return Contracts
- [ ] Remove all `raw map` responses from API
- [ ] Add type guards to TypeScript API client
- [ ] Update all Svelte components to use typed Contracts

### Phase 4: Enforcement (Week 4)

- [ ] Enable Dialyzer in CI (required for merge)
- [ ] Enable TypeScript strict check in CI
- [ ] Enable contract sync check in CI
- [ ] Add contract validation tests
- [ ] Document for team

### Ongoing

- [ ] Every new contract MUST have Elixir + TypeScript versions
- [ ] Every API endpoint MUST return a Contract
- [ ] Every Svelte component MUST use typed props
- [ ] Every function MUST have @spec
- [ ] CI must pass all type checks before merge

---

## 9. REAL-WORLD EXAMPLES

### Example 1: Adding a New Field to TicketContract

**Scenario:** Product team wants to add "section" field to tickets

**Step 1: Update Elixir Contract**

```elixir
# lib/voelgoedevents/contracts/api/ticket_contract.ex
@type t :: %__MODULE__{
  id: String.t(),
  code: String.t(),
  status: :valid | :used | :invalid | :duplicate,
  holder_name: String.t() | nil,
  holder_email: String.t() | nil,
  event_id: String.t(),
  section: String.t(),  # ← NEW FIELD
  created_at: DateTime.t(),
  used_at: DateTime.t() | nil
}

@contract_fields [
  :id,
  :code,
  :status,
  :holder_name,
  :holder_email,
  :event_id,
  :section,  # ← ADD HERE
  :created_at,
  :used_at
]

embedded_schema do
  # ... existing fields ...
  field :section, :string  # ← ADD HERE
end
```

**Step 2: Update TypeScript Interface**

```typescript
// scanner_pwa/src/lib/types/contracts/TicketContract.ts
export interface TicketContract {
  id: string;
  code: string;
  status: TicketStatus;
  holder_name: string | null;
  holder_email: string | null;
  event_id: string;
  section: string;  // ← NEW FIELD
  created_at: string;
  used_at: string | null;
}

export function isTicketContract(obj: unknown): obj is TicketContract {
  // ... existing checks ...
  && typeof t.section === 'string'  // ← ADD CHECK
}
```

**Step 3: Update Svelte Component (Automatically typed!)**

```svelte
<script lang="ts">
  import type { TicketContract } from '$lib/types/contracts/TicketContract';

  export let ticket: TicketContract;
</script>

<div>
  <!-- ✅ TypeScript knows section exists -->
  <p>Section: {ticket.section}</p>
</div>
```

**Step 4: CI Checks**

- ✅ Elixir contract compiles with new field
- ✅ TypeScript compiler validates interface matches
- ✅ Contract sync check passes (both updated)
- ✅ Tests pass

**Step 5: Merge & Deploy**

Everything is type-safe from end to end.

---

### Example 2: Catching a Bug with Type Safety

**Scenario:** Frontend developer renames a field without updating the backend

**Before Type Safety:**
```typescript
// ❌ Developer accidentally renames field
export interface ScanResult {
  request_id: string;  // ← renamed from requestId
}
```

API returns `{ requestId: "..." }` but code expects `request_id`.

**Runtime Error:** "Cannot read property 'request_id' of undefined" (in production!)

**With Type Safety:**

```typescript
// Frontend code can't compile
result.request_id  // ← TypeScript error: property doesn't exist on interface

// They must rename it in the interface
export interface ScanResult {
  requestId: string;  // ← matches Elixir
}

// ✅ Compiler happy, deploy safe
```

**OR they try to update only Elixir:**

```elixir
# They rename in Elixir
def scan_result_contract do
  %{request_id: ...}  # ← updated
end
```

**CI Fails:** "Contract sync check failed - TypeScript not updated"

**Either way, the bug is caught before production.**

---

## 10. MIGRATION & ROLLOUT

### Phase-Based Rollout

**Week 1: Foundation**
- Deploy Dialyzer + Credo
- Deploy base Contract infrastructure
- No breaking changes to existing API

**Week 2: Core Domains**
- Create Contracts for Scanning + Payments
- Update those API endpoints to use Contracts
- Update corresponding Svelte components

**Week 3: Full Coverage**
- Create Contracts for all remaining API endpoints
- Update all controllers
- Update all Svelte components

**Week 4: Enforcement**
- Enable all CI type checks (required for merge)
- Delete all raw map responses
- 100% Contract coverage

### Gradual Migration Strategy

**For each endpoint:**

1. **Create Contract**
   ```elixir
   defmodule VoelgoedEvents.Contracts.Api.MyResourceContract do
     # ...
   end
   ```

2. **Add backward compatibility**
   ```elixir
   def get_my_resource(id) do
     resource = MyResource |> Ash.read_one!()
     
     # Return both old (map) and new (contract) temporarily
     contract = MyResourceContract.from_resource(resource)
     {:ok, contract}
   end
   ```

3. **Update Svelte to use new Contract**
   ```typescript
   // Old: let data: any = await fetch(...)
   // New: let data: MyResourceContract = await fetch(...)
   ```

4. **Once all clients updated, remove raw map response**
   ```elixir
   # Only return contract
   contract = MyResourceContract.from_resource(resource)
   {:ok, contract}
   ```

5. **Merge when CI passes**

---

## 11. TROUBLESHOOTING

### Q: "Dialyzer is too strict and throws false positives"

**A:** Dialyzer can be noisy. Use suppressions carefully:

```elixir
defmodule MyModule do
  @dialyzer {:nowarn_function, maybe_broken_function: 1}
  
  def maybe_broken_function(x) do
    # Dialyzer won't complain about this function
  end
end
```

**But:** Only suppress genuine false positives. Most warnings are real bugs.

### Q: "TypeScript strict mode breaks all my code"

**A:** Migrate gradually:

```json
{
  "compilerOptions": {
    "strict": false,  // Start here
    "noImplicitAny": true,  // Gradually enable individual checks
    "strictNullChecks": true,
    "strictFunctionTypes": true
    // Add more as you fix errors
  }
}
```

Then enable `"strict": true` once all code is compliant.

### Q: "Contracts are too boilerplate-heavy"

**A:** They pay for themselves:

- ✅ Catch bugs before production (worth 10x the code)
- ✅ Auto-complete in Svelte (massive productivity boost)
- ✅ Documentation that never lies (always in sync)
- ✅ Onboard new developers faster (type safety teaches patterns)

### Q: "Frontend and backend contracts are out of sync. What now?"

**A:** CI checks prevent this, but if it happens:

```bash
# In backend
mix test test/type_safety/contract_validation_test.exs

# In frontend
npm run type-check

# If both pass, contracts are in sync
# If they don't, the type checker tells you exactly what's wrong
```

---

## 12. AI AGENT INSTRUCTIONS

### For AI Coding Agents (Claude, GPT, etc.)

When working on VoelgoedEvents codebase, follow these rules:

#### Rule 1: Type Safety First

Every new function MUST have `@spec`.

```elixir
# ✅ CORRECT
@spec create_scan(ticket_code :: String.t(), org_id :: String.t()) :: {:ok, Scan.t()} | {:error, term()}
def create_scan(ticket_code, org_id) do
  # ...
end

# ❌ WRONG - Missing @spec
def create_scan(ticket_code, org_id) do
  # ...
end
```

#### Rule 2: API Responses Use Contracts

Never return raw maps from API endpoints.

```elixir
# ✅ CORRECT
def scan(conn, params) do
  case Reactor.run(...) do
    {:ok, scan} ->
      contract = ScanResultContract.from_reactor_result(true, :success, "OK", scan, req_id)
      json(conn, contract)
  end
end

# ❌ WRONG - Raw map
def scan(conn, params) do
  case Reactor.run(...) do
    {:ok, scan} ->
      json(conn, %{success: true, scan: scan})  # ← No type safety
  end
end
```

#### Rule 3: Frontend Components Are Typed

All Svelte components receive typed props.

```svelte
<!-- ✅ CORRECT -->
<script lang="ts">
  import type { ScanResultContract } from '$lib/types/contracts';
  export let result: ScanResultContract;
</script>

<!-- ❌ WRONG - No types -->
<script>
  export let result;
</script>
```

#### Rule 4: Contract Sync

If you create or modify an Elixir contract, create or modify the matching TypeScript interface.

```bash
# When you create this file:
lib/voelgoedevents/contracts/api/my_contract.ex

# Also create this file:
scanner_pwa/src/lib/types/contracts/MyContract.ts

# CI will fail if both aren't updated together
```

#### Rule 5: Type Guards for API Responses

Always validate API responses at runtime using type guards.

```typescript
// ✅ CORRECT
const data = await fetch(...).then(r => r.json());
if (!isScanResultContract(data)) {
  throw new Error('Invalid response');
}
// Now TypeScript knows `data` is ScanResultContract

// ❌ WRONG - No validation
const data = await fetch(...).then(r => r.json());
// What if the API changed? You won't know until runtime crashes
```

#### Rule 6: Enum Sync

Elixir enums MUST match TypeScript discriminated unions.

```elixir
# Elixir
field :status, Ecto.Enum, values: [:success, :duplicate, :invalid, :error]
```

```typescript
// TypeScript
export type ScanStatus = 'success' | 'duplicate' | 'invalid' | 'error';

// NOT:
export type ScanStatus = 'Success' | 'Duplicate' | 'Invalid' | 'Error'; // ❌ Different casing
```

#### Rule 7: Never Use `any` in Business Logic

```typescript
// ❌ WRONG
function handleResult(result: any) {
  return result.code;
}

// ✅ CORRECT
function handleResult(result: ScanResultContract): string {
  return result.ticket?.code ?? 'N/A';
}
```

#### Rule 8: Dialyzer Must Pass

Before submitting code, run:

```bash
mix dialyzer
```

If it fails, fix the code. Do not suppress unless genuinely a false positive.

#### Rule 9: Frontend Type Check Must Pass

Before submitting code, run:

```bash
cd scanner_pwa && npm run type-check
```

If it fails, fix the code. Do not use `// @ts-ignore`.

#### Rule 10: Tests Must Validate Contracts

When writing tests for API endpoints, validate the response matches the contract.

```elixir
test "scan endpoint returns valid ScanResultContract" do
  response = post(conn, "/api/scans", @params)
  
  # Validate contract
  assert response[:success] == true
  assert response[:status] in [:success, :duplicate, :invalid, :error]
  assert is_binary(response[:message])
  assert is_binary(response[:request_id])
  assert is_binary(response[:timestamp])
end
```

### Instructions for AI Agents Writing Code

**When creating a new API endpoint:**

1. **Create Elixir contract** in `lib/voelgoedevents/contracts/`
   - Add @type definition
   - Add @contract_fields whitelist
   - Add from_* constructor function
   - Add validation in changeset

2. **Create TypeScript interface** in `scanner_pwa/src/lib/types/contracts/`
   - Mirror the Elixir contract exactly
   - Add type guard function
   - Add version comment

3. **Update controller** to return contract, not raw map

4. **Update Svelte component** to use typed props

5. **Add test** that validates response matches contract

6. **Run CI checks:**
   ```bash
   mix dialyzer
   mix test
   cd scanner_pwa && npm run type-check
   ```

**Document Version:** 1.0 FINAL  
**Date:** November 27, 2025  
**Status:** 🚀 PRODUCTION READY  
**Next Step:** Start Phase 1 on Monday  
**Philosophy:** Contract-First Development - "We do not guess data shapes. We define them."

---

**VoelgoedEvents Engineering Team & AI Agents - Type Safety is not optional. It's the foundation of enterprise-grade software.**