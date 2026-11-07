---
name: write-plan
description: Investigate a repository or workflow read-only and save an evidence-backed architectural plan with outcome-based phases and acceptance criteria.
metadata:
  origin: custom
---

# Write Plan

Investigate read-only and save a self-contained plan that defines the architecture, intended outcomes, and acceptance criteria. Leave routine implementation decisions to execution. Create or edit only that plan; do not change implementation or external state, and do not execute the plan.

Read and apply [Plan standards](references/plan-standards.md) and [Resolve plan requirements](references/requirements.md).

## Original planning

Before you investigate, exclude all other plans in the repository. Do not discover, read, search, compare, or reuse them, and do not derive requirements, decisions, structure, sequencing, or findings from them. Exclude plan files and directories from broad content searches. You can check whether a destination path exists, without reading existing plans.

The exclusion also covers delegated research and review, and plan content in summaries, memory, or already-loaded context. Ground the plan in current user requirements, repository instructions, the actual implementation and tests, and non-plan documentation. When the requirements reference falls back to stored requirements or digests, it must not use other plans or plan-derived material.

## Destination

Honor an explicit output path, and report a conflict instead of overwriting. Otherwise follow the plan file name rule with `<kind>` = `plan`, for example `.local/261031-import-validation-plan-claude.md`.

## Coordinate agents

Keep end-to-end reasoning, decisions, and plan writing in the main agent. Delegation is optional; use it when independent research, verification, or context isolation justifies the handoff cost, under the user's agent-routing instructions and [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md). Good assignments are independent evidence questions or separate components with stable interfaces. Inside T3 Code, use T3 delegation; otherwise use the harness's native controls. Do not substitute external reviewer services.

Give each agent the outcome, a precise question, scope, relevant requirements and decisions, dependencies, acceptance criteria, and all read-only, authority, and original-planning exclusions. Ask for a compact result with source locations, evidence, assumptions, gaps, and exact check results. Continue non-overlapping work while agents run, reuse their evidence, and duplicate investigation only for deliberate corroboration.

When independent scrutiny would expose missing requirements, weak evidence, or unsafe sequencing, run [code-review](../code-review/SKILL.md) once on the draft, with a short brief that names the draft and the requirements. The reviewer reads the draft and permitted repository evidence itself. Keep the draft unchanged during the review, and keep the original-planning exclusions. This does not authorize implementation or a review loop. Reconcile the findings against evidence, and report which draft was reviewed and what changed after. Without an independent reviewer, check the draft yourself and report that limit.

## Investigate and decide

Read repository instructions and worktree state. Use read-only inspection and non-mutating checks only. Starting services, using production, incurring cost, or making external calls needs explicit authorization; put checks that need writes or extra authority into the plan instead.

Inspect responsibilities, boundaries and contracts, data flow, persistence, integrations, failure modes, and existing tests only far enough to justify the architecture and its feasibility. Verify material claims, separate facts, inferences, gaps, and recommendations, and cite sources precisely. Plan safe removal of evidenced cleanup in the directly affected scope; leave exhaustive tracing to execution.

Keep user-specified technical constraints. Include concrete technical detail only when it establishes an architectural invariant, a material risk, feasibility, or an explicit requirement. Otherwise leave file-by-file edits, algorithms, exact schemas or code, exhaustive call traces, and test mechanics to execution agents, who investigate them independently.

Prefer proportionate clean-slate solutions. Add compatibility, migration, deprecation, or dual operation only when explicitly required. Treat security boundaries and data guarantees as invariants unless the requirements change them; existing behavior and possible future uses do not automatically become requirements.

For each material finding, give the evidence, requirement impact, target behavior, tradeoffs, dependencies, and uncertainty. Prioritize and deduplicate. Stop investigating when evidence supports the chosen architecture and feasible phases, with explicit conditions for remaining gaps.

## Write and verify

Scale the structure to the task. After the requirements and TL;DR, cover scope and non-goals, constraints and assumptions, relevant current behavior, the chosen architecture with evidence and rationale, responsibilities and boundary contracts, numbered outcome-based phases with dependencies, observable acceptance criteria, and material risks or blockers. Put recommendations into phase outcomes. Avoid repeated checklists, exhaustive alternatives, and speculative detail.

Where useful, mark independently assignable work, ownership boundaries, prerequisites, and shared files or resources that need serialization, and say what must finish before dependent work starts. Give the executor enough context to choose delegation at runtime; do not prescribe a fixed agent topology or assume unavailable roles or tools.

Read back the saved plan. Check requirement coverage and provenance, TL;DR accuracy, phase numbering and effort shares, evidence, dependencies, validation, and scope, and remove contradictions and duplication. Then respond under the plan standards.
