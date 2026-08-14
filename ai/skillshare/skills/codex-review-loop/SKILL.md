---
name: codex-review-loop
description: Run the canonical bounded review-remediation workflow using one read-only external Codex CLI invocation per scheduled round, with broad rounds 1-3, blocker-focused rounds 4-9, and an optional final read-only round 10. Use only when explicitly invoked as $codex-review-loop or explicitly requested by name, including from another skill; never invoke implicitly.
---

# Codex Review Loop

Read `../code-review-loop/SKILL.md`, `../code-review/SKILL.md`, and `../codex-review/SKILL.md`. Follow the canonical loop with these substitutions. The primary agent owns assessment, remediation, verification, and completion.

Explicit invocation authorizes only scheduled bounded Codex calls and their minimum non-secret data transfer—not unrelated data, remote writes, or expanded remediation.

## Use Codex as the scheduled reviewer

Replace each scheduled internal `code-review` with exactly one fresh external Codex CLI call using `codex-review`'s ephemeral read-only mechanism and contract. One top-level call consumes one round even on failure; never retry, substitute reviewers, or use bypass flags.

Use one private temporary run directory and one frozen scope. Write one compact request and exact result per round. Include only:

- original requirements and acceptance criteria;
- frozen typed target, current task-attributable surface, and exclusions;
- `codex-review`'s shared default review lens;
- round number, phase, and allowed focus.

For broad rounds 1-3, tell Codex to inspect the complete surface itself and apply that round's broad focus. Do not pass prior outputs, the ledger, remediation summaries, or conclusions. For focused rounds 4-9, pass only the one independently verified blocker, its current relevant surface, and immediate regression boundary; exclude lower-priority exploration. Round 10 receives the complete current surface, broad final-audit focus, and no prior conclusions.

Before each invocation, apply `codex-review`'s outer-runtime preflight and obtain any narrow process authority before starting. Keep the inner sandbox read-only. If authority is unavailable, record incomplete and stop without invoking. Never launch and retry, alter `CODEX_HOME`, copy/symlink credentials, use bypass flags, or weaken the sandbox.

For every result, use the strict shared external schema, then normalize assessed findings to the canonical schema. Apply `codex-review`'s prompt-bearing `review -`, `--ignore-user-config`, ephemeral read-only execution, output contract, direct inspection, guarded same-message prose recovery, and at-least-30-minute outer deadline. Poll the same yielded handle until exit or the real deadline; yield/silence is not timeout, and never cancel or replace a healthy process. Preserve the exact result and completion state; snapshot before and after. Mutation, incomplete inspection, empty/unusable output, real timeout, or CLI failure makes the round incomplete; invent no findings.

Schema-invalid usable prose consumes its round; never retry or replace it. Record recovery provenance and coverage risk in the round and final residual risk. Assess/remediate recovered findings after rounds 1-9. Such prose establishes clean or early stop only when it explicitly confirms complete frozen-surface inspection and no finding meeting the 80% threshold. Follow canonical stop rules.

After rounds 1-9, independently assess, fix every accepted authorized item, resolve residual tasks, run proportionate checks, and update the ledger. Defer only for a stated authority, input, or external-state blocker. Make no remediation during or after round 10.

## Return and clean up

Use the canonical compact handoff and summary. Include rounds/phases, Codex completion failures, accepted/partial/declined counts, fixes, checks, unresolved findings, blockers, and residual risk. Omit raw transcripts unless requested.

Delete only the validated current run directory; if cleanup cannot be verified, preserve and report its exact path. Never commit, push, publish comments, or make other remote writes without separate authorization.
