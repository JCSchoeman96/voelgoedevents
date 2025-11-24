defmodule Voelgoedevents.Ash.Resources.Ticketing.Ticket do
  @moduledoc "Ash resource: Ticket with state machine."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.TicketingDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table("CHANGE_ME")
    repo(Voelgoedevents.Repo)
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
