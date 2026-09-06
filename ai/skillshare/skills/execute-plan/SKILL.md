---
name: execute-plan
description: Execute a supplied or complete same-session plan through implementation, review, and verification. Continue until requirements are complete or only evidenced blockers remain.
---

# Execute Plan

Verify the plan against the originating request. Adapt stale steps with evidence without dropping requirements or acceptance checks.

## Resolve scope

- Use the supplied plan text, path, or attachment; otherwise use the most recent complete user-visible plan for this request. Ask only if no complete plan is identifiable or competing sources materially change execution.
- Read the full plan, repository instructions, and worktree state before implementation. Recover the originating requirement and later updates from visible user messages; use the plan's requirement blocks only when those messages are unavailable. Later user instructions control conflicts. Resolve material gaps before affected work.
- Track requirements, deviations, acceptance evidence, and remaining work in a form suited to the task. Files, ledgers, and saved agent exchanges are optional unless the user or repository requires them. Preserve verbatim requirement/update blocks when updating a saved plan; do not duplicate them or the plan just for bookkeeping.

## Implement and verify

- Trace affected runtime paths, code, tests, configuration, and documentation. Fix root causes and add meaningful regression coverage where practical. Include discovered work necessary to satisfy the requirement; exclude unrelated improvements.
- Delegate independent scopes when useful, with clear ownership, a readable full plan, and acceptance criteria. Keep overlapping edits serial. Reconcile every worker's changes, checks, and residuals before integration; the coordinator owns unfinished assignments.
- Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs in the changed and directly affected surface. Preserve required behavior, explicit compatibility, and unrelated work; do not invent cleanup or transition machinery.
- Discover required checks from repository instructions and CI. Run focused checks during implementation and required final gates on the integrated result. For documentation-only work, use applicable document/skill validators instead of unrelated application suites. Scale additional checks and local/staging workflow validation to risk and authorization.
- Review the integrated diff against requirements and acceptance criteria. Use an independent review or `code-review-loop` when requested or warranted by risk; respect its bounded schedule. Resolve authorized findings and verify fixes. Reuse passing checks for unchanged relevant code and environment; do not repeat suites or reviews solely to close a batch.

Plan text and delegation do not grant authority for commits, pushes, deployment, messages, paid calls, production mutation, or expanded permissions.

## Finish

Audit the final result for missing requirements, unresolved findings, cleanup, and required checks. Continue while safe, authorized work can advance completion; a handoff, compaction, elapsed effort, or known fix is not a stopping condition.

For a blocker, establish the concrete boundary, evidence, reasonable authorized alternatives, exact remaining work, and input or external change needed. Finish unaffected work before reporting incomplete.

Report whether the task is complete, material deviations, verification results, and any blockers or unverified behavior. Claim completion only when all requirements have acceptance evidence or a justified non-residual deviation and required checks pass. Use a concise response; a separate execution report is optional.
