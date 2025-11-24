defmodule Voelgoedevents.Ash.Resources.Scanning.ScanSession do
  @moduledoc "Ash resource: Scan session."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.ScanningDomain,
    data_layer: AshPostgres.DataLayer

  postgres do
    # TODO: configure correct table name and repo
    table("CHANGE_ME")
    repo(Voelgoedevents.Repo)
  end

  # TODO: define attributes, relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
