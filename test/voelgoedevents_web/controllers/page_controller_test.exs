defmodule VoelgoedeventsWeb.PageControllerTest do
  use VoelgoedeventsWeb.ConnCase, async: true
  import Phoenix.ConnTest

  describe "home page" do
    test "GET / responds successfully", %{conn: conn} do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "Voelgoedevents"
    end
  end
end
