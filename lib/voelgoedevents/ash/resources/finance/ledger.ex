defmodule Voelgoedevents.Ash.Resources.Finance.Ledger do
  @moduledoc """
  RESOURCE: Ledger
  The top-level container for double-entry bookkeeping (e.g. "General Ledger", "Sales 2024").
  """
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.FinanceDomain,
    data_layer: AshPostgres.DataLayer,
    # ✅ KEPT YOUR EXTENSION
    extensions: [AshPaperTrail]

  postgres do
    table "financial_ledgers" # ✅ Renamed to avoid conflicts with 'payments' domain
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    # ✅ CHANGED: Logic fix. A Ledger is a container.
    attribute :name, :string do
      allow_nil? false
      public? true
      description "e.g. 'Main Operational Ledger'"
    end

    attribute :currency, :atom do
      allow_nil? false
      default :ZAR
      public? true
    end

    attribute :active, :boolean, default: true

    timestamps()
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end
end