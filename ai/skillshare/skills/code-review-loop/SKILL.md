---
name: code-review-loop
description: Review, remediate, and verify code through bounded rounds—internal by default, or with requested external reviewer(s) (Claude, Codex, Grok, Gemini; combined into one parallel panel when multiple external reviewers are named, sequential after internal when both are requested, and two-pass waves on repeat requests). Use for review-and-fix requests; use code-review for one read-only review.
metadata:
  origin: custom
---

# Code Review Loop

Own assessment, repairs, verification, and completion. Read `code-review` and the original requirements. Keep the requested target, exclusions, authority, and unrelated work. Do not commit, push, publish comments, change branches, stash, reset, or clean the checkout without authorization.

## Select reviewers

Resolve the reviewer sequence under Reviewer selection (`code-review/references/reviewer-selection.md`, loop mode) and Two-pass review (`code-review/references/two-pass-review.md`). Each sequential stage (internal, Wave 1 external loop/panel, Wave 2 external loop/panel) runs as its own loop invocation with its own ten-round cap; all reviewers within one external panel stage share that stage's ten-round cap.

Examples: `/code-review-loop` (internal), `/code-review-loop claude` (Claude), `/code-review-loop claude, codex, and grok` (one combined panel), `/code-review-loop internal and claude & codex` (internal, then combined panel), `/code-review-loop claude and codex x 2` (Wave 1 Opus + Sol panel, then Wave 2 Astra).

## Coordinate review

Every round reviews under `code-review`. External loops (Codex, Claude, Grok, Gemini) always delegate each reviewer through its one-shot `*-review` skill (`codex-review`, `claude-review`, `grok-review`, `gemini-review`)—never through `*-review-loop`—with the caller's selected provider, pass family, and options. When multiple external reviewers are selected together (any count, such as Claude + Codex + Grok), run them as one combined panel loop rather than separate sequential loops; keep internal review sequential before an external panel when both are requested, and keep two-pass waves sequential under Two-pass review (`code-review/references/two-pass-review.md`). For an internal loop inside T3 Code, use the harness's native subagent controls when the current session's active model and effort already satisfy Reviewer model and effort (`code-review/references/reviewer-settings.md`) and no worktree isolation or explicit setting override is needed; otherwise delegate each round as a fresh `delegate_task` on the current session's provider with explicit model and effort. Without T3 orchestration, delegating internal review is optional—use a separate native reviewer when independent scrutiny adds value or when the main session's settings do not satisfy the reviewer policy. Delegated rounds follow the delegated review runtime (`code-review/references/external-runtime.md`) and Subagent roles and reasoning (`execute-plan/references/subagent-reasoning.md`). Keep ownership clear, and join assigned work before you advance.

Reviewers and repair agents reason from requirements and current evidence; they do not defer to each other's conclusions. Give later rounds only concise prior findings, responses, and open objections, as claims to verify without provider or model attribution; leave out unrelated repair history. Report reviewer independence accurately.

## Assess findings

Assess all completed reviews and any retained partial findings from the round, together with all open findings, before you edit. In a multi-reviewer panel, deduplicate overlapping claims across reviewers first; cross-reviewer agreement is a triage signal, not proof, and every claim is judged on evidence. For each distinct claim, check the requirement or invariant, a reachable trigger, the impact, and attribution to the target. Accept, partially accept, or reject it with a short evidence-based reason. Separate a valid defect from the reviewer's proposed fix. Check disputed facts directly. Do not implement a suggestion only because a reviewer repeats it or gives it high priority, and do not reject a valid defect only because its repair is inconvenient.

Reject unsupported claims, preferences, and scope expansion without routine user confirmation. Resolve material requirement ambiguity from existing authority; ask the user only when still necessary, and continue independent work. Keep a compact ledger in context of findings, decisions, repairs, and check evidence. Partial acceptance keeps the valid part open; a genuinely unresolved claim stays open. Findings from a partial inspection can be assessed, but partial coverage cannot establish a clean result.

## Repair

Group accepted defects across all reviewers in the round by root cause. Before you edit, trace the affected ownership, boundaries, callers, data flow, and invariants, and choose a proportionate correction and its checks. Refactor when local patches would duplicate rules or leave the cause in place. Keep required behavior, data, explicit compatibility, and scope; do not add unrelated redesign or cleanup. Repair agents verify the diagnosis and approach independently, and return evidence for any disagreement instead of implementing a faulty request.

Finish all repairs, regression coverage, and directly related cleanup for the round and inspect the combined diff before running verification checks. Verify the original failure and surviving behavior across affected consumers with fast targeted checks during intermediate repair rounds; do not rerun full test suites after every intermediate round. When running as a stage inside `execute-plan`, defer full-suite verification to the closing `final-pass`; in a standalone loop, run or reuse the required full gates once repairs settle. Apply Check evidence and reuse (`final-pass/references/check-evidence.md`): unaffected passing checks can stay valid, but an edited result still needs fresh review.

If accepted defects persist after two repair stages, reassess the cumulative changes and shared invariants before the next edit, revise the repair plan, and use a bounded refactor when warranted. Repeated rejected suggestions do not trigger refactoring or scope expansion. This reassessment does not reset the round cap.

## Rounds

Keep review and remediation sequential; do not edit the target during a review. Use at most ten completed review rounds per loop stage, regardless of panel size. Failed attempts do not use a round. Parallel inspections launched together against the same unchanged target form one round. The cap is a limit, not a quota.

