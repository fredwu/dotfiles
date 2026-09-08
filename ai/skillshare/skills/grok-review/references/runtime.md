# Grok review runtime

Read this before preflight or a review call. These constraints apply to single reviews and every external loop round.

Use the installed `grok` CLI as a normal headless process. Authentication is the CLI's cached `grok login` session in `$GROK_HOME/auth.json` (default `~/.grok/auth.json`), or whatever fallback the CLI already applies. Do not require `XAI_API_KEY` or any other credential environment variable. Do not read, copy, or relocate the CLI's auth files, and do not put a secret in the request, argv, command text, or output. If the CLI reports no credentials, return incomplete and tell the user to run `grok login`.

Do not relocate `HOME` or `GROK_HOME`; that hides the login session. Create a private empty `0700` CWD outside the target and the run directory. The target must stay outside that CWD and outside sandbox-writable temporary paths.

Confirm installed help and bundled documentation for the flags below. `grok inspect` does not accept `--sandbox`; inspect from the empty CWD only to record version, CWD, and project root. Do not fail inspect because the real Grok home still has hooks, skills, plugins, or MCP servers. Then snapshot relevant target state.

`--sandbox workspace` with an empty CWD keeps the target readable and not writable. Do not require `strict`, `read-only`, or a custom profile: those can refuse to start on some hosts (for example when a runtime-socket deny path is a symlink). Pass `--no-leader` so a user `[cli] use_leader` setting does not attach this process to a shared leader. Pass `--storage-mode local` so the session is not written back to the backend; it still lands under `$GROK_HOME/sessions` for the empty CWD.

Do not pass `--json-schema`. On the installed CLI it can force a first-turn schema object and skip tool inspection. Put the external schema in the request and require the final answer to be exactly one conforming JSON object.

From the empty CWD, launch Grok with Zsh builtins, without a script or persistent wrapper. Store the real `PATH`, `HOME`, `GROK_HOME` (or `$HOME/.grok`), `LANG`, `TMPDIR`, and validated paths in non-exported `REVIEW_*` parameters. Do not enable shell tracing. Unset every inherited export, then restore only that narrow child environment.

```sh
for REVIEW_EXPORTED in ${(k)parameters[(R)*-export*]}; do
  unset "$REVIEW_EXPORTED"
done
export PATH="$REVIEW_PATH" HOME="$REVIEW_HOME" GROK_HOME="$REVIEW_GROK_HOME" \
  LANG="$REVIEW_LANG" TMPDIR="$REVIEW_TMPDIR"
unset REVIEW_EXPORTED
exec grok --agent general-purpose --cwd "$REVIEW_CWD" \
  --prompt-file "$REVIEW_REQUEST" --verbatim --permission-mode dontAsk \
  --tools "read_file,grep,list_dir,task" \
  --disallowed-tools "run_terminal_cmd,search_replace,search_tool,use_tool" \
  --deny MCPTool \
  --deny "Read($REVIEW_GROK_HOME)" --deny "Read($REVIEW_GROK_HOME/**)" \
  --deny "Read(~/.grok)" --deny "Read(~/.grok/**)" \
  --deny "Glob($REVIEW_GROK_HOME)" --deny "Glob($REVIEW_GROK_HOME/**)" \
  --deny "Glob(~/.grok)" --deny "Glob(~/.grok/**)" \
  --deny "Read($REVIEW_HOME/.ssh)" --deny "Read($REVIEW_HOME/.ssh/**)" \
  --deny "Read(~/.ssh)" --deny "Read(~/.ssh/**)" \
  --deny "Glob($REVIEW_HOME/.ssh)" --deny "Glob($REVIEW_HOME/.ssh/**)" \
  --deny "Glob(~/.ssh)" --deny "Glob(~/.ssh/**)" \
  --sandbox workspace --no-memory --no-leader --storage-mode local \
  --rules "Inspect the frozen target with read_file, grep, or list_dir before the final JSON object. Do not emit that object until inspection finishes." \
  --no-auto-update --disable-web-search --no-plan \
  --output-format json \
  > "$REVIEW_STDOUT" 2> "$REVIEW_STDERR"
```

Permission denies are tool-layer only and do not block CLI bootstrap. Do not kernel-deny the auth files. Deny each credential tree as both the directory and its descendants, in absolute and literal `~` form; `~` is matched as text. `Read` also covers `grep`. `Glob` covers `list_dir`. `--disallowed-tools` applies to the parent and to `task` workers. Treat a successful tool read of those trees as a boundary violation. Other home paths remain readable under `workspace`; do not invent an unbounded deny list, and do not deny `$HOME/**` when the target lives under `$HOME`.

Put absolute target paths in the request; do not set `--cwd` to the target. Add no broad allow rules, mutation commands, approval bypasses, custom hooks, or scripts. For an explicitly authorized remote target, replace only the local MCP/web denies with exact named read-only operations.

Poll the same process for at least 30 minutes unless it exits. Success requires exit zero, one JSON envelope, `stopReason: end_turn`, and one schema-conforming result object: use `structuredOutput` when it is a conforming object, otherwise the last conforming JSON object in envelope `text`. Leading prose does not make a tool-using review incomplete. The result must show complete inspection: at least one tool turn, and not a pre-inspection `incomplete`. Treat a missing or invalid object, tool-less output, mutation, ambient discovery, authentication failure, sandbox refusal, or timeout as incomplete without retry.

Snapshot again. Reverse only the call's exact delta when safe; never blanket-restore a dirty tree. Then apply the scratch lifecycle.

## Scratch lifecycle

The caller owns cleanup after child exit; shell `exec` cannot perform it. Create scratch only for agent isolation, transfer, completion checks, or diagnosis, never user presentation. Track every task-created request, output, schema copy, log, probe, working directory, and the child session group under `$GROK_HOME/sessions` for that CWD. After consumers exit and assessment finishes, remove them and verify removal on success, preflight/call failure, or abandonment. Stop task-owned consumers before early cleanup. Preserve canonical schemas, pre-existing CLI state, requested deliverables, and unrelated files; never delete shared directories wholesale.

Always remove each empty CWD and its child session group after its attempt; never retain them for handoff. Retain only non-secret request or diagnostic scratch for active agent continuation, with a cleanup owner and removal point. Report retained paths or cleanup failures, not raw logs.
