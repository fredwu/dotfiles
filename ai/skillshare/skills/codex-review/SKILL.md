---
name: codex-review
description: Perform exactly one read-only external review with the local Codex CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $codex-review or explicitly requested by name, including from another skill; never invoke implicitly. Use codex-review-loop for iterative remediation.
---

# Codex Review

Run exactly one model-bearing top-level Codex CLI review. Metadata preflight does not count as the review. Do not edit, remediate, publish, retry, follow up, or run a second review. The caller owns scope and assessment.

Read `../code-review/SKILL.md`. Reuse its typed target, lenses, evidence threshold, priorities, summaries, external schema at `../code-review/references/external-review-result.schema.json`, and canonical schema at `../code-review/references/review-result.schema.json`. Send only the minimum non-secret material authorized by explicit invocation; never send credentials, unrelated user data, the whole conversation, prior reviews, or hidden conclusions.

## Prepare the request

Freeze the target per `code-review` and create a private temporary run directory outside the repository with an empty `0700` working directory. Serialize the exact authorized snapshot into the stdin request: relevant current and base content, status and diff metadata, applicable repository instructions, and a manifest with relative path, role, size, and hash for every content block. Do not include `.git`, `.codex`, credentials, symlink targets, unrelated files, host session metadata, or absolute host paths. If the complete snapshot cannot fit safely in one request, return incomplete without a model call.

Require inspection of every serialized content block before the final result, preserved scope, repository-relative `path:line` evidence, no style nits or speculation, and disclosure of unfinished work. Include only actionable target-attributable findings with confidence at least 80/100. Assign priority independently of confidence: `P0` critical/systemic, `P1` core blocker, `P2` concrete defect, and `P3` low-impact but actionable. Follow applicable agent-routing instructions: worker subagents remain available inside this one invocation, receive the relevant embedded snapshot content, inherit the same no-filesystem/no-network boundary, and must finish before the top-level process synthesizes the result. Forbid nested review-skill invocation or another top-level `codex` process only to preserve the one-call contract.

Require the entire final message to be exactly one JSON object conforming to the external schema, with no prose or fences. The final object is terminal: emit it only after complete inspection succeeds or inspection is impossible, and never for progress. Permit `incomplete` only when inspection is impossible and `clean` only after complete-surface inspection. Tell Codex to omit `assessment` and `assessment_rationale`; the caller adds them after verification. Preserve `code-review`'s clean-slate durable-architecture lens.

## Run the review

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

## Assess and return

Independently verify each valid finding, label it `accept`, `partial`, or `decline`, and normalize it to the canonical contract with `assessment` and `assessment_rationale`. This is not another review round.

Return accepted and partial findings first, the declined count, inspected surface, and one-line residual risk. Omit raw logs unless requested. Delete only the validated run directory; otherwise preserve and report its exact path. Never commit, push, publish comments, or make other remote writes without separate authorization.
