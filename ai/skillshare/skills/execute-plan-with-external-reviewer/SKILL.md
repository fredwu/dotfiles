---
name: execute-plan-with-external-reviewer
description: Execute a full plan with final-pass after every phase, then one selected external review loop over the entire implementation and a final final-pass. Requires an explicit codex, claude, or grok reviewer argument.
---

# Execute Plan with External Reviewer

## Select the reviewer before edits

Usage: `$execute-plan-with-external-reviewer <reviewer> [plan]`.

Require exactly one reviewer argument, with one of these exact lowercase values:

- `codex` selects [codex-review-loop](../codex-review-loop/SKILL.md).
- `claude` selects [claude-review-loop](../claude-review-loop/SKILL.md).
- `grok` selects [grok-review-loop](../grok-review-loop/SKILL.md).

If the argument is missing, invalid, or ambiguous, resolve it with the user before any edits. Never infer a reviewer from the current provider, default it, or silently substitute another. Confirm that the selected skill is available without loading its instructions yet; a missing dependency blocks implementation until resolved. The plan is optional here only because the base executor can resolve a complete same-session plan.

## Inherit execution, replace checkpoint scheduling

Read and apply [execute-plan](../execute-plan/SKILL.md), including its linked requirements and [subagent role policy](../execute-plan/references/subagent-reasoning.md). Inherit its full-completion obligation, authority and scope limits, independent implementation investigation, delegation and reconciliation, cleanup, verification, stop rules, reporting, and temporary-file handling.

This skill replaces the base executor's entire **Completion and review checkpoints** section with the sequence below. This sequence also governs checkpoint links reached through `final-pass` or the selected review loop. Do not run a separate `code-review-loop`, per-phase external loops, or extra review invocations through those links. Review mechanics belong only to the selected external loop; do not copy them here or load other provider skills.

## Complete all phases, then review once

1. Implement each coherent phase and verify its acceptance criteria and integration with completed work. Define phases by coherent deliverables and acceptance checks, not arbitrary batches. Resolve all discovered task-relevant issues within scope; reject unsupported claims with evidence. Run [final-pass](../final-pass/SKILL.md) after **every phase**, including the last, before closing the phase or starting dependent work. Use its standalone check mode: review-specific recovery clauses apply only after the selected loop returns. Keep external review explicitly **pending**; phase verification does not establish review completion. Perform its cleanup and required gates each time. Continue phases back to back without a per-phase review loop or routine user handoff.
2. After all phases and their final passes are complete, load and invoke **only the selected external review-loop skill, exactly once**, over the **entire integrated implementation**, including all phases and task-attributable repairs and cleanup. Use the original requirements and acceptance criteria, full task surface, and exclusions. One invocation can contain multiple bounded rounds under that skill's contract; it is not one review prompt. Follow its runtime, authority, context, round limits, failure recovery, and handoff rules without substitution or nested loops.
3. After that invocation returns, run `final-pass` **again**, even if the last phase already passed. Reconcile the loop's findings, residuals, failed checks, and missing coverage with the complete implementation. Finish authorized repairs and verification under `final-pass`'s post-loop recovery rules. The cap ends that review invocation, not the execution obligation. Never restart the loop or add disguised rounds to evade its cap. Preserve an incomplete or capped loop status and identify repairs verified without fresh external review; direct inspection cannot create a clean external result.

For a single-phase plan, the order is still implementation, phase `final-pass`, selected external loop, then final `final-pass`. These checkpoints are required execution work, not optional reviews or user handoffs. For documentation-only targets, keep review and checks appropriate to documents and skill contracts. A blocked required phase check prevents advancing dependent work; finish independent authorized work under the inherited stop rules.

Close execution only when every requirement has acceptance evidence or justified supersession, task-relevant issues are resolved, required checks pass, the selected loop has returned, and final-pass has established any missing coverage with evidence. Do not relabel actionable work as a residual risk, known failure, optional follow-up, or future phase to claim completion. Report the selected reviewer, actual review coverage and terminal status, exact checks, and any concrete blockers or unreviewed repairs. Deferred review is never completed review. Preserve the base executor's full-completion and blocker rules through handoffs and compaction.
