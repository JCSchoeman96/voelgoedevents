defmodule VoelgoedeventsWeb.Plugs.SetTenant do
  @moduledoc """
  Plug to capture the tenant slug from the URL and set the Ash tenant context.

  Reads the `tenant_slug` param from the URL (e.g., /t/cocacola),
  queries the Organization by slug, and sets it as the Ash tenant.
  Returns a 404 if the organization is not found or inactive.
  """

  import Plug.Conn
  require Ash.Query

  alias Voelgoedevents.Ash.Resources.Accounts.Organization
  alias Voelgoedevents.Ash.Domains.AccountsDomain

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant_slug = conn.params["tenant_slug"]

    case fetch_organization(tenant_slug) do
      {:ok, organization} ->
        Ash.PlugHelpers.set_tenant(conn, organization.id)

      {:error, :not_found} ->
        conn
        |> send_resp(404, "Not Found")
        |> halt()
    end
  end

  defp fetch_organization(slug) do
    Organization
    |> Ash.Query.filter(slug == ^slug and status == :active)
    |> Ash.read_one(domain: AccountsDomain)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, org} -> {:ok, org}
      {:error, _} -> {:error, :not_found}
    end
  end
end
