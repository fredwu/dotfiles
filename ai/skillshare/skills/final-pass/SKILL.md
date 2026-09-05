---
name: final-pass
description: Review completed changes for material omissions, fix authorized issues, and verify the final result. Run the full canonical quality suite for non-documentation changes and applicable document validators for documentation-only changes.
---

# Final Pass

Review the complete change set against the original request and later updates. Resolve material omissions and inconsistencies across code, documentation, tests, and configuration within the authorized scope.

Perform one deliberate cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs when safe. Preserve required behavior, explicit compatibility, and unrelated work. Under read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

- **Documentation-only:** run applicable document or skill validators; skip unrelated application quality/test suites. Do not claim implementation verification.
- **Non-documentation changes:** discover the full canonical gate from repository instructions, contributor docs, task runners, manifests, and CI. Run all included checks, including format, lint, static analysis, types, security, build, and tests where required. Targeted checks do not replace this gate. Fix authorized in-scope failures and rerun after changes.

Reuse passing results only when they cover the final relevant code state and environment; a review without changes does not require duplicate runs. Respect authorization boundaries for checks with external side effects or cost.

Report exact commands/results and any failed, blocked, unavailable, or unverified checks. State which suites were intentionally skipped and why.
