defmodule Voelgoedevents.Ash.Resources.Monetization.FeeModel do
  @moduledoc "Defines a custom fee structure (Phase 21)."
  use Voelgoedevents.Ash.Resources.Base, domain: Voelgoedevents.Ash.Domains.MonetizationDomain

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end
  end

  postgres do
    table "fee_models"
    repo Voelgoedevents.Repo
  end
end
