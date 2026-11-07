---
name: definitive-plan
description: Audit two or more candidate plans and save one self-contained definitive plan under .local/. Use only on explicit invocation, not for comparison advice.
metadata:
  origin: custom
---

# Definitive Plan

Audit two or more candidate plans, choose the strongest as the base, correct it independently, and save one complete synthesis. Discovery and verification are read-only. The only permitted change is the new plan file and its `.local/` directory; do not edit candidates, implementation, or external state.

Read and apply [Plan standards](../write-plan/references/plan-standards.md) and [Resolve plan requirements](../write-plan/references/requirements.md).

## Candidates and requirements

Use explicit candidate paths exactly. Otherwise inspect only direct child files of `.local/` at the repository root (the workspace root when there is no repository), exclude earlier definitive outputs, and choose the one coherent set of plans for the same task by content and context. Ask for paths if fewer than two readable regular files remain or the set is ambiguous. Read candidates fully when practical; if you must sample, cover every requirement, conclusion, recommendation, caveat, evidence reference, and step, and disclose the limit.

Prefer conversation context for requirements. When it is incomplete, reconcile the candidates' requirements and digests by meaning and provenance, not exact wording, and use candidate-independent evidence for material differences. Label inferred or uncertain requirements, and ask only when an unresolved difference materially affects the task or authority. Visible user direction wins conflicts. Selectors and output preferences do not replace the underlying brief.

## Audit and synthesize

Assess the candidates symmetrically against the requirements: correctness, evidence, shared omissions, contradictions, risks, dependencies, prioritization, acceptance, executability, and the execution contract. Independently verify material claims that you can check safely; agreement between candidates is not proof. Label unavailable evidence. You can delegate independent read-only audits under [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md); reconcile their results and make the final selection yourself.

Use the strongest overall candidate as the base. Resolve conflicts from requirements and evidence: adopt better positions, combine compatible ideas, state justified conditions, or reject every candidate's answer. Keep required behavior and explicit compatibility.

Write a synthesis, not concatenated candidates. Remove duplicates, superseded analysis, candidate identities, rankings, and comparison narration; keep evidence provenance. Besides the required plan content, include scope, relevant evidence, the chosen direction, prioritized concrete changes and locations, dependencies, acceptance checks, and material risks or blockers. Check every conclusion and action against the requirements, and repair drift and omissions that the candidates share.

## Save and respond

Follow the plan file name rule with `<kind>` = `definitive-plan`. An explicit output path must be under `.local/`; normalize its stem to end in `-definitive-plan-<agent>`, completing a partial `-definitive` or `-definitive-plan` suffix or replacing another agent suffix.

Read back the saved plan. Check requirement accuracy and provenance, the TL;DR, phase numbering and effort shares, coverage, evidence, consistency, and executability. Respond under the plan standards, and name the base candidate.
