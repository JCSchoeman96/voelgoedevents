defmodule Voelgoedevents.Auth.RbacCache do
  @moduledoc """
  ETS-backed hot cache for membership role lookups.

  Follows the hot-layer guidance from Appendix C: store short-lived membership/role
  tuples in `:rbac_cache` keyed by `{user_id, organization_id}` so RBAC checks can
  skip database reads when possible.
  """

  alias Ash.Query
  alias Voelgoedevents.Ash.Resources.Accounts.Membership

  @table :rbac_cache
  @default_ttl_ms 60_000

  @doc """
  Fetch the role name for a user/organization pair.

  Performs a hot-layer lookup first and falls back to an Ash read when the ETS
  cache misses or is expired.
  """
  @spec fetch_role(binary(), binary(), keyword()) :: {:ok, atom()} | {:error, term()} | :miss
  def fetch_role(user_id, organization_id, opts \\ []) do
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)

    case hot_lookup(user_id, organization_id, ttl_ms) do
      {:ok, role} -> {:ok, role}
      :miss -> hydrate_from_source(user_id, organization_id, ttl_ms, opts)
    end
  end

  @doc """
  Write-through helper to refresh the hot cache from a membership record.
  """
  @spec refresh(Membership.t(), keyword()) :: :ok | {:error, term()}
  def refresh(%Membership{} = membership, opts \\ []) do
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)

    with {:ok, %Membership{} = loaded} <- ensure_role_loaded(membership) do
      persist_cache(loaded, ttl_ms)
    end
  end

  @doc """
  Remove a cached membership entry for the given user/org pair.
  """
  @spec delete(binary(), binary()) :: :ok
  def delete(user_id, organization_id) do
    :ets.delete(@table, {user_id, organization_id})
    :ok
  end

  defp hot_lookup(user_id, organization_id, ttl_ms) do
    now_ms = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, {user_id, organization_id}) do
      [{{^user_id, ^organization_id}, role, expires_at}] when is_integer(expires_at) and expires_at > now_ms ->
        refresh_expiry(user_id, organization_id, role, ttl_ms, now_ms)
        {:ok, role}

      _ ->
        :ets.delete(@table, {user_id, organization_id})
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp hydrate_from_source(user_id, organization_id, ttl_ms, opts) do
    actor = Keyword.get(opts, :actor) || %{id: user_id, organization_id: organization_id}

    query =
      Membership
      |> Query.filter(user_id == ^user_id and organization_id == ^organization_id)
      |> Query.load(:role)

    case Ash.read(query, actor: actor) do
      {:ok, [%Membership{} = membership]} ->
        refresh(membership, ttl_ms: ttl_ms)

        case membership.status do
          :active ->
            {:ok, membership.role && membership.role.name}

          _inactive ->
            {:error, :inactive_membership}
        end

      {:ok, []} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_role_loaded(%Membership{role: %{name: _}} = membership), do: {:ok, membership}

  defp ensure_role_loaded(%Membership{} = membership) do
    case Ash.load(membership, :role) do
      {:ok, %Membership{} = loaded} -> {:ok, loaded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp persist_cache(%Membership{status: :active, role: %{name: role}} = membership, ttl_ms)
       when is_atom(role) do
    expires_at = expiry_from_now(ttl_ms)
    :ets.insert(@table, {{membership.user_id, membership.organization_id}, role, expires_at})
    :ok
  end

  defp persist_cache(%Membership{} = membership, _ttl_ms) do
    delete(membership.user_id, membership.organization_id)
    :ok
  end

  defp refresh_expiry(user_id, organization_id, role, ttl_ms, now_ms) do
    :ets.insert(@table, {{user_id, organization_id}, role, now_ms + ttl_ms})
    :ok
  end

  defp expiry_from_now(ttl_ms), do: System.monotonic_time(:millisecond) + ttl_ms
end
