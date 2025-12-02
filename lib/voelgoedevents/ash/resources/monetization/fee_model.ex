defmodule Voelgoedevents.Ash.Resources.Monetization.FeeModel do
  @moduledoc "Defines a custom fee structure (Phase 21)."
  use Ash.Resource, data_layer: AshPostgres.DataLayer, domain: Voelgoedevents.Ash.Domains.MonetizationDomain
  attributes do uuid_primary_key :id end

  postgres do
    table "fee_models"
    repo Voelgoedevents.Repo
  end
end
