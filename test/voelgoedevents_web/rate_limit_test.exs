defmodule VoelgoedeventsWeb.RateLimitTest do
  use VoelgoedeventsWeb.ConnCase, async: true

  @password "TestPassword123!"

  test "auth sign-in is rate limited per IP + path", %{conn: conn} do
    conn =
      Enum.reduce(1..12, conn, fn _i, conn ->
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => "nobody@example.com", "password" => @password}
        })
      end)

    assert conn.status == 429
  end
end
