defmodule VoelgoedeventsWeb.Plugs.CurrentUserPlug do
  @moduledoc "Plug to load the authenticated user and active organization from the session."

  import Plug.Conn
  require Ash.Query

  alias Voelgoedevents.Ash.Domains.AccountsDomain
  alias Voelgoedevents.Ash.Resources.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, user_id} <- fetch_user_id(conn),
         {:ok, %User{} = user} <- load_user(user_id) do
      conn
      |> assign(:current_user, user)
      |> assign(:organization_id, active_organization_id(user))
    else
      _ ->
        conn
    end
  end

  defp fetch_user_id(conn) do
    case get_session(conn, :user_id) do
      nil -> :error
      user_id -> {:ok, user_id}
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

  defp active_organization_id(%User{memberships: memberships}) do
    memberships
    |> Enum.find(&(&1.status == :active))
    |> case do
      %{organization_id: organization_id} -> organization_id
      _ -> nil
    end
  end
end
