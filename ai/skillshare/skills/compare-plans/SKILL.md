---
name: compare-plans
description: Compare the current completed analysis plan with one or more supplied or identifiable peer plans and return prioritized findings to improve the current plan. Use definitive-version for winner selection.
metadata:
  origin: custom
---

# Compare Plans

Compare the current plan with its peers, independently and read-only, and return findings that improve the current plan. Do not edit any plan or external state, or run checks that write artifacts. Keep comparison state in context.

Read and apply [Plan standards](../write-plan/references/plan-standards.md) and [Resolve plan requirements](../write-plan/references/requirements.md).

## Inputs

The current plan is the latest completed analysis plan presented to the user, including its linked saved file; private reasoning and status updates are not plans. It is the baseline to improve.

Use every explicit peer path, and validate each one without substitution or silent drops; do not add inferred peers when paths are given. Without explicit peers, inspect only readable sibling plans beside the current plan, and include every one that clearly addresses the same task. Report duplicates or a peer that resolves to the current plan, and compare each distinct plan once. Ask narrowly about unresolved inputs or an ambiguous selection, continue with the resolved plans, and disclose the incomplete coverage.

Label the plans Current, A, B, and so on, with their paths or source identifiers. Account for every requested input as compared, duplicate, baseline, or unresolved.

Establish the current task under the requirements reference. Missing originals or different wording are not blockers; disclose material uncertainty and, where possible, recommend actions that hold under every supported reading. Selectors and output preferences are local guidance. A missing or different requirements section is a finding only when it affects understanding or coverage.

## Compare

Read every plan fully when practical. If you must sample, cover each plan's requirement-relevant conclusions, recommendations, caveats, and references, and disclose the limit. Assess requirement fit, correctness, shared omissions, contradictions, risks, dependencies, acceptance, executability, and conformance with the execution contract in the plan standards. Flag missing or conflicting checkpoint provisions and unsupported session breaks or confirmation handoffs, including ones all plans share.

Verify finding premises against current source, configuration, schemas, contracts, tests, and other primary evidence, and cite precise locations. Reconcile differences in scope, version, assumptions, and behavior. Missing decisive evidence needs a condition or a specific gathering step, not a guess. You can delegate independent read-only evidence questions under [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md); reconcile the results before you conclude.

For every material conflict, give each distinct position and the plans that hold it, and decide whether evidence supports the current plan, some peers, a combination, a conditional choice, none, or more investigation. Include conflicts among peers, and conflicts where the current plan is already right. Group each issue once across the set instead of pairwise, and name the plans that share a defect or omission, including all of them. Omit equivalent coverage, cosmetic differences, invented cleanup, and scope expansion.

## Response

Briefly identify the current plan, peer labels, input coverage, and material reading or evidence limits. State the effective requirements only when needed to explain scope or an ambiguity; do not repeat the originating message or requirement history. Then return a numbered `## Findings` table:

| # | Severity | Finding | Our choice / position | Their choice / position | Independent recommendation | Basis |
|---:|---|---|---|---|---|---|

- With several peers, rename `Their choice / position` to `Peer choices / positions`, use plan labels, group agreeing peers while keeping each source location, and name the affected plans for shared issues. Keep the same columns for one peer.
- Start each Finding cell with its type: **Conflict**, **Improvement**, or **Decision point**. Severity is Critical, High, Medium, or Low, by the consequence of leaving the finding unresolved.
- Put conflicts first, then sort by severity and impact. Include every independently material issue, merge inseparable ones, and keep cells concise.
- Positions need labeled locations. The basis needs the decisive evidence, or the missing fact and how to gather it. Decision points need a recommended path and conditions where possible.

After the table, flag high-risk recommendations with rationale, mitigations, and residual risks. With no material findings, omit the table and say briefly that the peers add no material improvement within the disclosed coverage; still disclose retained high-risk recommendations, including shared ones. Use plain language; omit praise, scorecards, and process narration.
