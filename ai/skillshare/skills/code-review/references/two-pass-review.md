# Two-pass external review

Use this when a request asks for a Codex, Claude, or Gemini review or review loop to run twice. Read intent, not syntax: `codex x 2`, `codex x2`, `codex ×2`, `2x codex`, `codex twice`, `claude two passes`, and `gemini x 2` all count. A number that appears only in a path, a plan, or background context is not a repeat request.

## Passes

For review loops (`code-review-loop`, `*-review-loop`, `execute-plan`, and `ship-plan` execution), a two-pass request expands a provider into two sequential waves (`ship-plan` runs a single Wave-1 plan review by default and reserves two-pass waves for implementation unless the user explicitly asks for two-pass plan review). Each wave uses one model family for that provider:

| Provider | Pass 1 | Pass 2 |
| -------- | ------ | ------ |
| Codex    | Sol    | Astra  |
| Claude   | Opus   | Fable  |
| Gemini   | Neon   | Carbon |

For a single two-pass provider, Wave 1 runs its Pass 1 loop and Wave 2 runs its Pass 2 loop. When combined with other external reviewers (for example `claude and codex x 2`, or `claude x 2, codex x 2, and grok`), Wave 1 combines all Pass-1 external reviewers and any single-pass external peers into one panel loop (`code-review-loop`), and Wave 2 runs all Pass-2 reviewers (combined into one panel loop when multiple providers are two-pass). Single-pass external peers (such as Claude in `claude and codex x 2`, or Grok) run only in Wave 1.

Each wave is a full loop invocation with its own target-based `code-review-loop` round cap (**5 rounds** for code/implementation targets; **3 rounds** for planning or documentation targets), recovery, and terminal status. Finish Wave 1, including its repairs, before Wave 2 starts; never run Pass 1 and Pass 2 of the same provider in the same round. Wave 2 never uses seeded `broad coverage`; it always reviews the whole current target, including Wave 1 repairs, starting with its own broad Round 1 and following the same focused-repair and convergence rules. Give it Wave 1 residuals and open objections only as unattributed claims to verify. A capped or incomplete Wave 1 does not cancel Wave 2.

For a one-shot read-only review (`code-review` or `*-review`) with a repeat request, there are no repairs between passes, so run both families in parallel against the same unchanged target (alongside any other requested reviewers) and merge findings.

## Resolve the models

Resolve each pass's family under [Resolve a model family](reviewer-settings.md#resolve-a-model-family); effort follows the same policy. If a pass's family is unavailable, that reviewer/pass is blocked, and the other reviewers and passes still run.

An explicit model that the user names for a specific pass replaces that pass's family. If it is not clear which pass an explicit model applies to, ask before review starts.

## Limits and reporting

Two passes are defined only for Codex, Claude, and Gemini. For another count, or a repeat request for Grok or internal review, ask before review starts; do not invent model families. Regardless of wording (`x 2`, `twice`, `two passes`), a repeat marker directly following one provider (such as `claude and codex x 2`, `claude and codex twice`, `internal and claude twice`, or `codex x 2 and claude`) binds to that adjacent provider, unless the user explicitly scopes it to multiple providers (such as `both twice`, `all x 2`, or `claude x 2 and codex x 2`). For provider binding, ask before review starts only when the phrasing itself is ambiguous about which provider(s) repeat (such as a leading multiplier before a list like `2x claude and codex`); unsupported counts, unsupported providers, and ambiguous explicit models still require asking independently.

Name each pass with its loop or panel and family in progress markers, for example `Review: codex-review-loop (Astra) · ~P% overall` or `Review: claude (Opus) + codex (Sol) review panel · ~P% overall`. Report the resolved model, status, and coverage of each reviewer and pass separately.
