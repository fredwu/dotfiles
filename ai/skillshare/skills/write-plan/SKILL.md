---
name: write-plan
description: Investigate a repository or workflow read-only and save an evidence-backed architectural plan with outcome-based phases and acceptance criteria.
---

# Write Plan

Save a self-contained plan that defines the architecture, intended outcomes, and acceptance criteria. Leave routine implementation decisions to execution. Only create or edit that plan; keep implementation and external state unchanged.

## Original planning

Before investigation, exclude all other plans in the repository. Do not discover, read, search, compare, or reuse them, or derive requirements, decisions, structure, sequencing, or findings from them. Exclude plan files and directories from broad content searches. Destination path and existence checks are allowed to prevent collisions, without reading existing plan contents.

Apply this exclusion to delegated research and review, and to plan content in summaries, memory, or already-loaded context. Ground the original plan in current user requirements, repository instructions, actual implementation and tests, and relevant non-plan documentation. Other plans and plan-derived material are not evidence, even when they describe the same task.

## Requirement and destination

Read and apply [Resolve plan requirements](references/requirements.md) within these source exclusions; its fallback to stored requirements or digests must not use other plans or plan-derived material. Start with concise `## User requirements`, then `## TL;DR` immediately after the requirements and any update subsection. Capture current intent and source, not a transcript of the chat.

Honor an explicit output path. Otherwise use `.local/<topic>-plan-<agent>.md`, with a concise kebab-case topic and runtime-derived `claude`, `codex`, `grok`, or `agent`. For collisions, insert the first available number before the agent suffix. Never overwrite an unrelated plan; report explicit-path conflicts.

## Coordinate agents

Keep end-to-end reasoning, decisions, and plan synthesis with the main agent. Follow the repository's agent-routing rules. Consider delegation when independent research, verification, or context isolation improves the result enough to justify coordination and handoff costs. Keep tightly coupled, sequential, or context-heavy work in one loop, either the main agent or a bounded worker. Complexity, domain labels, and planning stages do not by themselves justify separate agents. Judge the choice by whole-task quality, latency, and regressions; neither delegation nor a fixed agent count is required. Before delegating, apply [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md). Use only callable capabilities; do not substitute external reviewer services.

Choose assignments with clear context boundaries and few dependencies on the rest of the investigation, such as independent evidence questions or separate components with stable interfaces. Continue useful non-overlapping work while they run.

Give each agent the outcome, precise question, scope and ownership, relevant requirements and decisions, dependencies, acceptance criteria, and all read-only, authority, and original-plan exclusions. Supply the context needed for that assignment and let the agent load further permitted references as needed. Require a compact result for the parent with source locations, supporting evidence, assumptions, gaps, and exact check results. Keep plan writing with one owner. Reuse relevant completed evidence; duplicate investigation only for deliberate corroboration.

Consider a separate read-only challenge of the current draft when independent scrutiny would help expose missing requirements, weak evidence, or unsafe sequencing. Give the reviewer the draft, original requirements, and permitted sources without steering its verdict. Await all assigned work, reconcile conflicting claims against evidence, and incorporate supported results before finalizing. Without an independent reviewer, perform the check directly and report its limits accurately.

## Investigate and decide

Read repository instructions and worktree state. Use read-only inspection and non-mutating checks. Starting services, using production, incurring cost, or making external calls requires explicit authorization. Put checks needing additional writes or authority in the plan instead.

Inspect system responsibilities, boundaries and contracts, data flow, persistence, integrations, failure modes, and existing tests only far enough to justify architectural decisions and feasibility. Verify material claims; distinguish facts, inferences, gaps, and recommendations with precise citations. Identify material, evidenced cleanup in the directly affected scope and plan safe removal; leave exhaustive removal tracing to execution. Do not invent findings or expand scope.

Preserve user-specified technical constraints. Include concrete technical detail when needed to establish an architectural invariant, material risk, feasibility, or an explicit user requirement. Otherwise defer function/file-by-file edits, algorithms, exact schemas or code, exhaustive call traces, and detailed test mechanics to execution agents, who must investigate them independently.

Prefer proportionate clean-slate solutions. Add compatibility, migration, deprecation, or dual operation only when explicitly required. Treat security boundaries and data guarantees as provisional invariants; existing behavior and future use cases do not automatically become requirements.

Resolve decisions and risks with the best-supported recommendation, including high-risk, destructive, expensive, or difficult-to-reverse choices. Risk alone is not a reason to defer to the user. With incomplete evidence, state assumptions, a conditional recommendation, and a decisive check or fallback. Include mitigation, residual risk, and applicable recovery steps. Recommendations do not authorize execution; retain required authorization before affected actions and continue independent planning when essential input is unavailable.

For each material finding, explain the evidence, requirement impact, target behavior, relevant tradeoffs, dependencies, and uncertainty. Prioritize and deduplicate. Stop when evidence supports the chosen architecture and feasible outcome-based phases, with explicit conditions for remaining gaps.

## Plan and verify

State that the plan completes in one autonomous execution session unless the user explicitly requests otherwise. Include implementation, cleanup, and verification, and use [Completion and review checkpoints](../execute-plan/SKILL.md#completion-and-review-checkpoints) as the authority for checkpoint order and reviewer selection: `final-pass` after every phase, the selected review sequence over all integrated implementation after all phases, then a final `final-pass`. Do not add per-phase review loops. Resolve discovered task-relevant issues within execution. Phases, milestones, checkpoints, size, complexity, risk, and copied schedules do not justify session breaks or routine confirmation handoffs. Preserve concrete blockers and required authorization for affected actions; keep independent work executable.

Choose a structure proportionate to the task. After the requirements and TL;DR, cover scope and non-goals, constraints and assumptions, relevant current behavior, chosen architecture with evidence and rationale, system responsibilities and boundary contracts, coherent outcome-based phases and dependencies, observable acceptance criteria, and material risks or blockers. Carry recommendations into phase outcomes; reserve open items for essential unavailable input or required execution authorization, with a recommended path and conditions wherever possible. Avoid repeated checklists, exhaustive alternatives, and speculative detail.

Where useful, identify independently assignable steps, ownership boundaries, prerequisites, shared files or resources needing serialization, and review or integration opportunities. Explain what must be complete before dependent work starts. Give the executor enough context to choose delegation at runtime; do not prescribe a fixed agent topology or assume unavailable roles or tools.

Read back the saved plan; check requirement coverage and provenance, TL;DR accuracy, evidence, dependencies, validation, and scope, and remove contradictions and duplication. Link the plan in chat and briefly state material verification limits, high-risk recommendations with reasons, mitigations and residual risks, and essential missing input or required execution authorization. Use plain language; omit praise, process narration, and routine approval requests. Do not execute the plan.

Keep working state in context; create no scratch files, reports, ledgers, or supporting artifacts. Preserve the saved plan, including in `.local/`. For execution steps needing temporary files, require a concrete agent purpose, clear task ownership, and removal after use, including failure or abandonment; preserve unrelated files and durable deliverables.
