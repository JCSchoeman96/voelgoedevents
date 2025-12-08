defmodule Voelgoedevents.Ash.Resources.Venues.Venue do
  @moduledoc "Ash resource: Venue details."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.VenuesDomain

  postgres do
    # TODO: configure correct table name
    table "venues"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end
  end

  # TODO: define relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
