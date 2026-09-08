# Codex review runtime

Read this before preflight or a review call. These constraints apply to single reviews and every external loop round.

Use the installed `codex exec` CLI as a normal headless process. Authentication is the CLI's cached login in `$CODEX_HOME/auth.json` (default `~/.codex/auth.json`), or whatever fallback the CLI already applies. Do not require `OPENAI_API_KEY` or any other credential environment variable. Do not read, copy, or relocate the CLI's auth files, and do not put a secret in the request, argv, command text, or output. If the CLI reports no credentials, return incomplete and tell the user to run `codex login`.

Do not relocate `HOME` or `CODEX_HOME`. Create a private empty `0700` CWD outside the target and the run directory. Put the complete authorized snapshot in the stdin request. Do not set `-C` to the target or pass `--add-dir`.

`--sandbox read-only` with an empty CWD keeps the workspace not writable. Host reads remain possible; the snapshot is the authorized surface. `--ignore-user-config` skips `$CODEX_HOME/config.toml` so the review does not inherit that file's MCP servers, plugin list, or sandbox default. Auth and skill discovery still use `CODEX_HOME` and the usual skill paths. `--enable multi_agent` exposes worker spawn. Then snapshot relevant target state.

From the empty CWD, launch Codex with Zsh builtins, without a script or persistent wrapper. Keep untrusted text in files.

```sh
exec codex exec --ephemeral --ignore-user-config --ignore-rules \
  --enable multi_agent \
  --disable apps --disable plugins --disable hooks --disable memories \
  --sandbox read-only \
  -C "$REVIEW_CWD" \
  -c 'approval_policy="never"' \
  -c 'web_search="disabled"' \
  -c 'shell_environment_policy={inherit="none"}' \
  --skip-git-repo-check --output-schema "$REVIEW_OUTPUT_SCHEMA" \
  -o "$REVIEW_STDOUT" - < "$REVIEW_REQUEST"
```

`--ephemeral` does not persist a session. `$REVIEW_OUTPUT_SCHEMA` must be [output.schema.json](output.schema.json), the external result fields without `allOf`; the installed CLI rejects `allOf`. After the call, still enforce the external schema's verdict/findings cardinality. Add no approval bypass, extra filesystem grant, MCP server, or wrapper.

Poll the same process for at least 30 minutes unless it exits. Success requires exit zero and one schema-conforming JSON object in `$REVIEW_STDOUT`. Leading prose or a failed worker spawn does not make a completed inspection incomplete if that object is present. Treat empty or invalid output, mutation, authentication failure, sandbox refusal, or timeout as incomplete without retry.

Snapshot again. Reverse only the call's exact delta when safe; never blanket-restore a dirty tree. Then apply the scratch lifecycle.

## Scratch lifecycle

The caller owns cleanup after child exit; shell `exec` cannot perform it. Create scratch only for agent isolation, transfer, completion checks, or diagnosis, never user presentation. Track every task-created request, output, schema copy, log, probe, and working directory. After consumers exit and assessment finishes, remove them and verify removal on success, preflight/call failure, or abandonment. Stop task-owned consumers before early cleanup. Preserve canonical schemas, pre-existing CLI state, requested deliverables, and unrelated files; never delete shared directories wholesale.

Always remove each empty CWD after its attempt; never retain it for handoff. Retain only non-secret request or diagnostic scratch for active agent continuation, with a cleanup owner and removal point. Report retained paths or cleanup failures, not raw logs.
