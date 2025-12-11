defmodule Voelgoedevents.Caching.MembershipCache do
  @moduledoc """
  Hot (ETS) + warm (Redis) cache for membership role lookups.

  Keys: `vge:mem:{user_id}:{org_id}` → role atom or `nil`.
  L1 TTL: 5 minutes (ETS), L2 TTL: 30 minutes (Redis).
  """

  alias Ash.Query
  alias Voelgoedevents.Ash.Resources.Accounts.Membership
  alias Voelgoedevents.Infrastructure.Redis

  require Ash.Query

  @type role_value :: atom() | nil

  @redis_prefix "vge:mem"
  @redis_ttl_seconds 1_800
  @ets_table :rbac_cache
  @ets_ttl_ms 300_000

  @doc "Fetch the cached role for a user/organization pair, hydrating from Ash on cache miss."
  @spec fetch_role(binary(), binary(), keyword()) :: {:ok, role_value} | {:error, term()}
  def fetch_role(user_id, organization_id, opts \\ []) do
    ensure_table!()

    ttl_ms = Keyword.get(opts, :ttl_ms, @ets_ttl_ms)

    case lookup_ets(user_id, organization_id, ttl_ms) do
      {:ok, role} ->
        {:ok, role}

      :miss ->
        with {:ok, role} <- lookup_redis(user_id, organization_id) do
          cache_ets(user_id, organization_id, role, ttl_ms)
          {:ok, role}
        else
          _ -> hydrate_from_source(user_id, organization_id, ttl_ms, opts)
        end
    end
  end

  @doc "Persist membership details into the cache layers."
  @spec refresh(Membership.t(), keyword()) :: :ok | {:error, term()}
  def refresh(%Membership{} = membership, opts \\ []) do
    ensure_table!()

    ttl_ms = Keyword.get(opts, :ttl_ms, @ets_ttl_ms)

    {:ok, role} = role_from_membership(membership)
    persist_all(membership.user_id, membership.organization_id, role, ttl_ms)
  end

  @doc "Invalidate both cache layers for the given user/organization pair."
  @spec invalidate(binary(), binary()) :: :ok
  def invalidate(user_id, organization_id) do
    ensure_table!()

    :ets.delete(@ets_table, {user_id, organization_id})

    case Redis.command(["DEL", redis_key(user_id, organization_id)]) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp hydrate_from_source(user_id, organization_id, ttl_ms, opts) do
    actor = Keyword.get(opts, :actor) || %{id: user_id, organization_id: organization_id}

    query =
      Membership
      |> Query.filter(user_id == ^user_id and organization_id == ^organization_id)
      |> Query.load(:role)

    case Ash.read(query, actor: actor) do
      {:ok, [%Membership{} = membership]} ->
        with {:ok, role} <- role_from_membership(membership) do
          persist_all(user_id, organization_id, role, ttl_ms)
          {:ok, role}
        end

      {:ok, []} ->
        persist_all(user_id, organization_id, nil, ttl_ms)
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lookup_ets(user_id, organization_id, ttl_ms) do
    now_ms = System.monotonic_time(:millisecond)

    case :ets.lookup(@ets_table, {user_id, organization_id}) do
      [{{^user_id, ^organization_id}, role, expires_at}]
      when is_integer(expires_at) and expires_at > now_ms ->
        cache_ets(user_id, organization_id, role, ttl_ms, now_ms)
        {:ok, role}

      _ ->
        :ets.delete(@ets_table, {user_id, organization_id})
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp lookup_redis(user_id, organization_id) do
    case Redis.command(["GET", redis_key(user_id, organization_id)]) do
      {:ok, nil} -> :miss
      {:ok, binary} -> decode_value(binary)
      {:error, _reason} -> :miss
    end
  end

  defp persist_all(user_id, organization_id, role, ttl_ms) do
    cache_ets(user_id, organization_id, role, ttl_ms)
    cache_redis(user_id, organization_id, role)
    :ok
  end

  defp cache_ets(
         user_id,
         organization_id,
         role,
         ttl_ms,
         now_ms \\ System.monotonic_time(:millisecond)
       ) do
    :ets.insert(@ets_table, {{user_id, organization_id}, role, now_ms + ttl_ms})
  end

  defp cache_redis(user_id, organization_id, role) do
    Redis.command([
      "SETEX",
      redis_key(user_id, organization_id),
      @redis_ttl_seconds,
      encode_value(role)
    ])
  end

  defp decode_value(binary) when is_binary(binary) do
    case :erlang.binary_to_term(binary, [:safe]) do
      value -> {:ok, value}
    end
  rescue
    _ -> :miss
  end

  defp encode_value(role), do: :erlang.term_to_binary(role)

  defp role_from_membership(%Membership{status: :active, role: %{name: role}})
       when is_atom(role) do
    {:ok, role}
  end

  defp role_from_membership(%Membership{status: _}), do: {:ok, nil}

  defp redis_key(user_id, organization_id), do: "#{@redis_prefix}:#{user_id}:#{organization_id}"

  @doc false
  def ensure_table do
    ensure_table!()
  end

  defp ensure_table! do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [
          :set,
          :public,
          :named_table,
          read_concurrency: true,
          write_concurrency: true
        ])

        :ok

      _ ->
        :ok
    end
  end
end
