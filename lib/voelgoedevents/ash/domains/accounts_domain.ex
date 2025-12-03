defmodule Voelgoedevents.Ash.Domains.AccountsDomain do
  @moduledoc "Ash domain for users, roles, and memberships."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Accounts.Token
    resource Voelgoedevents.Ash.Resources.Accounts.User
    resource Voelgoedevents.Ash.Resources.Accounts.Role
    resource Voelgoedevents.Ash.Resources.Accounts.Membership
    resource Voelgoedevents.Ash.Resources.Accounts.Organization
    resource Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings
  end

  # See docs/domain/*.md for the domain rules.
end
