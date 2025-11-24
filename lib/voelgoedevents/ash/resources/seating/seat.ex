defmodule Voelgoedevents.Ash.Resources.Seating.Seat do
  @moduledoc "Ash resource: Individual seat."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.SeatingDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table("CHANGE_ME")
    repo(Voelgoedevents.Repo)
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
