---
name: revise-plan
description: Revise the current saved plan in place from the latest compare-plans findings and optional user guidance, keeping current requirements and its TL;DR accurate.
metadata:
  origin: custom
---

# Revise Plan

Revise the current plan in place from the latest `compare-plans` result and any user guidance. Edit only that plan, and keep verification read-only. Write to another path only on explicit user direction.

Read and apply [Plan standards](../write-plan/references/plan-standards.md) and [Resolve plan requirements](../write-plan/references/requirements.md).

## Resolve inputs

Read the latest complete `compare-plans` result that is visible or supplied, including its requirement reading and its numbered findings or no-material-difference conclusion. Take the current plan from an explicit path, otherwise from that comparison's current plan. Never pick a sibling plan only because its path appears. Ask for a path if the plan stays unresolved.

Read the whole plan. Check that it matches the comparison's task and cited positions; wording differences alone are not mismatches. Ask for a fresh comparison only if a material mismatch remains after you reconcile requirements and evidence.

Update `## User requirements` to current intent with concise provenance, and refresh `## TL;DR`. Later user task changes affect scope, analysis, steps, and validation; distinguish them from selectors and choices about individual findings.

## Apply findings

Apply every finding's independent recommendation unless clear user guidance supersedes it, or evidence or governing requirements contradict it. Guidance about some findings does not exclude the others. If guidance maps ambiguously, keep the supported default and report the ambiguity. A recommendation to keep the current position can need no edit; keep valid conditions and evidence-gathering steps.

Verify premises in proportion to their freshness, uncertainty, and impact. Adapt or reject unsupported, obsolete, unsafe, or out-of-scope advice, and explain material departures. User preferences are not facts, and missing evidence is not certainty.

Audit the whole plan for omissions, contradictions, scope drift, dependencies, and acceptance gaps, including defects the comparison missed, and check it against the execution contract and phase structure. For a no-material-difference result, leave the prose unchanged unless guidance or this audit justifies a material revision.

Integrate each change wherever it has an effect. Remove superseded prose, comparison narration, plan labels, and change or disposition ledgers; keep current requirements and meaningful provenance. Put chosen recommendations, rationale, and conditions into the analysis and execution steps. The result must stand alone without the comparison.

## Verify and respond

Read back the plan and its diff. Check requirement accuracy and provenance, the TL;DR, phase numbering and effort shares, coverage of every finding and guidance item, evidence, executable checks, and scope. Respond under the plan standards, and also list unapplied advice with reasons. If nothing changed, say so.
