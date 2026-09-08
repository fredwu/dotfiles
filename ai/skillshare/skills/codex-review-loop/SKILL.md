---
name: codex-review-loop
description: Review and remediate code through bounded external Codex CLI rounds. Use only when explicitly invoked or requested by name, including from another skill.
---

# Codex Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md) and [codex-review](../codex-review/SKILL.md), including their required references. Inherit the canonical loop, including complete coverage in rounds 1-3 and early clean completion; substitute only the reviewer and runtime below.

Explicit invocation authorizes reached Codex calls and minimum non-secret transfer only. It does not authorize unrelated data transfer, remote writes, or expanded remediation.

## Substitute the reviewer

Replace each reached internal review with one fresh model-bearing top-level Codex call under `codex-review`'s runtime and result contract in embedded mode. Failed preflight makes the round incomplete without a model call; a failed call consumes its round. Never retry, substitute reviewers, weaken isolation, or use bypass flags. Nested workers do not consume rounds; forbid nested review skills and extra top-level review processes.

Pass the canonical round's permitted inputs and `codex-review`'s reviewer instructions; exclude caller-only runtime, assessment, and cleanup instructions.

Use one private run directory with an empty working directory. Serialize a fresh complete authorized snapshot for each round without exposing the source repository. Keep the current manifest, request, exact result, and completion state until assessed; remove earlier round files once no agent needs them. Apply the required runtime preflights and no-grant profile on every call.

Apply the runtime's completion checks. Failures are incomplete, never clean; invent no findings and assess only valid completed output. Stop on boundary violations; otherwise follow canonical stop rules.

Return the canonical handoff with reached rounds/phases and completion failures. Apply runtime cleanup to every round and the shared run directory, including failure or abandonment.
