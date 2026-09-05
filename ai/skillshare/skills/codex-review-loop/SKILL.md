---
name: codex-review-loop
description: Review and remediate code through bounded external Codex CLI rounds. Use only when explicitly invoked or requested by name, including from another skill.
---

# Codex Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md) and [codex-review](../codex-review/SKILL.md), including their required references. Follow the canonical loop's target, ledger, phases, fresh-input rules, sequential remediation, stop conditions, and final handoff. The primary agent owns assessment, fixes, verification, and completion.

Explicit invocation authorizes scheduled Codex calls and minimum non-secret transfer only. It does not authorize unrelated data transfer, remote writes, or expanded remediation.

## Substitute the reviewer

Replace each scheduled internal review with exactly one fresh model-bearing top-level Codex call using `codex-review`'s mechanism and contract. Preflight consumes no model call; failed preflight makes the scheduled round incomplete. A failed model call consumes its round. Never retry, substitute reviewers, weaken isolation, or use bypass flags. Workers inside the call do not consume rounds; preserve applicable routing and forbid nested review skills or extra top-level Codex processes.

Each request must carry the canonical round's permitted requirements, frozen current surface, exclusions, lenses, fields, phase/focus, and `codex-review`'s inspection, threshold, priorities, delegation, terminal-output, completeness, and one-call rules. Keep caller-only runtime, assessment, cleanup, ledger, and earlier conclusions out of the request; only rounds 4-9 may receive their one verified blocker.

Use one private run directory with an empty working directory. Serialize a fresh complete authorized snapshot for each round without exposing the source repository. Preserve each manifest, request, exact result, and completion state. Apply the required runtime preflights and no-grant profile on every call.

Treat runtime, boundary, mutation, timeout, malformed-output, and incomplete-inspection failures as incomplete, never clean; discard unusable output and invent no findings. Stop on a boundary violation because later rounds cannot repair containment. Otherwise follow the canonical stop rules. Assess only valid completed findings. Make no remediation during or after round 10 within this loop invocation.

Return the canonical handoff and human summary, including reached rounds/phases and completion failures. Omit raw transcripts unless requested. Delete only the validated run directory; otherwise preserve and report its path. Never commit, push, publish comments, or make remote writes without separate authorization.
