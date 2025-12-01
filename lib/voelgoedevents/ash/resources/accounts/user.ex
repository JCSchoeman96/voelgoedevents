defmodule Voelgoedevents.Ash.Resources.Accounts.User do
  @moduledoc "Ash resource: User accounts."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "users"
    repo Voelgoedevents.Repo
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end
    end

    tokens do
      enabled? true
      token_resource Voelgoedevents.Ash.Resources.Accounts.Token
      signing_secret fn _, _ ->
        {:ok, Application.fetch_env!(:voelgoedevents, :token_signing_secret)}
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    timestamps()
  end

  relationships do
    has_many :memberships, Voelgoedevents.Ash.Resources.Accounts.Membership do
      destination_attribute :user_id
    end

    many_to_many :organizations, Voelgoedevents.Ash.Resources.Organizations.Organization do
      through Voelgoedevents.Ash.Resources.Accounts.Membership
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :organization_id
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  actions do
    defaults [:read]
  end
end
