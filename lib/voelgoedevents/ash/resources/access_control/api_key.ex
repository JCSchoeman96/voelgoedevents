defmodule Voelgoedevents.Ash.Resources.AccessControl.ApiKey do
  @moduledoc """
  RESOURCE: ApiKey
  """
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccessControlDomain, # 👈 MUST MATCH FILE DEFINITION
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak, AshArchival]

  postgres do
    table "api_keys"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :key_hash, :string, allow_nil?: false, sensitive?: true
  end
  
  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
