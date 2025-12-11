defmodule Voelgoedevents.RateLimit do
  @moduledoc """
  Hammer-based rate limiting backend for Voelgoedevents.

  Backed by Redis via hammer_backend_redis.
  Used both by HTTP plugs and AshRateLimiter.
  """

  use Hammer, backend: Hammer.Redis
end