For each reviewer in the loop, track three orthogonal facts against the current unchanged target: whether it is `blocked` (unavailable or exhausted attempts), whether it is `open` (not yet reviewed, or has accepted findings or unresolved objections not yet verified), and whether it has `broad coverage` (a complete broad review on the current unchanged target). Initially every reviewer is non-blocked, `open`, and lacks broad coverage. Any complete broad review grants broad coverage on the current unchanged target, independently of whether findings remain; a complete review clears `open` only when all of its claims are resolved without further edits. Any edit clears current broad coverage for every reviewer (preserving any earlier completed review only as historical evidence) while leaving reviewers with accepted findings or unresolved objections `open`.

- Round 1 runs every requested non-blocked reviewer in parallel for a broad review of the complete current target with all relevant lenses.
- Rounds 2–9, while any non-blocked reviewer is `open` (except where the broad closing round below takes precedence), run **only** the currently `open` non-blocked reviewers in parallel so already-clean reviewers sit out unstable edits. Run a **broad** review when the repair is expected to settle all open findings (especially in a single-reviewer loop) so it can close in one round rather than forcing a separate broad closing round; use a **focused** review (on repairs, open defects, affected invariants and consumers, and regressions) when multi-round iteration is still active or edits are narrowly localized in a panel.
- Once no non-blocked reviewer is `open`—and by Round 8 or 9 if `open` rounds are still active late in the budget, taking precedence so room remains for one repair pass—use the next round for a broad closing review across every non-blocked reviewer that still lacks `broad coverage` on the current unchanged target. Round 10 is always broad and read-only across every non-blocked reviewer without broad coverage on the current unchanged target.
- After edits, get a fresh review while rounds remain. Do not restart the loop to avoid the cap.

Evidence-based rejection does not need reviewer agreement, or another call only to get a `No findings` verdict. A complete broad review makes that reviewer clean (`open` cleared with broad coverage) once all its claims are resolved without edits. Keep each reviewer's reported findings and explain your disposition; do not describe a disputed review as a review with no findings. A real unresolved objection keeps that reviewer `open` and prevents a clean close; if an unresolved objection cannot be cleared by authorized edits or existing authority (and no further authorized edits remain), do not re-run reviewers endlessly on an unchanged target—ask the user if needed or finish the stage as incomplete with the objection recorded.

### Recover failed attempts

Assess content, not format. Normalize prose, Markdown, or missing bookkeeping yourself without another model call, and keep useful partial findings without inventing missing inspection.

For a model-capacity, rate-limit, API, launch, transport, timeout, authentication, workspace failure, or incomplete required coverage in an otherwise successful response, record the cause and keep useful partial findings. Retry the same round against the unchanged target with the same scope, provider, model, options, and broad or focused purpose. A failed broad closing review stays a broad closing review on retry.

Use up to three attempts per round unless the user says otherwise. In a multi-reviewer panel, track attempts and failures per reviewer independently: retry only failed reviewer(s) against the unchanged target without discarding or re-running other reviewers' completed inspections from that round. For transient failures, follow retry-after guidance or use increasing delays within the budget. For configuration or access failures, fix the cause before you retry; mark that reviewer `blocked` if required input or access is unavailable. A user cancellation stops work. Do not duplicate active calls or switch providers silently. If attempts or the time budget run out for a reviewer, mark it `blocked` for the rest of this loop stage and record its cause and any useful partial findings.

Once every reviewer assigned to a round has either completed its inspection or become `blocked`: assess all completed findings together with any retained useful partial findings before deciding whether to repair, schedule another round, or close (never counting a failed or partial inspection toward completed coverage or round count). If at least one reviewer completed an inspection, charge one shared round; if every reviewer assigned to that round became `blocked` (zero completed inspections), do not advance or charge the round—after assessing any retained partial findings, recompute eligibility among any remaining non-blocked reviewers at that same round number (for example, scheduling remaining non-blocked reviewers that still lack broad coverage). If no non-blocked reviewer remains anywhere in the stage (including a single-reviewer loop whose reviewer is blocked), stop the stage as incomplete without advancing past an uncompleted round or claiming that the round cap was reached.

Track round and attempt separately. T3 launch keys and task replacement follow T3 coordination (`code-review/references/t3-runtime.md`); with ACP, use a fresh session after a confirmed failure. A permitted transport fallback stays in the same round and attempt budget.

## Finish

The loop stage is clean when every requested reviewer is non-blocked, has no `open` findings or objections, and has broad coverage on the final unchanged target, every finding has an evidence-backed disposition, and repair verification passes (in a standalone loop, required full checks must pass or reuse valid evidence; inside `execute-plan`, targeted repair checks suffice and the closing `final-pass` owns the final full-suite gates). Verified repairs still need fresh review before a clean close. When every non-blocked reviewer has cleared `open` and has broad coverage on the final unchanged target (so no eligible reviewer remains for another round), but one or more requested reviewers are `blocked`, finish the stage as incomplete—preserving each reviewer's status, rounds used, and missing coverage.

After the cap or a real blocker, hand the residual findings and missing coverage to `final-pass` for authorized direct repair and verification. Keep the loop's actual capped or incomplete status, and identify repairs verified without fresh review. A cap ends this review invocation, not the authorized implementation work. Do not call direct inspection a clean review.

During plan execution, follow `execute-plan` (`Completion and review checkpoints`). Report material findings, fixes, rejected claims with reasons, rounds used, per-reviewer resolved model, coverage, and terminal status (for panels), checks, and limits concisely. Remove only task-owned scratch and verify the cleanup. Save reports or transcripts only on request.
