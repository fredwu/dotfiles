---
name: grok-review-loop
description: Run the canonical bounded review-remediation workflow using one read-only external Grok CLI invocation per scheduled round, with broad rounds 1-3, blocker-focused rounds 4-9, and an optional final read-only round 10. Use only when explicitly invoked as $grok-review-loop or explicitly requested by name, including from another skill; never invoke implicitly.
---

# Grok Review Loop

Read `../code-review-loop/SKILL.md`, `../code-review/SKILL.md`, and `../grok-review/SKILL.md`. Follow the canonical loop with these substitutions. The primary agent owns assessment, remediation, verification, and completion.

Explicit invocation authorizes only scheduled bounded Grok calls and their minimum non-secret data transfer—not unrelated data, remote writes, or expanded remediation.

## Use Grok as the scheduled reviewer

Replace each scheduled internal `code-review` with exactly one fresh external Grok CLI call using `grok-review`'s direct-repository, `dontAsk`, read-only-sandbox, `--no-plan`, bounded-turn, no-memory mechanism and contract. Keep web search disabled. One top-level call consumes one round even on failure; never retry, substitute reviewers, or use bypass flags.

Use one private temporary run directory and one frozen scope. Write one compact request and exact result per round. The scheduled Grok process is a separate `grok --prompt-file` invocation and will not receive `grok-review` by implicit invocation, so copy only `grok-review`'s request-body prompt contract into every request, not its caller CLI. Include only:

- original requirements and acceptance criteria;
- frozen typed target, current task-attributable surface, and exclusions;
- `grok-review`'s shared default review lens and current prompt contract;
- round number, phase, and allowed focus.

Keep phase as this loop round's phase, not `phase: single`. Set `--cwd` to the frozen root every round for direct current-repository inspection; keep request/output files in the external run directory. For broad rounds 1-3, require complete-surface inspection with that round's broad focus; pass no prior outputs, ledger, remediation summaries, or conclusions. For focused rounds 4-9, pass only one independently verified blocker, its current relevant surface, and immediate regression boundary; exclude lower-priority exploration. Give round 10 the complete current surface, broad final-audit focus, and no prior conclusions.

For every result, pass strict shared schema content directly, then normalize assessed findings to the canonical schema; add no Python, jq, or other validator. Preserve the exact stdout envelope, stderr, and completion state. Apply `grok-review`'s tool, permission, sandbox, output, envelope, and at-least-30-minute outer deadline rules. Poll the same yielded handle until exit or the real deadline; yield/silence/empty poll is not timeout, and never cancel or replace a healthy process. Snapshot before and after. Mutation, incomplete inspection, missing/incoherent structured output, timeout, sandbox failure, or CLI failure makes the round incomplete; invent no findings. An incomplete Grok round is a completion failure, not a clean review; do not early-stop from it as if no findings remain while residual authorized work exists. Follow canonical stop rules.

After rounds 1-9, independently assess, fix every accepted authorized item, resolve residual tasks, run proportionate checks, and update the ledger. Defer only for a stated authority, input, or external-state blocker. Make no remediation during or after round 10.

## Return and clean up

Use the canonical compact handoff and summary. Include rounds/phases, Grok completion failures, accepted/partial/declined counts, fixes, checks, unresolved findings, blockers, and residual risk. Omit raw transcripts unless requested.

Delete only the validated current run directory; if cleanup cannot be verified, preserve and report its exact path. Never commit, push, publish comments, or make other remote writes without separate authorization.
