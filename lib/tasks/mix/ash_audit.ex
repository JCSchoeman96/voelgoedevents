defmodule Mix.Tasks.Ash.Audit do
  @moduledoc """
  Ash 3.x structural audit for the Voelgoedevents project.

  This task is intentionally *conservative* and focuses on hard, mechanical rules:

    * Block known Ash 2.x patterns and deprecated callbacks.
    * Enforce that no `authorize? do` policy blocks exist.
    * Provide a single command that can be wired into pre-commit / CI.

  Over time you can extend `@forbidden_snippets/0` and add more checks.

  Usage:

      mix ash.audit

  Exits with a non-zero status if any violation is found.
  """

  use Mix.Task

  @shortdoc "Run Ash 3.x compliance checks for Voelgoedevents"

  # ---------------------------------------------------------------------------
  #  CONFIG: FORBIDDEN PATTERNS (Ash 2.x / deprecated API)
  # ---------------------------------------------------------------------------

  # These are *string* or *regex* patterns that should never appear in the codebase.
  # We will expand this list as we discover more problematic usage.
  defp forbidden_snippets do
    [
      # Ash 2.x changeset callbacks – banned in 3.x
      ~r/\bAsh\.Changeset\.before_action\b/,
      ~r/\bAsh\.Changeset\.after_action\b/,
      ~r/\bAsh\.Changeset\.before_transaction\b/,
      ~r/\bAsh\.Changeset\.after_transaction\b/,

      # Old policy authorizer
      ~r/\bAsh\.Policy\.Authorizer\b/,

      # Old-style authorize? blocks (Ash 2.x)
      ~r/authorize\?\s+do/,

      # Generic "before_action" callback usage on resources
      ~r/\bbefore_action\s+do/,
      ~r/\bafter_action\s+do/
    ]
  end

  # Directories to scan for .ex / .exs files.
  defp scan_paths do
    [
      "lib",
      "test"
      # You can add "priv" or other paths here if needed.
    ]
  end

  # ---------------------------------------------------------------------------
  #  MIX TASK ENTRY POINT
  # ---------------------------------------------------------------------------

  @impl true
  def run(_args) do
    Mix.shell().info("==> Running Ash 3.x audit…")

    Mix.Task.run("app.start", [])

    with :ok <- scan_for_forbidden_snippets() do
      Mix.shell().info([:green, "Ash audit passed (no forbidden Ash 2.x patterns found)."])
    else
      {:error, :forbidden_snippets, violations} ->
        print_forbidden_snippet_violations(violations)
        Mix.raise("Ash audit failed: forbidden Ash 2.x / deprecated patterns were found.")
    end
  end

  # ---------------------------------------------------------------------------
  #  CHECK 1: FORBIDDEN SNIPPETS
  # ---------------------------------------------------------------------------

  defp scan_for_forbidden_snippets do
    files =
      scan_paths()
      |> Enum.flat_map(&Path.wildcard("#{&1}/**/*.{ex,exs}"))

    violations =
      files
      |> Enum.flat_map(&check_file_for_forbidden_snippets/1)

    case violations do
      [] -> :ok
      list -> {:error, :forbidden_snippets, list}
    end
  end

  defp check_file_for_forbidden_snippets(path) do
    content = File.read!(path)

    forbidden_snippets()
    |> Enum.flat_map(fn pattern ->
      case Regex.run(pattern, content) do
        nil ->
          []

        _ ->
          [%{file: path, pattern: pattern}]
      end
    end)
  end

  defp print_forbidden_snippet_violations(violations) do
    Mix.shell().error("""
    ----------------------------------------------------------------------
    Ash audit: Forbidden Ash 2.x / deprecated patterns detected
    ----------------------------------------------------------------------
    The following files contain patterns that are NOT allowed under Ash 3.x.
    Please remove or refactor them before committing.
    """)

    violations
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, entries} ->
      Mix.shell().error("File: #{file}")

      entries
      |> Enum.map(& &1.pattern)
      |> Enum.uniq()
      |> Enum.each(fn pattern ->
        Mix.shell().error("  - matched pattern: #{inspect(pattern)}")
      end)

      Mix.shell().error("")
    end)
  end
end
