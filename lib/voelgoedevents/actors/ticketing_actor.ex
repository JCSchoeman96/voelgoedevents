defmodule Voelgoedevents.Actors.TicketingActor do
  @moduledoc """
  Ticketing domain orchestrator — responsible for high-level workflows such as:

    - Ticket purchase flows (GA + reserved)
    - Seat allocation and reservation operations
    - Post-purchase issuance
    - Scanning integration and event-day flows
    - Refund initiation coordination (not financial processing)

  This actor is designed so AI agents have a clear, single point of entry
  for ticketing-related multi-step operations.

  # TODO:
  - Add functions for purchase flows (prepare → validate → reserve → issue)
  - Add seat block + pricing coordination helpers
  - Integrate scanning domain and event engine
  - Add workflow templates for agents (e.g., "resolve scanning discrepancy")

  NOTE:
  Core business logic lives in Ash resources. This actor composes actions.
  """

  # TODO: Add function stubs
  # def process_purchase(params), do: ...
end
