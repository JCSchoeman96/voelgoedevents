defmodule Voelgoedevents.Ash.Extensions.Auditable.Transformer do
  @moduledoc """
  Transformer for the Auditable extension.

  Injects `after_action` hooks on all create/update/destroy actions to automatically
  log changes to the AuditLog resource.

  ## Implementation Notes

  - Reads configuration from the `:auditable` DSL section
  - Skips injection if `enabled?: false`
  - Uses `changeset.changes` to capture differential changes (not final state)
  - Supports both synchronous (default) and asynchronous audit logging
  - In sync mode, audit failures cause transaction rollback
  - In async mode, audit failures are spawned separately and don't block the transaction
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @impl true
  def after_compile?, do: false

  @impl true
  def transform(dsl_state) do
    # Read configuration from :auditable DSL section
    enabled? = Transformer.get_option(dsl_state, [:auditable], :enabled?) || true
    strategy = Transformer.get_option(dsl_state, [:auditable], :strategy) || :full_diff
    excluded_fields = Transformer.get_option(dsl_state, [:auditable], :excluded_fields) || []
    async? = Transformer.get_option(dsl_state, [:auditable], :async) || false

    if enabled? do
      inject_audit_hooks(dsl_state, strategy, excluded_fields, async?)
    else
      {:ok, dsl_state}
    end
  end

  defp inject_audit_hooks(dsl_state, strategy, excluded_fields, async?) do
    # Get all actions from the resource
    actions = Transformer.get_entities(dsl_state, [:actions])

    # Filter to mutation actions only (create/update/destroy)
    mutation_actions =
      Enum.filter(actions, fn action ->
        action.type in [:create, :update, :destroy]
      end)

    # Inject after_action hook for each mutation action
    Enum.reduce_while(mutation_actions, {:ok, dsl_state}, fn action, {:ok, state} ->
      {:ok, new_state} = add_audit_hook(state, action, strategy, excluded_fields, async?)
      {:cont, {:ok, new_state}}
    end)
  end

  defp add_audit_hook(dsl_state, action, strategy, excluded_fields, async?) do
    # Build the after_action callback function
    callback_fn = build_audit_callback(strategy, excluded_fields, async?)

    # Add the callback to the action's changes
    {:ok,
     Transformer.add_entity(
       dsl_state,
       [:actions, action.name],
       :change,
       {:after_action, callback_fn}
     )}
  end

  defp build_audit_callback(strategy, excluded_fields, async?) do
    fn changeset, result, context ->
      if async? do
        # Async mode: spawn audit logging, don't block transaction
        spawn(fn -> log_audit(changeset, result, context, strategy, excluded_fields, async?) end)
      else
        # Sync mode: audit inline, raise on failure
        log_audit(changeset, result, context, strategy, excluded_fields, async?)
      end

      {:ok, result}
    end
  end

  defp log_audit(changeset, result, context, strategy, excluded_fields, async?) do
    # Ash 3.x: context is a struct, use Map.get/2 for safe access
    actor = Map.get(context, :actor)

    if actor do
      # Build changes_data based on strategy
      changes_data =
        case strategy do
          :full_diff ->
            # Use changeset.changes (differential changes only), not changeset.attributes (final state)
            changeset.changes
            |> Map.drop(excluded_fields)

          :minimal ->
            %{changed: true}
        end

      # Extract actor_id based on actor type (user, device, system, api_key)
      # Note: actor_id must always be a UUID string, never "system" or other magic strings
      # Never generate random UUIDs - use stable derivations to prevent identity drift
      actor_id =
        case actor do
          %{user_id: uid} when not is_nil(uid) -> uid
          %{device_id: did} when not is_nil(did) -> did
          %{type: :system} ->
            # System actors should have user_id set via ActorUtils normalization
            # Fallback to canonical system UUID if missing (should not happen in production)
            Map.get(actor, :user_id) || Voelgoedevents.Ash.Support.ActorUtils.system_actor_user_id()
          %{type: :api_key} ->
            # API key actors should have user_id set via ActorUtils normalization
            # If missing, derive from api_key_id if available
            Map.get(actor, :user_id) ||
              (actor[:api_key_id] && actor[:api_key_id]) ||
              raise("API key actor missing user_id and api_key_id")
          _ -> Map.get(actor, :id) || Map.get(actor, :user_id)
        end

      # Build audit log parameters
      audit_params = %{
        actor_id: actor_id,
        action: to_string(context.action.name),
        resource: to_string(changeset.resource),
        resource_id: result.id,
        changes: changes_data,
        organization_id: Map.get(actor, :organization_id) || Map.get(result, :organization_id)
      }

      # Create audit log entry
      case Ash.create(
             Voelgoedevents.Ash.Resources.Audit.AuditLog,
             audit_params,
             actor: actor
           ) do
        {:ok, _audit_log} ->
          :ok

        {:error, reason} ->
          # Only raise if sync mode (strict compliance)
          if not async? do
            raise "Audit logging failed for #{inspect(changeset.resource)}##{inspect(result.id)}: #{inspect(reason)}"
          end
      end
    end
  end
end
