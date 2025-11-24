defmodule Voelgoedevents.Ash.Domains.EventsDomain do
  @moduledoc "Ash domain for events and occupancy snapshots."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Events.Event
    resource Voelgoedevents.Ash.Resources.Events.OccupancySnapshot
  end

  # See docs/domain/*.md for the domain rules.
end
