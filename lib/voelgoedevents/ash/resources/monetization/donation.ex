defmodule Voelgoedevents.Ash.Resources.Monetization.Donation do
  @moduledoc "Tracks voluntary donations collected during checkout (Phase 21)."
  use Ash.Resource, data_layer: AshPostgres.DataLayer
  attributes do uuid_primary_key :id end
end
