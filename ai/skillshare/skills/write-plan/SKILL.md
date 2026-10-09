---
name: write-plan
description: Investigate a repository or workflow read-only and save an evidence-backed, executable plan for implementation, audit, architecture, or remediation.
---

# Write Plan

Save a self-contained executable plan. Only create or edit that plan; keep implementation and external state unchanged.

## Original planning

Before investigation, exclude all other plans in the repository. Do not discover, read, search, compare, or reuse them, or derive requirements, decisions, structure, sequencing, or findings from them. Exclude plan files and directories from broad content searches. Destination path and existence checks are allowed to prevent collisions, without reading existing plan contents.

Apply this exclusion to delegated research and review, and to plan content in summaries, memory, or already-loaded context. Ground the original plan in current user requirements, repository instructions, actual implementation and tests, and relevant non-plan documentation. Other plans and plan-derived material are not evidence, even when they describe the same task.

## Requirement and destination

Read and apply [Resolve plan requirements](references/requirements.md) within these source exclusions; its fallback to stored requirements or digests must not use other plans or plan-derived material. Start with concise `## User requirements`, then `## TL;DR` immediately after the requirements and any update subsection. Capture current intent and source, not a transcript of the chat.

Honor an explicit output path. Otherwise use `.local/<topic>-plan-<agent>.md`, with a concise kebab-case topic and runtime-derived `claude`, `codex`, `grok`, or `agent`. For collisions, insert the first available number before the agent suffix. Never overwrite an unrelated plan; report explicit-path conflicts.

## Coordinate agents

Consider subagents early and when new evidence opens independent work. Prefer delegation when available, permitted, and likely to improve speed, coverage, or independent scrutiny enough to justify coordination. The agent decides; no fixed agent count or mandatory delegation applies. Direct work is appropriate for small or tightly coupled tasks, or when delegation is unavailable. Use only callable capabilities; do not invent tools or substitute external reviewer services.

When delegating, keep the coordinator focused on decomposition, evidence reconciliation, decisions, and plan synthesis. Split distinct read-only investigations by behavior, component, or evidence question, and continue useful non-overlapping work while they run. Prefer `worker` for complex or uncertain investigation and review, and `fastworker` for simple bounded evidence gathering or checks; use the closest available capabilities when these roles are absent.

Give each agent the relevant current requirements, repository context, precise question and scope, dependencies, acceptance criteria, and all read-only, authority, and original-plan exclusions. Request source locations, supporting evidence, assumptions, gaps, and check results. Keep plan writing with one owner. Reuse relevant completed evidence; duplicate investigation only for deliberate corroboration.

Consider a separate read-only challenge of the current draft when independent scrutiny would help expose missing requirements, weak evidence, or unsafe sequencing. Give the reviewer the draft, original requirements, and permitted sources without steering its verdict. Await all assigned work, reconcile conflicting claims against evidence, and incorporate supported results before finalizing. Without an independent reviewer, perform the check directly and report its limits accurately.

## Investigate and decide

Read repository instructions and worktree state. Use read-only inspection and non-mutating checks. Starting services, using production, incurring cost, or making external calls requires explicit authorization. Put checks needing additional writes or authority in the plan instead.

Trace relevant behavior, data flow, persistence, integrations, failure paths, and tests. Verify material claims; distinguish facts, inferences, gaps, and recommendations with precise citations. Inspect the directly affected scope once for confirmed obsolete, duplicate, dead, or unnecessary compatibility code and plan safe removal. Do not invent findings or expand scope.

Prefer proportionate clean-slate solutions. Add compatibility, migration, deprecation, or dual operation only when explicitly required. Treat security boundaries and data guarantees as provisional invariants; existing behavior and future use cases do not automatically become requirements.

Resolve decisions and risks with the best-supported recommendation, including high-risk, destructive, expensive, or difficult-to-reverse choices. Risk alone is not a reason to defer to the user. With incomplete evidence, state assumptions, a conditional recommendation, and a decisive check or fallback. Include mitigation, residual risk, and applicable recovery steps. Recommendations do not authorize execution; retain required authorization before affected actions and continue independent planning when essential input is unavailable.

For each material finding, explain the evidence, requirement impact, target behavior, relevant tradeoffs, dependencies, and uncertainty. Prioritize and deduplicate. Stop when evidence supports an executable plan with explicit conditions for any remaining gaps.

## Plan and verify

State that the plan completes in one autonomous execution session unless the user explicitly requests otherwise. Include implementation, cleanup, and verification, and apply [Completion and review checkpoints](../execute-plan/SKILL.md#completion-and-review-checkpoints): resolve discovered task-relevant issues within execution and require `code-review-loop` followed by `final-pass` after each phase for long or complex work, or once after all implementation for short, simple work. Phases, milestones, checkpoints, size, complexity, risk, and copied schedules do not justify session breaks or routine confirmation handoffs. Preserve concrete blockers and required authorization for affected actions; keep independent work executable.

Choose a structure proportionate to the task. After the requirements and TL;DR, cover scope and assumptions, relevant current behavior, prioritized findings and chosen direction, concrete ordered changes and likely locations, dependencies, acceptance checks, and material risks or blockers. Carry recommendations into the steps; reserve open items for essential unavailable input or required execution authorization, with a recommended path and conditions wherever possible. Avoid repeated checklists, exhaustive alternatives, and speculative detail.

Where useful, identify independently assignable steps, ownership boundaries, prerequisites, shared files or resources needing serialization, and review or integration opportunities. Explain what must be complete before dependent work starts. Give the executor enough context to choose delegation at runtime; do not prescribe a fixed agent topology or assume unavailable roles or tools.

Read back the saved plan; check requirement coverage and provenance, TL;DR accuracy, evidence, dependencies, validation, and scope, and remove contradictions and duplication. Link the plan in chat and briefly state material verification limits, high-risk recommendations with reasons, mitigations and residual risks, and essential missing input or required execution authorization. Use plain language; omit praise, process narration, and routine approval requests. Do not execute the plan.

Keep working state in context; create no scratch files, reports, ledgers, or supporting artifacts. Preserve the saved plan, including in `.local/`. For execution steps needing temporary files, require a concrete agent purpose, clear task ownership, and removal after use, including failure or abandonment; preserve unrelated files and durable deliverables.
