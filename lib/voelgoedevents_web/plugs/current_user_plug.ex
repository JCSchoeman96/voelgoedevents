defmodule VoelgoedeventsWeb.Plugs.CurrentUserPlug do
  @moduledoc "Plug to load the authenticated user and active organization from the session."

  import Plug.Conn
  require Ash.Query

  alias Voelgoedevents.Ash.Domains.AccountsDomain
  alias Voelgoedevents.Ash.Resources.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> fetch_user_session()
    |> load_user_from_session()
  end

  defp fetch_user_id(conn) do
    case get_session(conn, :user_id) do
      nil -> :error
      user_id -> {:ok, user_id}
    end
  end

  defp fetch_user_session(conn) do
    with {:ok, user_id} <- fetch_user_id(conn) do
      impersonated_user_id = get_session(conn, :impersonated_user_id)
      impersonator_id = get_session(conn, :impersonator_id)
      session_version = get_session(conn, :session_version)
      session_ip = get_session(conn, :session_ip)

      target_user_id =
        case {impersonated_user_id, impersonator_id} do
          {nil, _} -> user_id
          {_, nil} -> user_id
          _ -> impersonated_user_id
        end

      %{
        conn: conn,
        target_user_id: target_user_id,
        fallback_user_id: user_id,
        session_ip: session_ip,
        session_version: session_version,
        impersonator_id:
          if(target_user_id == user_id,
            do: nil,
            else: impersonator_id
          )
      }
    else
      _ ->
        conn
    end
  end

  defp load_user(user_id) do
    User
    |> Ash.Query.filter(id == ^user_id)
    |> Ash.Query.load(:memberships)
    |> Ash.read_one(domain: AccountsDomain)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, %User{} = user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_user_from_session(%{conn: conn} = session) do
    with {:ok, %User{} = user} <- load_user(session.target_user_id),
         :ok <- ensure_active_session(session, user, conn) do
      assign_user(conn, session, user)
    else
      {:error, :invalid_session} -> drop_session(conn)
      _ -> fallback_to_primary_user(session)
    end
  end

  defp load_user_from_session(conn), do: conn

  defp fallback_to_primary_user(
         %{fallback_user_id: fallback_id, target_user_id: target_id, conn: conn} = session
       )
       when fallback_id != target_id do
    with {:ok, %User{} = user} <- load_user(fallback_id),
         :ok <- ensure_active_session(session, user, conn) do
      session
      |> Map.merge(%{target_user_id: fallback_id, impersonator_id: nil})
      |> assign_user(user)
    else
      _ -> drop_session(conn)
    end
  end

  defp fallback_to_primary_user(%{conn: conn}), do: conn

  defp assign_user(%{conn: conn} = session, user) do
    computed_session_version = session_version(user)

    conn
    |> maybe_renew_session(session.session_version)
    |> put_session(:user_id, session.target_user_id)
    |> put_session(:session_version, computed_session_version)
    |> maybe_store_ip(session)
    |> assign(:current_user, user)
    |> assign(:organization_id, active_organization_id(user))
    |> maybe_assign_impersonator(session)
  end

  defp active_organization_id(%User{memberships: memberships}) do
    memberships
    |> Enum.find(&(&1.status == :active))
    |> case do
      %{organization_id: organization_id} -> organization_id
      _ -> nil
    end
  end

  defp maybe_assign_impersonator(conn, %{impersonator_id: nil}), do: conn

  defp maybe_assign_impersonator(
         conn,
         %{impersonator_id: impersonator_id, target_user_id: target_user_id, fallback_user_id: fallback_user_id}
       )
       when target_user_id != fallback_user_id do
    assign(conn, :impersonator_id, impersonator_id)
  end

  defp maybe_assign_impersonator(conn, _session), do: conn

  defp ensure_active_session(session, %User{} = user, conn) do
    with :ok <- validate_user_status(user),
         :ok <- validate_session_version(session.session_version, session_version(user)),
         :ok <- validate_session_ip(conn, session) do
      :ok
    else
      _ -> {:error, :invalid_session}
    end
  end

  defp validate_user_status(%User{status: :disabled}), do: {:error, :invalid_session}
  defp validate_user_status(_user), do: :ok

  defp validate_session_version(nil, _expected), do: :ok
  defp validate_session_version(stored, expected) when stored == expected, do: :ok
  defp validate_session_version(_stored, _expected), do: {:error, :invalid_session}

  defp validate_session_ip(conn, %{session_ip: session_ip}) do
    case {bind_session_ip?(), session_ip, client_ip(conn)} do
      {false, _, _} -> :ok
      {true, nil, _current_ip} -> :ok
      {true, stored_ip, current_ip} when stored_ip == current_ip -> :ok
      _ -> {:error, :invalid_session}
    end
  end

  defp maybe_renew_session(conn, nil), do: configure_session(conn, renew: true)
  defp maybe_renew_session(conn, _session_version), do: conn

  defp maybe_store_ip(conn, session) do
    case {bind_session_ip?(), client_ip(conn)} do
      {true, ip} when not is_nil(ip) and session.session_ip != ip -> put_session(conn, :session_ip, ip)
      _ -> conn
    end
  end

  defp client_ip(%Plug.Conn{remote_ip: nil}), do: nil
  defp client_ip(%Plug.Conn{remote_ip: remote_ip}), do: remote_ip |> :inet.ntoa() |> to_string()

  defp bind_session_ip? do
    Application.get_env(:voelgoedevents, :bind_session_ip, false)
  end

  defp session_version(%User{hashed_password: hashed_password, updated_at: updated_at}) do
    :crypto.hash(:sha256, "#{hashed_password}:#{updated_at}")
    |> Base.encode16(case: :lower)
  end

  defp drop_session(conn) do
    conn
    |> configure_session(drop: true)
    |> clear_session()
  end
end
