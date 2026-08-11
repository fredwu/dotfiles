---
name: grok-review-loop
description: Run the canonical bounded review-remediation workflow using one read-only external Grok CLI invocation per scheduled round, with broad rounds 1-3, blocker-focused rounds 4-9, and an optional final read-only round 10. Use only when explicitly invoked as $grok-review-loop or explicitly requested by name, including from another skill; never invoke implicitly.
---

# Grok Review Loop

Read `../code-review-loop/SKILL.md`, `../code-review/SKILL.md`, and `../grok-review/SKILL.md`. Follow the canonical loop completely, with the substitutions and constraints below. The primary agent owns all assessment, remediation, verification, and completion.

Explicit invocation authorizes the bounded Grok calls and minimum non-secret data transfer required by the scheduled rounds. It does not authorize unrelated data, remote writes, or expanded remediation.

## Use Grok as the scheduled reviewer

Replace each scheduled internal `code-review` invocation with exactly one fresh external Grok CLI invocation using `grok-review`'s direct-repository, `dontAsk`, read-only-sandbox, bounded-turn, no-memory mechanism and shared logical contract. Keep web search disabled. Never use bypass flags. One top-level CLI call is one round even if it fails; do not retry within a round or silently substitute another reviewer.

Use one private temporary run directory for the loop. Keep the frozen scope once, and write one compact per-round request and one exact result. Each request contains only:

- original requirements and acceptance criteria;
- frozen typed target, current task-attributable surface, and exclusions;
- `grok-review`'s shared default review lens;
- round number, phase, and allowed focus.

Set `--cwd` to the frozen repository root for every round so Grok inspects the current repository directly. Keep request and output files in the temporary run directory outside it. For broad rounds 1-3, tell Grok to inspect the complete surface itself and apply that round's broad focus. Do not pass prior outputs, the ledger, remediation summaries, or conclusions. For focused rounds 4-9, pass only the one independently verified blocker, its current relevant surface, and immediate regression boundary; exclude lower-priority exploration. Round 10 receives the complete current surface, broad final-audit focus, and no prior conclusions.

Use the strict shared external schema content directly for every result, then normalize assessed findings into the final canonical schema; do not add a Python, jq, or other validator. Preserve the exact stdout envelope, stderr, and completion state for independent assessment. Apply `grok-review`'s tool, permission, sandbox, output, envelope, and at-least-30-minute outer deadline rules to every call. If a call yields a running session or process handle, poll that same handle until the process exits or the real deadline expires. A yield, silence, or empty poll is not a timeout; never cancel a healthy yielded process or start a replacement. Snapshot the worktree before and after every call. Treat mutation, incomplete inspection, missing or incoherent structured output, timeout, sandbox failure, or CLI failure as an incomplete round; do not invent findings. Stop when the canonical progress rules require it.

After rounds 1-9, independently assess the result, fix every accepted authorized item, resolve residual tasks, run proportionate checks, and update the ledger. Deferral is allowed only for a stated authority, input, or external-state blocker. During and after round 10, make no remediation.

## Return and clean up

Use the canonical loop's compact agent handoff and human summary. Include rounds and phases used, Grok completion failures, accepted/partial/declined counts, fixes, checks, unresolved findings, blockers, and residual risk. Do not dump raw transcripts unless requested.

Delete only the validated current temporary run directory. If cleanup cannot be verified, preserve it and report its exact path. Never commit, push, publish comments, or make other remote writes unless separately authorized.
