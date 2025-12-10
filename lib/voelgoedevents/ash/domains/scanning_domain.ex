defmodule Voelgoedevents.Ash.Domains.ScanningDomain do
  @moduledoc "Ash domain for scanning events and sessions."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Scanning.Scan
    resource Voelgoedevents.Ash.Resources.Scanning.ScanSession
  end

  authorization do
    authorize :by_default
    require_actor? true
  end

  # See docs/domain/*.md for the domain rules.
end
