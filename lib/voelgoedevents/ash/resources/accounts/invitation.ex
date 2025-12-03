defmodule Voelgoedevents.Ash.Resources.Accounts.Invitation do
  @moduledoc "Ash resource: organization invitations."

  alias Ash.{Changeset, Context, Query}
  alias Voelgoedevents.Ash.Policies.PlatformPolicy
  alias Voelgoedevents.Ash.Resources.Accounts.{Membership, Role}

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require PlatformPolicy

  @role_names Role.allowed_roles()

  postgres do
    table "invitations"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :token, :string do
      allow_nil? false
      public? false
    end

    attribute :role, :atom do
      allow_nil? false
      constraints one_of: @role_names
      public? true
    end

    attribute :organization_id, :uuid do
      allow_nil? false
      public? false
    end

    timestamps()
  end

  identities do
    identity :unique_token, [:token]
    identity :unique_email_per_org, [:email, :organization_id]
  end

  relationships do
    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      require_actor? true
      accept [:email, :role]

      change set_attribute(:organization_id, actor(:organization_id))
      change &__MODULE__.ensure_token/1
    end

    action :accept do
      require_actor? true

      argument :token, :string do
        allow_nil? false
      end

      run &__MODULE__.accept_invitation/3
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action_type(:read) do
      authorize_if expr(organization_id == actor(:organization_id))
    end

    policy action(:create) do
      authorize_if expr(
                    organization_id == actor(:organization_id) and
                      exists(
                        organization.memberships,
                        user_id == actor(:id) and role.name == :owner
                      )
                  )
    end

    policy action(:accept) do
      authorize_if expr(actor(:email) != nil)
    end

    policy action_type(:destroy) do
      authorize_if expr(organization_id == actor(:organization_id))
    end

    default_policy :deny
  end

  def ensure_token(changeset) do
    case Changeset.get_attribute(changeset, :token) do
      nil -> Changeset.force_change_attribute(changeset, :token, generate_token())
      _ -> changeset
    end
  end

  def accept_invitation(_changeset, %{token: token}, context) do
    opts = Context.to_opts(context)

    with {:ok, actor} <- fetch_actor(context),
         {:ok, invitation} <- fetch_invitation(token, actor, opts),
         :ok <- ensure_actor_email(invitation, actor),
         {:ok, role_id} <- fetch_role_id(invitation.role, opts),
         {:ok, membership} <- ensure_membership(invitation, actor, role_id, opts),
         {:ok, _} <- destroy_invitation(invitation, opts) do
      {:ok, membership}
    end
  end

  defp fetch_actor(%{actor: %{id: _id} = actor}), do: {:ok, actor}
  defp fetch_actor(_context), do: {:error, :unauthorized}

  defp fetch_invitation(token, actor, opts) do
    __MODULE__
    |> Query.new()
    |> Query.filter(token == ^token)
    |> maybe_scope_to_actor(actor)
    |> Ash.read(opts)
    |> case do
      {:ok, [invitation]} -> {:ok, invitation}
      {:ok, []} -> {:error, :invitation_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_scope_to_actor(query, actor) do
    case Map.get(actor, :organization_id) do
      nil -> query
      organization_id -> Query.filter(query, organization_id == ^organization_id)
    end
  end

  defp ensure_actor_email(%{email: invitation_email}, %{email: actor_email})
       when not is_nil(invitation_email) and not is_nil(actor_email) do
    if normalize_email(invitation_email) == normalize_email(actor_email) do
      :ok
    else
      {:error, :email_mismatch}
    end
  end

  defp ensure_actor_email(_invitation, _actor), do: {:error, :email_missing}

  defp fetch_role_id(role_name, opts) do
    Role
    |> Query.filter(name == ^role_name)
    |> Ash.read(opts)
    |> case do
      {:ok, [%Role{id: id}]} -> {:ok, id}
      {:ok, []} -> {:error, :role_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_membership(%{organization_id: organization_id}, %{id: user_id}, role_id, opts) do
    membership_opts =
      opts
      |> Keyword.put_new(:tenant, organization_id)
      |> Keyword.put(:authorize?, false)

    Membership
    |> Query.filter(user_id == ^user_id and organization_id == ^organization_id)
    |> Ash.read(membership_opts)
    |> case do
      {:ok, [membership]} ->
        {:ok, membership}

      {:ok, []} ->
        Membership
        |> Changeset.for_create(:create, %{organization_id: organization_id, role_id: role_id, user_id: user_id})
        |> Ash.create(membership_opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp destroy_invitation(invitation, opts) do
    invitation
    |> Ash.destroy(Keyword.put_new(opts, :tenant, invitation.organization_id))
  end

  defp generate_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp normalize_email(email) when is_binary(email), do: String.downcase(email)
  defp normalize_email(email) when is_atom(email), do: email |> Atom.to_string() |> String.downcase()
  defp normalize_email(other), do: other
end
