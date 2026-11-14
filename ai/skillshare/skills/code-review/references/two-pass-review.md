# Two-pass external review

Use this when a request asks for a Codex or Claude review loop to run twice. Read intent, not syntax: `codex x 2`, `codex x2`, `codex ×2`, `2x codex`, `codex twice`, and `claude two passes` all count. A number that appears only in a path, a plan, or background context is not a repeat request.

## Passes

A two-pass request selects two sequential invocations of the provider's review loop. Each pass uses one model family:

| Provider | Pass 1 | Pass 2 |
| -------- | ------ | ------ |
| Codex    | Sol    | Astra  |
| Claude   | Opus   | Fable  |

Each pass is a full loop invocation with its own round cap, recovery, and terminal status. Finish pass 1, including its repairs, before pass 2 starts; never run the passes in parallel. Pass 2 reviews the whole current target, including pass-1 repairs. Give it pass-1 residuals and open objections only as claims to verify. A capped or incomplete pass 1 does not cancel pass 2.

## Resolve the models

Resolve each pass's family under [Resolve a model family](reviewer-settings.md#resolve-a-model-family); effort follows the same policy. If a pass's family is unavailable, that pass is blocked, and the other pass still runs.

An explicit model that the user names for a specific pass replaces that pass's family. If it is not clear which pass an explicit model applies to, ask before review starts.

## Limits and reporting

Two passes are defined only for Codex and Claude. For another count, or a repeat request for Grok or internal review, ask before review starts; do not invent model families.

Name each pass with its loop and family in progress markers, for example `Review: codex-review-loop (Astra) · ~P% overall`. Report the resolved model, status, and coverage of each pass separately.
