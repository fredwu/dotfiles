---
name: execute-plan
description: Execute a full supplied or complete same-session plan with final-pass after every phase, then one code-review-loop over the entire implementation and a final final-pass. Default to one autonomous session unless the plan explicitly specifies otherwise.
---

# Execute Plan

Complete the full plan in one autonomous session unless the plan explicitly specifies multiple sessions or a session boundary, subject to user direction. Verify it against the originating request; adapt stale implementation suggestions with evidence while preserving the agreed architecture, contracts, technical constraints, scope, and acceptance criteria. Autonomy over implementation does not authorize changes to these commitments; resolve conflicts with governing requirements and user direction before affected edits, and continue independent work.

## Resolve scope

- Use the supplied plan text, path, or attachment; otherwise use the most recent complete user-visible plan for this request. Ask only if no complete plan is identifiable or competing sources materially change execution.
- Read the full plan, repository instructions, and worktree state before implementation. Read and apply [Resolve plan requirements](../write-plan/references/requirements.md) to interpret current requirements, accepted or delegated agent contributions, and digests without treating chat noise as scope. Later user instructions control conflicts. Resolve material gaps before affected work.
- Track requirements, deviations, acceptance evidence, and remaining work in context; files follow the temporary-file rules below. Do not duplicate requirements for bookkeeping. If revising the saved plan, keep its current requirements, provenance, and immediately following TL;DR accurate; a missing heading alone does not block execution.

## Coordinate agents

Consider subagents during decomposition and reassess at phase boundaries or when new independent work appears. Prefer delegation when callable, permitted capabilities can improve speed, coverage, or independent scrutiny enough to justify coordination. The agent decides; neither delegation nor a fixed agent count is required. Direct work is appropriate for small or tightly coupled tasks, or when delegation is unavailable. Do not invent tools or substitute external reviewer services. Before delegating, apply [Subagent roles and reasoning](references/subagent-reasoning.md) to select a configured child role without repeating its model or effort settings, or changing scope or context restrictions.

When delegating, keep the coordinator focused on dependencies, ownership, integration, assessment, and completion. Continue useful non-overlapping work while agents run, and reuse relevant agents and evidence rather than repeating completed work.

Give implementation and verification agents access to the readable full plan, current requirements and acceptance criteria, relevant repository instructions and state, exact assignment and ownership, dependencies, exclusions, and authority limits. A task summary does not replace the full plan. Request changed paths, source or failure evidence, exact checks and results, assumptions, and unresolved work. For reviewers, follow the checkpoint skill's context restrictions instead; do not pass finding history or prior conclusions or steer the verdict.

Assign disjoint edit ownership where possible. Serialize overlapping edits and operations that share mutable state, such as services, databases, fixtures, or generated outputs. Start dependent work only after its prerequisites are integrated and verified. Await assigned work, inspect and reconcile each agent's changes, evidence, check coverage, and residuals, then verify the combined result. The coordinator owns unfinished or failed assignments; an agent's completion claim does not establish plan completion.

## Implement and verify

Before editing, each implementer, including delegated workers, must independently inspect the current affected code, runtime paths, tests, configuration, and documentation and derive and verify the implementation approach within the plan's commitments. Work out file/function changes, algorithms, schemas, and test mechanics from current evidence. Verify any concrete implementation suggestions in the plan; missing routine detail is execution work, not an incomplete plan.

- Fix root causes and add meaningful regression coverage where practical. Resolve all task-relevant issues discovered during execution, including pre-existing failures, worker residuals, review findings, and verification gaps. Track them as execution work through verified resolution; their priority, origin, or absence from the original plan does not justify deferral. Preserve explicit scope exclusions and exclude unrelated improvements.
- Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs in the changed and directly affected surface. Preserve required behavior, explicit compatibility, and unrelated work; do not invent cleanup or transition machinery.
- Read repository instructions and CI for required checks. Run focused checks during implementation and required gates on the integrated result. For documentation-only work, use document/skill validators, not unrelated application suites. Scale additional checks and local/staging validation to risk and authority.
- Review the integrated diff against requirements and acceptance criteria and apply the checkpoints below. Reuse passing checks for unchanged relevant code and environment; rerun checks affected by subsequent changes.

