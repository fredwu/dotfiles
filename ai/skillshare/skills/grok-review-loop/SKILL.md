---
name: grok-review-loop
description: Review and remediate code through bounded external Grok CLI rounds. Use only when explicitly invoked or requested by name, including from another skill.
---

# Grok Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md) and [grok-review](../grok-review/SKILL.md), including their required references. Follow the canonical loop's target, ledger, phases, fresh-input rules, sequential remediation, stop conditions, and final handoff. The primary agent owns assessment, fixes, verification, and completion.

Explicit invocation authorizes scheduled Grok calls and minimum non-secret transfer only. It does not authorize unrelated data transfer, remote writes, or expanded remediation.

## Substitute the reviewer

Replace each scheduled internal review with exactly one fresh model-bearing top-level Grok call using `grok-review`'s mechanism and contract. Preflight consumes no model call; failed preflight makes the scheduled round incomplete. A failed model call consumes its round. Never retry, substitute reviewers, weaken isolation, or use bypass flags. Workers inside the call do not consume rounds; preserve applicable routing and forbid nested review skills or extra top-level Grok processes.

Each request must carry the canonical round's permitted requirements, frozen current surface, exclusions, lenses, fields, phase/focus, and `grok-review`'s inspection, threshold, priorities, delegation, terminal-output, completeness, and one-call rules. Keep caller-only runtime, assessment, cleanup, ledger, and earlier conclusions out of the request; only rounds 4-9 may receive their one verified blocker.

Use one private non-secret run directory and a separate transient environment root per round. Preserve each preflight inspection, request, exact stdout, and stderr. Apply the required runtime's protected authentication, empty CWD, target-confined sandbox, and role mapping on every call. Delete and verify removal of each transient environment after preflight failure or the model attempt, regardless of outcome.

Treat runtime, boundary, mutation, timeout, malformed-output, and incomplete-inspection failures as incomplete, never clean; discard unusable output and invent no findings. Stop on a boundary violation because later rounds cannot repair containment. Otherwise follow the canonical stop rules. Assess only valid completed findings. Make no remediation during or after round 10 within this loop invocation.

Return the canonical handoff and human summary, including reached rounds/phases and completion failures. Omit raw transcripts unless requested. Delete only the validated run directory; otherwise preserve and report its path. Never commit, push, publish comments, or make remote writes without separate authorization.
