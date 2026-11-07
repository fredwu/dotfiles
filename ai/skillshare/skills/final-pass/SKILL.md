---
name: final-pass
description: Close a completed phase or execution; resolve omissions and residual issues, then establish passing evidence for the project's full testing and quality checks.
metadata:
  origin: custom
---

# Final Pass

Close a checkpoint: check the full change set against the original request and later updates, resolve what is missing, clean up, and establish passing evidence for the project's full checks.

## Checkpoint type

- **Phase checkpoint**, during [plan execution](../execute-plan/SKILL.md#completion-and-review-checkpoints): finish phase acceptance, integration with completed phases, cleanup, and required checks, then return to the executor. The selected reviews stay pending and do not block this checkpoint.
- **Closing checkpoint**: after the selected review sequence returns, or after the active loop ends at its cap or a concrete blocker. Do everything below, including post-review recovery.
- **Standalone**: a final check outside plan execution. Do everything below except post-review recovery, unless a review loop has ended.

## Resolve issues

Review code, documentation, tests, and configuration in the checkpoint scope, including integration with completed phases. Resolve task-relevant omissions and inconsistencies within scope. Reconcile execution and worker residuals, review findings, failed checks, and verification gaps. Fix every authorized task-relevant issue, including pre-existing failures found during the task, and reject unsupported findings with evidence. A review cap or a final read-only review round does not defer these repairs.

## Post-review recovery

While a review loop is active and has rounds left, it owns fresh review. Do not use this recovery to replace a required review; failed attempts follow the loop's [failure recovery](../code-review-loop/SKILL.md#recover-failed-attempts).

When the loop has ended at its cap or a concrete blocker, list the missing coverage and the repairs no reviewer has seen, against the original target, acceptance criteria, and review lenses. Inspect that coverage directly and record the evidence in context. Do not retry the failed call, restart the loop, or add disguised review rounds. The checkpoint can close when this coverage and all required repairs and checks are complete. Report the loop's actual capped or incomplete status and the unreviewed repairs; this recovery does not make a clean loop result. If you cannot establish the coverage, keep the checkpoint incomplete.

## Clean up

Do one cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and the related tests, configuration, and documentation. Keep required behavior, explicit compatibility, and unrelated work. With read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

## Run the full checks

Find the project's full test and quality gates in repository instructions (including AGENTS.md), CI workflows, scripts, and contributor or testing documentation. In each invocation, establish passing evidence for every required gate on the final state, by running it or by reusing valid evidence under [Check evidence and reuse](references/check-evidence.md). Targeted tests, smoke tests, and document validators do not replace full suites or quality checks. Small changes and long run times do not reduce coverage. Add checks in proportion to risk where the required gates leave a gap.

Only these permit a skip:

- An explicit user instruction.
- Documentation-only work: run the required document or skill validators and skip unrelated application suites. This does not apply when the checkpoint changes code, configuration, or tests anywhere.
- Checks that incur real external charges, such as smoke tests that call billed APIs, unless already authorized. Local compute and run time are not charges.

Missing access, services, or authority blocks a required check; it does not exempt it. Try reasonable authorized alternatives first, and keep authorization boundaries for external effects.

Fix authorized in-scope failures and verify the repairs. After each relevant change, reassess the evidence and rerun invalidated gates. Repeat until no actionable task-relevant issue remains and required checks pass. A failed or blocked required gate keeps the checkpoint incomplete. For each required gate, record the command, the result (passed, failed, skipped, or blocked), whether a pass was executed or reused (with its origin), and the reason for any skip or blocker.

## Finish

A phase checkpoint returns to the executor; it does not end execution. Stop with work remaining only on user direction, an explicit authorized session boundary, or a concrete blocker that needs missing authority, input, or external change. First try alternatives and finish independent work. Report blocked work as incomplete, not as a completed result with residuals.

Lead with changes or findings, then executed and reused check results, skips, and blockers, in short plain prose without stock headings or repeated summaries. Do not claim implementation verification from document validators, or fresh review from reused check evidence. Save a report only on request.

## Temporary files

Keep scratch notes in context. Create a temporary file only when an agent needs it; track it, delete it after use (also after failure or abandonment), and verify the deletion. If a file must stay for continuing agent work, name its cleanup owner and report its path. Never delete requested deliverables (including `.local/` plans), pre-existing files, unrelated work, or shared directories.
