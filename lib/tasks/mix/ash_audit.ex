defmodule Mix.Tasks.Ash.Audit do
  @moduledoc """
  Ash 3.x structural audit for the Voelgoedevents project.

  Goals:
    * Catch Ash 2.x/legacy patterns (mechanical, provable checks).
    * Enforce project security posture (deny-by-default policies, no auth bypass).
    * Enforce tenancy invariants for tenant-scoped resources.
    * Enforce "Ash is the business layer" (no direct Repo calls in ash layer).
    * CI-friendly output: deterministic, file:line:col, optional JSON.

  This audit is intentionally **static** (AST-based) and does **not** start the app or hit the DB.

  Usage:
      mix ash.audit
      mix ash.audit --format json
      mix ash.audit --paths lib --paths test
      mix ash.audit --warnings-as-errors
      mix ash.audit --fail-fast
      mix ash.audit --include-priv
      mix ash.audit --max-concurrency 8

  Fail-fast semantics:
    * Stops scanning as soon as an *error* is found in per-file checks.
    * Cross-file checks (domain↔resource authorizers) require a full scan, so they are skipped if we stop early.

  Allow markers (comments) to override specific rules when truly intentional:
      # ash_audit: allow_authorize_false
      # ash_audit: allow_missing_default_policy
      # ash_audit: allow_missing_domain_authorizers
      # ash_audit: allow_repo_call
      # ash_audit: allow_missing_multitenancy
      # ash_audit: allow_org_id_allow_nil
      # ash_audit: allow_missing_domain_binding
      # ash_audit: allow_imperative_callbacks
      # ash_audit: allow_policy_missing_expr
      # ash_audit: allow_missing_base

  Canonical references:
      Ash docs (v3): https://ash-hq.org/docs
      Project rules: /docs/ash/ASH_3_AI_STRICT_RULES.md
      RBAC matrix:   /docs/ash/ASH_3_RBAC_MATRIX.md
  """

  use Mix.Task

  @shortdoc "Run Ash 3.x compliance checks for Voelgoedevents"

  @switches [
    paths: :keep,
    format: :string,
    verbose: :boolean,
    fail_fast: :boolean,
    warnings_as_errors: :boolean,
    include_priv: :boolean,
    max_concurrency: :integer
  ]

  @default_paths ["lib", "test"]
  @default_format "text"

  @ash_domain_parts [:Ash, :Domain]
  @ash_resource_parts [:Ash, :Resource]
  @ash_api_parts [:Ash, :Api]

  @policy_authorizer_parts [:Ash, :Policy, :Authorizer]
  @repo_parts [:Voelgoedevents, :Repo]
  @base_resource_parts [:Voelgoedevents, :Ash, :Resources, :Base]

  defmodule Violation do
    @enforce_keys [:severity, :check, :file, :line, :message]
    defstruct [:severity, :check, :file, :line, :column, :message, :hint]
  end

  @spec run([String.t()]) :: :ok | no_return()
  @impl true
  def run(args) do
    {opts, _rest, invalid} = OptionParser.parse(args, strict: @switches)
    if invalid != [], do: Mix.raise("Invalid args: #{inspect(invalid)}")

    format = (opts[:format] || @default_format) |> String.downcase()
    verbose? = !!opts[:verbose]
    fail_fast? = !!opts[:fail_fast]
    warnings_as_errors? = !!opts[:warnings_as_errors]
    include_priv? = !!opts[:include_priv]
    max_concurrency = opts[:max_concurrency] || System.schedulers_online()

    paths =
      opts
      |> Keyword.get_values(:paths)
      |> case do
        [] ->
          base = @default_paths
          if include_priv?, do: base ++ ["priv"], else: base

        list ->
          list
      end

    files = gather_files(paths)

    Mix.shell().info("==> Ash audit (Ash 3.x) — scanning #{length(files)} files")
    if verbose?, do: Mix.shell().info("    Paths: #{Enum.join(paths, ", ")}")
    if verbose?, do: Mix.shell().info("    Concurrency: #{max_concurrency}")
    if verbose? and fail_fast?, do: Mix.shell().info("    Mode: fail-fast (per-file errors stop scan early)")

    {results, stopped_early?} =
      if fail_fast? do
        scan_sequential_fail_fast(files, verbose?, warnings_as_errors?)
      else
        {scan_parallel(files, verbose?, max_concurrency), false}
      end

    parse_errors =
      results
      |> Enum.flat_map(fn r ->
        case r.parse_error do
          nil ->
            []

          reason ->
            [
              %Violation{
                severity: :error,
                check: "parse_error",
                file: r.file,
                line: 1,
                message: "Failed to parse file: #{reason}",
                hint: "Fix syntax so the audit can analyze it."
              }
            ]
        end
      end)

    domains = Enum.flat_map(results, & &1.domains)
    resources = Enum.flat_map(results, & &1.resources)

    base_exists? =
      results
      |> Enum.flat_map(& &1.defined_modules)
      |> MapSet.new()
      |> MapSet.member?(@base_resource_parts)

    per_file_violations = Enum.flat_map(results, & &1.violations)

    cross_violations =
      if stopped_early? do
        []
      else
        domain_index = Enum.reduce(domains, %{}, fn d, acc -> Map.put(acc, d.module, d) end)

        resources
        |> Enum.flat_map(fn r -> cross_check_resource_domain_and_authorizers(r, domain_index) end)
        |> Kernel.++(base_resource_warnings(resources, base_exists?))
        |> Kernel.++(base_presence_note(resources, base_exists?))
      end

    all = normalize_output(parse_errors ++ per_file_violations ++ cross_violations, warnings_as_errors?)

    case format do
      "json" -> print_json(all)
      _ -> print_text(all)
    end

    exit_code =
      cond do
        Enum.any?(all, &(&1.severity == :error)) -> 1
        Enum.any?(all, &(&1.severity == :warning)) and warnings_as_errors? -> 1
        true -> 0
      end

    if exit_code == 0 do
      Mix.shell().info([:green, "Ash audit passed."])
      :ok
    else
      Mix.raise("Ash audit failed.")
    end
  end

  # ---------------------------------------------------------------------------
  # Scanning modes
  # ---------------------------------------------------------------------------

  defp scan_parallel(files, _verbose?, max_concurrency) do
    files
    |> Task.async_stream(
      &process_file(&1, false),
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, res} -> res
      {:exit, reason} ->
        %{
          file: "unknown",
          parse_error: "Task exit: #{inspect(reason)}",
          lines: [],
          defined_modules: [],
          domains: [],
          resources: [],
          violations: []
        }
    end)
  end

  defp scan_sequential_fail_fast(files, verbose?, warnings_as_errors?) do
    Enum.reduce_while(files, {[], false}, fn file, {acc, _stopped} ->
      if verbose?, do: Mix.shell().info("    Processing: #{file}")

      r = process_file(file, true)

      per_file = normalize_output(r.violations, warnings_as_errors?)
      parse_errs =
        case r.parse_error do
          nil ->
            []

          reason ->
            [
              %Violation{
                severity: :error,
                check: "parse_error",
                file: r.file,
                line: 1,
                message: "Failed to parse file: #{reason}",
                hint: "Fix syntax so the audit can analyze it."
              }
            ]
        end

      has_error? = Enum.any?(per_file ++ parse_errs, &(&1.severity == :error))

      if has_error? do
        {:halt, {acc ++ [%{r | violations: per_file}], true}}
      else
        {:cont, {acc ++ [%{r | violations: per_file}], false}}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # File scanning / parsing
  # ---------------------------------------------------------------------------

  defp gather_files(paths) do
    paths
    |> Enum.flat_map(fn path -> Path.wildcard("#{path}/**/*.{ex,exs}") end)
    |> Enum.reject(&excluded_path?/1)
    |> Enum.sort()
  end

  defp excluded_path?(path) do
    String.contains?(path, "/deps/") or
      String.contains?(path, "/_build/") or
      String.contains?(path, "/node_modules/") or
      String.contains?(path, "/priv/static/") or
      String.contains?(path, "/priv/resource_snapshots/")
  end

  defp process_file(file, _sequential?) do
    content = File.read!(file)
    lines = String.split(content, "\n", trim: false)

    case Code.string_to_quoted(content, columns: true, file: file) do
      {:ok, ast} ->
        defined_modules = MapSet.new(extract_defined_modules(ast))
        modules = extract_defmodules(ast)

        domains =
          modules
          |> Enum.filter(&module_uses?(&1.body, @ash_domain_parts))
          |> Enum.map(fn m ->
            %{
              module: m.module,
              file: file,
              line: m.line,
              has_policy_authorizer?: domain_has_policy_authorizer?(m.body),
              allow_missing_domain_authorizers?:
                allow_marker_near_line?(lines, m.line, "ash_audit: allow_missing_domain_authorizers")
            }
          end)

        resources =
          modules
          |> Enum.filter(fn m ->
            module_uses?(m.body, @ash_resource_parts) or module_uses?(m.body, @base_resource_parts)
          end)
          |> Enum.map(fn m ->
            policies = find_policies_block(m.body)
            multitenancy = find_multitenancy_block(m.body)
            org_attr = find_attribute(m.body, :organization_id)

            %{
              module: m.module,
              file: file,
              line: m.line,
              domain: find_resource_domain(m.body),
              allow_missing_domain_binding?:
                allow_marker_near_line?(lines, m.line, "ash_audit: allow_missing_domain_binding"),
              allow_missing_base?:
                allow_marker_near_line?(lines, m.line, "ash_audit: allow_missing_base"),
              has_policies?: policies != nil,
              policies_line: (policies && policies.line) || m.line,
              has_default_policy_deny?: (policies && policies.default_deny?) || false,
              policy_expr_issues: (policies && policies.expr_issues) || [],
              uses_base?: module_uses?(m.body, @base_resource_parts),
              org_attr: org_attr,
              multitenancy: multitenancy
            }
          end)

        violations =
          []
          |> Kernel.++(check_use_ash_api(file, ast))
          |> Kernel.++(check_forbidden_authorize_blocks(file, ast))
          |> Kernel.++(check_authorize_false_in_lib(file, ast, lines))
          |> Kernel.++(check_imperative_callbacks(file, ast, lines))
          |> Kernel.++(check_repo_calls_in_ash_layer(file, ast, lines))
          |> Kernel.++(check_domain_authorizers(domains))
          |> Kernel.++(check_resource_policy_rules(resources, lines))
          |> Kernel.++(check_tenant_resource_structure(resources, lines))
          |> Kernel.++(check_actor_literal_shape(file, ast))

        %{
          file: file,
          lines: lines,
          parse_error: nil,
          defined_modules: MapSet.to_list(defined_modules),
          domains: domains,
          resources: resources,
          violations: violations
        }

      {:error, {line, error, token}} ->
        %{
          file: file,
          lines: lines,
          parse_error: "line #{line}: #{error} #{inspect(token)}",
          defined_modules: [],
          domains: [],
          resources: [],
          violations: []
        }
    end
  rescue
    e ->
      %{
        file: file,
        lines: [],
        parse_error: Exception.message(e),
        defined_modules: [],
        domains: [],
        resources: [],
        violations: []
      }
  end

  # ---------------------------------------------------------------------------
  # Checks
  # ---------------------------------------------------------------------------

  defp check_use_ash_api(file, ast) do
    Macro.prewalk(ast, [], fn
      {:use, meta, [{:__aliases__, _m2, @ash_api_parts} | _]} = node, acc ->
        v = %Violation{
          severity: :error,
          check: "ash2_use_ash_api",
          file: file,
          line: meta[:line] || 1,
          column: meta[:column],
          message: "Forbidden: `use Ash.Api` (Ash 2.x). This project is Ash 3.x Domains-only.",
          hint: "Replace Ash.Api with Ash.Domain. See Ash v3 docs + /docs/ash/ASH_3_AI_STRICT_RULES.md."
        }

        {node, [v | acc]}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp check_forbidden_authorize_blocks(file, ast) do
    Macro.prewalk(ast, [], fn
      {:authorize?, meta, args} = node, acc ->
        if do_block_call?(args) do
          v = %Violation{
            severity: :error,
            check: "policy_authorize_block",
            file: file,
            line: meta[:line] || 1,
            column: meta[:column],
            message: "Forbidden `authorize? do ... end` block (legacy policy style).",
            hint:
              "Use `policies do ... end` with `policy ... do authorize_if/forbid_if ... end` and `default_policy :deny`."
          }

          {node, [v | acc]}
        else
          {node, acc}
        end

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp check_authorize_false_in_lib(file, ast, lines) do
    if String.starts_with?(file, "lib/") do
      Macro.prewalk(ast, [], fn
        {call, meta, args} = node, acc when is_atom(call) and is_list(args) and is_list(meta) ->
          if contains_authorize_false_kw?(args) do
            line = meta[:line] || 1

            if allow_marker_near_line?(lines, line, "ash_audit: allow_authorize_false") do
              {node, acc}
            else
              v = %Violation{
                severity: :error,
                check: "authorize_false_in_lib",
                file: file,
                line: line,
                column: meta[:column],
                message: "Forbidden `authorize?: false` in lib/ (auth bypass).",
                hint:
                  "Fix the policy/actor/tenant context instead of bypassing authorization.\n" <>
                    "If truly intentional, add `# ash_audit: allow_authorize_false` on the same line or within 3 lines above."
              }

              {node, [v | acc]}
            end
          else
            {node, acc}
          end

        {{:., meta_dot, _}, meta_call, args} = node, acc when is_list(args) ->
          line = meta_call[:line] || meta_dot[:line] || 1

          if contains_authorize_false_kw?(args) and
               not allow_marker_near_line?(lines, line, "ash_audit: allow_authorize_false") do
            v = %Violation{
              severity: :error,
              check: "authorize_false_in_lib",
              file: file,
              line: line,
              column: meta_call[:column] || meta_dot[:column],
              message: "Forbidden `authorize?: false` in lib/ (auth bypass).",
              hint:
                "Fix the policy/actor/tenant context instead of bypassing authorization.\n" <>
                  "If truly intentional, add `# ash_audit: allow_authorize_false` on the same line or within 3 lines above."
            }

            {node, [v | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    else
      []
    end
  end

  defp check_imperative_callbacks(file, ast, lines) do
    ash_layer? = String.starts_with?(file, "lib/voelgoedevents/ash/")
    allow? = allow_marker_near_line?(lines, 1, "ash_audit: allow_imperative_callbacks")

    if allow? do
      []
    else
      banned = [
        {[:Ash, :Changeset], :before_action},
        {[:Ash, :Changeset], :after_action},
        {[:Ash, :Changeset], :before_transaction},
        {[:Ash, :Changeset], :after_transaction}
      ]

      find_remote_calls(file, ast, banned, fn {mod, fun, line, col} ->
        %Violation{
          severity: if(ash_layer?, do: :error, else: :warning),
          check: "imperative_changeset_callback",
          file: file,
          line: line,
          column: col,
          message: "Imperative callback detected: #{Enum.join(mod, ".")}.#{fun}/…",
          hint:
            "Project rule: prefer action DSL (`change ...`, `validate ...`) or dedicated change modules.\n" <>
              "If you must keep this, add `# ash_audit: allow_imperative_callbacks` near the top of the file."
        }
      end)
    end
  end

  defp check_repo_calls_in_ash_layer(file, ast, lines) do
    if String.starts_with?(file, "lib/voelgoedevents/ash/") do
      aliases = repo_local_aliases(ast)

      Macro.prewalk(ast, [], fn
        {{:., meta_dot, [{:__aliases__, meta_alias, parts}, _fun]}, meta_call, _args} = node, acc ->
          line = meta_call[:line] || meta_dot[:line] || meta_alias[:line] || 1

          is_repo = parts == @repo_parts or MapSet.member?(aliases, parts)

          if is_repo and not allow_marker_near_line?(lines, line, "ash_audit: allow_repo_call") do
            v = %Violation{
              severity: :error,
              check: "repo_call_in_ash_layer",
              file: file,
              line: line,
              column: meta_call[:column] || meta_dot[:column] || meta_alias[:column],
              message: "Direct Repo call detected inside Ash business layer (`lib/voelgoedevents/ash/**`).",
              hint:
                "Move logic into Ash actions/changes/preparations/calculations.\n" <>
                  "If truly intentional, add `# ash_audit: allow_repo_call` on the same line or within 3 lines above."
            }

            {node, [v | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    else
      []
    end
  end

  defp check_domain_authorizers(domains) do
    Enum.flat_map(domains, fn d ->
      cond do
        d.allow_missing_domain_authorizers? -> []
        d.has_policy_authorizer? -> []
        true ->
          [
            %Violation{
              severity: :error,
              check: "domain_missing_policy_authorizer",
              file: d.file,
              line: d.line || 1,
              message: "Domain is missing policy authorizers (Ash.Policy.Authorizer).",
              hint:
                "Add to the Domain:\n" <>
                  "  authorization do\n" <>
                  "    authorizers [Ash.Policy.Authorizer]\n" <>
                  "  end\n" <>
                  "If intentionally non-policy domain, add `# ash_audit: allow_missing_domain_authorizers` within 3 lines above."
            }
          ]
      end
    end)
  end

  defp check_resource_policy_rules(resources, lines) do
    Enum.flat_map(resources, fn r ->
      v1 =
        cond do
          not r.has_policies? ->
            []

          r.has_default_policy_deny? ->
            []

          allow_marker_near_line?(lines, r.policies_line, "ash_audit: allow_missing_default_policy") ->
            []

          true ->
            [
              %Violation{
                severity: :error,
                check: "missing_default_policy_deny",
                file: r.file,
                line: r.policies_line || 1,
                message: "Resource has `policies do` but is missing `default_policy :deny`.",
                hint:
                  "Add `default_policy :deny` inside the `policies do` block.\n" <>
                    "If intentionally permissive (rare), add `# ash_audit: allow_missing_default_policy` within 3 lines above."
              }
            ]
        end

      v2 =
        r.policy_expr_issues
        |> Enum.flat_map(fn %{line: line, column: col, kind: kind} ->
          if allow_marker_near_line?(lines, line, "ash_audit: allow_policy_missing_expr") do
            []
          else
            [
              %Violation{
                severity: :warning,
                check: "policy_missing_expr_wrapper",
                file: r.file,
                line: line,
                column: col,
                message: "Policy condition looks like a raw expression (#{kind}) without `expr(...)` wrapper.",
                hint:
                  "Prefer: `authorize_if expr(...)` / `forbid_if expr(...)` / `authorize_unless expr(...)` / `forbid_unless expr(...)`.\n" <>
                    "If this is intentional, add `# ash_audit: allow_policy_missing_expr` within 3 lines above."
              }
            ]
          end
        end)

      v1 ++ v2
    end)
  end

  defp check_tenant_resource_structure(resources, lines) do
    Enum.flat_map(resources, fn r ->
      tenant_scoped? = r.org_attr != nil or r.multitenancy != nil

      if not tenant_scoped? do
        []
      else
        v_allow_nil =
          cond do
            r.org_attr == nil -> []
            r.org_attr.allow_nil_false? -> []
            allow_marker_near_line?(lines, r.org_attr.line, "ash_audit: allow_org_id_allow_nil") -> []
            true ->
              [
                %Violation{
                  severity: :error,
                  check: "tenant_org_id_allow_nil",
                  file: r.file,
                  line: r.org_attr.line || 1,
                  message: "`attribute :organization_id` must enforce `allow_nil? false` for tenant-scoped resources.",
                  hint:
                    "Make organization_id non-nullable at the Ash layer.\n" <>
                      "If truly intentional, add `# ash_audit: allow_org_id_allow_nil` within 3 lines above the attribute."
                }
              ]
          end

        v_multitenancy =
          cond do
            r.multitenancy != nil -> []
            allow_marker_near_line?(lines, r.line, "ash_audit: allow_missing_multitenancy") -> []
            true ->
              [
                %Violation{
                  severity: :error,
                  check: "tenant_missing_multitenancy",
                  file: r.file,
                  line: r.line || 1,
                  message: "Tenant-scoped resource is missing a `multitenancy do ... end` block.",
                  hint:
                    "Add a multitenancy block and bind tenant_attribute (typically :organization_id).\n" <>
                      "If truly intentional, add `# ash_audit: allow_missing_multitenancy` within 3 lines above."
                }
              ]
          end

        v_tenant_attr =
          cond do
            r.multitenancy == nil -> []
            r.multitenancy.mentions_org_id? -> []
            true ->
              [
                %Violation{
                  severity: :warning,
                  check: "tenant_multitenancy_missing_tenant_attribute",
                  file: r.file,
                  line: r.multitenancy.line || 1,
                  message: "Multitenancy block does not appear to reference `tenant_attribute :organization_id` (or equivalent).",
                  hint: "Prefer explicit tenant_attribute binding to organization_id for tenant scoping."
                }
              ]
          end

        v_allow_nil ++ v_multitenancy ++ v_tenant_attr
      end
    end)
  end

  defp check_actor_literal_shape(file, ast) do
    required = [:user_id, :organization_id, :role, :is_platform_admin, :is_platform_staff, :type]

    Macro.prewalk(ast, [], fn
      {call, meta, args} = node, acc when is_atom(call) and is_list(args) and is_list(meta) ->
        acc =
          Enum.reduce(args, acc, fn
            kw, acc2 when is_list(kw) and is_map(kw) ->
              case Keyword.fetch(kw, :actor) do
                {:ok, {:%{}, meta_map, kvs}} ->
                  keys =
                    kvs
                    |> Enum.map(fn {k, _} -> k end)
                    |> Enum.filter(&is_atom/1)
                    |> MapSet.new()

                  missing = Enum.reject(required, &MapSet.member?(keys, &1))

                  if missing == [] do
                    acc2
                  else
                    [
                      %Violation{
                        severity: :warning,
                        check: "actor_literal_missing_keys",
                        file: file,
                        line: meta_map[:line] || meta[:line] || 1,
                        column: meta_map[:column] || meta[:column],
                        message: "Actor literal is missing keys: #{Enum.join(Enum.map(missing, &inspect/1), ", ")}",
                        hint:
                          "Canonical actor shape requires: #{Enum.join(Enum.map(required, &inspect/1), ", ")}.\n" <>
                            "If this is a test, fix your actor helpers. If this is lib/, treat as a security smell."
                      }
                      | acc2
                    ]
                  end

                _ ->
                  acc2
              end

            _, acc2 ->
              acc2
          end)

        {node, acc}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  # ---------------------------------------------------------------------------
  # Cross-file checks
  # ---------------------------------------------------------------------------

  defp cross_check_resource_domain_and_authorizers(r, domain_index) do
    if not r.has_policies? do
      []
    else
      cond do
        r.allow_missing_domain_binding? ->
          []

        r.domain == nil ->
          [
            %Violation{
              severity: :warning,
              check: "resource_missing_domain_binding",
              file: r.file,
              line: r.line || 1,
              message: "Resource has policies but no domain binding was detected (domain: ...).",
              hint:
                "In Ash 3.x, resources should be bound to a Domain. Add `domain: MyDomain` in `use Ash.Resource, ...`.\n" <>
                  "If intentionally omitted, add `# ash_audit: allow_missing_domain_binding` within 3 lines above the resource module."
            }
          ]

        Map.has_key?(domain_index, r.domain) ->
          d = domain_index[r.domain]

          cond do
            d.allow_missing_domain_authorizers? -> []
            d.has_policy_authorizer? -> []
            true ->
              [
                %Violation{
                  severity: :error,
                  check: "resource_domain_missing_policy_authorizer",
                  file: r.file,
                  line: r.line || 1,
                  message:
                    "Resource policies will not be enforced: its domain #{inspect_module(r.domain)} is missing Ash.Policy.Authorizer.",
                  hint:
                    "Fix the Domain: add `authorization do authorizers [Ash.Policy.Authorizer] end`.\n" <>
                      "See /docs/ash/ASH_3_AI_STRICT_RULES.md."
                }
              ]
          end

        true ->
          [
            %Violation{
              severity: :warning,
              check: "resource_domain_unknown",
              file: r.file,
              line: r.line || 1,
              message: "Resource declares domain #{inspect_module(r.domain)} but that domain was not found in scanned paths.",
              hint: "Ensure the domain module exists in the scanned paths (or pass --paths to include it)."
            }
          ]
      end
    end
  end

  defp base_resource_warnings(resources, base_exists?) do
    if not base_exists? do
      []
    else
      resources
      |> Enum.filter(fn r ->
        (r.org_attr != nil or r.multitenancy != nil) and not r.uses_base? and not r.allow_missing_base?
      end)
      |> Enum.map(fn r ->
        %Violation{
          severity: :warning,
          check: "tenant_resource_missing_base",
          file: r.file,
          line: r.line || 1,
          message: "Tenant-scoped resource does not appear to `use Voelgoedevents.Ash.Resources.Base`.",
          hint:
            "If project standard is to use the base for tenancy/policies conventions, align this resource.\n" <>
              "If intentionally divergent, add `# ash_audit: allow_missing_base` within 3 lines above the resource module."
        }
      end)
    end
  end

  defp base_presence_note(resources, base_exists?) do
    if base_exists? do
      []
    else
      tenant_scoped_resources = Enum.filter(resources, fn r -> r.org_attr != nil or r.multitenancy != nil end)

      if tenant_scoped_resources == [] do
        []
      else
        [
          %Violation{
            severity: :warning,
            check: "base_resource_missing_from_scan",
            file: "N/A",
            line: 1,
            message: "Tenant-scoped resources exist, but Voelgoedevents.Ash.Resources.Base was not found in scanned paths.",
            hint:
              "If the base module exists, ensure it is included in --paths.\n" <>
                "If it doesn't exist, either create it or update docs + audit rules accordingly."
          }
        ]
      end
    end
  end

  # ---------------------------------------------------------------------------
  # AST helpers
  # ---------------------------------------------------------------------------

  defp extract_defined_modules(ast) do
    Macro.prewalk(ast, [], fn
      {:defmodule, _meta, [{:__aliases__, _m2, parts}, _]} = node, acc ->
        {node, [parts | acc]}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  # Robust: handle any opts list, not just [do: body]
  defp extract_defmodules(ast) do
    Macro.prewalk(ast, [], fn
      {:defmodule, meta, [{:__aliases__, _m2, parts}, opts]} = node, acc when is_list(opts) ->
        body = Keyword.get(opts, :do)

        if body do
          {node, [%{module: parts, line: meta[:line] || 1, body: body} | acc]}
        else
          {node, acc}
        end

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp module_uses?(body, want_parts) do
    Macro.prewalk(body, false, fn
      {:use, _meta, [{:__aliases__, _m2, ^want_parts} | _]} = node, _acc ->
        {node, true}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp domain_has_policy_authorizer?(body) do
    has_in_use_opts? =
      Macro.prewalk(body, false, fn
        {:use, _meta, [{:__aliases__, _m2, @ash_domain_parts}, opts]} = node, _acc when is_list(opts) ->
          {node, keyword_includes_authorizer?(opts, @policy_authorizer_parts)}

        node, acc ->
          {node, acc}
      end)
      |> elem(1)

    has_in_authorization_block? =
      Macro.prewalk(body, false, fn
        {:authorization, _meta, args} = node, _acc ->
          {node, authorization_block_includes_authorizer?(args, @policy_authorizer_parts)}

        node, acc ->
          {node, acc}
      end)
      |> elem(1)

    has_in_use_opts? or has_in_authorization_block?
  end

  defp authorization_block_includes_authorizer?(args, authorizer_parts) when is_list(args) do
    block = extract_do_block(args)

    if block == nil do
      false
    else
      Macro.prewalk(block, false, fn
        {:authorizers, _meta, [list]} = node, _acc when is_list(list) ->
          {node, Enum.any?(list, &alias_ast_matches?(&1, authorizer_parts))}

        {:authorizers, _meta, [single]} = node, _acc ->
          {node, alias_ast_matches?(single, authorizer_parts)}

        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    end
  end

  defp authorization_block_includes_authorizer?(_, _), do: false

  defp keyword_includes_authorizer?(opts, authorizer_parts) when is_list(opts) do
    case Keyword.fetch(opts, :authorizers) do
      {:ok, list} when is_list(list) -> Enum.any?(list, &alias_ast_matches?(&1, authorizer_parts))
      {:ok, single} -> alias_ast_matches?(single, authorizer_parts)
      _ -> false
    end
  rescue
    _ -> false
  end

  defp find_resource_domain(body) do
    via_use =
      Macro.prewalk(body, nil, fn
        {:use, _meta, [{:__aliases__, _m2, @ash_resource_parts}, opts]} = node, _acc when is_list(opts) ->
          dom =
            case Keyword.fetch(opts, :domain) do
              {:ok, {:__aliases__, _m3, parts}} -> parts
              _ -> nil
            end

          {node, dom}

        node, acc ->
          {node, acc}
      end)
      |> elem(1)

    if via_use != nil do
      via_use
    else
      Macro.prewalk(body, nil, fn
        {:domain, _meta, [{:__aliases__, _m2, parts}]} = node, _acc ->
          {node, parts}

        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    end
  end

  defp find_policies_block(body) do
    Macro.prewalk(body, nil, fn
      {:policies, meta, args} = node, _acc ->
        block = extract_do_block(args)

        if block == nil do
          {node, nil}
        else
          default_deny? = policies_block_has_default_deny?(block)
          expr_issues = policies_block_expr_issues(block)
          {node, %{line: meta[:line] || 1, default_deny?: default_deny?, expr_issues: expr_issues}}
        end

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp policies_block_has_default_deny?(block) do
    Macro.prewalk(block, false, fn
      {:default_policy, _m, [:deny]} = node, _acc -> {node, true}
      {:default_policy, _m, [{:deny, _, _}]} = node, _acc -> {node, true}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end

  # FIXED: add authorize_unless/forbid_unless
  defp policies_block_expr_issues(block) do
    Macro.prewalk(block, [], fn
      {:authorize_if, meta, [arg]} = node, acc ->
        {node, maybe_add_expr_issue(acc, meta, arg, :authorize_if)}

      {:forbid_if, meta, [arg]} = node, acc ->
        {node, maybe_add_expr_issue(acc, meta, arg, :forbid_if)}

      {:authorize_unless, meta, [arg]} = node, acc ->
        {node, maybe_add_expr_issue(acc, meta, arg, :authorize_unless)}

      {:forbid_unless, meta, [arg]} = node, acc ->
        {node, maybe_add_expr_issue(acc, meta, arg, :forbid_unless)}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp maybe_add_expr_issue(acc, meta, arg, kind) do
    if expr_wrapped?(arg) do
      acc
    else
      if raw_operator_ast?(arg) do
        [%{line: meta[:line] || 1, column: meta[:column], kind: Atom.to_string(kind)} | acc]
      else
        acc
      end
    end
  end

  defp expr_wrapped?({:expr, _, _}), do: true
  defp expr_wrapped?({:always, _, _}), do: true
  defp expr_wrapped?({:never, _, _}), do: true
  defp expr_wrapped?(_), do: false

  defp raw_operator_ast?({op, _, [_a, _b]}) when op in [:==, :!=, :>, :>=, :<, :<=, :in, :and, :or], do: true
  defp raw_operator_ast?({:not, _, [_a]}), do: true
  defp raw_operator_ast?(_), do: false

  defp find_multitenancy_block(body) do
    Macro.prewalk(body, nil, fn
      {:multitenancy, meta, args} = node, _acc ->
        block = extract_do_block(args)
        mentions_org_id? = (block && multitenancy_mentions_org_id?(block)) || false
        {node, %{line: meta[:line] || 1, mentions_org_id?: mentions_org_id?}}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp multitenancy_mentions_org_id?(block) do
    Macro.prewalk(block, false, fn
      {:tenant_attribute, _m, [:organization_id]} = n, _ -> {n, true}
      {:tenant_attribute, _m, [{:organization_id, _, _}]} = n, _ -> {n, true}
      n, acc -> {n, acc}
    end)
    |> elem(1)
  end

  defp find_attribute(body, name) when is_atom(name) do
    Macro.prewalk(body, nil, fn
      {:attribute, meta, [^name, _type]} = node, _acc ->
        {node, %{line: meta[:line] || 1, allow_nil_false?: false}}

      {:attribute, meta, [^name, _type, opts]} = node, _acc when is_list(opts) ->
        allow_nil_false? =
          cond do
            Keyword.keyword?(opts) and Keyword.get(opts, :allow_nil?) == false ->
              true

            Keyword.keyword?(opts) and Keyword.has_key?(opts, :do) ->
              block = Keyword.get(opts, :do)
              block_has_allow_nil_false?(block)

            true ->
              false
          end

        {node, %{line: meta[:line] || 1, allow_nil_false?: allow_nil_false?}}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp block_has_allow_nil_false?(block) do
    Macro.prewalk(block, false, fn
      {:allow_nil?, _meta, [false]} = node, _acc -> {node, true}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end

  defp extract_do_block(args) when is_list(args) do
    Enum.find_value(args, fn
      kw when is_list(kw) and is_map(kw) -> Keyword.get(kw, :do)
      _ -> nil
    end)
  end

  defp do_block_call?(args) when is_list(args), do: extract_do_block(args) != nil
  defp do_block_call?(_), do: false

  defp alias_ast_matches?({:__aliases__, _m, parts}, want_parts), do: parts == want_parts
  defp alias_ast_matches?(_, _), do: false

  defp find_remote_calls(file, ast, targets, build_violation) do
    Macro.prewalk(ast, [], fn
      {{:., meta_dot, [{:__aliases__, meta_alias, mod_parts}, fun]}, meta_call, _args} = node, acc ->
        if Enum.any?(targets, fn {m, f} -> m == mod_parts and f == fun end) do
          line = meta_call[:line] || meta_dot[:line] || meta_alias[:line] || 1
          col = meta_call[:column] || meta_dot[:column] || meta_alias[:column]
          v = build_violation.({mod_parts, fun, line, col})
          {node, [v | acc]}
        else
          {node, acc}
        end

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp repo_local_aliases(ast) do
    Macro.prewalk(ast, MapSet.new(), fn
      {:alias, _meta, [target]} = node, acc ->
        {node, maybe_add_repo_alias(acc, target, nil)}

      {:alias, _meta, [target, opts]} = node, acc when is_list(opts) ->
        {node, maybe_add_repo_alias(acc, target, opts)}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp maybe_add_repo_alias(acc, {:__aliases__, _m, @repo_parts}, opts) do
    local =
      case opts do
        nil ->
          [:Repo]

        kw when is_list(kw) ->
          case Keyword.get(kw, :as) do
            {:__aliases__, _m2, as_parts} -> as_parts
            _ -> [:Repo]
          end

        _ ->
          [:Repo]
      end

    MapSet.put(acc, local)
  end

  defp maybe_add_repo_alias(acc, _target, _opts), do: acc

  defp contains_authorize_false_kw?(args) when is_list(args) do
    Enum.any?(args, fn
      kw when is_list(kw) and is_map(kw) -> Keyword.get(kw, :authorize?) == false
      _ -> false
    end)
  rescue
    _ -> false
  end

  defp allow_marker_near_line?(lines, line, marker) do
    start_ln = max(1, line - 3)

    Enum.any?(start_ln..line, fn ln ->
      case Enum.at(lines, ln - 1) do
        nil -> false
        text -> String.contains?(text, marker)
      end
    end)
  end

  defp normalize_output(list, warnings_as_errors?) do
    list
    |> Enum.map(fn v ->
      if warnings_as_errors? and v.severity == :warning do
        %{v | severity: :error, hint: (v.hint || "") <> " (treated as error via --warnings-as-errors)"}
      else
        v
      end
    end)
    |> Enum.sort_by(fn v -> {v.file, v.line, v.column || 0, v.severity, v.check} end)
  end

  defp inspect_module(parts) when is_list(parts), do: Enum.join(parts, ".")
  defp inspect_module(_), do: "UnknownDomain"

  # ---------------------------------------------------------------------------
  # Output
  # ---------------------------------------------------------------------------

  defp print_text(violations) do
    {errors, warnings} = Enum.split_with(violations, &(&1.severity == :error))

    Mix.shell().info("")
    Mix.shell().info("---- Ash audit results ----")
    Mix.shell().info("Errors:   #{length(errors)}")
    Mix.shell().info("Warnings: #{length(warnings)}")
    Mix.shell().info("")

    Enum.each(violations, fn v ->
      loc =
        if v.column do
          "#{v.file}:#{v.line}:#{v.column}"
        else
          "#{v.file}:#{v.line}"
        end

      sev =
        case v.severity do
          :error -> [:red, "ERROR", :reset]
          :warning -> [:yellow, "WARN ", :reset]
        end

      Mix.shell().info([sev, " ", loc, " [", v.check, "] ", v.message])

      if v.hint && v.hint != "" do
        Mix.shell().info("       hint: " <> String.replace(v.hint, "\n", "\n             "))
      end
    end)

    Mix.shell().info("")
  end

  defp print_json(violations) do
    unless Code.ensure_loaded?(Jason) do
      Mix.raise("JSON output requested but Jason is not available. Add {:jason, ...} or use --format text.")
    end

    json =
      Enum.map(violations, fn v ->
        %{
          severity: v.severity,
          check: v.check,
          file: v.file,
          line: v.line,
          column: v.column,
          message: v.message,
          hint: v.hint
        }
      end)

    Mix.shell().info(Jason.encode!(%{violations: json}))
  end
end
