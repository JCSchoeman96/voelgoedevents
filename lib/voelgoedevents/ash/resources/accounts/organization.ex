defmodule Voelgoedevents.Ash.Resources.Accounts.Organization do
  @moduledoc "Ash resource: Organization/tenant."

  alias Ash.Changeset
  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require PlatformPolicy

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

    has_one :settings, Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings do
      destination_attribute :organization_id
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      require_actor? true
      accept [:name, :slug, :status]

      argument :settings, :map, allow_nil?: true

      change &__MODULE__.ensure_settings/1
    end

    update :update do
      require_actor? true
      accept [:name, :slug, :status]

      argument :settings, :map, allow_nil?: true

      change load(:settings)
      change &__MODULE__.update_settings/1
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

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

  def ensure_settings(changeset) do
    settings_attrs = Changeset.get_argument(changeset, :settings) || %{}

    Changeset.manage_relationship(changeset, :settings, settings_attrs, type: :create)
  end

  def update_settings(changeset) do
    case Changeset.fetch_argument(changeset, :settings) do
      {:ok, attrs} ->
        attrs_with_id =
          case Changeset.get_data(changeset, :settings) do
            %{id: id} -> Map.put(attrs, :id, id)
            _ -> attrs
          end

        Changeset.manage_relationship(changeset, :settings, attrs_with_id,
          type: :append_and_remove,
          on_lookup: :update,
          on_no_match: :create
        )

      :error ->
        changeset
    end
  end
end
