---
name: codex-review
description: Run one read-only external Codex review through T3 Code when available, otherwise ACP, and assess its findings. Use only when explicitly invoked or requested by name, including from another skill. Use codex-review-loop for iterative remediation.
---

# Codex Review

Run exactly one model-bearing review prompt in one fresh Codex root task or session. Permitted inspector children remain within the root round. Capability and authentication preflight do not count. Do not edit, remediate, publish, retry, follow up, or invoke another review. The caller owns scope and assessment.

Read [code-review](../code-review/SKILL.md) for the frozen target, review lenses, confidence threshold, priorities, and output contract. Read [the shared external runtime](../code-review/references/external-runtime.md) to prepare the complete frozen request and select T3 Code or ACP, then read the selected runtime's reference. Explicit invocation authorizes only the minimum non-secret transfer and the documented T3 context exception; exclude credentials and unrelated data.

Select the requested Codex provider, not a substitute. In ACP, use the shared client with `--agent codex` and explicit `--timeout-seconds` containing the caller-selected positive finite budget. In T3, use a fresh `delegate_task` under its completion, budget, and strict terminal validation rules. Do not invoke this skill recursively inside the reviewer prompt.

Assess valid completed findings and normalize to [the canonical schema](../code-review/references/review-result.schema.json). For embedded reviews or requested JSON, return one canonical `REVIEW_RESULT`. Otherwise give accepted and partial findings, declined count, inspected surface, runtime, and material limits in plain language. Skip stock headings, repeated summaries, and raw logs. Save a user report only if requested. Never commit, push, publish comments, or make remote writes without separate authorization. Clean task-owned scratch under the selected runtime's lifecycle rules.
