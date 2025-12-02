defmodule Voelgoedevents.Ash.Resources.Monetization.FeePolicy do
  @moduledoc "Defines the specific rates/rules for a FeeModel (Phase 21)."
  use Ash.Resource, data_layer: AshPostgres.DataLayer, domain: Voelgoedevents.Ash.Domains.MonetizationDomain
  attributes do uuid_primary_key :id end

  postgres do
    table "fee_policies"
    repo Voelgoedevents.Repo
  end
end
