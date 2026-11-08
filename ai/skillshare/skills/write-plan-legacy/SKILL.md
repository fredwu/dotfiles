---
name: write-plan-legacy
description: Save a legacy-removal plan for project-owned code, assuming a reset of project-owned persisted state. Use only on explicit invocation, for initial or follow-up cleanup audits.
metadata:
  origin: custom
---

# Write Plan Legacy

Audit project-owned code for legacy that can go, and save a removal plan. Apply [write-plan](../write-plan/SKILL.md) in full and the [audit plan rules](../write-plan/references/audit-plans.md), with the rules below. The default topic is `legacy-removal`. Save the plan; do not execute it.

## Find

Find evidenced obsolete, duplicate, dead, superseded, or unnecessary compatibility code, configuration, dependencies, feature flags, documentation, and persisted-state objects, such as database tables, columns, indexes, and enum values, or client storage keys and caches.

Keep intentional current-purpose fallback and redundancy, such as LLM fleets, multi-provider routing, failover, retries, graceful degradation, and fail-closed defaults. Also keep proper architectural layering, and leave out unrelated redesign or refactoring.

## Persisted state

Assume a reset of project-owned persisted state, and plan direct removal without legacy-data support or transition machinery. This assumption does not authorize the reset. Repository rules and the brief override it, for example a rule that protects committed migration history or requires user data to be kept.

## Trace

Before you propose a removal, trace definitions, callers, persistence, configuration, tests, dynamic or framework registration, generated references, external contracts, and operational tooling as relevant.
