---
name: final-pass
description: Perform one deliberate final pass over completed changes, resolve material omissions or inconsistencies, and run the repository or project's full canonical quality and test suite before handing off. Use at the end of implementation, especially when code, documentation, tests, or configuration must remain coherent.
---

# Final Pass

Review the completed work as a whole against the original request and the full set of changes.

Look for anything materially missed or inconsistent, with particular attention to coherence between code, documentation, tests, and configuration. Resolve every in-scope issue before verification.

Discover the repository or project's complete canonical quality gate from its instructions, contributor documentation, task runners, package manifests, and CI configuration. Include formatting, linting, static analysis, type checking, security checks, builds, and tests whenever they are part of that gate.

After resolving final issues, run the full canonical quality and test suite. Do not substitute targeted, changed-file, stale, or merely proportionate checks for the full gate. Fix in-scope failures and rerun the complete suite until it passes.

Do not silently skip failures or unavailable checks. Hand off the exact commands and results, including every failure, blocked or unavailable check, and anything left unverified.
