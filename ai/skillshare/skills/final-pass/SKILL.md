---
name: final-pass
description: Review completed changes for material omissions, fix authorized issues, and verify the final result with applicable checks.
---

# Final Pass

Review the full change set against the original request and later updates. Resolve material omissions and inconsistencies across code, documentation, tests, and configuration within scope.

Perform one cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs. Preserve required behavior, explicit compatibility, and unrelated work. With read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

Discover required gates from repository instructions and CI. Run applicable checks on the final relevant state, with additional checks proportional to risk. For documentation-only changes, use document or skill validators and skip unrelated application suites. Fix authorized in-scope failures and verify repairs; reuse passing results for unchanged relevant code and environment. Respect authorization boundaries for checks with external effects or cost.

Lead with changes or findings, then check results and material verification gaps. Use short, plain prose without stock headings or repeated summaries. Do not claim implementation verification from document validators. Save a user report only if requested; check logs follow the temporary-file rules.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
