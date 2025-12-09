defmodule Voelgoedevents.Ash.Resources.Accounts.Role do
  @moduledoc "Global role definitions for platform-wide RBAC."

  # Canonical tenant roles
  @allowed_roles [:owner, :admin, :staff, :viewer, :scanner_only]

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
      constraints one_of: @allowed_roles
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
    # Reads are open; writes are platform-admin only via PlatformPolicy
    defaults [:read, :create, :update]

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
