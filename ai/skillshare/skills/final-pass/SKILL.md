---
name: final-pass
description: Close a completed phase or execution after review; resolve omissions and residual issues, then verify the result with applicable checks.
---

# Final Pass

Use after `code-review-loop` at each required [execution checkpoint](../execute-plan/SKILL.md#completion-and-review-checkpoints), or for a standalone final check. Review the full checkpoint change set against the original request and later updates, including integration with completed phases. Resolve task-relevant omissions and inconsistencies across code, documentation, tests, and configuration within scope.

Reconcile execution and worker residuals, review findings, failed checks, and verification gaps. Fix all authorized task-relevant issues, including pre-existing failures discovered during the task. A review cap or terminal read-only audit does not defer these repairs: perform them here without restarting the loop. Reject unsupported findings with evidence.

For incomplete review output or repairs not reviewed again, identify the missing coverage against the original target, acceptance criteria, and review lenses. Inspect that coverage directly and record the evidence in task context; do not retry the review invocation or add disguised review rounds. A checkpoint can close when this coverage and all required repairs and checks are complete. Preserve the original loop's incomplete status or unreviewed-fix limit in the report; this recovery does not establish a clean loop result. If required coverage cannot be established, keep the checkpoint incomplete and apply the stop rules below.

Perform one cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs. Preserve required behavior, explicit compatibility, and unrelated work. With read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

Discover required gates from repository instructions and CI. Run applicable checks on the final relevant state, with additional checks proportional to risk. For documentation-only changes, use document or skill validators and skip unrelated application suites. Fix authorized in-scope failures and verify repairs; reuse passing results for unchanged relevant code and environment. Respect authorization boundaries for checks with external effects or cost.

After repairs, inspect the affected result and verify it again as needed until no actionable task-relevant issue remains and required checks pass. A phase checkpoint does not end execution: return to the executor to continue the remaining plan. Stop with work remaining only for user direction, an explicit authorized session boundary, or a concrete blocker requiring missing authority, input, or external change; first try reasonable authorized alternatives and complete independent work. Report blocked work as incomplete, not a completed result with residuals.

Lead with changes or findings, then check results and material verification gaps. Use short, plain prose without stock headings or repeated summaries. Do not claim implementation verification from document validators. Save a user report only if requested; check logs follow the temporary-file rules.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
