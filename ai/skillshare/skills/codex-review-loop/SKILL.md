---
name: codex-review-loop
description: >-
  Run the canonical bounded review-remediation workflow using one read-only
  external Codex CLI invocation per scheduled round, with broad rounds 1-3,
  blocker-focused rounds 4-9, and an optional final read-only round 10. Use only when
  explicitly invoked as $codex-review-loop or explicitly requested by name,
  including from another skill; never invoke implicitly.
---

# Codex Review Loop

Read `../code-review-loop/SKILL.md`, `../code-review/SKILL.md`, and `../codex-review/SKILL.md`. Follow the canonical loop completely, with the substitutions and constraints below. The primary agent owns all assessment, remediation, verification, and completion.

Explicit invocation authorizes the bounded Codex calls and minimum non-secret data transfer required by the scheduled rounds. It does not authorize unrelated data, remote writes, or expanded remediation.

## Use Codex as the scheduled reviewer

Replace each scheduled internal `code-review` invocation with exactly one fresh external Codex CLI invocation using `codex-review`'s ephemeral read-only mechanism and shared logical contract. Never use bypass flags. One top-level CLI call is one round even if it fails; do not retry within a round or silently substitute another reviewer.

Use one private temporary run directory for the loop. Keep the frozen scope once, and write one compact per-round request and one exact result. Each request contains only:

- original requirements and acceptance criteria;
- frozen typed target, current task-attributable surface, and exclusions;
- `codex-review`'s shared default review lens;
- round number, phase, and allowed focus.

For broad rounds 1-3, tell Codex to inspect the complete surface itself and apply that round's broad focus. Do not pass prior outputs, the ledger, remediation summaries, or conclusions. For focused rounds 4-9, pass only the one independently verified blocker, its current relevant surface, and immediate regression boundary; exclude lower-priority exploration. Round 10 receives the complete current surface, broad final-audit focus, and no prior conclusions.

Before every scheduled invocation, apply `codex-review`'s outer-runtime
preflight and obtain any narrow process authority before starting Codex. Keep
the inner reviewer sandbox read-only. If authority is unavailable, record the
round as incomplete and stop without invoking; never launch and retry, alter
`CODEX_HOME`, copy or symlink credentials, use a bypass flag, or weaken the
sandbox.

Use the strict shared external schema for every Codex result, then normalize
assessed findings into the final canonical schema. Apply `codex-review`'s
prompt-bearing `review -`, `--ignore-user-config`, ephemeral read-only execution,
output, and direct-inspection rules to every call. Give each outer execution
call a timeout/deadline of at least 30 minutes. If it yields a running session
or process handle, poll that same handle until exit or the real deadline; never
treat yield or silence as timeout, cancel it, or start a replacement. Preserve
the exact result and completion state for independent assessment. Snapshot the
worktree before and after every call. Treat mutation, incomplete inspection,
empty or schema-invalid output, a real timeout, or CLI failure as an incomplete
round; do not invent findings. Stop when the canonical progress rules require
it.

After rounds 1-9, independently assess the result, fix every accepted authorized item, resolve residual tasks, run proportionate checks, and update the ledger. Deferral is allowed only for a stated authority, input, or external-state blocker. During and after round 10, make no remediation.

## Return and clean up

Use the canonical loop's compact agent handoff and human summary. Include rounds and phases used, Codex completion failures, accepted/partial/declined counts, fixes, checks, unresolved findings, blockers, and residual risk. Do not dump raw transcripts unless requested.

Delete only the validated current temporary run directory. If cleanup cannot be verified, preserve it and report its exact path. Never commit, push, publish comments, or make other remote writes unless separately authorized.
