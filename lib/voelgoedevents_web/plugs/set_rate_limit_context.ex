defmodule VoelgoedeventsWeb.Plugs.SetRateLimitContext do
  import Plug.Conn
  alias Ash.PlugHelpers

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    ip = ip_string(conn)

    auth = auth_action(conn)

    email =
      conn.params
      |> extract_identifier()
      |> normalize_email()

    email_hash = if email, do: hash_email(email), else: nil

    rules =
      case auth do
        :login ->
          []
          |> maybe_add_rule(true, %{
            key: "vge:rl:auth:login:ip:#{ip}",
            max: 60,
            interval_ms: 60_000
          })
          |> maybe_add_rule(email_hash != nil, %{
            key: "vge:rl:auth:login:email_ip:#{email_hash}:#{ip}",
            max: 10,
            interval_ms: 600_000
          })
          |> maybe_add_rule(email_hash != nil, %{
            key: "vge:rl:auth:login:email:#{email_hash}",
            max: 20,
            interval_ms: 3_600_000
          })

        :reset ->
          []
          |> maybe_add_rule(true, %{
            key: "vge:rl:auth:reset:ip:#{ip}",
            max: 30,
            interval_ms: 3_600_000
          })
          |> maybe_add_rule(email_hash != nil, %{
            key: "vge:rl:auth:reset:email:#{email_hash}",
            max: 5,
            interval_ms: 3_600_000
          })

        :none ->
          []
      end

    labels = labels(auth, email_hash != nil)

    conn
    |> assign(:rate_limit_rules, rules)
    |> PlugHelpers.set_context(%{ip_address: ip})
    |> maybe_put_debug_header(labels)
  end

  defp auth_action(%Plug.Conn{method: "POST", request_path: "/auth/log_in"}), do: :login
  defp auth_action(%Plug.Conn{method: "POST", request_path: "/auth/reset"}), do: :reset
  defp auth_action(_), do: :none

  defp ip_string(%Plug.Conn{remote_ip: ip_tuple}) when is_tuple(ip_tuple) do
    case :inet.ntoa(ip_tuple) do
      {:error, _} -> "unknown"
      charlist when is_list(charlist) -> to_string(charlist)
    end
  end

  defp ip_string(_), do: "unknown"

  defp extract_identifier(params) when is_map(params) do
    cond do
      is_binary(get_in(params, ["user", "email"])) -> get_in(params, ["user", "email"])
      is_binary(Map.get(params, "email")) -> Map.get(params, "email")
      true -> nil
    end
  end

  defp extract_identifier(_), do: nil

  defp normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      v -> v
    end
  end

  defp normalize_email(_), do: nil

  defp hash_email(email) when is_binary(email) do
    :crypto.hash(:sha256, email)
    |> Base.encode16(case: :lower)
  end

  defp maybe_add_rule(rules, true, rule), do: [rule | rules]
  defp maybe_add_rule(rules, false, _rule), do: rules

  defp labels(:login, true), do: ["login_ip", "login_email_ip", "login_email"]
  defp labels(:login, false), do: ["login_ip"]
  defp labels(:reset, true), do: ["reset_ip", "reset_email"]
  defp labels(:reset, false), do: ["reset_ip"]
  defp labels(:none, _), do: []

  defp maybe_put_debug_header(conn, labels) do
    if Mix.env() == :dev and labels != [] do
      put_resp_header(conn, "x-vge-rate-limit-rules", Enum.join(labels, ","))
    else
      conn
    end
  end
end
