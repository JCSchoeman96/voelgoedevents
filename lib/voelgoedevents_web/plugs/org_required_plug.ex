defmodule VoelgoedeventsWeb.Plugs.OrgRequiredPlug do
  @moduledoc """
  Enforces that a user has selected an organization.
  Use this plug in pipelines that require org context.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]
  use VoelgoedeventsWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_organization_id] do
      nil ->
        conn
        |> put_flash(:error, "Please select an organization")
        |> redirect(to: ~p"/select-organization")
        |> halt()

      _org_id ->
        conn
    end
  end
end
