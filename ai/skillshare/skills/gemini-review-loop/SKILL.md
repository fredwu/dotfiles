---
name: gemini-review-loop
description: Review and remediate code through bounded Gemini rounds, preferring T3's orchestrator with ACP fallback. Use only when explicitly requested.
metadata:
  origin: custom
---

# Gemini Review Loop

Apply [code-review-loop](../code-review-loop/SKILL.md) in full, using [gemini-review](../gemini-review/SKILL.md) as the reviewer for each round. This selects one Gemini loop; reading shared mechanics does not add an internal review loop.

Use a fresh T3 task per round when its orchestrator is available; otherwise use a fresh Gemini ACP session under the [shared fallback policy](../code-review/references/external-runtime.md). Preserve the requested provider and explicit model/options.

The caller owns finding assessment and repairs. Accept, partially accept, or reject claims with evidence; reviewer agreement is not a completion requirement. Follow the shared round cap, same-round failure retries, fresh-review rules, checks, and honest reporting of incomplete coverage.
