defmodule Voelgoedevents.RateLimit do
  @moduledoc """
  Hammer-based rate limiting backend for Voelgoedevents.

  Backed by Redis via hammer_backend_redis.
  Used both by HTTP plugs and AshRateLimiter.
  """

  @type hit_result ::
          {:allow, non_neg_integer()}
          | {:deny, pos_integer()}
          | {:error, :unavailable}

  @doc """
  Executes a rate-limit check guarded by the circuit breaker.

  Returns:
    * `{:allow, count}` — request allowed, current count returned.
    * `{:deny, retry_after_ms}` — request denied, retry after the returned milliseconds.
    * `{:error, :unavailable}` — backend unavailable or invalid input; caller decides fail-open/closed.
  """
  @spec hit(binary(), integer(), pos_integer()) :: hit_result
  def hit(key, interval_ms, max_requests) when is_binary(key) do
    with {:ok, interval_ms} <- normalize_interval(interval_ms),
         {:ok, max_requests} <- normalize_max_requests(max_requests) do
      execute_check(key, interval_ms, max_requests)
    else
      {:error, _reason} ->
        {:error, :unavailable}
    end
  end

  def hit(_key, _interval_ms, _max_requests), do: {:error, :unavailable}

  defp execute_check(key, interval_ms, max_requests) do
    case Voelgoedevents.Infrastructure.CircuitBreaker.call(:rate_limiter_redis, fn ->
           Voelgoedevents.RateLimitBackend.hit(key, interval_ms, max_requests)
         end) do
      {:ok, {:allow, count}} when is_integer(count) and count >= 0 ->
        {:allow, count}

      {:ok, {:deny, _value}} ->
        {:deny, interval_ms}

      {:error, :circuit_open} ->
        {:error, :unavailable}

      {:error, %_{__exception__: true}} ->
        {:error, :unavailable}

      {:error, {:exit, _reason}} ->
        {:error, :unavailable}

      {:error, _other} ->
        {:error, :unavailable}
    end
  end

  defp normalize_interval(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp normalize_interval(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_interval}
    end
  end

  defp normalize_interval(_value), do: {:error, :invalid_interval}

  defp normalize_max_requests(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp normalize_max_requests(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_max_requests}
    end
  end

  defp normalize_max_requests(_value), do: {:error, :invalid_max_requests}
end
