defmodule Voelgoedevents.Ash.Domains.TicketingDomain do
  @moduledoc "Ash domain for tickets, pricing rules, and coupons."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Ticketing.Ticket
    resource Voelgoedevents.Ash.Resources.Ticketing.PricingRule
    resource Voelgoedevents.Ash.Resources.Ticketing.Coupon
    resource Voelgoedevents.Ash.Resources.Ticketing.OrderState
  end

  # See docs/domain/*.md for the domain rules.
end
