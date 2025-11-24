defmodule Voelgoedevents.Ash.Resources.Accounts.Membership do
  @moduledoc "Ash resource: Membership linking users to organizations."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table("CHANGE_ME")
    repo(Voelgoedevents.Repo)
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
