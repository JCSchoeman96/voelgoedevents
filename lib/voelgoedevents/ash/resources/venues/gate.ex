defmodule Voelgoedevents.Ash.Resources.Venues.Gate do
  @moduledoc "Ash resource: Entry gates for scanning."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.VenuesDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table("CHANGE_ME")
    repo(Voelgoedevents.Repo)
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
