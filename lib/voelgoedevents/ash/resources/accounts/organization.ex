defmodule Voelgoedevents.Ash.Resources.Accounts.Organization do
  @moduledoc "Ash resource: Organization/tenant."

  alias Ash.Changeset
  alias Ash.Context
  alias Ash.Query, as: Query
  require Query
  alias Voelgoedevents.Ash.Policies.PlatformPolicy
  alias Voelgoedevents.Ash.Resources.Accounts.Membership
  alias Voelgoedevents.Ash.Resources.Accounts.Role
  alias Voelgoedevents.Ash.Resources.Accounts.User
  alias Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings
  alias Voelgoedevents.Caching.MembershipCache

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
      accept [:name, :slug, :status]

      argument :settings, :map, allow_nil?: true

      change &__MODULE__.ensure_settings/2
    end

    update :update do
      require_atomic? false
      accept [:name, :slug, :status]

      argument :settings, :map, allow_nil?: true

      change &__MODULE__.set_org_context_from_record/2
      change after_action(&__MODULE__.upsert_settings_after_update/3)
      change after_action(&__MODULE__.invalidate_membership_cache_on_suspend/3)
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end

    create :register_tenant do
      accept []

      argument :organization_name, :string, allow_nil?: false
      argument :organization_slug, :string, allow_nil?: false
      argument :owner_email, :ci_string, allow_nil?: false
      argument :owner_password, :string, allow_nil?: false, sensitive?: true
      argument :owner_first_name, :string, allow_nil?: false
      argument :owner_last_name, :string, allow_nil?: false

      change set_attribute(:name, arg(:organization_name))
      change set_attribute(:slug, arg(:organization_slug))
      change &__MODULE__.ensure_settings/2
      change after_action(&__MODULE__.create_owner_and_membership/3)
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action(:create) do
      forbid_if expr(is_nil(^actor(:user_id)))

      authorize_if expr(^actor(:is_platform_admin) == true)
    end

    policy action(:update) do
      forbid_if expr(is_nil(^actor(:user_id)))

      authorize_if expr(^actor(:is_platform_admin) == true)

      authorize_if expr(
                     ^actor(:organization_id) == id and
                       ^actor(:role) in [:owner, :admin]
                   )
    end

    policy action_type(:read) do
      forbid_if expr(is_nil(^actor(:user_id)))

      authorize_if expr(id == ^actor(:organization_id))
    end

    policy action(:archive) do
      forbid_if expr(is_nil(^actor(:user_id)))

      authorize_if expr(^actor(:is_platform_admin) == true)

      authorize_if expr(
                     ^actor(:organization_id) == id and
                       ^actor(:role) in [:owner, :admin]
                   )
    end

    policy action(:register_tenant) do
      forbid_if expr(is_nil(^actor(:user_id)))

      authorize_if expr(^actor(:is_platform_admin) == true)
    end
  end

  def ensure_settings(changeset, _context) do
    case Changeset.fetch_argument(changeset, :settings) do
      {:ok, settings_attrs} ->
        Changeset.manage_relationship(changeset, :settings, settings_attrs, type: :create)

      :error ->
        changeset
    end
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

  def upsert_settings_after_update(changeset, organization, context) do
    case Changeset.fetch_argument(changeset, :settings) do
      {:ok, attrs} ->
        org_id = organization.id
        opts = opts_with_org_context(context, org_id)

        OrganizationSettings
        |> Query.filter(organization_id == ^org_id)
        |> Ash.read_one(opts)
        |> case do
          {:ok, nil} ->
            attrs = Map.put(attrs, :organization_id, org_id)

            OrganizationSettings
            |> Changeset.for_create(:create, attrs)
            |> Ash.create(opts)
            |> case do
              {:ok, _settings} ->
                {:ok, organization}

              {:error, %Ash.Error.Invalid{errors: errors} = error} ->
                if unique_org_settings_conflict?(errors) do
                  OrganizationSettings
                  |> Query.filter(organization_id == ^org_id)
                  |> Ash.read_one(opts)
                  |> case do
                    {:ok, %OrganizationSettings{} = settings} ->
                      settings
                      |> Changeset.for_update(:update, Map.delete(attrs, :organization_id))
                      |> Ash.update(opts)
                      |> case do
                        {:ok, _settings} -> {:ok, organization}
                        {:error, error} -> {:error, error}
                      end

                    {:ok, nil} ->
                      {:error, error}

                    {:error, error} ->
                      {:error, error}
                  end
                else
                  {:error, error}
                end

              {:error, error} ->
                {:error, error}
            end

          {:ok, %OrganizationSettings{} = settings} ->
            settings
            |> Changeset.for_update(:update, attrs)
            |> Ash.update(opts)
            |> case do
              {:ok, _settings} -> {:ok, organization}
              {:error, error} -> {:error, error}
            end

          {:error, error} ->
            {:error, error}
        end

      :error ->
        {:ok, organization}
    end
  end

  def set_org_context_from_record(changeset, _context) do
    org_id = changeset.data.id

    Ash.Changeset.set_context(
      changeset,
      merge_org_context(changeset.context, org_id)
    )
  end

  defp unique_org_settings_conflict?(errors) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{field: :organization_id, private_vars: private_vars} ->
        Keyword.get(private_vars, :constraint_type) == :unique and
          Keyword.get(private_vars, :constraint) in [
            "organization_settings_organization_id_index",
            "organization_settings_unique_organization_index"
          ]

      _ ->
        false
    end)
  end

  defp opts_with_org_context(context, org_id) when is_map(context) do
    base_opts = Context.to_opts(context)

    actor =
      Map.get(context, :actor) ||
        Keyword.get(base_opts, :actor)

    if is_nil(actor) do
      raise "OrganizationSettings upsert requires a non-nil actor in after_action context"
    end

    base_opts
    |> Keyword.put(:actor, actor)
    |> Keyword.update(:context, merge_org_context(%{}, org_id), &merge_org_context(&1, org_id))
  end

  defp opts_with_org_context(_context, _org_id) do
    raise "OrganizationSettings upsert requires an Ash after_action context map"
  end

  defp merge_org_context(existing_context, org_id) do
    existing_context =
      cond do
        is_map(existing_context) -> existing_context
        is_list(existing_context) -> Map.new(existing_context)
        true -> %{}
      end

    existing_source_context =
      case Map.get(existing_context, :source_context) do
        %{} = sc ->
          sc

        sc when is_list(sc) ->
          Map.new(sc)

        _ ->
          %{}
      end

    Map.merge(existing_context, %{
      organization_id: org_id,
      source_context: Map.merge(existing_source_context, %{organization_id: org_id})
    })
  end

  def invalidate_membership_cache_on_suspend(changeset, organization, context) do
    if suspended?(changeset) do
      opts = opts_with_org_context(context, organization.id)
      invalidate_memberships_for_org(opts, organization.id)
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

  @doc """
  Creates the owner user and membership after organization creation.
  Called as an after_action callback within the same transaction.
  """
  def create_owner_and_membership(changeset, organization, _context) do
    owner_email = Ash.Changeset.get_argument(changeset, :owner_email)
    owner_password = Ash.Changeset.get_argument(changeset, :owner_password)
    owner_first_name = Ash.Changeset.get_argument(changeset, :owner_first_name)
    owner_last_name = Ash.Changeset.get_argument(changeset, :owner_last_name)

    # Find the :owner role
    owner_role =
      Role
      |> Query.filter(name == :owner)
      |> Ash.read_one!(authorize?: false)

    # Hash the password using Bcrypt (same as AshAuthentication)
    hashed_password = Bcrypt.hash_pwd_salt(owner_password)

    # User.create manages membership creation; do not create membership here.
    # Create user with bypass authorization (system action)
    {:ok, _user} =
      User
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_argument(:password, owner_password)
      |> Ash.Changeset.for_create(
        :create,
        %{
          email: owner_email,
          first_name: owner_first_name,
          last_name: owner_last_name,
          hashed_password: hashed_password,
          organization_id: organization.id,
          role_id: owner_role.id,
          status: :active,
          confirmed_at: DateTime.utc_now()
        }
      )
      |> Ash.create(authorize?: false)

    {:ok, organization}
  end
end
