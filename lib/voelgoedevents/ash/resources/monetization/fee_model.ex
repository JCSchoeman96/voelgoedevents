defmodule Voelgoedevents.Ash.Resources.Monetization.FeeModel do
  @moduledoc "Defines a custom fee structure (Phase 21)."
  use Ash.Resource, data_layer: AshPostgres.DataLayer
  attributes do uuid_primary_key :id end
end
