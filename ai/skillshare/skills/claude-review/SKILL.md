---
name: claude-review
description: Run one read-only external Claude review through T3 Code inside T3, or direct ACP in other harnesses. Use only when explicitly requested. Use claude-review-loop for review and remediation.
---

# Claude Review

Run one advisory Claude review. Read [code-review](../code-review/SKILL.md) for scope and review lenses, then the [shared external runtime](../code-review/references/external-runtime.md) and the applicable transport reference.

Inside T3 Code, coordinate through T3 delegation. Outside T3, use the Claude ACP peer. Keep the handoff to requirements, repository/target, read-only scope, and important exclusions. Let the reviewer discover changes with Git and read source itself. Do not send diffs, source dumps, snapshots, or manifests, or substitute another provider.

Accept ordinary review text or structured output. Assess findings against source, retain useful partial findings, and state substantive limits. Formatting, missing bookkeeping fields, and Markdown do not fail a review. Do not edit or start another review within this single invocation. Do not commit, push, publish comments, or make remote writes without authorization. Clean task-owned scratch after assessment and report findings and limits concisely.
