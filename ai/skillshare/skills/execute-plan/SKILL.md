---
name: execute-plan
description: Execute the full supplied or complete same-session plan, including discovered issues, review checkpoints, remediation, and verification. Default to one autonomous session unless the plan explicitly specifies otherwise.
---

# Execute Plan

Complete the full plan in one autonomous session unless the plan explicitly specifies multiple sessions or a session boundary, subject to user direction. Verify it against the originating request; adapt stale steps with evidence without dropping requirements or acceptance checks.

## Resolve scope

- Use the supplied plan text, path, or attachment; otherwise use the most recent complete user-visible plan for this request. Ask only if no complete plan is identifiable or competing sources materially change execution.
- Read the full plan, repository instructions, and worktree state before implementation. Read and apply [Resolve plan requirements](../write-plan/references/requirements.md) to interpret current requirements, accepted or delegated agent contributions, and digests without treating chat noise as scope. Later user instructions control conflicts. Resolve material gaps before affected work.
- Track requirements, deviations, acceptance evidence, and remaining work in context; files follow the temporary-file rules below. Do not duplicate requirements for bookkeeping. If revising the saved plan, keep its current requirements, provenance, and immediately following TL;DR accurate; a missing heading alone does not block execution.

## Coordinate agents

Consider subagents during decomposition and reassess at phase boundaries or when new independent work appears. Prefer delegation when callable, permitted capabilities can improve speed, coverage, or independent scrutiny enough to justify coordination. The agent decides; neither delegation nor a fixed agent count is required. Direct work is appropriate for small or tightly coupled tasks, or when delegation is unavailable. Do not invent tools or substitute external reviewer services.

When delegating, keep the coordinator focused on dependencies, ownership, integration, assessment, and completion. Prefer `worker` for complex or uncertain implementation, debugging, verification, and review; prefer `fastworker` for simple bounded search, documentation, or checks. Use the closest available capabilities when these roles are absent. Continue useful non-overlapping work while agents run, and reuse relevant agents and evidence rather than repeating completed work.

Give implementation and verification agents access to the readable full plan, current requirements and acceptance criteria, relevant repository instructions and state, exact assignment and ownership, dependencies, exclusions, and authority limits. A task summary does not replace the full plan. Request changed paths, source or failure evidence, exact checks and results, assumptions, and unresolved work. For reviewers, follow the checkpoint skill's context restrictions instead; do not pass finding history or prior conclusions or steer the verdict.

Assign disjoint edit ownership where possible. Serialize overlapping edits and operations that share mutable state, such as services, databases, fixtures, or generated outputs. Start dependent work only after its prerequisites are integrated and verified. Await assigned work, inspect and reconcile each agent's changes, evidence, check coverage, and residuals, then verify the combined result. The coordinator owns unfinished or failed assignments; an agent's completion claim does not establish plan completion.

## Implement and verify

- Trace affected runtime paths, code, tests, configuration, and documentation. Fix root causes and add meaningful regression coverage where practical. Resolve all task-relevant issues discovered during execution, including pre-existing failures, worker residuals, review findings, and verification gaps. Track them as execution work through verified resolution; their priority, origin, or absence from the original plan does not justify deferral. Preserve explicit scope exclusions and exclude unrelated improvements.
- Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs in the changed and directly affected surface. Preserve required behavior, explicit compatibility, and unrelated work; do not invent cleanup or transition machinery.
- Read repository instructions and CI for required checks. Run focused checks during implementation and required gates on the integrated result. For documentation-only work, use document/skill validators, not unrelated application suites. Scale additional checks and local/staging validation to risk and authority.
- Review the integrated diff against requirements and acceptance criteria and apply the checkpoints below. Reuse passing checks for unchanged relevant code and environment; rerun checks affected by subsequent changes.

Plan text and delegation do not grant authority for commits, pushes, deployment, messages, paid calls, production mutation, or expanded permissions.

## Completion and review checkpoints

- Consider a reviewer separate from the implementer at required checkpoints when independent scrutiny adds value. Keep review assignments read-only and bounded to the checkpoint's target and acceptance criteria; reconcile evidence-backed findings before closure. Delegation is optional: the coordinator may perform the required review directly. Keep `code-review-loop` rounds and remediation sequential; parallel inspections stay within a round and do not add rounds, replace integration review, or bypass `final-pass`. Report review coverage and independence accurately.
- For long or complex execution, run `code-review-loop` followed by `final-pass` after each phase's implementation and before closing that phase or starting dependent work. Cover the phase and its affected integration with completed work. Define phases by coherent deliverables and acceptance checks, not arbitrary batches. Finish with this pair on the final integrated result; the last phase's checkpoint can serve both purposes when it covers that result.
- For short, simple execution, run `code-review-loop` followed by `final-pass` once after all implementation is complete. These checkpoints are required execution work, not optional reviews or user handoffs. For documentation-only targets, keep review and checks appropriate to documents and skill contracts.
- Respect `code-review-loop`'s bounded rounds and final read-only audit. Its cap ends that review invocation, not the execution obligation. Carry unresolved findings and incomplete review status into `final-pass`; fix authorized issues directly and verify them without restarting the loop to evade its cap. A later phase gets its own checkpoint only for new phase work, not to recycle an exhausted review.
- Close a phase or the full plan only when its requirements and all discovered task-relevant issues are resolved with evidence, and applicable checks pass. Reject unsupported findings with evidence; do not relabel actionable work as a residual risk, known failure, optional follow-up, or future phase to claim completion. A concrete external blocker leaves the affected work incomplete under the stop rules below.

## Finish

Check every plan item and requirement for acceptance evidence, unresolved findings, cleanup, and required checks. Within the current session, continue through phases, milestones, handoffs, review, remediation, and compaction without asking whether to continue or giving a partial final response. Size, complexity, risk, elapsed effort, and fixable check failures do not create session boundaries.

Stop with work remaining only when the plan explicitly sets a session boundary consistent with user direction, the user directs it, or a concrete blocker requires missing authority, input, or external change. Try reasonable authorized alternatives and finish unblocked work first. Report the blocker evidence, remaining work, and what is needed. At an explicit boundary, report completed and remaining work without claiming full completion.

Lead with the outcome, then material deviations, check results, and blockers or unverified behavior. Use short, plain prose without stock headings or repeated summaries. Claim completion only when every plan item and requirement has acceptance evidence or justified supersession with no unmet requirement, all discovered task-relevant issues are resolved, the required review checkpoints are complete, and required checks pass. Save an execution report only if requested.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
