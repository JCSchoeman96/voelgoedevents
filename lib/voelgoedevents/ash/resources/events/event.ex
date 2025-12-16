defmodule Voelgoedevents.Ash.Resources.Events.Event do
  @moduledoc "Ash resource: Event aggregate root."

  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.EventsDomain

  postgres do
    table "events"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end

    attribute :venue_id, :uuid do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :description, :string do
      allow_nil? true
      default ""
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: [:draft, :published, :on_sale, :paused, :closed]
      default :draft
    end

    attribute :start_at, :utc_datetime_usec do
      allow_nil? false
    end

    attribute :end_at, :utc_datetime_usec do
      allow_nil? false
    end

    attribute :settings, :map do
      allow_nil? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :venue, Voelgoedevents.Ash.Resources.Venues.Venue do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_slug_per_organization, [:slug, :organization_id]
  end

  validations do
    validate present([:organization_id, :venue_id, :name, :slug, :status, :start_at, :end_at])
    validate compare(:end_at, greater_than: :start_at)
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :organization_id,
        :venue_id,
        :name,
        :slug,
        :description,
        :status,
        :start_at,
        :end_at,
        :settings
      ]
    end

    update :update do
      accept [:venue_id, :name, :slug, :description, :status, :start_at, :end_at, :settings]
    end

    destroy :destroy do
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    # Read: Allow all authenticated org members
    policy action_type(:read) do
      forbid_if expr(is_nil(^actor(:user_id)))
      authorize_if expr(organization_id == ^actor(:organization_id))
    end

    # Create: Only organizers, admins, and owners can create events
    policy action_type(:create) do
      forbid_if expr(is_nil(^actor(:user_id)))
      forbid_if expr(arg(:organization_id) != ^actor(:organization_id))
      authorize_if expr(^actor(:role) in [:owner, :admin, :organizer])
    end

    # Update/Destroy: Only organizers, admins, and owners
    policy action_type([:update, :destroy]) do
      forbid_if expr(is_nil(^actor(:user_id)))
      forbid_if expr(organization_id != ^actor(:organization_id))
      authorize_if expr(^actor(:role) in [:owner, :admin, :organizer])
    end
  end
end
