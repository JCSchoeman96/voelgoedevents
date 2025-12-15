import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :voelgoedevents, Voelgoedevents.Repo,
  username: System.get_env("DB_USERNAME") || "voelgoed",
  password: System.get_env("DB_PASSWORD") || "voelgoed_dev",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: (System.get_env("DB_TEST_NAME") || "voelgoedevents_test") <> "#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :voelgoedevents, Voelgoedevents.ObanRepo,
  username: System.get_env("DB_USERNAME") || "voelgoed",
  password: System.get_env("DB_PASSWORD") || "voelgoed_dev",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: (System.get_env("DB_TEST_NAME") || "voelgoedevents_test") <> "#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :voelgoedevents, VoelgoedeventsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ppvdR+R6lnuRtis1urqXQeZkRZqZZQSLSqP0tJJvBU3czJDnGI/FYRrhjYywX0bE",
  server: false

# In test we don't send emails
config :voelgoedevents, Voelgoedevents.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# AshAuthentication token signing secret (test only)
config :voelgoedevents,
       :token_signing_secret,
       "test_only_token_signing_secret_for_testing_purposes_only_xyz789"
