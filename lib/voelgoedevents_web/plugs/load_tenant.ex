defmodule VoelgoedeventsWeb.Plugs.LoadTenant do
  @moduledoc """
  Resolves the tenant from the slug and assigns the current organization context.

  This plug loads the organization by URL slug, halts with 404 when missing, and
  sets both `conn.assigns.current_organization` and the Ash tenant for downstream
  multi-tenant safety.
  """

  import Plug.Conn
  require Ash.Query

  alias Ash.Query
  alias Voelgoedevents.Ash.Domains.AccountsDomain
  alias Voelgoedevents.Ash.Resources.Accounts.Organization

  def init(opts), do: opts

  def call(conn, _opts) do
    slug = conn.path_params["slug"] || conn.path_params["tenant_slug"]

    with {:ok, %Organization{} = organization} <- fetch_organization(slug) do
      conn
      |> assign(:current_organization, organization)
      |> assign(:organization_id, organization.id)
      |> Ash.PlugHelpers.set_tenant(organization.id)
    else
      _ ->
        conn
        |> send_resp(:not_found, "Not Found")
        |> halt()
    end
  end

  defp fetch_organization(nil), do: {:error, :not_found}

  defp fetch_organization(slug) do
    Organization
    |> Query.filter(slug == ^slug and status == :active)
    |> Ash.read_one(domain: AccountsDomain)
    |> case do
      {:ok, %Organization{} = organization} -> {:ok, organization}
      {:ok, nil} -> {:error, :not_found}
      {:error, _reason} -> {:error, :not_found}
    end
  end
end