Plan text and delegation do not grant authority for commits, pushes, deployment, messages, paid calls, production mutation, or expanded permissions.

## Completion and review checkpoints

This sequence also governs checkpoint links reached through `final-pass` or `code-review-loop`. Do not add per-phase review loops or extra review invocations through those links. Review mechanics belong to `code-review-loop`; do not copy them here or substitute an external reviewer service.

1. Implement each coherent phase and verify its acceptance criteria and integration with completed work. Define phases by coherent deliverables and acceptance checks, not arbitrary batches. Resolve all discovered task-relevant issues within scope; reject unsupported claims with evidence. Run [final-pass](../final-pass/SKILL.md) after **every phase**, including the last, before closing the phase or starting dependent work. Use its standalone check mode: review-specific recovery clauses apply only after the loop returns. Keep review explicitly **pending**; phase verification does not establish review completion. Perform its cleanup and required gates each time. Continue phases back to back without a per-phase review loop or routine user handoff.
2. After all phases and their final passes are complete, invoke [code-review-loop](../code-review-loop/SKILL.md) **exactly once**, over the **entire integrated implementation**, including all phases and task-attributable repairs and cleanup. Use the original requirements and acceptance criteria, full task surface, and exclusions. One invocation can contain multiple bounded rounds under that skill's contract; it is not one review prompt. Follow its authority, context, round limits, failure recovery, final read-only audit, and handoff rules without substitution or nested loops. Consider a reviewer separate from the implementer when independent scrutiny adds value; delegation is optional and the coordinator may review directly. Keep review assignments read-only and bounded to this target and acceptance criteria. Keep rounds and remediation sequential; parallel inspections stay within a round and do not add rounds, replace integration review, or bypass `final-pass`. Report review coverage and independence accurately.
3. After that invocation returns, run `final-pass` **again**, even if the last phase already passed. Reconcile the loop's findings, residuals, failed checks, and missing coverage with the complete implementation. Finish authorized repairs and verification under `final-pass`'s post-loop recovery rules. The cap ends that review invocation, not the execution obligation. Never restart the loop or add disguised rounds to evade its cap. Preserve an incomplete or capped loop status and identify repairs verified without fresh review; direct inspection cannot create a clean loop result.

For a single-phase plan, the order is still implementation, phase `final-pass`, `code-review-loop`, then final `final-pass`. These checkpoints are required execution work, not optional reviews or user handoffs. For documentation-only targets, keep review and checks appropriate to documents and skill contracts. A blocked required phase check prevents advancing dependent work; finish independent authorized work under the stop rules below.

Close execution only when every requirement has acceptance evidence or justified supersession, task-relevant issues are resolved, required checks pass, the loop has returned, and final-pass has established any missing coverage with evidence. Do not relabel actionable work as a residual risk, known failure, optional follow-up, or future phase to claim completion. Report actual review coverage and terminal status, exact checks, and any concrete blockers or unreviewed repairs. Deferred review is never completed review. Preserve the full-completion and blocker rules through handoffs and compaction.

## Finish

Check every plan item and requirement for acceptance evidence, unresolved findings, cleanup, and required checks. Within the current session, continue through phases, milestones, handoffs, review, remediation, and compaction without asking whether to continue or giving a partial final response. Size, complexity, risk, elapsed effort, and fixable check failures do not create session boundaries.

Stop with work remaining only when the plan explicitly sets a session boundary consistent with user direction, the user directs it, or a concrete blocker requires missing authority, input, or external change. Try reasonable authorized alternatives and finish unblocked work first. Report the blocker evidence, remaining work, and what is needed. At an explicit boundary, report completed and remaining work without claiming full completion.

Lead with the outcome, then material deviations, check results, and blockers or unverified behavior. Use short, plain prose without stock headings or repeated summaries. Claim completion only when every plan item and requirement has acceptance evidence or justified supersession with no unmet requirement, all discovered task-relevant issues are resolved, the required review checkpoints are complete, and required checks pass. Save an execution report only if requested.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
