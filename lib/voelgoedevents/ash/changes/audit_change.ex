defmodule Voelgoedevents.Ash.Changes.AuditChange do
  @moduledoc """
  Ash Change: captures changes and writes them to the AuditLog.

  NOTE: If an audit entry cannot be written, the action fails and the transaction is rolled back.
  """
  use Ash.Resource.Change

  alias Voelgoedevents.Ash.Domains.AuditDomain
  alias Voelgoedevents.Ash.Resources.Audit.AuditLog

  require Ash.Query

  @impl true
  def change(changeset, opts, context) do
    audit_resource = Keyword.get(opts, :audit_resource, AuditLog)
    audit_domain   = Keyword.get(opts, :audit_domain, AuditDomain)

    Ash.Changeset.after_action(changeset, fn changeset, result ->
      actor = context[:actor]

      if actor do
        audit_params = %{
          actor_id: actor.id,
          action: to_string(context.action.name),
          resource: to_string(context.resource),
          resource_id: result.id,
          changes: Map.take(result, Map.keys(changeset.attributes)),
          organization_id: Map.get(actor, :organization_id)
        }

        case audit_domain.create(audit_resource, audit_params, actor: actor) do
          {:ok, _audit_log} ->
             :ok

          {:error, reason} ->
            raise "Audit logging failed for #{inspect(context.resource)}##{inspect(result.id)}: #{inspect(reason)}"
        end
      end

      {:ok, result}
    end)
  end
end
