# Reviewer selection

Single source for parsing reviewer preferences across `code-review`, `code-review-loop`, `execute-plan`, and `ship-plan` (and direct provider wrappers `*-review` / `*-review-loop`).

## Parse preferences

- When invoked by a caller that already selected reviewer(s) or a pass family (such as `execute-plan`, `ship-plan`, `code-review-loop`, or a caller-assigned wrapper), use that selection without re-parsing or expanding.
- Otherwise read optional reviewer preferences from the user's request in context, including freeform language and explicit models or options. Do not require fixed argument positions, spelling, casing, or flags.
- When entered directly through a provider wrapper (`codex-review`, `claude-review`, `grok-review`, `gemini-review`, or their `-loop` counterparts), include that wrapper's provider as the default reviewer alongside any other reviewers or repeat requests in the prompt.
- A provider name appearing only in a file path, diff, plan text, implementation requirement, or background context is not a reviewer preference.
- Never infer an external reviewer from the current session's provider, and never substitute one. For provider selection, ask only when an external provider is genuinely unclear (such as an unnamed external reviewer or an ambiguous alternative like "claude or codex").
- Validate any explicit repeat request (`x 2`, `twice`, `two passes`) and pass assignment under [Two-pass review](two-pass-review.md) before applying single-pass rules—ask before review starts for unsupported counts, repeat requests for Grok or internal review, ambiguous repeat scope, or ambiguous explicit model pass assignment.

## Resolve modes

- **No preference, or `internal` only:** internal review (`code-review` / `code-review-loop`).
- **One named external reviewer (`claude`, `codex`, `grok`, or `gemini`):** that provider's review (`*-review`) or loop (`*-review-loop`). Reading shared mechanics never adds an internal review or loop.
- **Two or more named external reviewers (any count, such as `claude & codex` or `claude, codex, and grok`):**
  - One-shot (`code-review`): launch all selected reviewers **in parallel** against the unchanged target and merge findings.
  - Loop (`code-review-loop`, `execute-plan`, `ship-plan`): run them together as **one combined external panel loop** under `code-review-loop`, dispatching each provider through its one-shot `*-review` skill and runtime settings.
- **`internal` plus external reviewer(s):**
  - One-shot (`code-review`): launch internal and external reviewers **in parallel** against the unchanged target and merge findings.
  - Loop (`code-review-loop`, `execute-plan`): run the internal loop **sequentially first**, then the external loop or combined external panel, whatever position `internal` had in the request.
  - Plan review (`ship-plan` Stage 2): omit the extra `internal` plan-review loop; carry `internal` into Stage 4 (`execute-plan`).
- **Supported two-pass repeat (`x 2` / `twice`) for Codex, Claude, or Gemini:**
  - One-shot (`code-review`): launch both families **in parallel** alongside any other selected reviewers.
  - Loop (`code-review-loop`, `execute-plan`): expand into two sequential waves under [Two-pass review](two-pass-review.md)—Wave 1 combines all Pass-1 external reviewers (Codex Sol, Claude Opus, Gemini Neon) plus any single-pass external peers (such as Grok) into one panel; Wave 2 runs all Pass-2 reviewers (Codex Astra, Claude Fable, Gemini Carbon, combined if multiple are two-pass). Each sequential stage (internal, Wave 1, Wave 2) has its own ten-round cap.
  - Plan review (`ship-plan` Stage 2): run **Wave 1 only** (single pass) on the plan by default and apply both waves in Stage 4 (`execute-plan`), unless the user explicitly asks for two-pass plan review.

## Skill availability

Check the harness's available-skills list first to confirm the selected skills exist; inspect disk only if a needed skill is not listed. A missing required skill blocks execution. Load a review loop's instructions only when its checkpoint starts.
