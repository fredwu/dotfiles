---
name: code-review-loop
description: Review, remediate, and verify code through bounded rounds. Use for review-and-fix requests; use code-review for one read-only review.
metadata:
  origin: custom
---

# Code Review Loop

Own assessment, repairs, verification, and completion. Read [code-review](../code-review/SKILL.md) and the original requirements. Keep the requested target, exclusions, authority, and unrelated work. Do not commit, push, publish comments, change branches, stash, reset, or clean the checkout without authorization.

## Coordinate review

Every round reviews under [code-review](../code-review/SKILL.md). External loops (Codex, Claude, Grok) always delegate the reviewer. For an internal loop inside T3 Code, delegate each round as a fresh `delegate_task`; without T3 orchestration, delegating internal review is optional, so use a separate reviewer when independent scrutiny adds value. Delegated rounds follow the [external review runtime](../code-review/references/external-runtime.md) and [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md). Keep ownership clear, and join assigned work before you advance.

Reviewers and repair agents reason from requirements and current evidence; they do not defer to each other's conclusions. Give later rounds only concise prior findings, responses, and open objections, as claims to verify; leave out unrelated repair history. Report reviewer independence accurately.

## Assess findings

Assess the complete review and all open findings before you edit. For each distinct claim, check the requirement or invariant, a reachable trigger, the impact, and attribution to the target. Accept, partially accept, or reject it with a short evidence-based reason. Separate a valid defect from the reviewer's proposed fix. Check disputed facts directly. Do not implement a suggestion only because a reviewer repeats it or gives it high priority, and do not reject a valid defect only because its repair is inconvenient.

Reject unsupported claims, preferences, and scope expansion without routine user confirmation. Resolve material requirement ambiguity from existing authority; ask the user only when still necessary, and continue independent work. Keep a compact ledger in context of findings, decisions, repairs, and check evidence. Partial acceptance keeps the valid part open; a genuinely unresolved claim stays open. Findings from a partial inspection can be assessed, but partial coverage cannot establish a clean result.

## Repair

Group accepted defects by root cause. Before you edit, trace the affected ownership, boundaries, callers, data flow, and invariants, and choose a proportionate correction and its checks. Refactor when local patches would duplicate rules or leave the cause in place. Keep required behavior, data, explicit compatibility, and scope; do not add unrelated redesign or cleanup. Repair agents verify the diagnosis and approach independently, and return evidence for any disagreement instead of implementing a faulty request.

Verify the original failure and surviving behavior across affected consumers. Add regression coverage when practical, do directly related cleanup, and inspect the combined diff. Apply [Check evidence and reuse](../final-pass/references/check-evidence.md): unaffected passing checks can stay valid, but an edited result still needs fresh review.

If accepted defects persist after two repair stages, reassess the cumulative changes and shared invariants before the next edit, revise the repair plan, and use a bounded refactor when warranted. Repeated rejected suggestions do not trigger refactoring or scope expansion. This reassessment does not reset the round cap.

## Rounds

Keep review and remediation sequential; do not edit the target during a review. Use at most ten completed review rounds per invocation. Failed attempts do not use a round. Parallel inspections together form one round. The cap is a limit, not a quota.

- Rounds 1-3, when needed, review the complete current target with all relevant lenses.
- Rounds 4-9 can focus on repairs, open defects, affected invariants and consumers, and regressions.
- After focused rounds converge, use the next round for a broad closing review. Round 10 is always broad and read-only.
- After edits, get a fresh review while rounds remain. Do not restart the loop to avoid the cap.

Evidence-based rejection does not need reviewer agreement, or another call only to get a `No findings` verdict. A complete broad review can close once all its claims are resolved without edits. Keep the reviewer's reported findings and explain your disposition; do not describe a disputed review as a review with no findings. A real unresolved objection prevents a clean close.

### Recover failed attempts

Assess content, not format. Normalize prose, Markdown, or missing bookkeeping yourself without another model call, and keep useful partial findings without inventing missing inspection.

For a model-capacity, rate-limit, API, launch, transport, timeout, authentication, or workspace failure, record the cause and keep useful partial findings. Retry the same round against the unchanged target with the same scope, provider, model, options, and broad or focused purpose. A failed broad closing review stays a broad closing review on retry. Advance the round only after its required inspection completes and its findings are assessed.

Use up to three attempts per round unless the user says otherwise. For transient failures, follow retry-after guidance or use increasing delays within the budget. For configuration or access failures, fix the cause before you retry; stop as incomplete if required input or access is unavailable. A user cancellation stops work. Do not duplicate active calls or switch providers silently. If attempts or the time budget run out, report the failed round and blocker without advancing it or claiming that the round cap was reached.

Track round and attempt separately. T3 launch keys and task replacement follow [T3 coordination](../code-review/references/t3-runtime.md); with ACP, use a fresh session after a confirmed failure. A permitted transport fallback stays in the same round and attempt budget.

## Finish

The loop is clean when a complete broad review covers the final unchanged target, every finding has an evidence-backed disposition, no supported defect or material objection remains, and required checks pass. Verified repairs still need fresh review before a clean close.

After the cap or a real blocker, hand the residual findings and missing coverage to [final-pass](../final-pass/SKILL.md) for authorized direct repair and verification. Keep the loop's actual capped or incomplete status, and identify repairs verified without fresh review. A cap ends this review invocation, not the authorized implementation work. Do not call direct inspection a clean review.

During plan execution, follow [Completion and review checkpoints](../execute-plan/SKILL.md#completion-and-review-checkpoints). Report material findings, fixes, rejected claims with reasons, rounds used, checks, and limits concisely. Remove only task-owned scratch and verify the cleanup. Save reports or transcripts only on request.
