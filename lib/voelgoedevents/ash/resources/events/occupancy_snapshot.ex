defmodule Voelgoedevents.Ash.Resources.Events.OccupancySnapshot do
  @moduledoc "Ash resource: Periodic occupancy snapshots for dashboards."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.EventsDomain

  postgres do
    # TODO: configure correct table name
    table "occupancy_snapshots"
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
