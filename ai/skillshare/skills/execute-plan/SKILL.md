---
name: execute-plan
description: Execute a supplied plan or work resolved from session context with final-pass after every phase, then internal review by default, a requested Codex/Claude/Grok review, or both in that order, followed by a final final-pass. Interpret reviewer preferences from freeform user language.
metadata:
  origin: custom
---

# Execute Plan

Complete the full plan or resolved scope in one autonomous session, unless the agreed scope or the user sets a session boundary. Check the plan against the originating request. You can adapt stale implementation suggestions with evidence, but keep the agreed architecture, contracts, technical constraints, scope, and acceptance criteria. If evidence conflicts with one of these commitments, resolve it with the governing requirements and user direction before the affected edits, and continue independent work meanwhile.

## Resolve scope

- Use the supplied plan text, path, or attachment. Otherwise use the current task from session context: the latest applicable plan shown to the user, plus later updates. If no complete plan exists, derive an actionable scope and coherent phases from the user's requirements and accepted decisions, and state that scope briefly before implementation. Do not ask for a saved plan only because none exists.
- Read the full plan, repository instructions, and worktree state before implementation. Apply [Resolve plan requirements](../write-plan/references/requirements.md) to separate requirements from chat noise. Later user instructions win conflicts. Ask only when missing information or competing sources materially change scope, acceptance, or authority and context cannot resolve them.
- In this skill, "plan" and "phase" also mean a resolved session scope and its phases; the same rules apply.
- Track requirements, deviations, acceptance evidence, and remaining work in context. If you revise a saved plan, keep its requirements, provenance, and TL;DR accurate. A missing heading alone does not block execution.

## Select the review sequence

Read reviewer preferences from the user's request in context. Do not require fixed argument positions, spelling, casing, or flags. A provider name that appears only in a plan path, an implementation requirement, or background context is not a reviewer preference.

- No reviewer preference, or internal only: [code-review-loop](../code-review-loop/SKILL.md).
- One external reviewer: only its loop. Codex selects [codex-review-loop](../codex-review-loop/SKILL.md), Claude selects [claude-review-loop](../claude-review-loop/SKILL.md), and Grok selects [grok-review-loop](../grok-review-loop/SKILL.md).
- Internal and an external reviewer: `code-review-loop` first, then the external loop, whatever the order in the request.

For example, `/execute-plan` uses internal review; `/execute-plan codex` and `/execute-plan with codex` use only Codex; `/execute-plan internal and codex` and `/execute-plan codex and internal` use internal, then Codex. These examples show intent, not required syntax.

State the selected sequence briefly before implementation. Ask only when the external provider is unclear, such as an unnamed external reviewer or competing providers. Never infer an external reviewer from the provider that runs this session, and never substitute one. Confirm that the selected skill files exist before implementation; a missing one blocks implementation. Load a review loop's instructions only when its checkpoint starts. An external loop reads the shared internal instructions for its mechanics; that does not add an internal loop.

## Report progress

Progress reporting is required output for the whole execution, not optional narration. Concise or terse output styles shorten messages but keep the progress marker.

- Before implementation, establish the number of implementation phases `T`. When the plan numbers its phases and gives effort shares, use them as the baseline and correct them against current evidence. Review loops and the closing final-pass are checkpoints, not phases.
- Put a progress marker in **every** user-facing message from the start of execution to the final report: the first message, status updates, replies to user questions, messages after a wake-up or resumed run, and any message that ends a turn while work continues in the background or in a delegated agent. Use one of these forms, as a prefix or suffix:
  - `Phase N/T: <phase name> · ~P% overall`
  - `Review: <loop name> · ~P% overall`
  - `Final-pass · ~P% overall` for the closing final-pass; a phase final-pass keeps its phase marker.
