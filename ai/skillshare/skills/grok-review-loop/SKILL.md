---
name: grok-review-loop
description: Review and remediate code through bounded external Grok rounds, using T3 Code inside T3 and direct ACP in other harnesses. Use only when explicitly requested.
---

# Grok Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md), [grok-review](../grok-review/SKILL.md), and the applicable shared runtime reference. Inherit the shared assessment, holistic remediation, verification, round limits, recovery, and completion rules. Substitute only the requested reviewer.

Inside T3 Code, use a fresh T3 delegated task for every round. Outside T3, use a fresh Grok ACP session. Keep prompts minimal: requirements, repository/target, read-only scope, and material exclusions, plus concise prior findings/responses/objections when T3 requires them. The agent discovers and inspects changes itself. Do not send diffs, source dumps, snapshots, or manifests.

Read and assess the review content directly; prose and Markdown are valid handoffs. Do not fail or repeat a completed review solely because of output formatting or absent schema fields. Preserve useful findings from partial inspection and disclose real gaps. Do not create duplicate active calls, resume a failed prompt, or silently substitute a provider or transport.

Join review work before edits, repair accepted findings coherently, and verify the result. Use the next available fresh review after task edits and stop early after a complete broad clean result with checks passing. Preserve any real capped/incomplete status and finish authorized residual work through the shared final-pass rules. Report reached rounds, findings/fixes, checks, and material limits; remove only task-owned scratch.
