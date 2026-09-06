---
name: codex-review-loop
description: Review and remediate code through bounded external Codex CLI rounds. Use only when explicitly invoked or requested by name, including from another skill.
---

# Codex Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md) and [codex-review](../codex-review/SKILL.md), including their required references. Follow the canonical loop's target, finding tracking, phases, fresh-input rules, sequential remediation, stop conditions, and final handoff. The primary agent owns assessment, fixes, verification, and completion.

Explicit invocation authorizes scheduled Codex calls and minimum non-secret transfer only. It does not authorize unrelated data transfer, remote writes, or expanded remediation.

## Substitute the reviewer

Replace each scheduled internal review with one fresh model-bearing top-level Codex call under `codex-review`'s runtime and result contract in embedded mode. Failed preflight makes the round incomplete without a model call; a failed call consumes its round. Never retry, substitute reviewers, weaken isolation, or use bypass flags. Nested workers do not consume rounds; forbid nested review skills and extra top-level review processes.

Pass only the canonical round's permitted inputs plus `codex-review`'s reviewer instructions. Exclude caller-only runtime, assessment, cleanup, finding history, and prior conclusions; rounds 4-9 may include their one verified blocker.

Use one private run directory with an empty working directory. Serialize a fresh complete authorized snapshot for each round without exposing the source repository. Keep the current manifest, request, exact result, and completion state until assessed; retaining earlier round files is optional. Apply the required runtime preflights and no-grant profile on every call.

Apply the runtime's completion checks. Failures are incomplete, never clean; invent no findings and assess only valid completed output. Stop on boundary violations; otherwise follow canonical stop rules. Do not remediate during or after round 10.

Return the canonical concise handoff, including reached rounds/phases and completion failures. Reports and retained non-secret diagnostics are optional; omit raw transcripts unless requested. Remove only validated task-created temporary paths and report any retained paths.
