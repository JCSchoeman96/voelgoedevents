defmodule Voelgoedevents.Ash.Resources.Accounts.Token do
  @moduledoc "Ash resource: Token for authentication."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  token do
    confirmation do
      get_changes_action_name :get_confirmation_changes
      store_changes_action_name :store_confirmation_changes
    end
  end

  postgres do
    table "user_tokens"
    repo Voelgoedevents.Repo
  end
end
