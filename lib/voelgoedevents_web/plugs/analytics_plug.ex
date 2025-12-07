defmodule VoelgoedeventsWeb.Plugs.AnalyticsPlug do
  @moduledoc """
  Analytics tracking stub.
  TODO(Phase 3 - TOON-010): Implement real analytics pipeline.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Safe no-op: never crashes the request pipeline
    # Optional: Log in dev only
    if Mix.env() == :dev do
      # Logger.debug("[AnalyticsPlug] Stub - no tracking implemented yet")
    end

    conn
  end
end
