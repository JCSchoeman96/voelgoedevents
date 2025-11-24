defmodule Voelgoedevents.Ash.Domains.CoreDomain do
  @moduledoc "Ash domain aggregating core shared resources."

  use Ash.Domain
  resources do
    resource Voelgoedevents.Ash.Resources.Organizations.Organization
  end

  # See docs/domain/*.md for the domain rules.
end
