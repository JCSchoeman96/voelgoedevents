defmodule Voelgoedevents.Ash.Domains.SeatingDomain do
  @moduledoc "Ash domain for seating layouts, blocks, and seats."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Seating.Block
    resource Voelgoedevents.Ash.Resources.Seating.Layout
    resource Voelgoedevents.Ash.Resources.Seating.Seat
  end

  authorization do
    authorizers [Ash.Policy.Authorizer]
  end

  # See docs/domain/*.md for the domain rules.
end
