# CI/CD Phased Strictness

## Purpose
Align CI signals with the roadmap by allowing fast iteration during Phases 1–9 while keeping blocking checks for real failures. Strict blocking on linting and type analysis returns in Phase 10 hardening.

## Phase Policy
- **Phases 1–9 (Active Development):**
  - **Blocking:** `mix compile`, targeted `mix test` suites for active slices (Accounts, Events, basic Ticketing), and migrations when present.
  - **Report-only:** Credo, Dialyzer, compiler warnings, Sobelow, formatting drift, and unused dependency checks. These should surface in logs but not fail CI.
- **Phase 10+ (Hardening):** Turn all report-only checks into blockers by removing `continue-on-error` and `--mute-exit-status` guards so linting, type analysis, and security scans fail the pipeline.

## Current CI Implementation (Phases 1–9)
- Workflow: `.github/workflows/ci.yml`
- Behavior:
  - Runs `mix compile` and targeted tests for Accounts, Events, Ticketing, and checkout workflows as hard blockers.
  - Executes Credo with `--mute-exit-status`, Dialyzer, Sobelow, formatting, and unused dependency checks with `continue-on-error: true` so they report but do not block.
  - Scope aligns Credo to backend-active directories via `.credo.exs` and keeps Dialyzer false positives documented in `.dialyzer`.

## Hardening Toggle Checklist (Phase 10)
- Remove `continue-on-error` from Credo, Dialyzer, Sobelow, and hygiene steps.
- Drop `--mute-exit-status` from Credo so issues fail CI.
- Expand Credo scope back to all directories (assets, scanner, etc.).
- Add full test suite paths beyond active slices.
- Keep Dialyzer ignores minimal and justified; prefer code fixes over new entries.

## Developer Guidance
- During Phases 1–9, fix compile errors and active-slice tests immediately.
- Capture Credo/Dialyzer/Sobelow findings in tickets for cleanup during Phase 10.
- Document any Dialyzer ignore patterns in `.dialyzer` with a reason.
