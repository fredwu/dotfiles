---
name: write-plan-legacy
description: Save a legacy-removal plan for FeedBun-owned code, excluding Petal Pro boilerplate and assuming a database reset. Use for initial or follow-up cleanup audits.
---

# Write Plan Legacy

Use `$write-plan` with these constraints; its saved-plan, verbatim requirement, read-only, temporary-file, verification, and default of one autonomous execution session apply. Only explicit user direction changes that session default. The canonical requirement is the complete visible `write-plan-legacy` user message, not this skill's text.

- Audit FeedBun-owned code only; leave Petal Pro boilerplate unchanged.
- Find evidenced obsolete, duplicate, dead, superseded, or unnecessary compatibility code and database objects.
- Assume a database reset and plan direct removal, without legacy-data support or transition machinery. This assumption does not authorize performing the reset.
- Exclude intentional current-purpose fallback/redundancy, especially LLM fleets and routing/failover, proper architectural layering, and unrelated redesign or refactoring.
- Accept a clean result; uncertain candidates are evidence gaps.

Before proposing removal, trace definitions, callers, persistence, configuration, tests, dynamic/framework registration, generated references, external contracts, and operational tooling as relevant. Include directly related code, tests, configuration, and schema in each supported removal, with focused checks of surviving behavior. Apply `write-plan`'s autonomous risk and decision handling to removal choices, including high-risk recommendations and conditional choices for evidence gaps. Call out high-risk recommendations, mitigations, and residual risks in chat. Save the plan; do not execute it.
