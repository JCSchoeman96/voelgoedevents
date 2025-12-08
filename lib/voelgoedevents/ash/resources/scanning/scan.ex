defmodule Voelgoedevents.Ash.Resources.Scanning.Scan do
  @moduledoc "Ash resource: Scan event."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.ScanningDomain

  postgres do
    # TODO: configure correct table name
    table "scans"
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
