---
name: claude-review
description: Run one read-only external Claude review through T3 Code inside T3, or direct ACP in other harnesses. Use only when explicitly requested. Use claude-review-loop for review and remediation.
---

# Claude Review

Run one read-only Claude review. Apply [code-review](../code-review/SKILL.md) for requirements, scope, evidence standards, and output, and the [external runtime](../code-review/references/external-runtime.md) for transport and handoff. Pass the shared review instructions to the reviewer.

Use T3 delegation inside T3 Code and the Claude ACP peer elsewhere. Preserve the requested provider and explicit model/options. Do not substitute another provider.

Return the review and material limits without repairs or another review invocation. Treat findings as advisory claims; the caller evaluates them against requirements and source.
