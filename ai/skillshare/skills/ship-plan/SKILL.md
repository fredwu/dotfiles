---
name: ship-plan
description: Review and refine a supplied plan or session scope, run final-pass, then execute-plan with the same optional reviewer preferences.
---

# Ship Plan

Run the following stages sequentially: one review loop over the plan or session scope, [final-pass](../final-pass/SKILL.md), then [execute-plan](../execute-plan/SKILL.md). Complete each stage before starting the next. This shortcut preserves each skill's authority, checks, recovery, and completion rules; it does not authorize commits, pushes, or deployment.

## Resolve input and reviewers

Use the supplied plan text, path, or attachment. Otherwise use the current task's session context, including its latest applicable plan and later user updates. Apply `execute-plan`'s scope resolution and [Resolve plan requirements](../write-plan/references/requirements.md). Identify the outcome, scope, constraints, and acceptance criteria in context; no saved or previously complete plan is required. Ask only about material ambiguity that available context cannot resolve.

Interpret optional reviewer preferences exactly as `execute-plan` does, including freeform language and explicit model/options. Preserve those preferences for execution. Provider names in paths, implementation requirements, or background context are not reviewer selections. Never infer a reviewer from the executing provider or silently substitute another.

Select exactly one initial loop:

- Codex requested: [codex-review-loop](../codex-review-loop/SKILL.md).
- Claude requested: [claude-review-loop](../claude-review-loop/SKILL.md).
- Grok requested: [grok-review-loop](../grok-review-loop/SKILL.md).
- No external reviewer requested, including internal-only: [code-review-loop](../code-review-loop/SKILL.md).

An additional internal preference does not add an initial loop. Resolve competing external providers or an unspecified external reviewer before launching review. Confirm selected dependencies exist and state the initial loop and execution review sequence briefly.

## Run the shortcut

1. Apply the selected loop to the plan or resolved session scope as a planning target. Review requirements, architectural commitments, feasibility against the current repository, boundaries, omissions, and acceptance criteria. Assess findings and refine the plan or in-context scope within existing authority. Keep implementation changes for `execute-plan`; no implementation diff is required for this review. For a saved plan, give the reviewer its path; for session-only scope, supply a concise requirements and acceptance brief rather than full conversation history. Preserve the loop's review mechanics, fresh rounds, cap, failure recovery, and honest coverage reporting. Planning checks establish readiness, not implementation verification.
2. After that loop returns, always run `final-pass` over the resulting planning target, including after a capped or incomplete loop. Use its documentation-only checks and recovery rules to resolve planning residuals; preserve the loop's actual status. Do not invoke `execute-plan`'s implementation checkpoints at this stage. A concrete blocker or incomplete required final-pass prevents dependent execution; finish independent authorized work and report what is missing.
3. Invoke `execute-plan` with the refined plan or resolved session scope and the same reviewer preferences and explicit options passed to `ship-plan`. With no preference, preserve its internal default. Its implementation, phase final passes, selected implementation review loops, and closing final-pass all remain required. The initial planning review cannot satisfy or replace any implementation review.

Continue between stages without a routine confirmation or handoff. Report the result concisely, distinguishing planning review status from implementation review status and identifying material blockers or verification limits.

Examples: `$ship-plan codex` runs `codex-review-loop`, `final-pass`, then `execute-plan codex`. `$ship-plan internal and claude` runs `claude-review-loop`, `final-pass`, then `execute-plan internal and claude`. `$ship-plan` runs `code-review-loop`, `final-pass`, then `execute-plan` with its default internal review. These examples apply with a supplied plan or session context.
