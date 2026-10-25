---
name: code-review-loop
description: Review, remediate, and verify code through bounded rounds. Use for review-and-fix requests; use code-review for one read-only review.
---

# Code Review Loop

Own assessment, repairs, verification, and completion. Read [code-review](../code-review/SKILL.md) and the original requirements. Preserve the requested target, exclusions, authority, and unrelated work. Do not commit, push, publish comments, change branches, stash, reset, or clean the checkout without authorization.

## Coordinate agents

Keep handoffs minimal: requirements, repository/target, and important limits. Agents inspect Git and source themselves; do not send diffs, source dumps, snapshots, or manifests. Inside T3 Code, follow [T3 coordination](../code-review/references/t3-runtime.md) and use a fresh `delegate_task` for every review round; do not continue a review in an earlier task's child thread. Outside T3, use the harness's native controls. Apply [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md) when delegating. Keep ownership clear, serialize overlapping edits, and join all assigned work before advancing.

Outside T3, use a fresh reviewer when independent scrutiny is useful. Report independence accurately. T3 rounds include concise prior findings, responses, and unresolved objections required by the host; these are claims to verify, not an expected verdict. Do not carry repair-agent history into a reviewer unnecessarily.

## Assess and remediate holistically

Assess the complete review and open findings together. Verify claims against requirements, source, and reachable behavior; accept, partially accept, or decline with evidence. Track findings and checks in context. Useful findings from a partial review remain assessable; partial coverage is not a clean result.

Group related findings by root cause. Trace ownership, boundaries, callers, data flow, and invariants. Plan a proportionate integrated correction and regression checks before editing. Refactor when local patches would duplicate rules, conceal inconsistent behavior, or leave the cause intact. Preserve required behavior, data, explicit compatibility, and scope. Do not add unrelated redesign or cleanup.

Verify the original failure and surviving behavior across affected consumers. Add regression coverage when practical, perform directly related cleanup, and inspect the combined diff. Apply [Check evidence and reuse](../final-pass/references/check-evidence.md); unaffected passing checks can remain valid, but an edited result still needs fresh review.

### Escalate persistent findings

If reviews still require repairs after two remediation stages, reassess the cumulative implementation before the next edit. Re-read affected code and earlier repairs, trace shared invariants, and revise the repair/verification plan. Different findings can expose the same structural problem. Use a bounded refactor when warranted; independent local defects do not force a rewrite. This is coordinator analysis, not another review round or a reset of the cap.

## Run bounded rounds

Keep review and remediation sequential; do not edit the target during review. Let reviewers discover the current changes themselves. Use at most ten model-bearing review attempts in one invocation. Count genuine failed or cancelled attempts, but do not turn formatting cleanup into a new model call. A clean first broad review is sufficient; the cap is not a quota.

Rounds 1-3 cover the complete current target and all lenses. If needed, rounds 4-9 emphasize repairs, open findings, affected invariants and consumers, and immediate regressions while allowing other concrete issues. After focused convergence, use the next available round for a broad closing review. Round 10 is the final broad read-only audit. Do not skip available follow-up review after edits, restart a loop to evade its cap, or require unused rounds after a broad clean result.

Choose a reasonable per-round budget from scope and complexity. Wait on the same active work; do not infer a hang from silence or create duplicate calls. Keep task handles and confirm owned work has stopped before replacing a failed call.

### Recover failed attempts

Assess the review content, not its formatting. Prose, Markdown, wrappers, missing IDs, or absent schema bookkeeping are not review failures. Normalize useful content in caller context and verify substantive claims. Do not discard a useful partial review or invent missing inspection to call it clean.

For a genuine launch, authentication, transport, cancellation, or unavailable-workspace problem, record the cause and any useful partial findings separately. Diagnose and correct what is supported by evidence, then use the next fresh attempt when needed. Do not repeatedly relaunch unchanged failures or silently switch providers. Report concrete limits when required input, access, or external state is unavailable.

## Finish

A loop is clean when a complete broad review covers the final unchanged target, no accepted findings or task-relevant residuals remain, and required checks pass. During an active loop, verified repairs await the next fresh review before closure.

After the cap or a real continuation blocker, hand residual findings and missing coverage to [final-pass](../final-pass/SKILL.md) for authorized direct repair and verification. Preserve the loop's actual incomplete/capped status and identify repairs verified without fresh review. A cap ends that review invocation, not authorized implementation work. Do not label direct inspection as a clean external review.

During plan execution, follow [Completion and review checkpoints](../execute-plan/SKILL.md#completion-and-review-checkpoints). Return findings, fixes, reached rounds, checks, and material limits in plain language. Keep requested deliverables and unrelated files; remove only task-owned scratch after use and verify cleanup. Save reports or transcripts only when requested.
