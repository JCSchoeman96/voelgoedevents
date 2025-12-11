defmodule VoelgoedeventsWeb.Plugs.SetRateLimitContext do
  @moduledoc """
  Injects the client IP into the Ash context for use by AshRateLimiter.

  This makes `context[:ip_address]` available in resource-level rate_limit blocks.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    ip = extract_ip(conn)

    conn
    |> put_private(:rate_limit_ip, ip)
    |> Ash.PlugHelpers.set_context(%{ip_address: ip})
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
