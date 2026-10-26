---
name: code-review-loop
description: Review, remediate, and verify code through bounded rounds. Use for review-and-fix requests; use code-review for one read-only review.
---

# Code Review Loop

Own assessment, repairs, verification, and completion. Read [code-review](../code-review/SKILL.md) and the original requirements. Preserve the requested target, exclusions, authority, and unrelated work. Do not commit, push, publish comments, change branches, stash, reset, or clean the checkout without authorization.

## Coordinate review

Give reviewers the requirements, repository/target, important limits, and [code-review](../code-review/SKILL.md) instructions. They inspect Git and source themselves; do not send diffs, source dumps, snapshots, or manifests. Inside T3 Code, follow [T3 coordination](../code-review/references/t3-runtime.md) and use a fresh `delegate_task` per round. Outside T3, use native controls and a fresh reviewer when independent scrutiny is useful. Apply [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md) when delegating. Keep ownership clear and join assigned work before advancing.

Report independence accurately. T3 rounds include concise prior findings, responses, and unresolved objections required by the host; these are claims to verify, not an expected verdict. Omit unrelated repair history. Reviewers and repair agents must reason from requirements and current evidence, rather than defer to each other's conclusions.

## Assess findings independently

Assess the complete review and open findings before editing. For each distinct claim, check the requirement or invariant, reachable trigger, impact, and attribution to the target. Accept, partially accept, or reject it with a concise evidence-based reason. Separate a valid defect from the reviewer's proposed solution. Check disputed facts directly; do not implement a suggestion merely because a reviewer repeats it or assigns high priority. Do not reject a valid defect merely because its repair is inconvenient.

Reject unsupported claims, preferences, and scope expansion without routine user confirmation. Resolve material requirement ambiguity from existing authority; ask the user only when it remains necessary, and continue independent work. Keep a compact in-context ledger of findings, decisions, repairs, and check evidence. Partial acceptance retains the valid defect; a genuinely unresolved claim remains open. Useful findings from partial inspection remain assessable, but partial coverage cannot establish a clean result.

## Repair coherently

Group accepted defects by root cause. Trace affected ownership, boundaries, callers, data flow, and invariants; choose a proportionate correction and checks before editing. Refactor when local patches would duplicate rules or leave the cause intact. Preserve required behavior, data, explicit compatibility, and scope. Repair agents independently verify the diagnosis and approach, and return evidence for any disagreement instead of implementing a faulty request. Do not add unrelated redesign or cleanup.

Verify the original failure and surviving behavior across affected consumers. Add regression coverage when practical, perform directly related cleanup, and inspect the combined diff. Apply [Check evidence and reuse](../final-pass/references/check-evidence.md); unaffected passing checks can remain valid, but an edited result still needs fresh review.

If accepted defects persist after two repair stages, reassess cumulative changes and shared invariants before the next edit. Revise the repair plan and use a bounded refactor when warranted. Repeated rejected suggestions do not trigger refactoring or scope expansion. This reassessment does not reset the round cap.

## Run bounded rounds

Keep review and remediation sequential; do not edit the target during review. Use at most ten completed review rounds per invocation. Failed attempts do not consume a round; retry the same numbered round under the recovery policy below. Parallel inspections form one coordinated round. Stop after a complete broad review has no remaining supported defects and required checks pass; the cap is not a quota.

Rounds 1-3, when needed, cover the complete current target with all relevant review lenses. Rounds 4-9 may focus on repairs, open defects, affected invariants and consumers, and regressions. After focused convergence, use the next available round for a broad closing review; round 10 is always broad and read-only. After edits, obtain fresh review while rounds remain. Do not restart the loop to evade the cap.

Evidence-based rejection does not require reviewer agreement or another call solely to obtain a `No findings` verdict. A complete broad review can close after all its claims are resolved without edits. Preserve the reviewer's reported findings and explain the caller's disposition; do not describe a disputed review as the reviewer reporting no findings. A real unresolved objection prevents clean closure.

Choose a reasonable per-round budget from scope and complexity. Wait on the same active work; do not infer a hang from silence or create duplicate calls. Keep task handles and confirm owned work has stopped before replacing a failed call.

### Recover failed attempts

Assess content, not formatting. Normalize prose, Markdown, or missing bookkeeping in caller context without another model call. Retain useful partial findings without inventing missing inspection.

For a model-capacity, rate-limit, API, launch, transport, timeout, authentication, or workspace failure, record the cause and retain useful partial findings. Retry the same round against the unchanged target, preserving its scope, provider, model/options, and broad or focused purpose. Advance the round only after required inspection completes and its findings are assessed. A failed broad closing review remains a broad closing review on retry.

Use up to three attempts per round unless the user specifies otherwise. For transient failures, honor retry-after guidance or use increasing delays within the chosen budget. For configuration or access failures, correct the cause before retrying; stop as incomplete if required input or access is unavailable. A user-directed cancellation stops work. Do not duplicate active calls or silently switch providers. If retries or the round budget are exhausted, report the failed round and blocker without advancing it or claiming the review-round cap was reached.

Track round and attempt separately. In T3, retry an uncertain launch with its existing `clientRequestId`; inspect the retained task before assuming failure. Once the task is confirmed failed or stopped, use a fresh `delegate_task` and launch key for its replacement attempt in the same round. Outside T3, use a fresh reviewer/session after a confirmed failure.

## Finish

A loop is clean when a complete broad review covers the final unchanged target, every finding has an evidence-backed disposition, no supported defect or material objection remains unresolved, and required checks pass. Verified repairs await fresh review before closure.

After the cap or a real continuation blocker, hand residual findings and missing coverage to [final-pass](../final-pass/SKILL.md) for authorized direct repair and verification. Preserve the loop's actual incomplete/capped status and identify repairs verified without fresh review. A cap ends that review invocation, not authorized implementation work. Do not label direct inspection as a clean external review.

During plan execution, follow [Completion and review checkpoints](../execute-plan/SKILL.md#completion-and-review-checkpoints). Report material findings, fixes, rejected claims and reasons, reached rounds, checks, and limits concisely. Remove only task-owned scratch and verify cleanup. Save reports or transcripts only when requested.
