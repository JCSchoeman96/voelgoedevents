defmodule VoelgoedeventsWeb.CheckoutLiveTest do
  @moduledoc """
  LiveView tests for the checkout flow.

  NOTE:
  - Currently only tests that the LiveView mounts and renders the placeholder.
  - Cursor/agents will extend these tests once business logic is added.
  """

  use VoelgoedeventsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "checkout liveview" do
    test "renders the checkout page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/checkout")

      assert has_element?(view, "h1", "Checkout")
      assert has_element?(view, "[data-test=checkout-placeholder]")
    end
  end

  describe "authentication (future spec)" do
    @tag :skip
    test "redirects unauthenticated users to login", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/checkout")
      assert redirect_path =~ "/sign_in"
    end
  end
end
