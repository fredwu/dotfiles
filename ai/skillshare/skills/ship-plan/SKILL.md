---
name: ship-plan
description: Run final-pass on a supplied plan or session scope, review and refine it, run final-pass again, then execute-plan with the same optional reviewer preferences.
metadata:
  origin: custom
---

# Ship Plan

Run four stages in order, and finish each before the next: [final-pass](../final-pass/SKILL.md) over the plan or session scope, one review loop over it, `final-pass` again, then [execute-plan](../execute-plan/SKILL.md). Each skill keeps its own authority, checks, recovery, and completion rules. This shortcut adds no Git authority: `execute-plan` applies its own commit default, and pushes or deployment still need user direction.

## Resolve input and reviewers

Use the supplied plan text, path, or attachment. Otherwise use the current task's session context, including its latest applicable plan and later user updates. Apply `execute-plan`'s scope resolution and [Resolve plan requirements](../write-plan/references/requirements.md), and identify the outcome, scope, constraints, and acceptance criteria. No saved or complete plan is required. Ask only about material ambiguity that context cannot resolve.

Read reviewer preferences exactly as `execute-plan` does, including freeform language and explicit model or options, and keep them for execution. Provider names in paths, implementation requirements, or background context are not reviewer selections. Never infer a reviewer from the provider that runs this session, and never substitute one.

Select exactly one plan-review loop:

- Codex requested: [codex-review-loop](../codex-review-loop/SKILL.md).
- Claude requested: [claude-review-loop](../claude-review-loop/SKILL.md).
- Grok requested: [grok-review-loop](../grok-review-loop/SKILL.md).
- No external reviewer, including internal only: [code-review-loop](../code-review-loop/SKILL.md).

A repeat request for Codex or Claude, such as `codex x 2` or `claude twice`, runs that loop as two sequential passes under [Two-pass review](../code-review/references/two-pass-review.md), for plan review and again in execution: Codex uses Astra, then Sol; Claude uses Fable, then Opus. An additional internal preference does not add a plan-review loop. Resolve competing external providers or an unnamed external reviewer before review starts. Confirm that the selected skills exist, and briefly state the plan-review loop and the execution review sequence.

## Run the stages

1. **Initial plan final-pass.** Before the review loop, run `final-pass` as a standalone checkpoint over the planning target, with its documentation-only checks. Resolve omissions and residual issues in the plan or in-context scope within existing authority, so the review starts from the most complete plan. Do not run `execute-plan`'s implementation checkpoints. A concrete blocker stops dependent stages; report what is missing.
2. **Plan review.** Apply the selected loop, both passes in order for a two-pass request, to the plan or resolved scope as a planning target. Review requirements, architectural commitments, feasibility against the current repository, boundaries, omissions, and acceptance criteria. Assess findings, and refine the plan or in-context scope within existing authority. Leave implementation to `execute-plan`; this review needs no implementation diff. For a saved plan, give the reviewer its path; for session-only scope, give a concise requirements and acceptance brief, not the conversation history. Keep the loop's mechanics, fresh rounds, cap, failure recovery, and honest coverage reporting. Planning checks establish readiness, not implementation verification.
3. **Plan final-pass.** After the loop returns (both passes for a two-pass request), also after a capped or incomplete loop, run `final-pass` as a standalone checkpoint over the planning target, with its documentation-only checks. Keep the loop's actual status. Do not run `execute-plan`'s implementation checkpoints yet. A concrete blocker or an incomplete required final-pass stops dependent execution; finish independent authorized work and report what is missing.
4. **Execution.** Run `execute-plan` with the refined plan or scope and the same reviewer preferences and explicit options. With no preference, it uses its internal default. Its phases, phase final passes, review loops, and closing final-pass all stay required; the plan review cannot replace any implementation review.

Apply `execute-plan`'s [Report progress](../execute-plan/SKILL.md#report-progress) rules from the first message, with one overall estimate across all four stages. Before execution, use `Initial plan final-pass · ~P% overall`, `Plan review: <loop name> · ~P% overall` (with the family for each pass of a two-pass request, for example `Plan review: codex-review-loop (Sol) · ~P% overall`), and `Plan final-pass · ~P% overall`, and reserve most of the estimate for execution.

Continue between stages without routine confirmation or handoff. Report the result concisely, keep plan-review status separate from implementation review status, and name material blockers or verification limits.

Examples, with a supplied plan or session context: `/ship-plan codex` runs `final-pass`, `codex-review-loop`, `final-pass`, then `execute-plan codex`. `/ship-plan internal and claude` runs `final-pass`, `claude-review-loop`, `final-pass`, then `execute-plan internal and claude`. `/ship-plan codex x 2` runs `final-pass`, `codex-review-loop` (Astra), `codex-review-loop` (Sol), `final-pass`, then `execute-plan codex x 2`. `/ship-plan` runs `final-pass`, `code-review-loop`, `final-pass`, then `execute-plan` with its internal default.
