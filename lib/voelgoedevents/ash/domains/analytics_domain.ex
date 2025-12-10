defmodule Voelgoedevents.Ash.Domains.AnalyticsDomain do
  @moduledoc "Ash domain for analytics events and funnel snapshots."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Analytics.AnalyticsEvent
    resource Voelgoedevents.Ash.Resources.Analytics.FunnelSnapshot
  end

  authorization do
    authorizers [Ash.Policy.Authorizer]
  end

  # See docs/domain/*.md for the domain rules.
end
