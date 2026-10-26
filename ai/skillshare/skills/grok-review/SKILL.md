---
name: grok-review
description: Run one read-only Grok review through T3's orchestrator when available, with ACP fallback. Use only when explicitly requested. Use grok-review-loop for review and remediation.
---

# Grok Review

Run one read-only Grok review. Apply [code-review](../code-review/SKILL.md) for requirements, scope, evidence standards, and output, and the [external runtime](../code-review/references/external-runtime.md) for transport and handoff. Pass the shared review instructions to the reviewer.

Prefer T3's orchestrator when available; otherwise use the Grok ACP peer under the shared fallback policy. Preserve the requested provider and explicit model/options. Do not substitute another provider.

Return the review and material limits without repairs or another review invocation. Treat findings as advisory claims; the caller evaluates them against requirements and source.
