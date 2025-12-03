import Config

# --- GENERAL APP CONFIG ---
config :voelgoedevents,
  ecto_repos: [Voelgoedevents.Repo, Voelgoedevents.ObanRepo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    Voelgoedevents.Ash.Domains.AccountsDomain,
    Voelgoedevents.Ash.Domains.VenuesDomain,
    Voelgoedevents.Ash.Domains.EventsDomain,
    Voelgoedevents.Ash.Domains.SeatingDomain,
    Voelgoedevents.Ash.Domains.TicketingDomain,
    Voelgoedevents.Ash.Domains.PaymentsDomain,
    Voelgoedevents.Ash.Domains.ScanningDomain,
    Voelgoedevents.Ash.Domains.AnalyticsDomain,
    Voelgoedevents.Ash.Domains.FinanceDomain,
    Voelgoedevents.Ash.Domains.AccessControlDomain,
    Voelgoedevents.Ash.Domains.MonetizationDomain,
    Voelgoedevents.Ash.Domains.AuditDomain
  ]

  # --- OBAN CONFIG ---
config :voelgoedevents, Oban,
  repo: Voelgoedevents.ObanRepo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, mailers: 20, pdf_generation: 5]

# --- REDIS URL (Default for Dev) ---
config :voelgoedevents,
  redis_url: "redis://localhost:6379",
  redis_pool_size: 10

# --- CIRCUIT BREAKER CONFIG ---
config :voelgoedevents, Voelgoedevents.Infrastructure.CircuitBreaker,
  open_failure_count: 5,
  reset_timeout_ms: 60_000


# --- WEB ENDPOINT ---
config :voelgoedevents, VoelgoedeventsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: VoelgoedeventsWeb.ErrorHTML, json: VoelgoedeventsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Voelgoedevents.PubSub,
  live_view: [signing_salt: "z0iFT5fC"]

# --- MAILER ---
config :voelgoedevents, Voelgoedevents.Mailer, adapter: Swoosh.Adapters.Local

# --- ASSETS (Tailwind/Esbuild) ---
config :esbuild,
  version: "0.25.4",
  voelgoedevents: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "3.4.0", # Note: 4.x is bleeding edge; stick to 3.x if unsure, or keep 4.x if it works.
  voelgoedevents: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# --- LOGGER & JSON ---
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# --- ASH ADMIN ---
config :ash_admin,
  csp_nonce: false

# --- MONEY & CLDR CONFIG ---
config :ex_cldr,
  default_backend: Voelgoedevents.Cldr

config :ex_money,
  default_cldr_backend: Voelgoedevents.Cldr

# This tells Ash how to find the Money type
config :ash, :known_types, [AshMoney.Types.Money]

# This tells Postgres how to store the Money type
config :voelgoedevents, Voelgoedevents.Repo,
  migration_types: [AshMoney.AshPostgresExtension]

# --- ENVIRONMENT OVERRIDES ---
import_config "#{config_env()}.exs"
