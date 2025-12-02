defmodule Voelgoedevents.Ash.Resources.Accounts.Token do
  @moduledoc "Ash resource: Token for authentication."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "user_tokens"
    repo Voelgoedevents.Repo
  end
end
