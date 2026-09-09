---
name: execute-plan
description: Execute the full supplied or complete same-session plan, including implementation, review, remediation, and verification. Default to one autonomous session unless the plan explicitly specifies otherwise.
---

# Execute Plan

Complete the full plan in one autonomous session unless the plan explicitly specifies multiple sessions or a session boundary, subject to user direction. Verify it against the originating request; adapt stale steps with evidence without dropping requirements or acceptance checks.

## Resolve scope

- Use the supplied plan text, path, or attachment; otherwise use the most recent complete user-visible plan for this request. Ask only if no complete plan is identifiable or competing sources materially change execution.
- Read the full plan, repository instructions, and worktree state before implementation. Read and apply [Resolve plan requirements](../write-plan/references/requirements.md) to interpret current requirements, accepted or delegated agent contributions, and digests without treating chat noise as scope. Later user instructions control conflicts. Resolve material gaps before affected work.
- Track requirements, deviations, acceptance evidence, and remaining work in context; files follow the temporary-file rules below. Do not duplicate requirements for bookkeeping. If revising the saved plan, keep its current requirements, provenance, and immediately following TL;DR accurate; a missing heading alone does not block execution.

## Implement and verify

- Trace affected runtime paths, code, tests, configuration, and documentation. Fix root causes and add meaningful regression coverage where practical. Include discovered work necessary to satisfy the requirement; exclude unrelated improvements.
- Delegate independent scopes when useful, with clear ownership, a readable full plan, and acceptance criteria. Keep overlapping edits serial. Reconcile every worker's changes, checks, and residuals before integration; the coordinator owns unfinished assignments.
- Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs in the changed and directly affected surface. Preserve required behavior, explicit compatibility, and unrelated work; do not invent cleanup or transition machinery.
- Read repository instructions and CI for required checks. Run focused checks during implementation and required gates on the integrated result. For documentation-only work, use document/skill validators, not unrelated application suites. Scale additional checks and local/staging validation to risk and authority.
- Review the integrated diff against requirements and acceptance criteria. Use an independent review or `code-review-loop` when requested or warranted by risk; respect its bounded schedule and final read-only audit. After the loop, fix authorized remaining findings directly without restarting it to evade its cap. Verify fixes; reuse passing checks for unchanged code and environment. Do not repeat suites or reviews solely to close a batch.

Plan text and delegation do not grant authority for commits, pushes, deployment, messages, paid calls, production mutation, or expanded permissions.

## Finish

Check every plan item and requirement for acceptance evidence, unresolved findings, cleanup, and required checks. Within the current session, continue through phases, milestones, handoffs, review, remediation, and compaction without asking whether to continue or giving a partial final response. Size, complexity, risk, elapsed effort, and fixable check failures do not create session boundaries.

Stop with work remaining only when the plan explicitly sets a session boundary consistent with user direction, the user directs it, or a concrete blocker requires missing authority, input, or external change. Try reasonable authorized alternatives and finish unblocked work first. Report the blocker evidence, remaining work, and what is needed. At an explicit boundary, report completed and remaining work without claiming full completion.

Lead with the outcome, then material deviations, check results, and blockers or unverified behavior. Use short, plain prose without stock headings or repeated summaries. Claim completion only when every plan item and requirement has acceptance evidence or justified supersession with no unmet requirement, and required checks pass. Save an execution report only if requested.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
