defmodule VoelgoedeventsWeb.CheckoutLive do
  @moduledoc """
  LiveView for handling the checkout flow.

  NOTE:
  - This is scaffolding only.
  - Cursor/agents will implement the actual flow later.
  """

  use VoelgoedeventsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Later:
    # - Load event
    # - Load selected tickets
    # - Handle authentication/session
    {:ok, assign(socket, :page_title, "Checkout")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main>
      <h1>Checkout</h1>
      <p data-test="checkout-placeholder">
        Checkout flow not implemented yet.
      </p>
    </main>
    """
  end
end
