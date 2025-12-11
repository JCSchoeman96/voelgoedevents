defmodule Voelgoedevents.Ash.Resources.Finance.Ledger do
  @moduledoc """
  RESOURCE: Ledger
  The top-level container for double-entry bookkeeping (e.g. "General Ledger", "Sales 2024").
  """
  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.FinanceDomain,
    # ✅ KEPT YOUR EXTENSION
    extensions: [AshPaperTrail]

  postgres do
    # ✅ Renamed to avoid conflicts with 'payments' domain
    table "financial_ledgers"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
      public? true
    end

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

  relationships do
    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
    end
  end

  policies do
    # Platform admins have root access
    policy always() do
      authorize_if expr(actor(:is_platform_admin) == true)
    end

    # Read: Allow all authenticated org members (for reports/transparency)
    policy action_type(:read) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(organization_id == actor(:organization_id))
    end

    # Create/Update/Destroy: Only owner and admin (financial data is sensitive)
    policy action_type([:create, :update, :destroy]) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      authorize_if expr(actor(:role) in [:owner, :admin])
    end
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end
end
