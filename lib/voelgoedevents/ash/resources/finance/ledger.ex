defmodule Voelgoedevents.Ash.Resources.Finance.Ledger do
  @moduledoc """
  RESOURCE: Ledger
  """
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.FinanceDomain, # 👈 MUST MATCH FILE DEFINITION
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPaperTrail]

  postgres do
    table "ledgers"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :amount, :map
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
