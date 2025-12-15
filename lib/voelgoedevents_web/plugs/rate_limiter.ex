defmodule VoelgoedeventsWeb.Plugs.RateLimiter do
  @moduledoc """
  Applies one-or-more rate limit rules (usually set by SetRateLimitContext).

  Resilience:
    - If Redis/Hammer is unavailable, behavior is controlled by :on_error.
      Recommended:
        * dev/test: :allow
        * prod: :deny (or :service_unavailable)
  """
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    rules = conn.assigns[:rate_limit_rules] || []
    on_error = Keyword.get(opts, :on_error, default_on_error())

    Enum.reduce_while(rules, conn, fn rule, conn ->
      key = rule.key
      interval_ms = rule.interval_ms
      max = rule.max

      case Voelgoedevents.RateLimit.hit(key, interval_ms, max) do
        {:allow, _count} ->
          {:cont, conn}

        {:deny, retry_ms} ->
          conn
          |> put_resp_header("cache-control", "no-store")
          |> put_resp_header("retry-after", Integer.to_string(ceil(retry_ms / 1000)))
          |> send_resp(429, "Too Many Requests")
          |> halt()
          |> then(&{:halt, &1})

        {:error, _reason} ->
          handle_error(conn, on_error)
      end
    end)
  end

  defp handle_error(conn, :allow), do: {:cont, conn}

  defp handle_error(conn, :deny) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(429, "Too Many Requests")
    |> halt()
    |> then(&{:halt, &1})
  end

  defp handle_error(conn, :service_unavailable) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(503, "Rate limiter unavailable")
    |> halt()
    |> then(&{:halt, &1})
  end

  defp default_on_error do
    Application.get_env(:voelgoedevents, :rate_limiter_on_error, :allow)
  end
end
