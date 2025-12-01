defmodule Voelgoedevents.Ash.Domains.AccessControlDomain do
  @moduledoc """
  DOMAIN: Access Control
  API Keys, external integrations, and machine-to-machine auth.
  """
  use Ash.Domain, otp_app: :voelgoedevents

  resources do
    resource Voelgoedevents.Ash.Resources.AccessControl.ApiKey
  end
end
