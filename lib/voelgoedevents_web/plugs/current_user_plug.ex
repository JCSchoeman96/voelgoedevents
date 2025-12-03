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
    case load_user(session.target_user_id) do
      {:ok, %User{} = user} ->
        assign_user(conn, user, session)

      _ ->
        fallback_to_primary_user(session)
    end
  end

  defp load_user_from_session(conn), do: conn

  defp fallback_to_primary_user(
         %{fallback_user_id: fallback_id, target_user_id: target_id, conn: conn} = session
       )
       when fallback_id != target_id do
    case load_user(fallback_id) do
      {:ok, %User{} = user} ->
        session
        |> Map.merge(%{target_user_id: fallback_id, impersonator_id: nil})
        |> assign_user(user)

      _ ->
        conn
    end
  end

  defp fallback_to_primary_user(%{conn: conn}), do: conn

  defp assign_user(%{conn: conn} = session, user) do
    conn
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
end
