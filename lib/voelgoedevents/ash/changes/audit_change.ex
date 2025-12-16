defmodule Voelgoedevents.Ash.Changes.AuditChange do
  @moduledoc """
  @deprecated "Use Voelgoedevents.Ash.Extensions.Auditable instead"

  Ash Change: captures changes and writes them to the AuditLog.

  NOTE: This module is kept for backward compatibility and test purposes only.
  New code should rely on the Auditable extension which is automatically applied via Base.

  If an audit entry cannot be written, the action fails and the transaction is rolled back.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, opts, context) do
    audit_resource = Keyword.fetch!(opts, :audit_resource)
    audit_domain = Keyword.fetch!(opts, :audit_domain)

    Ash.Changeset.after_action(changeset, fn after_changeset, result ->
      after_ctx = Map.get(after_changeset, :context) || %{}
      ctx_private = fetch(after_ctx, :private) || %{}
      base_private = fetch(context || %{}, :private) || %{}

      actor =
        Map.get(after_changeset, :actor) ||
          fetch(after_ctx, :actor) ||
          fetch(ctx_private, :actor) ||
          fetch(context || %{}, :actor) ||
          fetch(base_private, :actor)

      actor_id =
        cond do
          is_binary(actor) ->
            actor

          is_integer(actor) ->
            Integer.to_string(actor)

          is_map(actor) ->
            Map.get(actor, :user_id) || Map.get(actor, :id)

          true ->
            nil
        end
        |> case do
          nil -> nil
          id -> to_string(id)
        end

      organization_id =
        Map.get(result, :organization_id) ||
          (is_map(actor) && Map.get(actor, :organization_id))

      action =
        case after_changeset.action do
          %{name: name} -> to_string(name)
          nil -> ""
          other -> to_string(other)
        end

      resource =
        case after_changeset.resource do
          nil ->
            case result do
              %{__struct__: struct} when not is_nil(struct) -> inspect(struct)
              _ -> ""
            end

          other ->
            inspect(other)
        end

      audit_params = %{
        actor_id: actor_id,
        action: action,
        resource: resource,
        resource_id: Map.get(result, :id),
        changes: Map.take(result, Map.keys(after_changeset.attributes)),
        organization_id: organization_id
      }

      action_info = Ash.Resource.Info.action(audit_resource, :create)
      accepted = action_info && Map.get(action_info, :accept, [])

      accepted_strings =
        accepted
        |> Enum.filter(&is_atom/1)
        |> Enum.map(&Atom.to_string/1)

      filtered_params =
        audit_params
        |> Map.take(accepted)
        |> Map.merge(Map.take(audit_params, accepted_strings))

      case Ash.create(audit_resource, filtered_params,
             action: :create,
             domain: audit_domain,
             actor: actor
           ) do
        {:ok, _audit_log} ->
          {:ok, result}

        {:error, reason} ->
          message =
            if is_exception(reason) do
              Exception.message(reason)
            else
              to_string(reason)
            end

          raise RuntimeError, "Audit logging failed: #{message}"
      end
    end)
  end

  defp fetch(map_or_kw, key) when is_map(map_or_kw), do: Map.get(map_or_kw, key)
  defp fetch(map_or_kw, key) when is_list(map_or_kw), do: Keyword.get(map_or_kw, key)
  defp fetch(_, _), do: nil
end
