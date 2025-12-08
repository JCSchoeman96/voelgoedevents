defmodule Voelgoedevents.Ash.Resources.Seating.Seat do
  @moduledoc "Ash resource: Individual seat."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.SeatingDomain

  postgres do
    # TODO: configure correct table name
    table "seats"
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
