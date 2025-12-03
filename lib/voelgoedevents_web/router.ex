defmodule VoelgoedeventsWeb.Router do
  use VoelgoedeventsWeb, :router
  use AshAuthentication.Phoenix.Router
  use Honeybadger.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VoelgoedeventsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :tenant_scope do
    plug VoelgoedeventsWeb.Plugs.CurrentUserPlug
    plug VoelgoedeventsWeb.Plugs.LoadTenant
    plug VoelgoedeventsWeb.Plugs.CurrentOrgPlug
  end

  scope "/auth" do
    pipe_through :browser

    auth_routes Voelgoedevents.Ash.Domains.AccountsDomain, []
  end

  scope "/", VoelgoedeventsWeb do
    pipe_through :browser


    auth_routes Voelgoedevents.Ash.Domains.AccountsDomain, []

    get "/", PageController, :home
  end

  # Tenant-scoped routes (multi-tenancy enforcement)
  scope "/t/:slug", VoelgoedeventsWeb do
    pipe_through [:browser, :tenant_scope]

    # Checkout will be a LiveView
    live "/checkout", CheckoutLive, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", VoelgoedeventsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:voelgoedevents, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VoelgoedeventsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
