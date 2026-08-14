---
name: codex-review-loop
description: Run the canonical bounded review-remediation workflow using one read-only external Codex CLI invocation per scheduled round, with broad rounds 1-3, blocker-focused rounds 4-9, and an optional final read-only round 10. Use only when explicitly invoked as $codex-review-loop or explicitly requested by name, including from another skill; never invoke implicitly.
---

# Codex Review Loop

Read `../code-review-loop/SKILL.md`, `../code-review/SKILL.md`, and `../codex-review/SKILL.md`. Follow the canonical loop with these substitutions. The primary agent owns scope, assessment, remediation, verification, and completion.

Explicit invocation authorizes only the scheduled Codex calls and minimum non-secret transfer, not unrelated data, remote writes, or expanded remediation.

## Use Codex for scheduled rounds

Replace each scheduled internal `code-review` with exactly one fresh model-bearing top-level Codex call using `codex-review`'s read-only mechanism and contract. Metadata preflight does not consume the round. Worker subagents required by applicable routing instructions remain inside that call and do not consume rounds. Forbid nested review skills or extra model-bearing Codex processes only to preserve one call per round. A failed call consumes its round; never retry, substitute reviewers, weaken the sandbox, or use bypass flags.

Freeze one typed scope and use one private temporary run directory with an empty working directory. Serialize a fresh complete authorized snapshot into each scheduled round's stdin request without exposing the source repository. Preserve each round's manifest, request, and exact result. Every request must include the original requirements, frozen current surface and exclusions, shared lenses and fields, round phase/focus, and `codex-review`'s inspection, confidence threshold, priority semantics, worker delegation, terminal JSON, completeness, and one-call rules. Keep caller-only CLI, polling, assessment, and cleanup instructions out of the request.

For broad rounds 1-3, require complete-surface inspection and pass no prior output, ledger, remediation narrative, or conclusion. For rounds 4-9, pass only the independently verified blocker, its current surface, and immediate regression boundary. Round 10 receives the complete current surface, a broad final-audit focus, and no prior conclusion.

Before each call, apply `codex-review`'s outer-runtime and no-grant preflights and obtain any narrow authority before starting. Use its ordinary prompt-bearing `codex exec` form, serialized snapshot, strict schema, ephemeral no-filesystem/no-network profile, existing agent routing, deadline, polling, snapshots, and mutation checks. A failed preflight consumes no model call but makes the scheduled round incomplete. Any boundary violation, malformed or unusable output, incomplete inspection, timeout, CLI failure, or mutation makes the round incomplete; discard its review output, invent no findings, and never treat it as clean. Stop on a boundary violation because later rounds cannot repair containment.

After rounds 1-9, assess every finding, fix each accepted authorized item, resolve residual work, run proportionate checks, and update the ledger. Use `blocked` only for missing authority, required input, or external-state change. Make no remediation during or after round 10.

Return the canonical handoff and summary with reached rounds/phases, completion failures, dispositions, fixes, checks, unresolved findings, blockers, and residual risk. Omit raw transcripts unless requested. Delete only the validated run directory; otherwise preserve and report its path. Never commit, push, publish comments, or make other remote writes without separate authorization.
