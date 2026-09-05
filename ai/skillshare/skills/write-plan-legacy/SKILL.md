---
name: write-plan-legacy
description: Write a read-only legacy-removal plan for FeedBun-owned code, leaving Petal Pro boilerplate unchanged. Use for first-pass or follow-up cleanup audits where a database reset is assumed and no findings is a valid result.
---

# Write Plan Legacy

Use `$write-plan` with these constraints. Its requirement, read-only, artifact, evidence, decision, and review rules still apply.

Use the complete visible `write-plan-legacy` user message as the canonical verbatim requirement. Do not substitute this skill's text or present its constraints as user-authored.

## Scope

- Audit FeedBun-owned code only; leave Petal Pro boilerplate unchanged.
- Seek evidenced legacy/deprecated behavior, redundant or duplicate implementations, unnecessary compatibility shims, dual reads/writes, superseded paths, dead/unused code, and obsolete database fields, indexes, or related objects.
- Assume a database reset. Plan direct removal without legacy-data support, deprecation periods, dual operation, or transition machinery.
- Exclude intentional current-purpose fallback/redundancy, including LLM model/provider fleets and routing/failover; proper architectural layering; and unrelated redesign, performance, style, or refactoring.
- Accept a clean result. Keep uncertain candidates as evidence gaps, not findings.

## Evidence and removal plan

Trace candidates through definitions, references/callers, persistence, configuration, tests, and runtime/framework registration. Check dynamic dispatch, macros/callbacks, generated references, environment-specific configuration, dependency injection, external contracts, operational tooling, and intentional fallback before declaring removal safe.

For each supported finding, plan removal of the obsolete path and related code, tests, configuration, and database objects, with focused verification of surviving FeedBun behavior and schema. Write the plan; do not execute it.

Decide ordinary removal mechanics using evidence and judgment. The inherited user-decision threshold applies; the assumed database reset does not itself require a decision-table entry or authorize performing the reset.
