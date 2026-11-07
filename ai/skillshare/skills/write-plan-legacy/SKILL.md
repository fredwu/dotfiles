---
name: write-plan-legacy
description: Save a legacy-removal plan for FeedBun-owned code, excluding Petal Pro boilerplate and assuming a database reset. Use for initial or follow-up cleanup audits.
metadata:
  origin: custom
---

# Write Plan Legacy

Apply [write-plan](../write-plan/SKILL.md) in full, with the constraints below. The user's message is the task brief. Record these constraints as skill constraints, not as the user's words, and do not copy the invocation into the requirements.

- Audit FeedBun-owned code only; leave Petal Pro boilerplate unchanged.
- Find evidenced obsolete, duplicate, dead, superseded, or unnecessary compatibility code and database objects.
- Assume a database reset and plan direct removal, without legacy-data support or transition machinery. This assumption does not authorize the reset.
- Exclude intentional current-purpose fallback or redundancy, especially LLM fleets and routing or failover, proper architectural layering, and unrelated redesign or refactoring.
- A clean result is valid; uncertain candidates are evidence gaps, not removals.

Before you propose a removal, trace definitions, callers, persistence, configuration, tests, dynamic or framework registration, generated references, external contracts, and operational tooling as relevant. Each supported removal includes the directly related code, tests, configuration, and schema, and focused checks of the surviving behavior. Save the plan; do not execute it.
