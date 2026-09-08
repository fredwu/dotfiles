---
name: final-pass
description: Review completed changes for material omissions, fix authorized issues, and verify the final result with applicable checks.
---

# Final Pass

Review the full change set against the original request and later updates. Resolve material omissions and inconsistencies across code, documentation, tests, and configuration within scope.

Perform one cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs. Preserve required behavior, explicit compatibility, and unrelated work. With read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

Discover required gates from repository instructions and CI. Run applicable checks on the final relevant state, with additional checks proportional to risk. For documentation-only changes, use document or skill validators and skip unrelated application suites. Fix authorized in-scope failures and verify repairs; reuse passing results for unchanged relevant code and environment. Respect authorization boundaries for checks with external effects or cost.

Briefly report changes, check results, and failed, blocked, skipped, or unverified checks that affect confidence. Do not claim implementation verification from document validators. Give results in chat; save reports for the user only when explicitly requested. Treat agent check logs as temporary files.

## Temporary files

Prefer context or in-memory tracking. Create temporary or transit files only for a concrete agent need, such as tool input, verification, or an active handoff; never create them only for user presentation. Track exact task-owned paths and remove them once their consumers finish, on success, failure, or abandonment; verify removal before returning. Retain scratch only for active agent continuation, with an explicit cleanup owner and removal point. Report cleanup failures or active handoff paths. Preserve requested durable deliverables, including saved plans in `.local/`, and pre-existing or unrelated files; never clean a shared directory wholesale.
