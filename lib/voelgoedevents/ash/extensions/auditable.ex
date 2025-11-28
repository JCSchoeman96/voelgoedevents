defmodule VoelgoedEvents.Ash.Extensions.Auditable do
  @moduledoc """
  ASH EXTENSION: AUDITING

  AGENTS:
  This module will eventually define the DSL for tracking who changed what.
  For now, it serves as the anchor for the `extensions/` directory.

  Status: Implementation pending (Phase 1.3).
  """
  use Ash.Resource.Extension
  # TODO: Implement DSL sections for `audit_log`
end