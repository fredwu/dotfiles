---
name: codex-review-loop
description: Review and remediate code through bounded Codex rounds, preferring T3's orchestrator with ACP fallback. Use only when explicitly requested.
---

# Codex Review Loop

Apply [code-review-loop](../code-review-loop/SKILL.md) in full, using [codex-review](../codex-review/SKILL.md) as the reviewer for each round. This selects one Codex loop; reading shared mechanics does not add an internal review loop.

Use a fresh T3 task per round when its orchestrator is available; otherwise use a fresh Codex ACP session under the [shared fallback policy](../code-review/references/external-runtime.md). Preserve the requested provider and explicit model/options.

The caller owns finding assessment and repairs. Accept, partially accept, or reject claims with evidence; reviewer agreement is not a completion requirement. Follow the shared round cap, same-round failure retries, fresh-review rules, checks, and honest reporting of incomplete coverage.
