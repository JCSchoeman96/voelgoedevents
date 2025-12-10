defmodule Voelgoedevents.Ash.Domains.AuditDomain do
  @moduledoc "Ash domain for audit logging and compliance trails."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Audit.AuditLog
  end

  authorization do
    authorize :by_default
    require_actor? true
  end
end
