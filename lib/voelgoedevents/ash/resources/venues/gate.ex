defmodule Voelgoedevents.Ash.Resources.Venues.Gate do
  @moduledoc "Ash resource: Entry gates for scanning."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.VenuesDomain

  postgres do
    # TODO: configure correct table name
    table "gates"
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
