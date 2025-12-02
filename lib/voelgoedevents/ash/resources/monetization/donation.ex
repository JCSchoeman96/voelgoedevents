defmodule Voelgoedevents.Ash.Resources.Monetization.Donation do
  @moduledoc "Tracks voluntary donations collected during checkout (Phase 21)."
  use Ash.Resource, data_layer: AshPostgres.DataLayer, domain: Voelgoedevents.Ash.Domains.MonetizationDomain
  attributes do uuid_primary_key :id end

  postgres do
    table "donations"
    repo Voelgoedevents.Repo
  end
end
