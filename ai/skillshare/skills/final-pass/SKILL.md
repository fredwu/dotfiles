---
name: final-pass
description: Perform one deliberate final pass over completed changes, resolve material omissions or inconsistencies, and run the repository or project's full canonical quality and test suite for any change set containing non-documentation files. Skip those checks for documentation-only changes. Use at the end of implementation, especially when code, documentation, tests, or configuration must remain coherent.
---

# Final Pass

Review the completed work as a whole against the original request and the full set of changes.

Look for anything materially missed or inconsistent, with particular attention to coherence between code, documentation, tests, and configuration. Resolve every in-scope issue before verification.

Determine whether the full change set is documentation-only (for example, changes limited to planning documents). Always perform the review and coherence pass above. If every changed file is documentation-only, explicitly skip all repository or project quality and test checks; these checks are unnecessary for that change set.

If any non-documentation file changed, discover the repository or project's complete canonical quality gate from its instructions, contributor documentation, task runners, package manifests, and CI configuration. Include formatting, linting, static analysis, type checking, security checks, builds, and tests whenever they are part of that gate.

After resolving final issues, run the full canonical quality and test suite when any non-documentation file changed. Do not substitute targeted, changed-file, stale, or merely proportionate checks for the full gate. Fix in-scope failures and rerun the complete suite until it passes.

Do not silently skip failures or unavailable checks. For documentation-only changes, hand off that the checks were intentionally skipped and why. Otherwise, hand off the exact commands and results, including every failure, blocked or unavailable check, and anything left unverified.
