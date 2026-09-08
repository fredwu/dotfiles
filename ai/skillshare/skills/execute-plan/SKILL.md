---
name: execute-plan
description: Execute the full supplied or complete same-session plan, including implementation, review, remediation, and verification. Default to one autonomous session unless the plan explicitly specifies otherwise.
---

# Execute Plan

Complete the full plan in one autonomous session unless the plan explicitly specifies multiple sessions or a session boundary, subject to user direction. Verify it against the originating request; adapt stale steps with evidence without dropping requirements or acceptance checks.

## Resolve scope

- Use the supplied plan text, path, or attachment; otherwise use the most recent complete user-visible plan for this request. Ask only if no complete plan is identifiable or competing sources materially change execution.
- Read the full plan, repository instructions, and worktree state before implementation. Recover the originating requirement and later updates from visible user messages; use the plan's requirement blocks only when those messages are unavailable. Later user instructions control conflicts. Resolve material gaps before affected work.
- Track requirements, deviations, acceptance evidence, and remaining work in a form suited to the task. Files, ledgers, and saved agent exchanges are optional unless the user or repository requires them. Preserve verbatim requirement/update blocks when updating a saved plan; do not duplicate them or the plan just for bookkeeping.

## Implement and verify

- Trace affected runtime paths, code, tests, configuration, and documentation. Fix root causes and add meaningful regression coverage where practical. Include discovered work necessary to satisfy the requirement; exclude unrelated improvements.
- Delegate independent scopes when useful, with clear ownership, a readable full plan, and acceptance criteria. Keep overlapping edits serial. Reconcile every worker's changes, checks, and residuals before integration; the coordinator owns unfinished assignments.
- Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs in the changed and directly affected surface. Preserve required behavior, explicit compatibility, and unrelated work; do not invent cleanup or transition machinery.
- Discover required checks from repository instructions and CI. Run focused checks during implementation and required final gates on the integrated result. For documentation-only work, use applicable document/skill validators instead of unrelated application suites. Scale additional checks and local/staging workflow validation to risk and authorization.
- Review the integrated diff against requirements and acceptance criteria. Use an independent review or `code-review-loop` when requested or warranted by risk; respect its bounded schedule and final read-only audit. After the loop returns, own and fix authorized residual findings directly; do not restart it to evade its cap. Verify fixes and reuse passing checks for unchanged relevant code and environment; do not repeat suites or reviews solely to close a batch.

Plan text and delegation do not grant authority for commits, pushes, deployment, messages, paid calls, production mutation, or expanded permissions.

## Finish

Audit every plan item and requirement for completion, acceptance evidence, unresolved findings, cleanup, and required checks. Unless the plan explicitly sets a session boundary or the user directs otherwise, continue through all phases, milestones, checkpoints, worker handoffs, review, remediation, and compaction without asking whether to continue or issuing a partial final response at those boundaries. Task size, complexity, risk, elapsed effort, and fixable check failures do not imply session breaks or routine confirmation handoffs.

Stop with work remaining only at an explicit plan session boundary consistent with user direction, when the user directs it, or when a concrete blocker requires missing authority, input, or external change. For a blocker, establish its evidence, reasonable authorized alternatives, exact remaining work, and what is needed; finish all unblocked work within the authorized session before reporting incomplete. At an explicit session boundary, report completed and remaining work without claiming the full plan is complete.

Report whether the task is complete, material deviations, verification results, and any blockers or unverified behavior. Claim completion only when every plan item and requirement has acceptance evidence or justified supersession that leaves no unmet requirement, and required checks pass. Use a concise response; a separate execution report is optional.
