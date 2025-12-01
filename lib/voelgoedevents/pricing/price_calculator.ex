defmodule Voelgoedevents.Pricing.PriceCalculator do
  @moduledoc """
  High-concurrency service for calculating the final price of a ticket/seat.
  Combines base price, dynamic tiers, and seating zone overrides.
  """
  # FIX: Changed single '\' to correct default operator '\\'
  @spec calculate_price(Voelgoedevents.Ash.Resources.Ticketing.TicketType.t(), map()) :: integer()
  def calculate_price(_ticket_type, _context \\ %{}), do: :not_implemented
end
