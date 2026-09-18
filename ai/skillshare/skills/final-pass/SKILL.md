---
name: final-pass
description: Close a completed phase or execution after review; resolve omissions and residual issues, then run the project's full testing and quality checks.
---

# Final Pass

Use after `code-review-loop` at each required [execution checkpoint](../execute-plan/SKILL.md#completion-and-review-checkpoints), or for a standalone final check. Review the full checkpoint change set against the original request and later updates, including integration with completed phases. Resolve task-relevant omissions and inconsistencies across code, documentation, tests, and configuration within scope.

Reconcile execution and worker residuals, review findings, failed checks, and verification gaps. Fix all authorized task-relevant issues, including pre-existing failures discovered during the task. A review cap or terminal read-only audit does not defer these repairs: perform them here without restarting the loop. Reject unsupported findings with evidence.

Do not use this recovery to replace a fresh review still required and available within the active loop, including after round 3. For genuinely incomplete review output or repairs left unreviewed after the loop ends, identify the missing coverage against the original target, acceptance criteria, and review lenses. Inspect that coverage directly and record the evidence in task context; do not retry the review invocation or add disguised review rounds. A checkpoint can close when this coverage and all required repairs and checks are complete. Preserve the original loop's incomplete status or unreviewed-fix limit in the report; this recovery does not establish a clean loop result. If required coverage cannot be established, keep the checkpoint incomplete and apply the stop rules below.

Perform one cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs. Preserve required behavior, explicit compatibility, and unrelated work. With read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

Discover the project's full testing and quality gates from repository instructions (including AGENTS.md), CI workflows, scripts, and contributor/testing documentation. Run every required gate during each final-pass invocation on the final relevant state. Targeted tests, smoke tests, or document validators do not replace full suites or quality checks. Small changes, long runtime, and earlier passing runs are not reasons to reduce coverage. Add checks proportional to risk where required gates leave a gap.

Only explicit user instructions, documentation-only work, or checks that incur actual external charges permit skips. For documentation-only work, run required document or skill validators and skip unrelated application suites; this exception does not cover code, configuration, or test changes anywhere in the checkpoint. Skip paid checks, such as smoke tests that call billed APIs, unless already authorized; ordinary runtime and local compute are not paid-check exceptions. Run all remaining free coverage. Preserve authorization boundaries for external effects; missing access, services, or authority blocks a required check rather than exempting it. Try reasonable authorized alternatives and report unresolved blockers.

Fix authorized in-scope failures and verify repairs. Reuse passing results only from this final-pass invocation when their relevant code, configuration, dependencies, and environment remain unchanged; otherwise rerun the affected gates. A failed or blocked required gate keeps the checkpoint incomplete. Record each required gate's command, result (passed, failed, skipped, or blocked), and the reason for any skip or blocker.

After repairs, inspect the affected result and verify it again as needed until no actionable task-relevant issue remains and required checks pass. A phase checkpoint does not end execution: return to the executor to continue the remaining plan. Stop with work remaining only for user direction, an explicit authorized session boundary, or a concrete blocker requiring missing authority, input, or external change; first try reasonable authorized alternatives and complete independent work. Report blocked work as incomplete, not a completed result with residuals.

Lead with changes or findings, then report check results, explicit skips, and blockers. Use short, plain prose without stock headings or repeated summaries. Do not claim implementation verification from document validators. Save a user report only if requested; check logs follow the temporary-file rules.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
