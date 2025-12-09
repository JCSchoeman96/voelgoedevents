defmodule Voelgoedevents.Infrastructure.Redis do
  @moduledoc """
  Central wrapper for Redis operations (Redix pool).
  Used for: Seat Maps, Rate Limiting, and Ephemeral State.
  """

  # This name matches the child spec in application.ex
  @name :voelgoed_redis

  def child_spec(_opts) do
    # Pulls REDIS_URL from runtime config
    url = Application.fetch_env!(:voelgoedevents, :redis_url)

    # TODO: Redix doesn't support native connection pooling.
    # If pooling is required, implement using NimblePool or Poolboy.
    # _pool_size = Application.get_env(:voelgoedevents, :redis_pool_size, 10)

    %{
      id: Redix,
      start: {Redix, :start_link, [url, [name: @name]]}
    }
  end

  def command(command) do
    Redix.command(@name, command)
  end

  def pipeline(commands) do
    Redix.pipeline(@name, commands)
  end
end
