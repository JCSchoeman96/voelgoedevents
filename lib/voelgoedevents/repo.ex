defmodule Voelgoedevents.Repo do
  use AshPostgres.Repo, otp_app: :voelgoedevents

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext", AshMoney.AshPostgresExtension]
  end

  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end
end