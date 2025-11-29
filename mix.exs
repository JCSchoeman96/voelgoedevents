defmodule Voelgoedevents.MixProject do
  use Mix.Project

  def project do
    [
      app: :voelgoedevents,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [plt_core_path: "priv/plts", plt_file: {:no_warn, "priv/plts/dialyzer.plt"}]
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {Voelgoedevents.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      # --- ASH ECOSYSTEM (The Core) ---
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_admin, "~> 0.13"},
      {:ash_state_machine, "~> 0.2"},
      {:ash_paper_trail, "~> 0.5"}, # Auditing
      {:ash_archival, "~> 1.0"},    # Soft Deletes
      {:ash_money, "~> 0.1"},       # Financial Types
      {:ash_cloak, "~> 0.1"},       # Encryption
      {:ash_oban, "~> 0.2"},        # Background Jobs Integration

      # --- PHOENIX & WEB ---
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0-rc", override: true}, # Ensure latest LiveView
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.5"},
      {:bandit, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},

      # --- ENTERPRISE FEATURES (Added) ---
      {:chromic_pdf, "~> 1.15"},    # PDF Ticket Generation
      {:ex_aws, "~> 2.5"},          # S3/Wasabi Adapter
      {:ex_aws_s3, "~> 2.5"},       # S3 Specifics
      {:hackney, "~> 1.20"},        # HTTP Client for AWS
      {:image, "~> 0.37"},          # High-performance Image Processing (Vix)
      {:honeybadger, "~> 0.7"},     # Error Tracking
      {:req, "~> 0.5"},           # Modern HTTP Client (for Webhooks)
      {:geo_postgis, "~> 3.4"},     # Location Search

      # --- SECURITY & UTILS ---
      {:cloak, "~> 1.1"},           # Core Encryption (used by AshCloak)
      {:jason, "~> 1.2"},           # JSON
      {:gettext, "~> 0.26"},        # Translations
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # --- DEV TOOLS ---
      {:igniter, "~> 0.3", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mishka_chelekom, "~> 0.0", only: [:dev]}, # Component Library
      {:live_debugger, "~> 0.2", only: [:dev]},
      {:lazy_html, ">= 0.1.0", only: :test},

      # --- OPTIONAL / PAID ---
      # {:oban_web, "~> 2.10"} # UNCOMMENT ONLY IF YOU HAVE A LICENSE
    ]
  end

  # Aliases for easier commands
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind voelgoedevents", "esbuild voelgoedevents"],
      "assets.deploy": [
        "tailwind voelgoedevents --minify",
        "esbuild voelgoedevents --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
