defmodule Voelgoedevents.RateLimitBackend do
  @moduledoc """
  Hammer v7 backend module (Redis-backed).
  This module must be started under supervision.
  """

  use Hammer, backend: Hammer.Redis
end
