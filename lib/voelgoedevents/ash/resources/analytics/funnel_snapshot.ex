defmodule Voelgoedevents.Ash.Resources.Analytics.FunnelSnapshot do
  @moduledoc "Ash resource: Funnel aggregates."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.AnalyticsDomain

  postgres do
    # TODO: configure correct table name
    table "funnel_snapshots"
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
