defmodule Voelgoedevents.Ash.Resources.Monetization.FeePolicy do
  @moduledoc "Defines the specific rates/rules for a FeeModel (Phase 21)."
  use Voelgoedevents.Ash.Resources.Base, domain: Voelgoedevents.Ash.Domains.MonetizationDomain

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end
  end

  postgres do
    table "fee_policies"
    repo Voelgoedevents.Repo
  end
end
