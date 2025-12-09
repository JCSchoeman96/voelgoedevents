# lib/voelgoedevents_web/live/tenancy/organization_selection_live.ex
defmodule VoelgoedeventsWeb.Live.Tenancy.OrganizationSelectionLive do
  use VoelgoedeventsWeb, :live_view

  require Ash.Query

  # Aliases
  alias Voelgoedevents.Ash.Resources.Accounts.Membership
  # TODO: Scaffolding - will be used when Domain-based reads are needed
  # alias Voelgoedevents.Ash.Domains.AccountsDomain
  # TODO: Scaffolding - may be used for direct Organization queries
  # alias Voelgoedevents.Ash.Resources.Accounts.Organization

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    user_id = current_user.id

    # Fetch organizations through the user's memberships
    # This is more efficient than querying organizations directly with a relationship filter
    query =
      Membership
      |> Ash.Query.filter(user_id == ^user_id and status == :active)
      |> Ash.Query.load(:organization)

    case Ash.read(query, actor: current_user) do
      {:ok, memberships} ->
        organizations = Enum.map(memberships, & &1.organization) |> Enum.reject(&is_nil/1)
        {:ok, assign(socket, :organizations, organizations)}
      {:error, _} ->
        {:ok, assign(socket, :organizations, [])}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto mt-10">
      <h1 class="text-3xl font-bold">Select an Organization</h1>
      <p class="text-gray-600">You must choose an organization to access the dashboard.</p>
      
      <div class="space-y-4 mt-6">
        <%= if Enum.empty?(@organizations) do %>
          <p class="text-red-500">You do not belong to any active organizations.</p>
        <% else %>
          <%= for org <- @organizations do %>
            <div class="p-4 border rounded-lg flex justify-between items-center">
              <span class="font-semibold"><%= org.name %></span>
              <%!-- TODO: Route "/dashboard/:slug" not yet defined - scaffolded for future dashboard implementation --%>
              <.link
                navigate={~p"/dashboard/#{org.slug}"}
                phx-click={JS.push("select_org", value: %{org_id: org.id})}
                class="btn btn-primary btn-sm"
              >
                Select
              </.link>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Handles the selection of an organization
  # In LiveView, we use push_navigate to change routes with session handling
  @impl true
  def handle_event("select_org", %{"org_id" => _org_id}, socket) do
    # The navigation is handled by the .link component's navigate attribute
    # The org_id will be extracted from the URL in the dashboard LiveView
    {:noreply, socket}
  end
end