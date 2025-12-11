defmodule VoelgoedeventsWeb.Live.AdminDashboard.DashboardLive do
  use VoelgoedeventsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold mb-4">Organization Dashboard</h1>
      <p>Welcome to the dashboard.</p>
    </div>
    """
  end
end