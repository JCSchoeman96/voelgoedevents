defmodule Voelgoedevents.Ash.Resources.Accounts.User do
  @moduledoc "Ash resource: User accounts."

  alias Ash.{Changeset, Context, Query}
  alias AshAuthentication.Info
  alias Voelgoedevents.Auth.ConfirmationSender
  alias Voelgoedevents.Ash.Policies.PlatformPolicy
  alias Voelgoedevents.Caching.MembershipCache
  alias Voelgoedevents.Ash.Validations.RequireExplicitPlatformAdmin

  require PlatformPolicy
  require Ash.Query

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshRateLimiter],
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
        hash_provider AshAuthentication.BcryptProvider
        register_action_accept [:first_name, :last_name]
      end
    end

    tokens do
      enabled? true
      require_token_presence_for_authentication? true
      token_resource Voelgoedevents.Ash.Resources.Accounts.Token
      # FIX: Use __MODULE__ (must be public)
      signing_secret &__MODULE__.get_token_signing_secret/2
      store_all_tokens? true
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

    attribute :confirmed_at, :utc_datetime_usec do
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

    attribute :is_platform_staff, :boolean do
      allow_nil? false
      default false
      public? false
      description "Marks a user as platform staff assigned to assist tenants."
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
    validate RequireExplicitPlatformAdmin
  end

  actions do
    read :read do
      # FIX: Use __MODULE__ reference
      prepare &__MODULE__.filter_by_organization/2
    end

    create :create do
      primary? true

      accept [:email, :first_name, :last_name, :status, :hashed_password, :confirmed_at]

      # Password argument for PasswordPolicy validation (when setting hashed_password directly)
      argument :password, :string do
        allow_nil? true
        sensitive? true
      end

      argument :is_platform_admin, :boolean do
        allow_nil? true
      end

      argument :is_platform_staff, :boolean do
        allow_nil? true
      end

      argument :organization_id, :uuid do
        allow_nil? false
      end

      argument :role_id, :uuid do
        allow_nil? false
      end

      # FIX: Use __MODULE__ references for changes
      change &__MODULE__.set_platform_admin_from_argument/2
      change &__MODULE__.set_platform_staff_from_argument/2
      change &__MODULE__.audit_platform_admin_change/2
      change &__MODULE__.setup_new_user_membership/2
    end

    update :update do
      require_atomic? false
      accept [:first_name, :last_name, :status, :confirmed_at]

      argument :is_platform_admin, :boolean do
        allow_nil? true
      end

      argument :is_platform_staff, :boolean do
        allow_nil? true
      end

      # FIX: Use __MODULE__ references for changes
      change &__MODULE__.set_platform_admin_from_argument/2
      change &__MODULE__.set_platform_staff_from_argument/2
      change &__MODULE__.audit_platform_admin_change/2
      change after_action(&__MODULE__.invalidate_membership_cache_on_deactivate/3)
    end

    action :resend_confirmation do
      argument :email, :string do
        allow_nil? false
        sensitive? true
      end

      # FIX: Use __MODULE__ reference
      run &__MODULE__.run_resend_confirmation/2
    end
  end

  @auth_actions [
    :sign_in_with_password,
    :register_with_password,
    :sign_in_with_token,
    :confirm,
    :resend_confirmation,
    :request_password_reset,
    :reset_password,
    :get_by_subject
  ]

  policies do
    # 1. Platform superuser override
    PlatformPolicy.platform_admin_root_access()

    # 2. AshAuthentication entry-point actions
    #    These must be callable WITHOUT an actor, because they are how a user becomes authenticated.
    #    Includes: sign-in, register, token sign-in, confirmation, password reset flows
    policy action(@auth_actions) do
      authorize_if always()
    end

    # 3. Normal CRUD – only the canonical actions, not auth actions
    policy action(:create) do
      forbid_if actor_attribute_equals(:id, nil)

      forbid_if expr(arg(:organization_id) != ^actor(:organization_id))

      forbid_if expr(
                  (not is_nil(arg(:is_platform_staff)) or not is_nil(arg(:is_platform_admin))) and
                    ^actor(:is_platform_admin) != true
                )

      authorize_if always()
    end

    policy action(:read) do
      # 1. Allow anonymous reads – needed for AshAuthentication to
      #    look up users by email during sign-in and registration.
      #    (These lookups are always constrained by identities / query filters,
      #     not "list all users".)
      authorize_if actor_attribute_equals(:id, nil)

      # 2. For logged-in users, enforce tenancy: they must have a membership
      #    in the organization they’re trying to read from.
      forbid_if expr(not exists(memberships, organization_id == ^actor(:organization_id)))

      # 3. If they weren’t forbidden by the tenancy check, allow.
      authorize_if always()
    end

    policy action(:update) do
      forbid_if actor_attribute_equals(:id, nil)
      forbid_if expr(not exists(memberships, organization_id == ^actor(:organization_id)))

      forbid_if expr(
                  (not is_nil(arg(:is_platform_staff)) or not is_nil(arg(:is_platform_admin))) and
                    ^actor(:is_platform_admin) != true
                )

      authorize_if always()
    end
  end

  rate_limit do
    # Use our Redis-backed Hammer module
    hammer Voelgoedevents.RateLimit

    # Limit password sign-in per IP
    action :sign_in_with_password,
      limit: 10,
      per: :timer.minutes(5),
      key: fn _changeset, context ->
        ip = context[:ip_address] || "unknown"
        "auth:user:sign_in:ip:#{ip}"
      end

    # Limit registration per IP
    action :register_with_password,
      limit: 5,
      per: :timer.hours(1),
      key: fn _changeset, context ->
        ip = context[:ip_address] || "unknown"
        "auth:user:register:ip:#{ip}"
      end
  end

  # ===========================================================================
  # PUBLIC NAMED FUNCTIONS (Must be public for &__MODULE__ captures)
  # ===========================================================================

  def get_token_signing_secret(_context, _resource) do
    {:ok, Application.fetch_env!(:voelgoedevents, :token_signing_secret)}
  end

  # Allow AshAuthentication and other “no actor yet” flows to query users
  # safely. Authorization is still enforced by the policies block.
  def filter_by_organization(query, %{actor: nil}), do: query

  def filter_by_organization(query, %{actor: actor}) do
    case Map.get(actor, :organization_id) do
      nil ->
        # Actor exists but has no org – hard deny
        Query.filter(query, false)

      organization_id ->
        Query.filter(query, exists(memberships, organization_id == ^organization_id))
    end
  end

  # User.create is the single source of truth for initial membership creation.
  def setup_new_user_membership(changeset, _context) do
    organization_id = Changeset.get_argument(changeset, :organization_id)
    role_id = Changeset.get_argument(changeset, :role_id)

    Changeset.manage_relationship(
      changeset,
      :memberships,
      [%{organization_id: organization_id, role_id: role_id}],
      type: :create
    )
  end

  def run_resend_confirmation(%{email: email}, context) do
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

  # Changed from defp to def
  def set_platform_admin_from_argument(changeset, _context) do
    case Changeset.fetch_argument(changeset, :is_platform_admin) do
      {:ok, value} -> Changeset.force_change_attribute(changeset, :is_platform_admin, value)
      :error -> changeset
    end
  end

  def set_platform_staff_from_argument(changeset, _context) do
    case Changeset.fetch_argument(changeset, :is_platform_staff) do
      {:ok, value} -> Changeset.force_change_attribute(changeset, :is_platform_staff, value)
      :error -> changeset
    end
  end

  # Changed from defp to def
  def audit_platform_admin_change(changeset, _context) do
    previous_value = Map.get(changeset.data, :is_platform_admin)

    Changeset.after_action(changeset, fn changeset, user ->
      if Changeset.changing_attribute?(changeset, :is_platform_admin) do
        actor = get_in(changeset.context, [:private, :actor]) || %{}

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

  # Changed from defp to def
  def invalidate_membership_cache_on_deactivate(changeset, user, context) do
    if disabled?(changeset) do
      context
      |> Context.to_opts()
      |> Keyword.put_new(:actor, context.actor)
      |> invalidate_memberships(user)
    end

    {:ok, user}
  end

  # Helper functions can remain private (defp) as they are not called by the DSL
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
