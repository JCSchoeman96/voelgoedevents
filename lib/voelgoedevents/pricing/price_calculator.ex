defmodule Voelgoedevents.Pricing.PriceCalculator do
  @moduledoc """
  High-concurrency service for dynamic price calculation (Phase 19).
  """
  @spec calculate_price(Voelgoedevents.Ash.Resources.Ticketing.TicketType.t(), map()) :: integer()
  def calculate_price(_ticket_type, _context \ %{}), do: :not_implemented
end
