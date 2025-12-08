defmodule Voelgoedevents.Ash.Resources.Accounts.Organization do
  @moduledoc "Ash resource: Organization/tenant."

  alias Ash.Changeset
  alias Ash.Context
  alias Ash.Query
  alias Voelgoedevents.Ash.Policies.PlatformPolicy
  alias Voelgoedevents.Ash.Resources.Accounts.Membership
  alias Voelgoedevents.Caching.MembershipCache

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require PlatformPolicy
  alias Ash.Query, as: Query
  require Query


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
      accept [:name, :slug, :status]

      argument :settings, :map, allow_nil?: true

      change &__MODULE__.ensure_settings/2
    end

    update :update do
      require_atomic? false
      accept [:name, :slug, :status]

      argument :settings, :map, allow_nil?: true

      change load(:settings)
      change &__MODULE__.update_settings/2
      change after_action(&__MODULE__.invalidate_membership_cache_on_suspend/3)
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action(:create) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(actor(:role) == :super_admin)
    end

    policy action(:update) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:archive) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if always()
    end
  end

  def ensure_settings(changeset, _context) do
    settings_attrs = Changeset.get_argument(changeset, :settings) || %{}

    Changeset.manage_relationship(changeset, :settings, settings_attrs, type: :create)
  end

  def update_settings(changeset, _context) do
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

  def invalidate_membership_cache_on_suspend(changeset, organization, context) do
    if suspended?(changeset) do
      context
      |> Context.to_opts()
      |> Keyword.put_new(:actor, context.actor)
      |> invalidate_memberships_for_org(organization.id)
    end

    {:ok, organization}
  end

  defp invalidate_memberships_for_org(opts, organization_id) do
    Membership
    |> Query.filter(organization_id == ^organization_id)
    |> Ash.read(opts)
    |> case do
      {:ok, memberships} ->
        Enum.each(memberships, fn membership ->
          MembershipCache.invalidate(membership.user_id, membership.organization_id)
        end)

      {:error, _reason} ->
        :ok
    end
  end

  defp suspended?(changeset) do
    Changeset.changing_attribute?(changeset, :status) and
      Changeset.get_attribute(changeset, :status) == :suspended
  end
end
