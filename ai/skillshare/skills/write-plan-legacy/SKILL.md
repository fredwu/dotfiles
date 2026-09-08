---
name: write-plan-legacy
description: Save a legacy-removal plan for FeedBun-owned code, excluding Petal Pro boilerplate and assuming a database reset. Use for initial or follow-up cleanup audits.
---

# Write Plan Legacy

Use `$write-plan` with the constraints below, including its authority, autonomous session, risk handling, temporary-file, verification, and chat rules. The canonical requirement is the complete visible `write-plan-legacy` user message, not this skill's text.

- Audit FeedBun-owned code only; leave Petal Pro boilerplate unchanged.
- Find evidenced obsolete, duplicate, dead, superseded, or unnecessary compatibility code and database objects.
- Assume a database reset and plan direct removal, without legacy-data support or transition machinery. This assumption does not authorize performing the reset.
- Exclude intentional current-purpose fallback/redundancy, especially LLM fleets and routing/failover, proper architectural layering, and unrelated redesign or refactoring.
- Accept a clean result; uncertain candidates are evidence gaps.

Before proposing removal, trace definitions, callers, persistence, configuration, tests, dynamic/framework registration, generated references, external contracts, and operational tooling as relevant. Include directly related code, tests, configuration, and schema in each supported removal, with focused checks of surviving behavior. Save the plan; do not execute it.
