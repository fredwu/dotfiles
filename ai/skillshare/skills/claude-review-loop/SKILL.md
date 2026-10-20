---
name: claude-review-loop
description: Review and remediate code through bounded external Claude rounds, preferring T3 Code with ACP available elsewhere. Use only when explicitly invoked or requested by name, including from another skill.
---

# Claude Review Loop

Read [code-review-loop](../code-review-loop/SKILL.md) and [claude-review](../claude-review/SKILL.md), including the selected runtime's reference. Inherit the canonical loop: early broad clean completion, fresh review after every remediation (also after round 3), focused continuation and broad closing reviews in rounds 4-9, sequential review counting, and a final broad read-only audit if round 10 is reached. Substitute only the reviewer and runtime below.

Apply the canonical [holistic assessment and remediation policy](../code-review-loop/SKILL.md#assess-and-remediate-holistically) to the complete round result and open accepted findings, including the [persistent-findings checkpoint](../code-review-loop/SKILL.md#escalate-persistent-findings). The caller owns its finding history, systematic reassessment, coherent repair or refactor plan, verification, and finding status. Explicit invocation authorizes reached Claude prompts and minimum non-secret transfer only; it does not authorize unrelated data transfer, remote writes, or expanded remediation.

## Substitute the reviewer

Replace each reached internal review with one fresh Claude root task or ACP session and exactly one model-bearing review prompt under `claude-review`'s embedded result contract. Never resume its reviewer context, send another review to its child thread, substitute providers, invoke nested review skills, or add review prompts. Permitted inspector children remain within the root round.

Prepare a fresh complete authorized snapshot each round. ACP receives only the canonical permitted round inputs and keeps its private snapshot and context restrictions. T3 follows the explicit [history-informed context exception](../code-review/references/external-runtime.md#prepare-the-frozen-request): supply the original brief, prior findings, caller responses, and unresolved objections in each fresh `delegate_task`. Broad rounds still inspect the complete target with all lenses; prior claims are unverified context. Describe T3 coverage accurately and do not claim fresh independent review.

Choose the budget for every reached round and follow the selected runtime's task management, terminal validation, before/after state checks, and cleanup rules. Apply the canonical [failure recovery policy](../code-review-loop/SKILL.md#recover-failed-attempts): failed model-bearing attempts consume their round; verified pre-prompt setup failures do not. Diagnose and verify a correction before the next fresh launch within the existing cap. Never launch a fallback or duplicate for an active, lost, or unknown task; never retry a model prompt in the same round. Failed or malformed output is incomplete and supplies no findings.

Keep the current request and exact result until assessed. Return the canonical handoff with reached rounds/phases, runtime and context/access limits, completion failures, and the separate caller-owned finding ledger. Clean task-owned files after assessment, including failure or abandonment. Preserve canonical schemas, requested deliverables, provider and app history, and unrelated files.
