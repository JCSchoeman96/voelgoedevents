defmodule Voelgoedevents.Ash.Resources.Accounts.Membership do
  @moduledoc "Ash resource: Membership linking users to organizations."

  alias Ash.Changeset
  alias Voelgoedevents.Ash.Policies.{OrgRbacPolicy, PlatformPolicy}
  alias Voelgoedevents.Ash.Policies.Checks.MembershipInviteScope
  alias Voelgoedevents.Caching.MembershipCache

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain

  require OrgRbacPolicy
  require PlatformPolicy

  postgres do
    table "memberships"
    repo Voelgoedevents.Repo
  end

  attributes do
    # Canonical primary key for Membership
    uuid_primary_key :id

    # Foreign key to the user
    attribute :user_id, :uuid do
      allow_nil? false
      public? false
    end

    # Foreign key to the organization
    attribute :organization_id, :uuid do
      allow_nil? false
      public? false
    end

    # Foreign key to the Role
    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    # Membership lifecycle state
    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :inactive]
      default :active
    end

    attribute :invited_at, :utc_datetime_usec do
      public? true
    end

    attribute :joined_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :role, Voelgoedevents.Ash.Resources.Accounts.Role do
      allow_nil? false
      attribute_writable? true
      define_attribute? false
    end

    belongs_to :user, Voelgoedevents.Ash.Resources.Accounts.User do
      allow_nil? false
      attribute_writable? true
      define_attribute? false
    end

    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
      define_attribute? false
    end
  end

  identities do
    # Logical uniqueness: a user can only have one membership per organization
    identity :unique_user_organization, [:user_id, :organization_id]
  end

  validations do
    validate present([:status, :role_id, :user_id, :organization_id])

    validate fn changeset, context ->
      status = Changeset.get_attribute(changeset, :status)
      joined_at = Changeset.get_attribute(changeset, :joined_at)

      if status == :active and is_nil(joined_at) do
        {:error, "joined_at must be set when activating membership"}
      else
        :ok
      end
    end

    # Validate organization_id matches actor's organization for create/invite actions
    # Note: Actor access moved to change function; validation can't reliably access actor context
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:role_id, :status, :invited_at, :joined_at, :user_id, :organization_id]

      change &__MODULE__.maybe_set_invited_at/2
      change &__MODULE__.maybe_set_joined_at/2
      change &__MODULE__.validate_platform_staff_protection/2
      change after_action(&__MODULE__.invalidate_membership_cache/3)
    end

    update :update do
      require_atomic? false
      accept [:role_id, :status, :invited_at, :joined_at]

      change &__MODULE__.maybe_set_joined_at/2
      change after_action(&__MODULE__.invalidate_membership_cache/3)
    end

    create :invite do
      accept [:role_id, :user_id, :organization_id]

      change set_attribute(:status, :inactive)
      change &__MODULE__.set_invited_at/2
      change &__MODULE__.validate_platform_staff_protection/2
      change after_action(&__MODULE__.invalidate_membership_cache/3)
    end

    update :join do
      require_atomic? false
      accept []

      change set_attribute(:status, :active)
      change &__MODULE__.set_joined_at/2
      change after_action(&__MODULE__.invalidate_membership_cache/3)
    end

    destroy :remove do
      require_atomic? false
      change after_action(&__MODULE__.invalidate_membership_cache/3)
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    # READ: same-org only, viewer and above
    policy action_type(:read) do
      forbid_if expr(is_nil(^actor(:user_id)))
      forbid_if expr(organization_id != ^actor(:organization_id))
      OrgRbacPolicy.can?(:viewer)
    end

    # CREATE/INVITE: same-org only, owner/admin, platform staff protection via change
    # Note: Use MembershipInviteScope check to compare actor org with changeset org
    # (avoids CannotFilterCreates error that occurs when filtering on attributes)
    policy action([:create, :invite]) do
      forbid_if expr(is_nil(^actor(:user_id)))
      forbid_if expr(is_nil(^actor(:organization_id)))
      authorize_if MembershipInviteScope
    end

    # UPDATE/REMOVE: same-org only, owner/admin, with platform staff protection
    policy action([:update, :remove]) do
      forbid_if expr(is_nil(^actor(:user_id)))
      forbid_if expr(organization_id != ^actor(:organization_id))

      # Tenants cannot touch memberships for platform staff users;
      # only platform admins may do that.
      forbid_if expr(
                  user.is_platform_staff == true and
                    ^actor(:is_platform_admin) != true
                )

      OrgRbacPolicy.can?(:admin)
    end

    # JOIN: invited user in the correct org can accept their own membership
    policy action(:join) do
      forbid_if expr(is_nil(^actor(:user_id)))

      forbid_if expr(
                  user_id != ^actor(:user_id) or
                    organization_id != ^actor(:organization_id)
                )

      authorize_if always()
    end
  end

  def maybe_set_invited_at(changeset, _context) do
    status = Changeset.get_attribute(changeset, :status)

    if status == :inactive and is_nil(Changeset.get_attribute(changeset, :invited_at)) do
      Changeset.change_attribute(changeset, :invited_at, DateTime.utc_now())
    else
      changeset
    end
  end

  def maybe_set_joined_at(changeset, _context) do
    status = Changeset.get_attribute(changeset, :status)
    joined_at = Changeset.get_attribute(changeset, :joined_at)

    cond do
      status == :active and is_nil(joined_at) ->
        Changeset.change_attribute(changeset, :joined_at, DateTime.utc_now())

      true ->
        changeset
    end
  end

  def set_invited_at(changeset, _context) do
    Changeset.change_attribute(changeset, :invited_at, DateTime.utc_now())
  end

  def set_joined_at(changeset, _context) do
    Changeset.change_attribute(changeset, :joined_at, DateTime.utc_now())
  end

  def invalidate_membership_cache(_changeset, membership, _context) do
    MembershipCache.invalidate(membership.user_id, membership.organization_id)
    {:ok, membership}
  end

  @doc """
  Validates organization_id matches actor's organization and that non-platform-admin actors
  cannot create/invite memberships for platform staff users.

  This change function validates tenant scoping and loads the User resource to check
  is_platform_staff, avoiding the CannotFilterCreates error that occurs when policies
  reference relationships or filter on attributes during create.
  """
  def validate_platform_staff_protection(changeset, context) do
    actor = Map.get(context, :actor)

    # Platform admins bypass platform staff check
    changeset =
      if actor && Map.get(actor, :is_platform_admin) == true do
        changeset
      else
        user_id = Changeset.get_attribute(changeset, :user_id)

        if user_id do
          case Ash.read_one(
                 Voelgoedevents.Ash.Resources.Accounts.User,
                 id: user_id,
                 authorize?: false
               ) do
            {:ok, user} when not is_nil(user) ->
              if user.is_platform_staff == true do
                Changeset.add_error(
                  changeset,
                  field: :user_id,
                  message: "Cannot create membership for platform staff user"
                )
              else
                changeset
              end

            _ ->
              # If user not found or error, let other validations handle it
              changeset
          end
        else
          changeset
        end
      end

    changeset
  end
end
