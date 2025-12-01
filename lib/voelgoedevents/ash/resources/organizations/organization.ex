defmodule Voelgoedevents.Ash.Resources.Organizations.Organization do
  @moduledoc "Ash resource: Organization/tenant."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "organizations"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    # Status flag for tenancy
    attribute :active, :boolean do
      allow_nil? false
      default true
    end

    timestamps()
  end

  relationships do
    has_many :memberships, Voelgoedevents.Ash.Resources.Accounts.Membership do
      destination_attribute :organization_id
    end

    many_to_many :users, Voelgoedevents.Ash.Resources.Accounts.User do
      through Voelgoedevents.Ash.Resources.Accounts.Membership
      source_attribute_on_join_resource :organization_id
      destination_attribute_on_join_resource :user_id
    end
  end

  # ✅ ADD: Basic Actions so we can seed data
  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug]
    end

    update :update do
      accept [:name, :active]
    end
  end
end
