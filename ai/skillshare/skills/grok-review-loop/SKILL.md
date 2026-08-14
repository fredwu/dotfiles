---
name: grok-review-loop
description: Run the canonical bounded review-remediation workflow using one read-only external Grok CLI invocation per scheduled round, with broad rounds 1-3, blocker-focused rounds 4-9, and an optional final read-only round 10. Use only when explicitly invoked as $grok-review-loop or explicitly requested by name, including from another skill; never invoke implicitly.
---

# Grok Review Loop

Read `../code-review-loop/SKILL.md`, `../code-review/SKILL.md`, and `../grok-review/SKILL.md`. Follow the canonical loop with these substitutions. The primary agent owns scope, assessment, remediation, verification, and completion.

Explicit invocation authorizes only the scheduled Grok calls and minimum non-secret transfer, not unrelated data, remote writes, or expanded remediation.

## Use Grok for scheduled rounds

Replace each scheduled internal `code-review` with exactly one fresh model-bearing top-level Grok call using `grok-review`'s read-only mechanism and contract. Metadata and authentication preflight do not consume the round. Map applicable repository `worker` and `fastworker` roles to Grok's built-in `general-purpose` task; these tasks remain inside the call and do not consume rounds, and subagent use is otherwise unrestricted. Forbid nested review skills or extra model-bearing Grok processes only to preserve one call per round. A failed call consumes its round; never retry, substitute reviewers, weaken the sandbox, or use bypass flags.

Freeze one typed scope and use one private non-secret run directory plus a separate transient environment root per round. Preserve each round's preflight inspection, compact request, exact stdout, and stderr, but delete and verify removal of its transient root after preflight and any model attempt regardless of outcome. Because Grok does not receive `grok-review` implicitly, every request must include the original requirements, frozen current surface and exclusions, shared lenses and fields, round phase/focus, and `grok-review`'s inspection-first rule, confidence threshold, priority semantics, role mapping, terminal `StructuredOutput`, completeness, and one-call rules. Keep caller-only CLI, isolation, polling, assessment, and cleanup instructions out of the request.

For broad rounds 1-3, require complete-surface inspection and pass no prior output, ledger, remediation narrative, or conclusion. For rounds 4-9, pass only the independently verified blocker, its current surface, and immediate regression boundary. Round 10 receives the complete current surface, a broad final-audit focus, and no prior conclusion.

Apply `grok-review`'s empty-CWD runtime, script-free API-key preflight, target-confined custom sandbox, child environment policy, `general-purpose` agent, schema, connected-tool policy, deadline, snapshots, mutation checks, and cleanup. Normalize only completed structured findings after independent assessment. Missing protected authentication, failed sandbox checks, ambient discovery, malformed output, premature `incomplete`, incomplete inspection, structured-output failure, timeout, CLI failure, or mutation makes the round incomplete; invent no findings and never treat it as clean. The failed model call consumes its scheduled round and is not retried. Follow canonical stop rules.

After rounds 1-9, assess every finding, fix each accepted authorized item, resolve residual work, run proportionate checks, and update the ledger. Use `blocked` only for missing authority, required input, or external-state change. Make no remediation during or after round 10.

Return the canonical handoff and summary with reached rounds/phases, completion failures, dispositions, fixes, checks, unresolved findings, blockers, and residual risk. Omit raw transcripts unless requested. Delete only the validated run directory; otherwise preserve and report its path. Never commit, push, publish comments, or make other remote writes without separate authorization.
