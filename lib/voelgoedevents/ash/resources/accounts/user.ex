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
      require_token_presence_for_authentication? true
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

    attribute :first_name, :string do
      allow_nil? false
      public? true
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :active, :disabled]
      default :pending
    end

    attribute :confirmed_at, :utc_datetime do
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

    many_to_many :organizations, Voelgoedevents.Ash.Resources.Accounts.Organization do
      through Voelgoedevents.Ash.Resources.Accounts.Membership
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :organization_id
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  validations do
    validate present([:email, :first_name, :last_name, :status])
  end

  actions do
    defaults [:read]
  end
end
