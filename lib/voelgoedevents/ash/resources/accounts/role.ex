defmodule Voelgoedevents.Ash.Resources.Accounts.Role do
  @moduledoc "Global role definitions for platform-wide RBAC."

  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require PlatformPolicy

  postgres do
    table "roles"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :atom do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_name, [:name]
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create do
      primary? true
      accept [:name, :description]
    end

    update :update do
      accept [:name, :description]
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action_type(:read) do
      authorize_if always()
    end
  end
end
