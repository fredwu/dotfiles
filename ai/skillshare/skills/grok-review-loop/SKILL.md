---
name: grok-review-loop
description: Review and remediate code through bounded external Grok ACP rounds. Use only when explicitly invoked or requested by name, including from another skill.
---

# Grok Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md) and [grok-review](../grok-review/SKILL.md), including their required references. Inherit the canonical loop, including early broad clean completion, mandatory fresh review after every remediation (also after round 3), focused continuation and broad closing reviews in rounds 4-9, sequential review counting, and the final broad read-only audit if round 10 is reached; substitute only the reviewer and runtime below.

Apply the canonical [holistic assessment and remediation policy](../code-review-loop/SKILL.md#assess-and-remediate-holistically) to the complete round result and open accepted findings, including warranted refactors, integrated verification, and authorized residual work. The caller owns this policy; keep its plans and assessment history out of isolated reviewer prompts.

Explicit invocation authorizes reached Grok prompts and minimum non-secret transfer only. It does not authorize unrelated data transfer, remote writes, or expanded remediation.

## Substitute the reviewer

Replace each reached internal review with one fresh Grok root ACP session and exactly one top-level model-bearing prompt under `grok-review`'s runtime and result contract in embedded mode. Apply the canonical [failure recovery policy](../code-review-loop/SKILL.md#recover-failed-attempts): a failed prompt consumes its round; a pre-prompt setup failure does not consume a model round. Diagnose and verify a correction before the next fresh launch within the existing cap. Never retry the failed call, resume its session, substitute reviewers, weaken isolation, or fall back to CLI review transport. Apply the shared [reviewer tools and delegation](../code-review/references/acp-runtime.md#reviewer-tools-and-delegation) policy; Grok native workers remain disabled. Do not invoke nested review skills or add top-level review prompts.

Pass the canonical round's permitted inputs and `grok-review`'s reviewer instructions; exclude caller-only runtime, assessment, and cleanup instructions. Serialize a fresh complete authorized snapshot in each round, without exposing the source repository. Each invocation uses one fresh root session and removes its private working directory. File-tool mode uses a fresh hash-validated snapshot bundle for that round; the request still carries all authorized source content and its manifest.

Keep the current request and exact completed result until independently assessed. Remove earlier round files once no agent needs them. Apply the shared runtime on every call. Failures are incomplete, never clean; invent no findings and assess only valid completed output. Stop the affected call on boundary violations; the canonical policy owns repair, continuation, and terminal stop decisions.

Return the canonical handoff with reached rounds/phases and completion failures. Clean all task-owned request, output, and diagnostic files, including failure or abandonment. Preserve canonical schemas, requested deliverables, pre-existing provider state, and unrelated files.
