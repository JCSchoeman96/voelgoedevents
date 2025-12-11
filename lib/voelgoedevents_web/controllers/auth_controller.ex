defmodule VoelgoedeventsWeb.AuthController do
  @moduledoc """
  Phoenix controller for AshAuthentication browser flows.

  This controller handles success/failure/sign-out for web authentication.
  It is strictly a Phoenix edge adapter - no Ash resource calls, no domain
  logic, no RBAC checks. All auth behavior comes from AshAuthentication.
  """
  use VoelgoedeventsWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @doc """
  Called on successful authentication (login or registration).

  Stores user in session, assigns current_user, and redirects to
  the return_to path (or "/" if not set).
  """
  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  @doc """
  Called on authentication failure.

  Renders the failure template with an unauthorized status.
  """
  def failure(conn, _activity, _reason) do
    conn
    |> put_status(:unauthorized)
    |> put_view(VoelgoedeventsWeb.AuthHTML)
    |> render(:failure)
  end

  @doc """
  Handles user sign-out.

  Clears the session and redirects to the return_to path (or "/").
  """
  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:voelgoedevents)
    |> redirect(to: return_to)
  end
end
