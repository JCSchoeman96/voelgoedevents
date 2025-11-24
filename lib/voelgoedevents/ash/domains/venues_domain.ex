defmodule Voelgoedevents.Ash.Domains.VenuesDomain do
  @moduledoc "Ash domain for venues and gates."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Venues.Venue
    resource Voelgoedevents.Ash.Resources.Venues.Gate
  end


  # TODO: Add resources for this domain.
  # See docs/domain/*.md for the domain rules.
end
