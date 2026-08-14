---
name: grok-review
description: Perform exactly one read-only external review with the local Grok CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $grok-review or explicitly requested by name, including from another skill; never invoke implicitly. Use grok-review-loop for iterative remediation.
---

# Grok Review

Run one model-bearing top-level Grok review. Metadata and authentication preflight do not count. Do not edit, remediate, publish, retry, follow up, or start another model-bearing Grok process.

Read `../code-review/SKILL.md`. Reuse its frozen target, lenses, thresholds, summaries, external schema at `../code-review/references/external-review-result.schema.json`, and canonical schema at `../code-review/references/review-result.schema.json`. Send only the minimum authorized non-secret material; never send credentials, unrelated data, the conversation, prior reviews, or hidden conclusions.

## Prepare

Create a private non-secret run directory outside the target. Its request contains only the requirements, frozen descriptor and exclusions, `phase: single`, user focus, shared lenses and fields, and these rules: inspect the complete surface with tools before terminal output; preserve files and scope; cite repository-relative `path:line` evidence; omit nits and speculation; disclose unfinished work; apply the clean-slate durable-architecture lens; and omit caller-only assessment fields. Include only actionable target-attributable findings with confidence at least 80/100. Assign priority independently of confidence: `P0` critical/systemic, `P1` core blocker, `P2` concrete defect, and `P3` low-impact but actionable. `incomplete` requires an attempted inspection that proved impossible, not pending work.

Map applicable repository `worker` and `fastworker` roles to Grok's built-in `general-purpose` task. These tasks inherit the same scope and finish before synthesis; do not otherwise restrict subagent use. Call terminal `StructuredOutput` exactly once after inspection and return `clean` only after complete inspection. Do not invoke another review skill or top-level Grok process inside this call.

## Run the protected call

Confirm installed help and bundled documentation. Grok 1.0.3 cannot both bootstrap from copied `auth.json` and kernel-deny that credential from reviewer tools, so this script-free path requires an already supplied `XAI_API_KEY` in the top-level environment. Never read or copy `auth.json`, use an auth-provider command, or place a secret in the request, argv, command text, or output.

Create private empty `HOME`, `GROK_HOME`, and CWD directories. The target must be outside the CWD, `GROK_HOME`, and sandbox-writable temporary paths. In `0600` `$GROK_HOME/config.toml`, set `[models].default`, disable every installed Claude/Cursor compatibility cell and Codex sessions, and use:

```toml
[shell_environment_policy]
inherit = "core"
ignore_default_excludes = false
exclude = ["*KEY*", "*SECRET*", "*TOKEN*"]
include_only = ["PATH", "HOME", "LANG", "LC_*", "TMPDIR"]
```

In `0600` `$GROK_HOME/sandbox.toml`, use the only review profile:

```toml
[profiles.review-target]
extends = "strict"
restrict_network = true
read_only = ["<absolute-frozen-root>", "<absolute-run-directory>"]
deny = ["<absolute-original-auth-or-excluded-secret-path>"]
```

Use one exact `deny` entry per existing secret path, or an empty list. Built-in `strict` writes to its CWD; built-in `read-only` reads everywhere. Empty CWD plus `strict` and `read_only` grants target reads without target writes, and the kernel scope includes shell tools and `task` workers. Grok 1.0.3 macOS tests confirmed target read, target write denial, denied-secret read denial, denial of `ps` parent-environment inspection, and that denying copied authentication also blocks Grok's own bootstrap. Revalidate after a Grok or platform change; fail closed if any property differs.

Run isolated `inspect --json`. Require the isolated config source, built-in `general-purpose` agent, and no hooks, plugins, skills, unexpected compatibility sources, or unapproved MCP servers. Then snapshot relevant target state.

From the empty CWD, launch Grok with Zsh builtins, without a script or persistent wrapper. Store the validated paths, schema, inherited `PATH` and locale, and `XAI_API_KEY` in non-exported `REVIEW_*` parameters with `typeset +x`. Never print the key, enable shell tracing, or expand its value into recorded command text. Remove every inherited export, restore only the named child environment, then replace the shell:

```sh
for REVIEW_EXPORTED in ${(k)parameters[(R)*-export*]}; do
  unset "$REVIEW_EXPORTED"
done
export PATH="$REVIEW_PATH" HOME="$REVIEW_HOME" GROK_HOME="$REVIEW_GROK_HOME" \
  LANG="$REVIEW_LANG" TMPDIR="$REVIEW_TMPDIR" XAI_API_KEY="$REVIEW_API_KEY" \
  GROK_TELEMETRY_ENABLED=0 GROK_TELEMETRY_TRACE_UPLOAD=0 \
  GROK_TELEMETRY_MIXPANEL_ENABLED=0 GROK_EXTERNAL_OTEL=0 \
  OTEL_METRICS_EXPORTER=none OTEL_LOGS_EXPORTER=none OTEL_TRACES_EXPORTER=none
unset REVIEW_API_KEY REVIEW_EXPORTED
exec grok --agent general-purpose --no-leader --storage-mode local --cwd "$REVIEW_CWD" \
  --prompt-file "$REVIEW_REQUEST" --verbatim --permission-mode dontAsk \
  --tools "read_file,grep,list_dir,run_terminal_cmd,task" --deny MCPTool \
  --sandbox review-target --rules "Inspect the complete frozen target before StructuredOutput." \
  --no-memory --no-auto-update --disable-web-search \
  --output-format json --json-schema "$REVIEW_SCHEMA" \
  > "$REVIEW_STDOUT" 2> "$REVIEW_STDERR"
```

Put absolute target paths in the request; do not set `--cwd` to the target. `--json-schema` supplies `StructuredOutput`; omit it from `--tools` because 1.0.3 cannot map that name and otherwise fails open. Keep shell use read-only. Add no broad allow rules, mutation commands, worker restrictions, approval bypasses, custom hooks, or scripts. For an explicitly authorized remote target, replace only the local MCP/web denies with exact named read-only operations.

Poll the same process for at least 30 minutes unless it exits. Success requires exit zero, one JSON envelope, `stopReason: end_turn`, no `structuredOutputError`, schema-conforming object-valued `structuredOutput`, coherent findings, and complete inspection. Treat premature `incomplete`, prose, concatenated JSON, missing structured output, mutation, ambient discovery, missing authentication, sandbox failure, or timeout as incomplete without retry or prose recovery.

Snapshot again. Reverse only the call's exact delta when safe; never blanket-restore a dirty tree. Delete and verify the transient environment regardless of outcome. Preserve the non-secret run directory on failure; delete it after validated success.

Independently verify valid findings and normalize them with `assessment: accept | partial | decline` and a rationale. Return accepted and partial findings first, declined count, inspected surface, and one-line residual risk. Never commit, push, publish, or make other remote writes without separate authorization.
