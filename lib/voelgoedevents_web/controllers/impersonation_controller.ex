defmodule VoelgoedeventsWeb.ImpersonationController do
  @moduledoc "Controller for platform admin user impersonation lifecycle."

  use VoelgoedeventsWeb, :controller

  require Logger

  alias Voelgoedevents.Ash.Domains.AuditDomain
  alias Voelgoedevents.Ash.Resources.Audit.AuditLog

  plug :ensure_platform_admin

  @doc "Starts impersonation for the provided user identifier."
  def create(conn, %{"user_id" => impersonated_user_id}) do
    conn
    |> configure_session(renew: true)
    |> put_session(:impersonator_id, conn.assigns.current_user.id)
    |> put_session(:impersonated_user_id, impersonated_user_id)
    |> audit("impersonation_start", impersonated_user_id)
    |> send_resp(:no_content, "")
  end

  def create(conn, _params), do: send_resp(conn, :bad_request, "")

  @doc "Stops impersonation and clears related session state."
  def delete(conn, _params) do
    impersonated_user_id = get_session(conn, :impersonated_user_id)

    conn
    |> configure_session(renew: true)
    |> delete_session(:impersonator_id)
    |> delete_session(:impersonated_user_id)
    |> audit("impersonation_end", impersonated_user_id || conn.assigns.current_user.id)
    |> send_resp(:no_content, "")
  end

  defp ensure_platform_admin(%{assigns: %{current_user: %{is_platform_admin: true}}} = conn, _opts),
    do: conn

  defp ensure_platform_admin(conn, _opts) do
    conn
    |> send_resp(:forbidden, "")
    |> halt()
  end

  defp audit(conn, action, target_user_id) do
    actor = %{id: conn.assigns.current_user.id, organization_id: Map.get(conn.assigns, :organization_id)}

    attrs = %{
      actor_id: actor.id,
      action: action,
      resource: "user",
      resource_id: to_string(target_user_id),
      changes: %{
        impersonator_id: actor.id,
        impersonated_user_id: target_user_id
      }
    }

    case Ash.create(AuditLog, attrs, domain: AuditDomain, actor: actor) do
      {:ok, _audit_log} -> :ok
      {:error, reason} -> Logger.warning("failed_impersonation_audit", action: action, reason: reason)
    end

    conn
  end
end
