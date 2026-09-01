---
name: final-pass
description: Perform one deliberate final pass over completed changes, resolve material omissions or inconsistencies, and run the full canonical quality and test suite for any change set containing non-documentation files. Skip those checks for documentation-only changes. Use after implementation when code, documentation, tests, and configuration must remain coherent.
---

# Final Pass

Review all completed changes against the original request. Find and resolve material omissions or inconsistencies across code, documentation, tests, and configuration.

Perform one deliberate cleanup round over the changed and directly affected task surface. Remove confirmed in-scope legacy, redundant, duplicate, dead or unused, obsolete, superseded, and no-longer-needed compatibility code plus directly related tests, configuration, and documentation when safe and authorized. Preserve required behavior, explicitly required compatibility, unrelated work, and scope. Under documentation-only or read-only authority, report material implementation cleanup findings instead of editing them. A clean result is acceptable; do not invent work.

Classify the full change set:

- **Documentation-only:** perform the review above, but explicitly skip all repository quality and test checks as unnecessary.
- **Contains non-documentation files:** discover the complete canonical gate from repository instructions, contributor docs, task runners, manifests, and CI. Run every included format, lint, static-analysis, type, security, build, and test check. Do not substitute targeted, changed-file, stale, or proportionate checks. Fix in-scope failures and rerun the full suite until it passes.

Report the exact commands and results. For non-documentation changes, list every failed, blocked, unavailable, or unverified check; for documentation-only changes, state that checks were intentionally skipped and why.
