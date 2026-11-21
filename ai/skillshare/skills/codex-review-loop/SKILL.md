---
name: codex-review-loop
description: Review and remediate code through bounded Codex rounds, preferring T3's orchestrator with ACP fallback. Use only when explicitly requested.
metadata:
  origin: custom
---

# Codex Review Loop

Apply `code-review-loop` in full, using `codex-review` as the reviewer for each Codex round. Reading shared mechanics does not add an internal review loop. When a caller has already selected this loop or pass family, run only that assignment without re-parsing or expanding. On direct invocation, pass Codex as the default reviewer together with the user's request to `code-review-loop` (`Select reviewers`), which resolves any additional external reviewers, `internal`, and repeat requests under Two-pass review (`code-review/references/two-pass-review.md`).

Use a fresh T3 task per round when its orchestrator is available; otherwise use a fresh Codex ACP session under the shared fallback policy (`code-review/references/external-runtime.md`). Preserve the requested provider and explicit model/options.

The caller owns finding assessment and repairs. Accept, partially accept, or reject claims with evidence; reviewer agreement is not a completion requirement. Follow the shared round cap, same-round failure retries, fresh-review rules, checks, and honest reporting of incomplete coverage.
