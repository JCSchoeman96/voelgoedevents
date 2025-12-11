defmodule VoelgoedeventsWeb.Router do
  use VoelgoedeventsWeb, :router
  use AshAuthentication.Phoenix.Router
  use Honeybadger.Plug

  # ---------------------------------------------------------------------------
  # Browser Pipeline
  # ---------------------------------------------------------------------------
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VoelgoedeventsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug :load_from_session
    plug VoelgoedeventsWeb.Plugs.CurrentUserPlug
  end

  # ---------------------------------------------------------------------------
  # Auth-Limited Pipeline (Browser + Rate Limiting)
  # ---------------------------------------------------------------------------
  pipeline :auth_limited do
    # We *extend* browser in scopes: [:browser, :auth_limited]
    plug VoelgoedeventsWeb.Plugs.SetRateLimitContext

    plug VoelgoedeventsWeb.Plugs.RateLimiter,
      max_requests: 10,
      interval_ms: 60_000
  end

  # ---------------------------------------------------------------------------
  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  pipeline :org_scoped do
    plug VoelgoedeventsWeb.Plugs.OrgRequiredPlug
  end

  pipeline :tenant_scope do
    plug VoelgoedeventsWeb.Plugs.LoadTenant
    plug VoelgoedeventsWeb.Plugs.CurrentOrgPlug
  end

  pipeline :ash_actor do
    plug VoelgoedeventsWeb.Plugs.SetAshActorPlug
  end

  # ---------------------------------------------------------------------------
  # # Authentication Routes (ALL Rate Limited)
  scope "/", VoelgoedeventsWeb do
    # Browser (session, CSRF, layout) + rate limiting + Ash context
    pipe_through [:browser, :auth_limited]

    sign_in_route(
      path: "/auth/log_in",
      register_path: "/auth/register",
      reset_path: "/auth/reset",
      auth_routes_prefix: "/auth"
    )

    reset_route(
      path: "/auth/reset",
      auth_routes_prefix: "/auth"
    )

    sign_out_route AuthController, "/auth/log_out"
  end

  scope "/auth" do
    # Also browser + rate limiting
    pipe_through [:browser, :auth_limited]

    auth_routes VoelgoedeventsWeb.AuthController,
                Voelgoedevents.Ash.Resources.Accounts.User,
                path: "/"

    confirm_route Voelgoedevents.Ash.Resources.Accounts.User, :confirm,
      live_view: VoelgoedeventsWeb.Auth.ConfirmationLive
  end

  # ---------------------------------------------------------------------------
  # Public Routes
  # ---------------------------------------------------------------------------
  scope "/", VoelgoedeventsWeb do
    pipe_through [:browser, :ash_actor]

    get "/", PageController, :home
    live "/select-organization", Live.Tenancy.OrganizationSelectionLive, :index
  end

  scope "/dashboard", VoelgoedeventsWeb do
    pipe_through [:browser, :ash_actor]

    live "/:slug", Live.AdminDashboard.DashboardLive, :show
  end

  scope "/t/:slug", VoelgoedeventsWeb do
    pipe_through [:browser, :tenant_scope, :ash_actor]

    live "/checkout", CheckoutLive, :show

    post "/impersonation", ImpersonationController, :create
    delete "/impersonation", ImpersonationController, :delete
  end

  # ---------------------------------------------------------------------------
  # Dev Routes
  # ---------------------------------------------------------------------------
  if Application.compile_env(:voelgoedevents, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VoelgoedeventsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
