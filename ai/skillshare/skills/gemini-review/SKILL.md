---
name: gemini-review
description: Run a read-only Gemini review pass through T3's orchestrator when available, with ACP fallback (one Gemini review by default; direct multi-reviewer or repeat requests run selected reviewers in parallel). Use only when explicitly requested. Use gemini-review-loop for review and remediation.
metadata:
  origin: custom
---

# Gemini Review

Run a read-only Gemini review pass (one Gemini review by default). Apply `code-review` for requirements, scope, evidence standards, and output, and the external runtime (`code-review/references/external-runtime.md`) for transport and handoff. Reading shared mechanics does not add an internal review. When invoked by a caller that already selected this review (such as `code-review-loop` or a panel round), run only that assigned Gemini review without re-parsing or expanding. On direct invocation, pass Gemini as the default reviewer together with the user's request to `code-review` (`Select reviewers`), which resolves any additional reviewers and repeat requests under Two-pass review (`code-review/references/two-pass-review.md`). Pass the shared review instructions to the reviewer.

Prefer T3's orchestrator when available; otherwise use the Gemini ACP peer under the shared fallback policy. Preserve the requested provider and explicit model/options. Do not substitute another provider.

Return the review and material limits without repairs, reviews beyond the resolved selection, or follow-up review invocations. Treat findings as advisory claims; the caller evaluates them against requirements and source.
