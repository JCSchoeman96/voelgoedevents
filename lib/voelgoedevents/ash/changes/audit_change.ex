defmodule Voelgoedevents.Ash.Changes.AuditChange do
  @moduledoc """
  @deprecated "Use Voelgoedevents.Ash.Extensions.Auditable instead"

  Ash Change: captures changes and writes them to the AuditLog.

  NOTE: This module is kept for backward compatibility and test purposes only.
  New code should rely on the Auditable extension which is automatically applied via Base.

  If an audit entry cannot be written, the action fails and the transaction is rolled back.
  """
  use Ash.Resource.Change

  alias Voelgoedevents.Ash.Domains.AuditDomain
  alias Voelgoedevents.Ash.Resources.Audit.AuditLog

  require Ash.Query

  @impl true
  def change(changeset, opts, context) do
    audit_resource = Keyword.fetch!(opts, :audit_resource)
    audit_domain = Keyword.fetch!(opts, :audit_domain)

    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      actor = context.actor

      if actor do
        audit_params = %{
          actor_id: resolve_actor_id(actor),
          action: to_string(resolve_action_name(context.action)),
          resource: to_string(context.resource),
          resource_id: result.id,
          changes: Map.take(result, Map.keys(changeset.attributes)),
          organization_id: Map.get(actor, :organization_id)
        }

        case Ash.create(audit_resource, audit_params, domain: audit_domain, actor: actor) do
          {:ok, _audit_log} ->
            {:ok, result}

          {:error, reason} ->
            raise "Audit logging failed: #{inspect(reason)}"
        end
      end

      {:ok, result}
    end)
  end

  defp resolve_actor_id(%{user_id: user_id}) when not is_nil(user_id), do: user_id
  defp resolve_actor_id(%{id: id}) when not is_nil(id), do: id
  defp resolve_actor_id(map) when is_map(map), do: Map.get(map, :user_id) || Map.get(map, :id)
  defp resolve_actor_id(_), do: nil

  defp resolve_action_name(%{name: name}) when not is_nil(name), do: name
  defp resolve_action_name(name) when is_atom(name), do: name
  defp resolve_action_name(_), do: nil
end
