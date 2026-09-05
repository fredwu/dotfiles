# Codex review runtime

Read this before preflight or a review call. These constraints apply to single reviews and every external loop round.

Before invoking, confirm the outer runtime permits the exact `codex exec` process to read existing authentication and write normal ephemeral CLI state. Obtain narrow authority before starting if needed; otherwise return incomplete without using Codex as an access probe, relocating its home, copying credentials, or weakening isolation.

Do not rely on legacy `--sandbox read-only` or `--add-dir`: they constrain writes, not reads. Before any model-bearing call, validate the exact no-grant permission profile with non-model probes. Model tools and workers must have no filesystem or network grants, no approval path, and no inherited environment. Confirm that tool processes cannot read the Codex authentication location, a non-secret sentinel in an unrelated temporary directory, or the source repository. Authentication may be visible to the parent CLI only. If any check fails or the installed CLI cannot express this boundary, return incomplete without a model call.

Snapshot relevant status and diffs before and after the call. Run Codex from the empty directory with the complete snapshot on stdin. Keep `--ephemeral`, `--ignore-user-config`, `--ignore-rules`, approval policy `never`, no filesystem grants, tool and hosted-web network disabled, an empty inherited tool environment, no ambient hooks/apps/plugins/memory, and explicit multi-agent routing. Do not expose the repository or any payload directory as a workspace or additional directory.

Configure no MCP server or connected tool. Capture any explicitly authorized remote evidence into the serialized snapshot before the Codex call.

Use ordinary prompt-bearing `codex exec` for every target so multi-agent routing and the strict output schema remain in the same turn context. Put the exact frozen type, selector, identities, included worktree classes, and exclusions in the serialized request.

```text
codex exec --ephemeral --ignore-user-config --ignore-rules --enable multi_agent \
  --disable apps --disable plugins --disable hooks --disable memories \
  -C <empty-private-directory> -c 'approval_policy="never"' \
  -c 'web_search="disabled"' \
  -c 'default_permissions="review_payload_only"' \
  -c 'permissions.review_payload_only={filesystem={":root"="deny"},network={enabled=false}}' \
  -c 'shell_environment_policy={inherit="none"}' \
  --skip-git-repo-check --output-schema <external-schema-file> \
  -o <output-file> - < <request-file>
```

Confirm syntax and profile enforcement with the installed CLI. Keep untrusted text in files, not shell interpolation. Do not add `:minimal`, a workspace root, temporary-directory access, or any other filesystem grant. Add no script, wrapper, approval-evasion, unrelated capability restriction, or bypass flag.

Set an outer deadline of at least 30 minutes and poll only the yielded handle until exit or the real deadline; silence is not a timeout. Success requires one non-empty schema-conforming terminal JSON result, coherent verdict and findings, and complete-surface inspection. Preserve the exact result and completion state.

Fail on boundary violation, mutation, timeout, missing CLI or login, empty or schema-invalid output, or incomplete inspection. Treat any output produced after a boundary violation as unusable. Reverse only the call's exact delta when safe; never blanket-restore a dirty tree, retry, recover findings from invalid output, or invent findings.
