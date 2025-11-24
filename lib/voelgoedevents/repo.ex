defmodule Voelgoedevents.Repo do
  use Ecto.Repo,
    otp_app: :voelgoedevents,
    adapter: Ecto.Adapters.Postgres
end
