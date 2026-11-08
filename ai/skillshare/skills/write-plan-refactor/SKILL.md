---
name: write-plan-refactor
description: Save a refactoring audit plan for project-owned code, covering architecture, data flow, security, code quality, readability, tests, and documentation. Use only on explicit invocation, for periodic audits after feature work.
metadata:
  origin: custom
---

# Write Plan Refactor

Audit project-owned code, tests, and documentation for structural problems and improvement opportunities, and save a prioritized refactoring plan. Apply [write-plan](../write-plan/SKILL.md) in full and the [audit plan rules](../write-plan/references/audit-plans.md), with the rules below. The default topic is `refactor-audit`. Save the plan; do not execute it.

## Approach

Find root causes, not symptoms. Group related findings by their shared cause, such as a missing boundary, a misplaced responsibility, or an inconsistent convention, and plan one coherent change for each cause. Do not plan patches on patches or local workarounds for a structural problem.

Prefer the simplest design that meets the current requirements. The benefit of each change to correctness, security, clarity, or cost of change must be clearly larger than its effort and risk. Remove or flatten unnecessary abstraction, indirection, configuration, and generality. Do not add layers, patterns, frameworks, or extension points for speculative needs. Follow the project's existing idioms unless they are the problem.

## Threshold

Report only issues that have a material effect on the code as it is used now. Leave out:

- Style preferences, naming or formatting nitpicks, and alternatives that are only different, not better.
- Highly unlikely edge cases, and hardening against inputs or states that the code cannot reach.
- Isolated small issues that do not show a pattern and do not block a planned change.

Healthy code needs no change; a short plan or a clean result is valid.

## Code

Examine the lenses that apply to the stack:

- **Architecture:** module and context boundaries, responsibilities, dependency direction and cycles, coupling, and layering. For example, web modules that bypass Phoenix contexts, or business logic in controllers, LiveViews, or components.
- **Data flow:** sources of truth, duplicated or derived state that can drift, validation and normalization at boundaries, transaction and side-effect order, and error propagation, such as swallowed errors and inconsistent result shapes.
- **Security:** authentication and authorization at each entry point, input validation and output encoding, injection, secret handling, sensitive data in logs or responses, and unsafe defaults.
- **Code quality:** duplicated logic or knowledge, functions and modules with too many jobs, complex conditionals, different patterns for the same job, and weak contracts or types.
- **Readability:** names, file and module layout, and comments. Code must explain itself; a comment explains only intent, a tradeoff, or a constraint that the code cannot show.

## Tests

Treat tests as first-class code, and prefer quality to quantity. Judge the suite by the confidence it gives for changes and refactors, not by test count or coverage.

- **Protection:** tests must protect behavior contracts, boundaries, security, data integrity, and known regressions, through public interfaces and at the right layer. Where a planned refactor has no safety net, plan characterization tests before it.
- **Design:** find tests that couple to implementation details, mock too much, share fragile setup, or are hard to read or have unclear names. Plan to rewrite them.
- **Trim:** find redundant tests, tests of framework or library behavior, and trivial assertions. Plan to merge or delete them. Each deletion names the surviving test or contract that covers its behavior, or says why the behavior needs no test.

Test-suite speed and coverage tooling are the focus of `write-plan-perf`.

## Documentation

Treat documentation as first-class, and prefer quality to quantity. Audit READMEs, guides, architecture notes, module and function docs, and repository instructions for agents. Find inaccurate, stale, duplicated, or contradictory content, and gaps in what a contributor or agent needs to work safely. Plan to correct, merge, trim, or delete it. Keep one source of truth for each fact, near the code that it describes.

## Plan content

Rank findings by evidenced impact: security and correctness first, then cost of change, then readability. For each finding, give the root cause, representative locations, the target design, and why it is simpler. Do not list every occurrence.

Put safety-net tests before the refactors that need them. Each phase leaves the code working and consistent, and updates its tests and documentation. A refactor keeps behavior unless the plan names the behavior change, such as a security fix.

Removal of code that a refactor makes obsolete stays in scope. Standalone legacy-removal and performance findings are notes for `write-plan-legacy` and `write-plan-perf`.
