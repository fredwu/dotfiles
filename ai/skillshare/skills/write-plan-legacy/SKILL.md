---
name: write-plan-legacy
description: Write a read-only, evidence-backed plan to remove legacy, deprecated, compatibility, duplicate-path, unused, dead, or obsolete database code from FeedBun-owned code while leaving Petal Pro boilerplate unchanged. Use for focused first-pass or follow-up legacy-removal audits where the database can be reset and a clean no-findings result is acceptable.
---

# Write Plan Legacy

Invoke `$write-plan` and follow it fully, adding the specialization below without weakening or replacing that workflow.

## Preserve the real requirement

Use the complete visible `$write-plan-legacy` user message as `$write-plan`'s canonical `## User requirement (verbatim)` payload. Do not expand it, fabricate a prompt, substitute this skill text, or label fixed skill constraints as user-authored.

## Constrain the audit

- Audit only FeedBun-owned code; leave Petal Pro boilerplate unchanged.
- Perform a deliberate first or follow-up legacy-removal sweep. Limit candidates to evidenced legacy or deprecated behavior, compatibility shims, dual reads or writes, parallel old/new paths for one responsibility, stale or dead code, and obsolete database fields, indexes, or related objects.
- Assume a database reset. Plan direct removal without legacy-data support, compatibility or deprecation paths, dual-operation periods, or transition machinery.
- Exclude intentional current-purpose fallback or redundancy, including LLM model/provider fleets and routing or failover; proper architectural layering; and unrelated quality, redesign, performance, style, or refactoring concerns.
- Accept no findings. Do not invent issues, keep weak candidates, nitpick, or expand scope for apparent substance.

## Require evidence

Trace each candidate through definitions, references, callers, persistence, configuration, tests, and runtime/framework registration. Before calling it removable, check dynamic dispatch, macros or callbacks, generated references, environment-specific configuration, dependency injection, external contracts, operational tooling, and intentional fallback.

Retain a finding only when repository evidence supports both legacy/dead status and a safe removal direction. Record uncertainty as an evidence gap.

## Plan the target state

For each finding, plan removal of the obsolete path and related code, tests, configuration, and database objects. Include focused verification of surviving FeedBun behavior and schema. Keep the investigation read-only: write but do not execute the plan.

Use repository evidence and best judgment to decide all ordinary removal mechanics and other low-impact or readily reversible details, and integrate them into the recommended target state and execution steps. Multiple reasonable options alone do not justify a decision-table entry. Reserve that table for unresolved choices that require user judgment because they would fundamentally or drastically change the core architecture or implementation strategy, authorize destructive or expensive work beyond the assumed database reset, or be difficult to reverse.
