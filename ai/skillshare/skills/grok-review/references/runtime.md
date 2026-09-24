# Grok review runtime

Read this before preflight or a review call. These constraints apply to single reviews and every external loop round.

Use the installed `grok` CLI as a normal headless process. Select its existing cached login file from the incoming `GROK_AUTH_PATH`, or `${GROK_HOME:-$HOME/.grok}/auth.json`; resolve this to an absolute path before entering the empty CWD or changing the child environment. Pass only that path through `GROK_AUTH_PATH`. The CLI reads and refreshes the original file in place. Do not read, copy, or relocate the auth file, require an API key, or put a secret in the request, argv, command text, or output. If the file is unavailable or the CLI reports no credentials, return incomplete and tell the user to run `grok login`.

Create private empty `0700` synthetic `HOME` and `GROK_HOME` directories under the run directory, and a separate empty `0700` CWD outside both the target and run directory. The target must stay outside these directories and outside sandbox-writable temporary paths. Keep the real login accessible only through `GROK_AUTH_PATH`; never project the real home configuration into the synthetic directories.

Confirm installed help and bundled documentation for the flags below. `grok inspect` does not accept `--sandbox`; inspect from the empty CWD with the same narrow synthetic environment as the review call. Require the expected version and CWD, no project root, and no discovered instructions, skills, hooks, plugins, MCP servers, or other non-built-in agents. Recheck after any authentication preflight that writes configuration. Fail preflight if ambient configuration remains. Then snapshot relevant target state.

`--sandbox workspace` with an empty CWD keeps the target readable and not writable. Do not require `strict`, `read-only`, or a custom profile: those can refuse to start on some hosts (for example when a runtime-socket deny path is a symlink). Pass `--no-leader` so a user `[cli] use_leader` setting does not attach this process to a shared leader. Pass `--storage-mode local` so the session is not written back to the backend; it still lands under the synthetic `$GROK_HOME/sessions` for the empty CWD. Pass `--no-subagents`: the installed CLI exposes `spawn_subagent` rather than `task`, and the default child has full capability with tools rendered from its agent definition, outside the verified parent allowlist.

Do not pass `--json-schema`. On the installed CLI it can force a first-turn schema object and skip tool inspection. Put the external schema in the request and require the final answer to be exactly one conforming JSON object.

From the empty CWD, launch Grok with Zsh builtins, without a script or persistent wrapper. Store the real `PATH`, `HOME`, `GROK_HOME` (or `$HOME/.grok`), `LANG`, `TMPDIR`, the absolute auth path, synthetic home paths, and validated paths in non-exported `REVIEW_*` parameters. Before the snippet below, set `REVIEW_AUTH_DIR` to the absolute auth file's parent. Fail preflight if it is the real home, an ancestor of the real home, or an ancestor of the target. Check that the auth path names a readable regular file and that the synthetic directories are empty and owner-only before preflight. Do not enable shell tracing. Unset every inherited export, then restore only the narrow child environment shown below. Use it for `grok inspect` and any authentication preflight too.

```sh
for REVIEW_EXPORTED in ${(k)parameters[(R)*-export*]}; do
  unset "$REVIEW_EXPORTED"
done
export PATH="$REVIEW_PATH" HOME="$REVIEW_SYNTH_HOME" \
  GROK_HOME="$REVIEW_SYNTH_GROK_HOME" GROK_AUTH_PATH="$REVIEW_AUTH_PATH" \
  LANG="$REVIEW_LANG" TMPDIR="$REVIEW_TMPDIR"
unset REVIEW_EXPORTED
exec grok --agent general-purpose --cwd "$REVIEW_CWD" \
  --prompt-file "$REVIEW_REQUEST" --verbatim --permission-mode dontAsk \
  --tools "read_file,grep,list_dir" --no-subagents \
  --disallowed-tools "run_terminal_cmd,search_replace,search_tool,use_tool" \
  --deny MCPTool \
  --deny "Read($REVIEW_GROK_HOME)" --deny "Read($REVIEW_GROK_HOME/**)" \
  --deny "Read($REVIEW_SYNTH_GROK_HOME)" --deny "Read($REVIEW_SYNTH_GROK_HOME/**)" \
  --deny "Read($REVIEW_AUTH_DIR)" --deny "Read($REVIEW_AUTH_DIR/**)" \
  --deny "Read(~/.grok)" --deny "Read(~/.grok/**)" \
  --deny "Glob($REVIEW_GROK_HOME)" --deny "Glob($REVIEW_GROK_HOME/**)" \
  --deny "Glob($REVIEW_SYNTH_GROK_HOME)" --deny "Glob($REVIEW_SYNTH_GROK_HOME/**)" \
  --deny "Glob($REVIEW_AUTH_DIR)" --deny "Glob($REVIEW_AUTH_DIR/**)" \
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

Permission denies are tool-layer only and do not block CLI bootstrap. Do not kernel-deny the auth file. Set `REVIEW_AUTH_DIR` to the auth file's parent and deny it, the real Grok home, and the synthetic Grok home as both directories and descendants; `~` is matched as text. `Read` also covers `grep`. `Glob` covers `list_dir`. Treat a successful tool read of those trees as a boundary violation. Other real home paths remain readable under `workspace`; do not invent an unbounded deny list, and do not deny the real `$HOME/**` when the target lives there.

Put absolute target paths in the request; do not set `--cwd` to the target. Add no broad allow rules, mutation commands, approval bypasses, custom hooks, or scripts. For an explicitly authorized remote target, the caller must obtain only the named read-only data and serialize the frozen snapshot outside Grok's CWD before the call. Grok reads that local snapshot with the same three file tools; return incomplete if the authorized snapshot cannot be made.

Poll the same process for at least 30 minutes unless it exits. Success requires exit zero, one JSON envelope, `stopReason: end_turn`, and one schema-conforming result object: use `structuredOutput` when it is a conforming object, otherwise the last conforming JSON object in envelope `text`. Leading prose does not make a tool-using review incomplete. The result must show complete inspection: at least one tool turn, and not a pre-inspection `incomplete`. Check the task-owned session's actual tool definitions: only `read_file`, `grep`, and `list_dir` may be exposed. Treat a missing or invalid object, tool-less output, unexpected tool, mutation, ambient discovery, authentication failure, sandbox refusal, or timeout as incomplete without retry.

Snapshot again. Reverse only the call's exact delta when safe; never blanket-restore a dirty tree. Then apply the scratch lifecycle.

## Scratch lifecycle

The caller owns cleanup after child exit; shell `exec` cannot perform it. Create scratch only for agent isolation, transfer, completion checks, or diagnosis, never user presentation. Track every task-created request, output, schema copy, log, synthetic home, probe, working directory, and the child session group under the synthetic `$GROK_HOME/sessions` for that CWD. After consumers exit and assessment finishes, remove them and verify removal on success, preflight/call failure, or abandonment. Stop task-owned consumers before early cleanup. Preserve canonical schemas, the real auth file and CLI state, requested deliverables, and unrelated files; never delete shared directories wholesale.

Always remove each empty CWD and its child session group after its attempt; never retain them for handoff. Retain only non-secret request or diagnostic scratch for active agent continuation, with a cleanup owner and removal point. Report retained paths or cleanup failures, not raw logs.
