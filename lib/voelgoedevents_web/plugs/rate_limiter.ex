defmodule VoelgoedeventsWeb.Plugs.RateLimiter do
  @moduledoc """
  HTTP-level rate limiting for sensitive endpoints.

  Uses Hammer + Redis under Voelgoedevents.RateLimit.
  Typically applied to /auth routes to limit attempts per IP.
  """

  @behaviour Plug

  import Plug.Conn
  require Logger

  @default_max 10
  @default_interval_ms :timer.minutes(1)

  def init(opts), do: opts

  def call(conn, opts) do
    max_requests = Keyword.get(opts, :max_requests, @default_max)
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)

    ip = extract_ip(conn)
    key = "auth:http:ip:#{ip}"

    case Voelgoedevents.RateLimit.hit(key, interval_ms, max_requests) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(max_requests))
        |> put_resp_header("x-ratelimit-remaining", to_string(max(0, max_requests - count)))

      {:deny, retry_after_ms} ->
        Logger.warning("HTTP auth rate limit exceeded",
          ip: ip,
          path: conn.request_path
        )

        conn
        |> put_resp_header("retry-after", Integer.to_string(div(retry_after_ms, 1000)))
        |> put_resp_content_type("application/json")
        |> send_resp(429, ~s({"error":"Too Many Requests"}))
        |> halt()
    end
  end

  defp extract_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
