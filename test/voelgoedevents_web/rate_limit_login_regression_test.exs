defmodule VoelgoedeventsWeb.RateLimitLoginRegressionTest do
  use VoelgoedeventsWeb.ConnCase, async: true

  @login_page "/auth/log_in"
  @wrong_post "/auth/log_in"
  @real_sign_in "/auth/user/password/sign_in"

  # Helpers -------------------------------------------------------------------

  defp extract_csrf_token!(html) when is_binary(html) do
    case Regex.run(~r/name="csrf-token"\s+content="([^"]+)"/, html) do
      [_, token] -> token
      _ -> raise "Could not find csrf-token meta tag in login page HTML"
    end
  end

  defp establish_session_and_csrf(conn) do
    conn = get(conn, @login_page)
    csrf = extract_csrf_token!(html_response(conn, 200))
    {conn, csrf}
  end

  defp post_form(conn, path, csrf, params, ip \\ "127.0.0.1") do
    conn
    |> recycle()
    |> put_req_header("accept", "text/html")
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> put_req_header("x-csrf-token", csrf)
    # ensure stable IP keying if your limiter keys off request IP / forwarded-for
    |> put_req_header("x-forwarded-for", ip)
    |> post(path, params)
  end

  # Tests ---------------------------------------------------------------------

  test "POSTing to /auth/log_in (404) does not trigger login rate limit", %{conn: conn} do
    {conn, csrf} = establish_session_and_csrf(conn)

    statuses =
      for _ <- 1..30 do
        c = post_form(conn, @wrong_post, csrf, %{"email" => "test@example.com"})
        c.status
      end

    assert Enum.all?(statuses, &(&1 == 404)),
           "Expected 404 for wrong POST route, got: #{inspect(statuses)}"

    refute Enum.any?(statuses, &(&1 == 429)),
           "Wrong route should not burn login rate limit, but saw 429 in: #{inspect(statuses)}"
  end

  test "real sign-in endpoint eventually rate limits after repeated attempts", %{conn: conn} do
    {conn, csrf} = establish_session_and_csrf(conn)

    # Try enough times to exceed your configured threshold.
    # If your limiter is high, increase this number or (better) lower limits in test config.
    attempts = 60

    statuses =
      for _ <- 1..attempts do
        c = post_form(conn, @real_sign_in, csrf, %{"email" => "test@example.com"})
        c.status
      end

    # You will likely see lots of 401s (invalid credentials) before rate limiting kicks in.
    # We only care that 429 happens at some point.
    assert Enum.any?(statuses, &(&1 == 429)),
           "Expected to eventually hit 429 on #{@real_sign_in}. Statuses: #{inspect(statuses)}"
  end
end
