---
name: write-plan-audit
description: Save a combined refactoring and performance audit plan for project-owned code (explicit invocation only).
metadata:
  origin: custom
---

# Write Plan Audit

Audit project-owned code, runtime performance, tests, and documentation in one pass, and save a single coherent, prioritized plan. Read and apply `write-plan` in full, the audit plan rules (`write-plan/references/audit-plans.md`), `write-plan-refactor`, and `write-plan-perf`, with the synthesis rules below. Use `audit` as the default topic instead of `refactor-audit` or `perf-audit`. Save the plan; do not execute it.

## Combined scope

Both `write-plan-refactor` and `write-plan-perf` are in scope as one audit:

- Override `write-plan-refactor`'s handoffs to `write-plan-perf` and `write-plan-perf`'s narrower focus: neither structural/legacy/documentation findings nor runtime-performance/test-speed/coverage findings are relegated to out-of-scope notes.
- Only evidenced findings outside both skills become brief notes under `audit-plans.md`.
- Use `write-plan-perf`'s `Measure` rules during investigation so findings combine measurement with static evidence where safe and practical.

## Synthesis

Produce one integrated plan, not two separate audits stitched together:

- Satisfy both skills' plan-content requirements inside one unified structure (one `## User requirements`, one `## TL;DR`, one baseline table, and one consecutive `Phase 1`..`Phase N` sequence totaling 100%).
- Deduplicate across both skills and group by shared root cause. When a structural problem and a performance problem share a cause—such as misplaced boundaries causing N+1 queries, duplicated state causing redundant renders, or legacy code inflating bundle, compile, or test cost—plan one coherent change instead of separate refactor and optimization phases over the same area.
- Unify test-suite work across `write-plan-refactor` (`Tests`) and `write-plan-perf` (`Test suite`). Do not rewrite or speed up tests slated for deletion, movement to a faster layer, or removal alongside dead code.
- Reconcile behavior guarantees across both skills: keep behavior, security boundaries, and data guarantees unchanged except where a refactoring finding explicitly names a behavior change (such as a security fix or dropped legacy-data support).

## Ranking and phase order

Rank findings across both audits together: security and correctness first, then high-impact performance and structural cost-of-change findings (weighed by evidenced impact and confidence against effort and risk), then readability and lower-impact cleanups.

Sequence phases so lenses reinforce each other instead of churning the same code, while keeping each underlying skill's ordering rules:

1. Capture missing performance baselines early when runtime measurement was unavailable during investigation.
2. Put legacy and dead-code removals before refactors or optimizations around them, so no phase reshapes or optimizes code a later phase deletes.
3. Put safety-net or characterization tests before refactors or risky optimizations (such as caching or concurrency changes) that lack protection.
4. Put structural refactors before—or unified with—local performance optimizations in the same area, so optimizations target the final design rather than code about to be reshaped.
