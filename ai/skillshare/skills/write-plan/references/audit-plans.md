# Audit plan rules

Shared rules for the focused audit variants of [write-plan](../SKILL.md), such as `write-plan-perf` and `write-plan-legacy`. Each variant applies `write-plan` in full, then these rules, then its own focus rules.

## Brief

The user's message is the task brief. It can narrow, extend, or override the variant's defaults; an empty brief means the whole project-owned codebase. Record the variant's defaults as skill constraints, not as the user's words, and do not copy the invocation into the requirements.

## Owned scope

Audit only project-owned code, configuration, tests, and documentation. Find the ownership boundary from repository instructions, upstream remotes and merge history, and vendored, generated, and dependency directories. When ownership of a path is unclear, compare it with the upstream ref; a local edit to an inherited file does not make the whole file project-owned.

Plan no changes to upstream-tracked boilerplate (for example Petal Pro) or third-party code, so that upstream merges stay easy. When only such code can fix a finding, record it as an out-of-scope note, with the minimal-change path that repository rules allow, if any.

## Evidence

A clean result is valid. An uncertain candidate is an evidence gap with its decisive check, not a planned change. Do not invent findings to fill the plan.

## Change completeness

Each planned change includes its directly related code, tests, configuration, documentation, and repository instructions, and names focused checks for the surviving behavior.

## Focus

Put evidenced findings outside the variant's focus into brief notes, not phases. Directly affected cleanup under `write-plan` stays in scope.

## Destination

Use the `write-plan` destination rule. When the brief gives no topic, use the variant's default topic.
