defmodule Voelgoedevents.Ash.Resources.Accounts.Organization do
  @moduledoc "Ash resource: Organization/tenant."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: [:active, :suspended, :archived]
      default :active
    end

    attribute :settings, :map do
      allow_nil? false
      default %{}
    end

    timestamps()
  end

  identities do
    identity :unique_slug, [:slug]
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

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :slug, :status, :settings]
    end

    update :update do
      accept [:name, :slug, :status, :settings]
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end
  end

  policies do
    policy action(:create) do
      authorize_if expr(actor(:role) == :super_admin)
    end

    policy action_type([:read, :update]) do
      authorize_if always()
    end

    policy action(:archive) do
      authorize_if always()
    end
  end
end
