---
name: ship-plan
description: Prepare and review a supplied plan or session scope (running final-pass only where needed), then execute-plan with the same optional reviewer preferences.
metadata:
  origin: custom
---

# Ship Plan

Run up to four stages in order, and finish each before the next: prepare the plan or session scope (`final-pass`), run the selected plan-review sequence over it, run a post-review plan `final-pass` when needed, then run `execute-plan`. Each skill keeps its own authority, checks, recovery, and completion rules. This shortcut adds no Git authority: `execute-plan` applies its own commit default, and pushes or deployment still need user direction.

## Resolve input and reviewers

Use the supplied plan text, path, or attachment. Otherwise use the current task's session context, including its latest applicable plan and later user updates. Apply `execute-plan`'s scope resolution and Resolve plan requirements (`write-plan/references/requirements.md`), and identify the outcome, scope, constraints, and acceptance criteria. No saved or complete plan is required. Ask only about material ambiguity that context cannot resolve. If the checkout starts on a non-default branch and the user did not give Git directions, ask before Stage 1 whether Stage 4 should commit on that branch or leave changes uncommitted, and carry that answer into `execute-plan`.

Resolve reviewer preferences under Reviewer selection (`code-review/references/reviewer-selection.md`) and Two-pass review (`code-review/references/two-pass-review.md`):

- **Plan review (Stage 2):** uses the resolved external reviewer(s) (or internal `code-review-loop` if no external reviewer was named). An additional `internal` preference does not add a plan-review loop, and a two-pass request (`x 2` / `twice`) runs **Wave 1 only** on the plan by default unless the user explicitly asks for two-pass plan review.
- **Execution (Stage 4):** keeps the full resolved reviewer preferences, including `internal` and two-pass waves.

Verify skill availability using the harness's available-skills list first (checking disk only if unlisted), and briefly state the plan-review sequence and the execution review sequence.

## Run the stages

1. **Initial plan final-pass.** Before the review loop, run `final-pass` as a standalone checkpoint over the planning target, with its documentation-only checks. If the plan was just written or revised in this session, keep this pass lightweight: reconcile only later user updates and run any repository document validators rather than re-auditing unchanged sections from scratch. Otherwise, when the repository defines no document validators, verify conformance with Plan standards (`write-plan/references/plan-standards.md`) directly for a saved plan (requirements, TL;DR, phase numbering and effort shares, evidence, and execution contract), or verify that derived requirements, scope, exclusions, phase breakdown, and acceptance criteria are complete and consistent for a session-only scope, without running unrelated application test suites. Resolve omissions and residual issues in the plan or in-context scope within existing authority, so the review starts from the most complete plan. Do not run `execute-plan`'s implementation checkpoints. A concrete blocker stops dependent stages; report what is missing.
2. **Plan review.** Apply the selected plan-review sequence (combining multiple external reviewers into one panel; Wave 1 only on `x 2` unless two-pass plan review was explicitly requested) to the plan or resolved scope as a planning target. Review requirements, architectural commitments, feasibility against the current repository, boundaries, omissions, and acceptance criteria. Assess findings, and refine the plan or in-context scope within existing authority. Leave implementation to `execute-plan`; this review needs no implementation diff. For a saved plan, give the reviewer its path; for session-only scope, give a concise requirements and acceptance brief, not the conversation history. Keep each stage's loop mechanics, fresh rounds, cap, failure recovery, and honest coverage reporting. Planning checks establish readiness, not implementation verification.
3. **Plan final-pass (conditional).** After Stage 2 returns, run `final-pass` (standalone, documentation-only checks) **only** if Stage 2 ended capped or incomplete (needing post-review recovery), left residuals, or made edits that still need post-edit cleanup or document-validator verification. When Stage 2 ended clean with no unvalidated edits or residuals, skip Stage 3 and proceed directly to Stage 4 rather than churning an already-reviewed plan. Keep each stage and reviewer's actual status. Do not run `execute-plan`'s implementation checkpoints yet. A concrete blocker or an incomplete required final-pass stops dependent execution; finish independent authorized work and report what is missing.
4. **Execution.** Run `execute-plan` with the refined plan or scope and the same reviewer preferences and explicit options. With no preference, it uses its internal default. Its phases, phase final passes, review loops, and closing final-pass all stay required; the plan review cannot replace any implementation review.

Apply `execute-plan` (`Report progress`) rules from the first message, with one overall estimate across all stages. Before execution, use `Initial plan final-pass · ~P% overall`, `Plan review: <loop or panel name> · ~P% overall` (with the family for two-pass reviewers, for example `Plan review: codex-review-loop (Sol) · ~P% overall` or `Plan review: claude (Opus) + codex (Sol) review panel · ~P% overall`), and `Plan final-pass · ~P% overall` (when Stage 3 runs), reserving most of the estimate for execution; Stage 4 continues `~P%` without resetting.

Continue between stages without routine confirmation or handoff. Report the result concisely, keep plan-review status separate from implementation review status, and name material blockers or verification limits.

Examples: `/ship-plan codex` runs initial `final-pass`, `codex-review-loop`, conditional `final-pass`, then `execute-plan codex`. `/ship-plan claude, codex, and grok` runs one combined panel on the plan, then `execute-plan claude, codex, and grok`. `/ship-plan internal and claude` runs `claude-review-loop` on the plan, then `execute-plan internal and claude`. `/ship-plan claude and codex x 2` runs Wave 1 combined Claude (Opus) + Codex (Sol) on the plan, then `execute-plan claude and codex x 2` (Wave 1 Opus + Sol, Wave 2 Astra). `/ship-plan codex x 2` runs `codex-review-loop` (Sol) on the plan, then `execute-plan codex x 2` (Sol, then Astra). `/ship-plan` runs `code-review-loop` on the plan, then `execute-plan` with its internal default.
