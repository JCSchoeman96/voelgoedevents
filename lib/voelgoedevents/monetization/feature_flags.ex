defmodule Voelgoedevents.Monetization.FeatureFlags do
  @moduledoc "Core service for checking if an advanced feature is enabled per tenant (Phase 21)."
  def is_enabled?(_organization, _feature_key), do: false
end
