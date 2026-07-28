---
name: codex-review-loop
description: Run the canonical bounded review-remediate loop with every scheduled review supplied by the external Codex CLI through codex-review. Use for iterative external Codex review and authorized remediation of a sufficiently identified change target.
---

# Codex Review Loop

Use `../code-review-loop/SKILL.md` as the normative loop mechanism. Before acting, completely read the user request, applicable repository instructions, that file, and `../codex-review/SKILL.md`.

Apply every non-reviewer mechanism from the normative loop without restating or replacing it, including its contract, surface resolution and refresh, ledger, assessment and dispositions, authorization-bounded remediation, checks, round bounds, stopping rules, final inspection, transcript handling, and audit report. Make only the exhaustive reviewer substitutions below.

## Substitute external Codex for code-review

For every scheduled round, invoke exactly one external Codex CLI review according to `../codex-review/SKILL.md`. Never invoke `code-review`, a generic review subagent, or any other scheduled reviewer.

The original user request must identify the target well enough for Codex to discover it from the repository root or parent of named paths. If it does not, ask the user to clarify. Do not compensate by sending a typed descriptor, private change inventory, diff, or invented scope to Codex.

Send Codex only the original user task, plus an optional one-line focus only when it came from the user's trigger. Never send the typed descriptor, inventory, diff, ledger, logs, tool traces, prior review, remediation summary, prior conclusions, or an internally selected round emphasis. Do not pass a model unless requested. A custom prompt must not be combined with `--base`, `--uncommitted`, or `--commit`.

Run one fresh ephemeral invocation, snapshot the worktree and relevant diff before and after it, and make no git mutation while it runs. Follow `codex-review`'s timeout, polling, diagnostics, cleanup, and no-process-killing rules exactly. A non-empty output file is success. Preserve the complete Codex output verbatim, then independently assess it.

Treat mutation or unusable output as a failed, counted round. Do not schedule a replacement reviewer. When safe, use the normative loop's one clearly separated same-round self-review fallback; otherwise stop. A fallback is never Codex output or an independent reviewer. Reverse mutation only when the exact reviewer-created delta is safely isolatable; otherwise stop and ask the user.

Round 10 is an external Codex consultation only. Codex receives the same restricted input; the invoking agent synthesizes the audit and performs no later remediation.

For every used round, label the unedited transcript `Codex review`, followed by `Assessment`. Apply all remaining reporting requirements from the normative loop unchanged.
