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

    # AshAuthentication: Load user from session (must come after fetch_session)
    plug :load_from_session

    # Project plugs: CurrentUserPlug augments the loaded user with impersonation, validation
    plug VoelgoedeventsWeb.Plugs.CurrentUserPlug
    # NOTE: Actor hydration moved to :ash_actor pipeline (runs after tenant resolution)
  end

  pipeline :api do
    plug :accepts, ["json"]

    # AshAuthentication: Load user from bearer token for API requests
    plug :load_from_bearer
  end

  pipeline :org_scoped do
    plug :browser
    plug VoelgoedeventsWeb.Plugs.OrgRequiredPlug
  end

  pipeline :tenant_scope do
    plug VoelgoedeventsWeb.Plugs.LoadTenant  # Sets org from slug
    plug VoelgoedeventsWeb.Plugs.CurrentOrgPlug
  end

  # Dedicated actor hydration pipeline (runs AFTER tenant resolution)
  pipeline :ash_actor do
    plug VoelgoedeventsWeb.Plugs.SetAshActorPlug
  end

  # ==========================================================================
  # Authentication Routes
  # UX entrypoints in root scope, strategy routes under /auth
  # ==========================================================================

  # Root scope - UX entrypoints (sign-in, register, reset, logout LiveViews)
  scope "/", VoelgoedeventsWeb do
    pipe_through [:browser]

    # Shared sign-in/register/reset UI (LiveView)
    sign_in_route(
      path: "/auth/log_in",
      register_path: "/auth/register",
      reset_path: "/auth/reset",
      auth_routes_prefix: "/auth"
    )

    # Separate reset LiveView entrypoint (for token-based reset)
    reset_route(
      path: "/auth/reset",
      auth_routes_prefix: "/auth"
    )

    # Sign-out route (clears session & tokens)
    sign_out_route AuthController, "/auth/log_out"
  end

  # Strategy routes under /auth (no namespace - use fully-qualified module names)
  scope "/auth" do
    pipe_through [:browser]

    # Strategy routes (password sign_in, register, etc.)
    auth_routes VoelgoedeventsWeb.AuthController,
                Voelgoedevents.Ash.Resources.Accounts.User,
                path: "/"

    # Email confirmation route
    confirm_route Voelgoedevents.Ash.Resources.Accounts.User, :confirm,
      live_view: VoelgoedeventsWeb.Auth.ConfirmationLive
  end

  # ==========================================================================
  # Public Routes
  # ==========================================================================
  scope "/", VoelgoedeventsWeb do
    pipe_through [:browser, :ash_actor]

    get "/", PageController, :home
    live "/select-organization", Live.Tenancy.OrganizationSelectionLive, :index
  end

  # Tenant-scoped routes (multi-tenancy enforcement)
  scope "/t/:slug", VoelgoedeventsWeb do
    # CRITICAL: browser -> tenant_scope (resolves org) -> THEN ash_actor (hydrates with org)
    pipe_through [:browser, :tenant_scope, :ash_actor]

    # Checkout will be a LiveView
    live "/checkout", CheckoutLive, :show

    post "/impersonation", ImpersonationController, :create
    delete "/impersonation", ImpersonationController, :delete
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
