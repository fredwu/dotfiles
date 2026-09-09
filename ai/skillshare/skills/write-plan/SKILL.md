---
name: write-plan
description: Investigate a repository or workflow read-only and save an evidence-backed, executable plan for implementation, audit, architecture, or remediation.
---

# Write Plan

Save a self-contained executable plan. Only create or edit that plan; keep implementation and external state unchanged.

## Requirement and destination

Read and apply [Resolve plan requirements](references/requirements.md) for new plans and revisions. Start with concise `## User requirements`, then `## TL;DR` immediately after the requirements and any update subsection. Capture current intent and source, not a transcript of the chat.

Honor an explicit output path. Otherwise use `.local/<topic>-plan-<agent>.md`, with a concise kebab-case topic and runtime-derived `claude`, `codex`, `grok`, or `agent`. For collisions, insert the first available number before the agent suffix. Never overwrite an unrelated plan; report explicit-path conflicts.

## Investigate and decide

Read repository instructions and worktree state. Use read-only inspection and non-mutating checks. Starting services, using production, incurring cost, or making external calls requires explicit authorization. Put checks needing additional writes or authority in the plan instead.

Trace relevant behavior, data flow, persistence, integrations, failure paths, and tests. Verify material claims; distinguish facts, inferences, gaps, and recommendations with precise citations. Inspect the directly affected scope once for confirmed obsolete, duplicate, dead, or unnecessary compatibility code and plan safe removal. Do not invent findings or expand scope.

Prefer proportionate clean-slate solutions. Add compatibility, migration, deprecation, or dual operation only when explicitly required. Treat security boundaries and data guarantees as provisional invariants; existing behavior and future use cases do not automatically become requirements.

Resolve decisions and risks with the best-supported recommendation, including high-risk, destructive, expensive, or difficult-to-reverse choices. Risk alone is not a reason to defer to the user. With incomplete evidence, state assumptions, a conditional recommendation, and a decisive check or fallback. Include mitigation, residual risk, and applicable recovery steps. Recommendations do not authorize execution; retain required authorization before affected actions and continue independent planning when essential input is unavailable.

For each material finding, explain the evidence, requirement impact, target behavior, relevant tradeoffs, dependencies, and uncertainty. Prioritize and deduplicate. Delegate independent read-only evidence scopes when useful; reconcile their results. Stop when evidence supports an executable plan with explicit conditions for any remaining gaps.

## Plan and verify

State that the plan completes in one autonomous execution session unless the user explicitly requests otherwise. Include implementation, review, remediation, cleanup, and verification. Phases, milestones, checkpoints, size, complexity, risk, and copied schedules do not justify session breaks or routine confirmation handoffs. Preserve concrete blockers and required authorization for affected actions; keep independent work executable.

Choose a structure proportionate to the task. After the requirements and TL;DR, cover scope and assumptions, relevant current behavior, prioritized findings and chosen direction, concrete ordered changes and likely locations, dependencies, acceptance checks, and material risks or blockers. Carry recommendations into the steps; reserve open items for essential unavailable input or required execution authorization, with a recommended path and conditions wherever possible. Avoid repeated checklists, exhaustive alternatives, and speculative detail.

Read back the saved plan; check requirement coverage and provenance, TL;DR accuracy, evidence, dependencies, validation, and scope, and remove contradictions and duplication. Use an independent challenge when helpful. Link the plan in chat and briefly state material verification limits, high-risk recommendations with reasons, mitigations and residual risks, and essential missing input or required execution authorization. Use plain language; omit praise, process narration, and routine approval requests. Do not execute the plan.

Keep working state in context; create no scratch files, reports, ledgers, or supporting artifacts. Preserve the saved plan, including in `.local/`. For execution steps needing temporary files, require a concrete agent purpose, clear task ownership, and removal after use, including failure or abandonment; preserve unrelated files and durable deliverables.
