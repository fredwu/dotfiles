# Grok review runtime

Read this before preflight or a review call. These constraints apply to single reviews and every external loop round.

Confirm installed help and bundled documentation. This script-free path requires an already supplied `XAI_API_KEY` in the top-level environment. In the original Grok 1.0.3 validation, denying tools access to copied authentication also blocked CLI bootstrap. Treat that as historical evidence and revalidate containment for the installed version; do not assume later versions preserve it. Never read or copy `auth.json`, use an auth-provider command, or place a secret in the request, argv, command text, or output.

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

Put absolute target paths in the request; do not set `--cwd` to the target. `--json-schema` supplies `StructuredOutput`; omit it from `--tools` because 1.0.3 could not map that name and otherwise failed open; verify the installed version preserves the intended tool boundary. Keep shell use read-only. Add no broad allow rules, mutation commands, worker restrictions, approval bypasses, custom hooks, or scripts. For an explicitly authorized remote target, replace only the local MCP/web denies with exact named read-only operations.

Poll the same process for at least 30 minutes unless it exits. Success requires exit zero, one JSON envelope, `stopReason: end_turn`, no `structuredOutputError`, schema-conforming object-valued `structuredOutput`, coherent findings, and complete inspection. Treat premature `incomplete`, prose, concatenated JSON, missing structured output, mutation, ambient discovery, missing authentication, sandbox failure, or timeout as incomplete without retry or prose recovery.

Snapshot again. Reverse only the call's exact delta when safe; never blanket-restore a dirty tree. Delete and verify the transient environment regardless of outcome. Preserve the non-secret run directory on failure; delete it after validated success.
