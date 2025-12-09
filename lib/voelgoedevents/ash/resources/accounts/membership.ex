defmodule Voelgoedevents.Ash.Resources.Accounts.Membership do
  @moduledoc "Ash resource: Membership linking users to organizations."

  alias Ash.Changeset
  alias Voelgoedevents.Ash.Policies.{OrgRbacPolicy, PlatformPolicy}
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
    attribute :user_id, :uuid do
      allow_nil? false
      primary_key? true
      public? false
    end

    attribute :organization_id, :uuid do
      allow_nil? false
      primary_key? true
      public? false
    end

    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :inactive]
      default :active
    end

    attribute :invited_at, :utc_datetime do
      public? true
    end

    attribute :joined_at, :utc_datetime do
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
    identity :primary, [:user_id, :organization_id]
  end

  validations do
    validate present([:status, :role_id, :user_id, :organization_id])

    validate fn changeset, _context ->
      status = Changeset.get_attribute(changeset, :status)
      joined_at = Changeset.get_attribute(changeset, :joined_at)

      if status == :active and is_nil(joined_at) do
        Changeset.add_error(changeset, :joined_at, "must be set when activating membership")
      else
        changeset
      end
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:role_id, :status, :invited_at, :joined_at, :user_id, :organization_id]

      change &__MODULE__.maybe_set_invited_at/2
      change &__MODULE__.maybe_set_joined_at/2
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

    policy action_type(:read) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      OrgRbacPolicy.can?(:read_only)
    end

    policy action([:create, :invite, :update, :remove]) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      OrgRbacPolicy.can?(:admin)
    end

    policy action(:join) do
      forbid_if expr(user_id != actor(:id) or organization_id != actor(:organization_id))
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
      status == :active and is_nil(joined_at) -> Changeset.change_attribute(changeset, :joined_at, DateTime.utc_now())
      true -> changeset
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
end
