defmodule VoelgoedeventsWeb.EventLiveTest do
  @moduledoc "LiveView tests stub for event views."

  use VoelgoedeventsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "home page" do
    test "GET / responds successfully", %{conn: conn} do
      # Hit the normal controller route
      conn = get(conn, "/")

      # Basic sanity check: status and some text
      assert html_response(conn, 200) =~ "Voelgoedevents"
    end
  end
end
