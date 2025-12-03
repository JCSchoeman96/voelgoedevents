defmodule Voelgoedevents.Ash.Resources.Accounts.User do
  @moduledoc "Ash resource: User accounts."

  alias Ash.{Changeset, Context, Query}
  alias AshAuthentication.Info
  alias Voelgoedevents.Auth.ConfirmationSender
  alias Voelgoedevents.Ash.Policies.PlatformPolicy
  alias Voelgoedevents.Caching.MembershipCache

  require PlatformPolicy

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo Voelgoedevents.Repo
  end

  authentication do
    add_ons do
      confirmation :confirm do
        monitor_fields [:email]
        require_interaction? true
        confirmed_at_field :confirmed_at
        sender ConfirmationSender
      end
    end

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

    attribute :is_platform_admin, :boolean do
      allow_nil? false
      default false
      public? false
      description "Marks a user as a platform-wide administrator."
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

    validate {Voelgoedevents.Ash.Validations.PasswordPolicy, field: :password}

    validate fn changeset ->
      if changeset.action.type == :update and
           Changeset.changing_attribute?(changeset, :is_platform_admin) and
           match?(:error, Changeset.fetch_argument(changeset, :is_platform_admin)) do
        Changeset.add_error(changeset, field: :is_platform_admin, message: "explicit input required")
      else
        changeset
      end
    end
  end

  actions do
    read :read do
      require_actor? true

      prepare build(fn query, %{actor: actor} ->
        case Map.get(actor, :organization_id) do
          nil ->
            Query.filter(query, false)

          organization_id ->
            Query.filter(query, exists(memberships, organization_id == ^organization_id))
        end
      end)
    end

    create :create do
      primary? true
      require_actor? true

      accept [:email, :first_name, :last_name, :status, :hashed_password, :confirmed_at]

      argument :is_platform_admin, :boolean do
        allow_nil? true
      end

      argument :organization_id, :uuid do
        allow_nil? false
      end

      argument :role_id, :uuid do
        allow_nil? false
      end

      change &set_platform_admin_from_argument/2

      change &audit_platform_admin_change/2

      change fn changeset, _context ->
        organization_id = Changeset.get_argument(changeset, :organization_id)
        role_id = Changeset.get_argument(changeset, :role_id)

        Changeset.manage_relationship(
          changeset,
          :memberships,
          [%{organization_id: organization_id, role_id: role_id}],
          type: :create
        )
      end
    end

    update :update do
      require_actor? true
      accept [:first_name, :last_name, :status, :confirmed_at]

      argument :is_platform_admin, :boolean do
        allow_nil? true
      end

      change &set_platform_admin_from_argument/2
      change &audit_platform_admin_change/2
      change after_action(&__MODULE__.invalidate_membership_cache_on_deactivate/3)
    end

    action :resend_confirmation do
      require_actor? false

      argument :email, :string do
        allow_nil? false
        sensitive? true
      end

      run fn %{email: email}, context ->
        opts = Ash.Context.to_opts(context)

        with {:ok, [user]} <-
               __MODULE__
               |> Query.new()
               |> Query.filter(email == ^email)
               |> Ash.read(opts),
             strategy <- Info.strategy!(__MODULE__, :confirm),
             {:ok, token} <-
               AshAuthentication.AddOn.Confirmation.confirmation_token(
                 strategy,
                 Changeset.new(user),
                 user,
                 opts
               ) do
          {sender, send_opts} = strategy.sender

          send_opts
          |> Keyword.put(:tenant, context.tenant)
          |> Keyword.put(:changeset, Changeset.new(user))
          |> then(&sender.send(user, token, &1))

          {:ok, user}
        else
          {:ok, []} -> {:error, :not_found}
          {:error, reason} -> {:error, reason}
          :error -> {:error, :not_found}
        end
      end
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action(:create) do
      authorize_if expr(arg(:organization_id) == actor(:organization_id))
    end

    policy action_type([:read, :update]) do
      authorize_if expr(exists(memberships, organization_id == actor(:organization_id)))
    end

    policy action([:confirm, :resend_confirmation]) do
      authorize_if always()
    end

    default_policy :deny
  end

  defp set_platform_admin_from_argument(changeset, _context) do
    case Changeset.fetch_argument(changeset, :is_platform_admin) do
      {:ok, value} -> Changeset.force_change_attribute(changeset, :is_platform_admin, value)
      :error -> changeset
    end
  end

  defp audit_platform_admin_change(changeset, _context) do
    previous_value = Map.get(changeset.data, :is_platform_admin)

    Changeset.after_action(changeset, fn changeset, user, context ->
      if Changeset.changing_attribute?(changeset, :is_platform_admin) do
        actor = Map.get(context, :actor) || %{}

        Voelgoedevents.AuditLogger.log_critical(%{
          event: "accounts.user.is_platform_admin_changed",
          actor_user_id: Map.get(actor, :id),
          organization_id: Map.get(actor, :organization_id),
          entity_type: "user",
          entity_id: user.id,
          previous_value: previous_value,
          new_value: user.is_platform_admin
        })
      end

      {:ok, user}
    end)
  end

  def invalidate_membership_cache_on_deactivate(changeset, user, context) do
    if disabled?(changeset) do
      context
      |> Context.to_opts()
      |> Keyword.put_new(:actor, context.actor)
      |> invalidate_memberships(user)
    end

    {:ok, user}
  end

  defp invalidate_memberships(opts, user) do
    case Ash.load(user, :memberships, opts) do
      {:ok, %{memberships: memberships}} when is_list(memberships) ->
        Enum.each(memberships, fn membership ->
          MembershipCache.invalidate(membership.user_id, membership.organization_id)
        end)

      _ ->
        :ok
    end
  end

  defp disabled?(changeset) do
    Changeset.changing_attribute?(changeset, :status) and
      Changeset.get_attribute(changeset, :status) == :disabled
  end
end