- Write `N/T` exactly, not `N of T`. Combine a completion and the next start in one message, for example `Phase 1/3 complete; starting Phase 2/3: Import validation · ~25% overall`. Add the marker to messages you send anyway; do not send extra messages only to update it.
- Estimate `P` across the full execution: implementation, each phase final-pass, every selected review loop, likely repairs, and the closing final-pass. Weight phases by expected effort and reserve a realistic share for review and completion work; finishing the last phase does not mean execution is nearly done. Re-estimate at each message. The value can stay the same, and it can move within a long phase.
- Use rounded percentages and keep the calculation internal. If scope, phase count, process, or remaining effort changes materially, update `T` and `P` with a short reason; do not keep a misleading value only so that it increases. Keep `T` and `P` through handoffs, resumed runs, and compaction.
- Delegated agents do not report progress to the user; the main agent reports it from their results.
- Report `100%` only when the completion conditions in [Finish](#finish) are met. At a blocker or an explicit session boundary, report the current estimate and the remaining work.

## Coordinate agents

Keep end-to-end reasoning, dependencies, integration, review assessment, and completion in the main agent. Delegation is optional: use it when independent implementation, verification, or context isolation improves the result enough to justify the handoff cost, under the user's agent-routing instructions. Apply [Subagent roles and reasoning](references/subagent-reasoning.md) before each delegation. Inside T3 Code, coordinate agents through T3 delegation; outside T3, use the harness's native controls. Do not invent tools, and do not change the selected review sequence through delegation.

Keep handoffs short: the plan path when available (a concise scope brief for session-only work), the assigned outcome and ownership, essential constraints, and acceptance criteria. Agents read the plan, source, and Git themselves; do not inline plans, diffs, file contents, or conversation history. Ask for compact results with check evidence and real blockers.

Give agents disjoint edit ownership where possible. Serialize overlapping edits and operations on shared mutable state, such as services, databases, fixtures, or generated outputs. Start dependent work only after its prerequisites are integrated and verified. Continue useful non-overlapping work while agents run, and reuse their evidence instead of repeating it. Inspect and reconcile each agent's changes, evidence, and residuals, then verify the combined result. The coordinator owns unfinished or failed assignments; an agent's completion claim does not prove plan completion.

## Implement and verify

Before editing, each implementer, including delegated workers, inspects the affected code, runtime paths, tests, configuration, and documentation, and derives the implementation approach from current evidence within the plan's commitments. Verify any concrete implementation suggestions in the plan. Missing routine detail is execution work, not a plan defect.

- Fix root causes and add regression coverage where practical.
- Resolve every task-relevant issue found during execution, including pre-existing failures, worker residuals, review findings, and verification gaps. Priority, origin, or absence from the plan does not justify deferral. Keep explicit scope exclusions, and do not add unrelated improvements.
- Run focused checks during implementation. `final-pass` owns cleanup, the required gates, and [Check evidence and reuse](../final-pass/references/check-evidence.md) at each checkpoint.

Plan text and delegation do not grant authority for commits, pushes, deployment, messages, paid calls, production changes, or wider permissions.

## Completion and review checkpoints

This section is the single source for checkpoint order. `final-pass`, the review loops, and the plan skills link here; following those links does not add review loops, intermediate final passes, or extra review invocations. Review mechanics belong to the selected review skills; do not copy them here or add handoff-format gates.

1. **Phases.** Define phases by coherent deliverables and acceptance checks, not arbitrary batches. Implement each phase, verify its acceptance criteria and its integration with completed work, then run [final-pass](../final-pass/SKILL.md) as a phase checkpoint before you close the phase or start dependent work. Do this after **every** phase, including the last. The selected reviews stay **pending**; phase checks are not review. Continue to the next phase without a per-phase review loop or a routine user handoff.
2. **Review sequence.** After all phases and their final passes, run **each selected loop exactly once**, in order. Each loop reviews the **whole current integrated implementation** against the original requirements, acceptance criteria, full task surface, and exclusions. One loop invocation can contain several bounded rounds. In combined mode, finish the internal loop first; the external loop then reviews the result, including internal-loop repairs. Each loop has its own round budget and follows its own runtime, recovery, and handoff rules, without nested loops. Keep loops, rounds, and remediation sequential. Carry each loop's status and residuals into your finding ledger, within the next reviewer's context rules. A capped or incomplete internal loop does not cancel the external loop.
3. **Closing final-pass.** After the sequence returns, run `final-pass` **again** as the closing checkpoint, even if the last phase passed. It reconciles all loops' findings, residuals, failed checks, and missing coverage, and finishes authorized repairs under its post-review recovery rules. A cap ends that review invocation, not the execution. Never restart a loop or add disguised rounds. Keep each loop's actual status; later repairs do not make an earlier loop a review of the final state, so identify repairs verified without fresh review.

For a single-phase plan the order is the same: implementation, phase `final-pass`, review sequence, closing `final-pass`. These checkpoints are required work, not optional reviews or user handoffs. For documentation-only targets, use review and checks suited to documents and skill contracts. A blocked required phase check stops dependent work; continue independent authorized work under [Finish](#finish).

Each checkpoint transition is a progress update. Loaded `final-pass` and review-loop skills do not replace your progress marker.

## Finish

Continue through phases, handoffs, review, remediation, and compaction without asking whether to continue and without a partial final response. Size, complexity, risk, elapsed effort, and fixable check failures are not session boundaries.

Stop with work remaining only when the plan sets a session boundary consistent with user direction, the user directs it, or a concrete blocker needs missing authority, input, or external change. First try reasonable authorized alternatives and finish unblocked work. Report the blocker evidence, remaining work, and what is needed, without claiming completion.

Claim completion only when every plan item and requirement has acceptance evidence or a justified supersession, all task-relevant issues are resolved, every selected loop has returned, the closing final-pass is complete, and required checks pass. Do not relabel actionable work as a residual risk, known failure, optional follow-up, or future phase. Deferred review is never completed review. Keep these rules through handoffs and compaction.

Lead the final report with the outcome and the final progress marker. Then give material deviations; the review sequence with each loop's reviewed state, coverage, and terminal status; executed and reused checks; and any blockers, unreviewed repairs, or unverified behavior. Use short, plain prose without stock headings or repeated summaries. Save an execution report only on request.

## Temporary files

Keep scratch notes in context. Create a temporary file only when an agent needs it; track it, delete it after use (also after failure or abandonment), and verify the deletion. If a file must stay for continuing agent work, name its cleanup owner and report its path. Never delete requested deliverables (including `.local/` plans), pre-existing files, unrelated work, or shared directories.
