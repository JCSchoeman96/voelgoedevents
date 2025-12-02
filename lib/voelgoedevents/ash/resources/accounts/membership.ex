defmodule Voelgoedevents.Ash.Resources.Accounts.Membership do
  @moduledoc "Ash resource: Membership linking users to organizations."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "memberships"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:owner, :admin, :staff, :scanner]
      default :staff
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Voelgoedevents.Ash.Resources.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_user_organization, [:user_id, :organization_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:role, :user_id, :organization_id]
    end

    update :update do
      accept [:role]
    end
  end
end
