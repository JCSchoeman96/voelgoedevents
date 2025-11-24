defmodule Voelgoedevents.Ash.Resources.Events.OccupancySnapshot do
  @moduledoc "Ash resource: Periodic occupancy snapshots for dashboards."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.EventsDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table("CHANGE_ME")
    repo(Voelgoedevents.Repo)
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
