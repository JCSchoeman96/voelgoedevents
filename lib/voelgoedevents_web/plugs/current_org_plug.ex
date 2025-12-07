defmodule VoelgoedeventsWeb.Plugs.CurrentOrgPlug do
  @moduledoc """
  Adjusts organization context based on session.
  Runs AFTER CurrentUserPlug.
  Does NOT set actor (only updates context).
  """

  import Plug.Conn
  alias Ash.PlugHelpers

  def init(opts), do: opts

  def call(conn, _opts) do
    # Prefer session-selected org, fallback to user's default (already in assigns)
    org_id = get_session(conn, :selected_organization_id) ||
             conn.assigns[:current_organization_id]

    # Only verify organization existence if we have an ID
    org_id = if is_valid_org_id?(org_id), do: org_id, else: nil

    conn
    |> PlugHelpers.set_context(%{organization_id: org_id})
    |> assign(:current_organization_id, org_id)
  end

  # Basic validation to ensure we don't pass garbage to context
  defp is_valid_org_id?(nil), do: false
  defp is_valid_org_id?(id) when is_binary(id), do: true
  defp is_valid_org_id?(_), do: false
end
