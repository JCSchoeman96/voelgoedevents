defmodule Voelgoedevents.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VoelgoedeventsWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl true
  def start(_type, _args) do
    :ok = Voelgoedevents.Caching.MembershipCache.ensure_table()

    children = [
      VoelgoedeventsWeb.Telemetry,

      # 0. Hot-layer ETS cache tables (must start before dependants)
      Voelgoedevents.Infrastructure.EtsRegistry,

      # 1. Database & Infra (Start these FIRST)
      Voelgoedevents.Repo,
      Voelgoedevents.ObanRepo,
      {DNSCluster, query: Application.get_env(:voelgoedevents, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Voelgoedevents.PubSub},

      # 2. Redis Connection (The "Tank" Engine)
      Voelgoedevents.Infrastructure.Redis,
      Voelgoedevents.Infrastructure.CircuitBreaker,

      # 3. Observability Layer
      Voelgoedevents.Observability.SLOTracker,

      # 4. Process Registries (For GenServer Actors)
      # For Actors
      {Registry, keys: :unique, name: Voelgoedevents.Registry},
      # For PubSub topics
      {Registry, keys: :duplicate, name: Voelgoedevents.BroadcastRegistry},

      # 5. Background Jobs
      {Oban, Application.fetch_env!(:voelgoedevents, Oban)},

      # 6. Authentication Supervisor (must be before web endpoint)
      {AshAuthentication.Supervisor, otp_app: :voelgoedevents},

      # Hammer Redis rate limiter
      {Voelgoedevents.RateLimitBackend, url: System.get_env("REDIS_URL", "redis://localhost:6379")},

      # 7. Web Endpoint (Start LAST)
      VoelgoedeventsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Voelgoedevents.Supervisor]

    # Start the supervisor
    result = Supervisor.start_link(children, opts)

    # Attach telemetry handlers after supervisor is running
    Voelgoedevents.Observability.TelemetryHandler.setup()

    result
  end
end
