---
name: write-plan-legacy
description: Write a read-only, evidence-backed plan to remove legacy, deprecated, compatibility, duplicate-path, unused, dead, or obsolete database code from FeedBun-owned code while leaving Petal Pro boilerplate unchanged. Use for focused first-pass or follow-up legacy-removal audits where the database can be reset and a clean no-findings result is acceptable.
---

# Write Plan Legacy

Invoke `$write-plan` and follow it fully. Apply the constraints below as this skill's specialization; do not duplicate, weaken, or replace the `$write-plan` workflow.

## Preserve the real requirement

Preserve the complete visible user message that invoked `$write-plan-legacy` as the canonical `## User requirement (verbatim)` payload required by `$write-plan`. Do not expand the invocation into a fabricated prompt, substitute this skill's text for the user's message, or present these fixed skill constraints as user-authored content.

## Constrain the audit

- Audit only FeedBun-owned code. Leave Petal Pro boilerplate unchanged and exclude recommendations that would modify it.
- Treat the audit as a deliberate legacy-removal sweep, including a follow-up sweep when prior cleanup has already occurred.
- Investigate only evidenced legacy or deprecated behavior, backward-compatibility code and shims, dual reads or writes, parallel old and new approaches to the same responsibility, stale or unused code, dead code, and obsolete database fields, indexes, or related objects.
- Assume the database will be reset. Plan direct removal without legacy-data support, compatibility paths, deprecation stages, dual-operation periods, or transition machinery.
- Exclude intentional fallbacks and redundancy with a current product purpose, including LLM model or provider fleets and their routing or failover. Exclude proper architectural layering and unrelated quality, redesign, performance, style, or refactoring concerns.
- Accept a clean no-findings conclusion. Do not invent issues, retain weak candidates, nitpick, or expand scope to make the plan appear substantial.

## Require evidence

Trace each candidate through its definitions, references, callers, persistence, configuration, tests, and runtime or framework registration as applicable. Before classifying anything as removable, check for dynamic dispatch, macros or framework callbacks, generated references, environment-specific configuration, dependency injection, external contracts, operational tooling, and intentional fallback behavior.

Retain a finding only when repository evidence supports both its legacy or dead status and safe removal direction. Record uncertainty as an evidence gap rather than converting it into a finding.

## Plan the target state

For every retained finding, plan clean removal of the obsolete path and its directly related code, tests, configuration, and database objects. Include focused verification that proves the surviving FeedBun behavior and schema remain correct. Keep the investigation and output read-only exactly as required by `$write-plan`; write the plan, but do not execute it.
