defmodule Voelgoedevents.Workflows.Scanning.SyncResolver do
  @moduledoc """
  Workflow for merging offline scan data with the central database (Phase 5.4).
  Must use `captured_at` timestamps to resolve conflicts.
  """
  def resolve(_offline_scans), do: {:error, :not_implemented}
end
