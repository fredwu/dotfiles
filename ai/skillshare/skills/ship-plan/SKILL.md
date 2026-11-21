---
name: ship-plan
description: Run final-pass on a supplied plan or session scope, review and refine it, run final-pass again, then execute-plan with the same optional reviewer preferences.
metadata:
  origin: custom
---

# Ship Plan

Run four stages in order, and finish each before the next: `final-pass` over the plan or session scope, the selected plan-review sequence over it, `final-pass` again, then `execute-plan`. Each skill keeps its own authority, checks, recovery, and completion rules. This shortcut adds no Git authority: `execute-plan` applies its own commit default, and pushes or deployment still need user direction.

## Resolve input and reviewers

Use the supplied plan text, path, or attachment. Otherwise use the current task's session context, including its latest applicable plan and later user updates. Apply `execute-plan`'s scope resolution and Resolve plan requirements (`write-plan/references/requirements.md`), and identify the outcome, scope, constraints, and acceptance criteria. No saved or complete plan is required. Ask only about material ambiguity that context cannot resolve. If the checkout starts on a non-default branch and the user did not give Git directions, ask before Stage 1 whether Stage 4 should commit on that branch or leave changes uncommitted, and carry that answer into `execute-plan`.

Read reviewer preferences exactly as `execute-plan` does, including freeform language and explicit model or options, and keep them for execution. Provider names in paths, implementation requirements, or background context are not reviewer selections. Never infer a reviewer from the provider that runs this session, and never substitute one.

Select the plan-review sequence:

- One or more explicitly named external reviewers: run their loops sequentially in the requested order. Codex selects `codex-review-loop`, Claude selects `claude-review-loop`, Grok selects `grok-review-loop`, and Gemini selects `gemini-review-loop`.
- No external reviewer, including internal only: `code-review-loop`.

A repeat request for Codex, Claude, or Gemini, such as `codex x 2`, `claude twice`, or `gemini x 2`, expands that reviewer into two sequential passes under Two-pass review (`code-review/references/two-pass-review.md`), for plan review and again in execution: Codex uses Sol, then Astra; Claude uses Opus, then Fable; Gemini uses Neon, then Carbon. An additional internal preference does not add a plan-review loop (it applies in execution). Ask only when the external provider is genuinely unclear, such as an unnamed external reviewer or an ambiguous alternative like "codex or claude". Confirm that the selected skills exist, and briefly state the plan-review sequence and the execution review sequence.

## Run the stages

1. **Initial plan final-pass.** Before the review loop, run `final-pass` as a standalone checkpoint over the planning target, with its documentation-only checks. When the repository defines no document validators, verify conformance with Plan standards (`write-plan/references/plan-standards.md`) directly for a saved plan (requirements, TL;DR, phase numbering and effort shares, evidence, and execution contract), or verify that derived requirements, scope, exclusions, phase breakdown, and acceptance criteria are complete and consistent for a session-only scope, without running unrelated application test suites. Resolve omissions and residual issues in the plan or in-context scope within existing authority, so the review starts from the most complete plan. Do not run `execute-plan`'s implementation checkpoints. A concrete blocker stops dependent stages; report what is missing.
2. **Plan review.** Apply the selected plan-review sequence in order (including both passes for a two-pass request) to the plan or resolved scope as a planning target. Review requirements, architectural commitments, feasibility against the current repository, boundaries, omissions, and acceptance criteria. Assess findings, and refine the plan or in-context scope within existing authority. Leave implementation to `execute-plan`; this review needs no implementation diff. For a saved plan, give the reviewer its path; for session-only scope, give a concise requirements and acceptance brief, not the conversation history. Keep each loop's mechanics, fresh rounds, cap, failure recovery, and honest coverage reporting. Planning checks establish readiness, not implementation verification.
3. **Plan final-pass.** After the plan-review sequence returns (also after a capped or incomplete loop), run `final-pass` as a standalone checkpoint over the planning target, with its documentation-only checks (falling back to the same direct saved-plan or session-scope verification when the repository defines no document validators). Keep each loop's actual status. Do not run `execute-plan`'s implementation checkpoints yet. A concrete blocker or an incomplete required final-pass stops dependent execution; finish independent authorized work and report what is missing.
4. **Execution.** Run `execute-plan` with the refined plan or scope and the same reviewer preferences and explicit options. With no preference, it uses its internal default. Its phases, phase final passes, review loops, and closing final-pass all stay required; the plan review cannot replace any implementation review.

Apply `execute-plan` (`Report progress`) rules from the first message, with one overall estimate across all four stages. Before execution, use `Initial plan final-pass · ~P% overall`, `Plan review: <loop name> · ~P% overall` (with the family for each pass of a two-pass request, for example `Plan review: codex-review-loop (Sol) · ~P% overall`), and `Plan final-pass · ~P% overall`, and reserve most of the estimate for execution; Stage 4 continues `~P%` without resetting.

Continue between stages without routine confirmation or handoff. Report the result concisely, keep plan-review status separate from implementation review status, and name material blockers or verification limits.

Examples, with a supplied plan or session context: `/ship-plan codex` runs `final-pass`, `codex-review-loop`, `final-pass`, then `execute-plan codex`. `/ship-plan codex and claude` runs `final-pass`, `codex-review-loop`, `claude-review-loop`, `final-pass`, then `execute-plan codex and claude`. `/ship-plan internal and claude` runs `final-pass`, `claude-review-loop`, `final-pass`, then `execute-plan internal and claude`. `/ship-plan codex x 2` runs `final-pass`, `codex-review-loop` (Sol), `codex-review-loop` (Astra), `final-pass`, then `execute-plan codex x 2`. `/ship-plan gemini x 2` runs `final-pass`, `gemini-review-loop` (Neon), `gemini-review-loop` (Carbon), `final-pass`, then `execute-plan gemini x 2`. `/ship-plan` runs `final-pass`, `code-review-loop`, `final-pass`, then `execute-plan` with its internal default.
