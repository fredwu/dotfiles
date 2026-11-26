---
name: final-pass
description: Close a completed phase or execution; review changes, resolve omissions, and clean up first, then establish passing evidence for the project's full testing and quality checks.
metadata:
  origin: custom
---

# Final Pass

Close a checkpoint in strict order: review the full change set against the original request and later updates, finish all needed repairs, recovery, and cleanup first, and run the project's full checks only at the end once edits are settled.

## Checkpoint type

- **Phase checkpoint**, during plan execution (`execute-plan`, `Completion and review checkpoints`): finish phase acceptance, integration with completed phases, cleanup, and required checks in order, then return to the executor. For an intermediate phase (`1..T-1` of a multi-phase plan), run affected tests and fast static gates (compile, typecheck, lint) rather than slow full-repo suites unless a dependent phase explicitly requires full-suite verification first. For the final phase (`T`, or the single phase of a single-phase plan), establish all required full test and quality gates. The selected reviews stay pending and do not block this checkpoint.
- **Closing checkpoint**: after the selected review sequence returns, or after the active loop ends at its cap or a concrete blocker. Do everything below in order, including post-review recovery.
- **Standalone**: a final check outside plan execution. Do everything below in order except post-review recovery, unless a review loop has ended.

## Resolve issues

Start by reviewing the full change set—code, documentation, tests, and configuration in the checkpoint scope, including integration with completed phases—before running full test or quality suites. Resolve task-relevant omissions and inconsistencies within scope. Reconcile execution and worker residuals, review findings, prior failed checks, and verification gaps. Fix every authorized task-relevant issue, including pre-existing failures found during the task, and reject unsupported findings with evidence. A review cap or a final read-only review round does not defer these repairs. Use fast targeted checks if needed while making edits; do not run full suites yet.

## Post-review recovery

While a review loop is active and has rounds left, it owns fresh review. Do not use this recovery to replace a required review; failed attempts follow the loop's failure recovery (`code-review-loop/references/failure-recovery.md`).

When the loop has ended at its cap or a concrete blocker, list the missing coverage and the repairs no reviewer has seen, against the original target, acceptance criteria, and review lenses. Inspect that coverage directly and record the evidence in context. Do not retry the failed call, restart the loop, or add disguised review rounds. The checkpoint can close when this coverage and all required repairs and checks are complete. Report the loop's actual capped or incomplete status and the unreviewed repairs; this recovery does not make a clean loop result. If you cannot establish the coverage, keep the checkpoint incomplete.

## Clean up

Before running the full checks, do one cleanup round over changed and directly affected files. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and the related tests, configuration, and documentation. Keep required behavior, explicit compatibility, and unrelated work. With read-only or documentation-only authority, report material implementation findings without editing them. A clean result is valid.

## Visual verification

For any change affecting rendered UI, layout, styling, diagrams, or motion—including small CSS or bug fixes excluded from full mockup exploration (`execute-plan/references/ui-mockups.md`)—render and visually inspect the affected output before closing. Inspect the actual screenshot, frames, or clip for clipped text, wrapped labels, broken alignment, or broken transitions.

- **Checkpoint scope:** Required at final phase `T`, closing `final-pass`, and standalone `final-pass` whenever a permitted local render path exists. Intermediate phases (`1..T-1`) run it when the phase delivers a UI surface. Docs-only diagrams (such as Mermaid) run visual verification when a local renderer is available; otherwise record the unverified visual limit without blocking doc work.
- **Tool routing (single source of truth):**
  - **Static HTML / mockups:** Inside T3 Code, use `html_preview` (returns a PNG without opening a shared tab; do not call `html_render` or `preview_*` unless asked). Outside T3 Code, use an available browser or screenshot tool (such as Playwright).
  - **Web UI & CSS/JS motion:** Inside T3 Code, use `preview_*` / `preview_recording_*` **only** when browser work was requested by the user (closing any tab you opened when done); otherwise use an isolated browser tool such as Playwright CLI (screenshots, state-transition captures, or video) for self-verification without opening unasked shared tabs.
  - **Mobile / TV simulators & emulators:** Use `device_screenshot` / `agent-device`.
  - **Native desktop UI:** Use `cua-driver` (following `cua-driver-prefs.md`) with **background capture only** for unasked self-verification checks. If background capture is unavailable for an unasked check, record a verification limit instead of taking foreground focus.
- **Server & headless boundary:** Starting an ephemeral local dev/preview server is permitted within existing local-check authority and must be stopped afterward; never touch production/external services or open unasked browser tabs. When no permitted local rendering environment exists for a non-mandatory visual check (such as a headless environment lacking a display, browser, or simulator), record the exact verification limit in the report rather than stalling `final-pass` as `incomplete` unless the project explicitly defines a required visual gate.

## Run the full checks

Run this step only after `Resolve issues`, applicable `Post-review recovery`, `Clean up`, and applicable `Visual verification` are complete and no further edits are planned. Do not launch full test or quality suites speculatively at the start of `final-pass` or in parallel with review, cleanup, or visual verification.

Find the project's full test and quality gates in repository instructions (including AGENTS.md), CI workflows, scripts, and contributor or testing documentation. In each invocation, establish passing evidence for every required gate on the final state, by running it or by reusing valid evidence under [Check evidence and reuse](references/check-evidence.md). Targeted tests, smoke tests, and document validators do not replace full suites or quality checks. Small changes and long run times do not reduce coverage. Add checks in proportion to risk where the required gates leave a gap.

Only these permit a skip:

- An explicit user instruction.
- Intermediate phase checkpoint (`1..T-1` in `execute-plan`): run affected tests and fast static gates (compile, typecheck, lint) and reserve slow full-repo suites for the final phase (`T`) and closing checkpoint, unless a dependent phase explicitly requires full-suite verification first.
- Documentation-only work: run the required document or skill validators and skip unrelated application suites. This does not apply when the checkpoint changes code, configuration, or tests anywhere.
- Checks that incur real external charges, such as smoke tests that call billed APIs, unless already authorized. Local compute and run time are not charges.

Missing access, services, or authority blocks a required check; it does not exempt it. Try reasonable authorized alternatives first, and keep authorization boundaries for external effects.

If the full checks expose authorized in-scope failures, batch the repairs and any resulting cleanup first (using targeted checks if needed while fixing), repeat affected `Visual verification` when repairs change rendered UI, layout, diagram, or motion output, then reassess evidence and rerun only the invalidated gates. Repeat until no actionable task-relevant issue remains and required checks pass. A failed or blocked required gate keeps the checkpoint incomplete. For each required gate, record the command, the result (passed, failed, skipped, or blocked), whether a pass was executed or reused (with its origin), and the reason for any skip or blocker.

## Finish

A phase checkpoint returns to the executor; it does not end execution. Stop with work remaining only on user direction, an explicit authorized session boundary, or a concrete blocker that needs missing authority, input, or external change. First try alternatives and finish independent work. Report blocked work as incomplete, not as a completed result with residuals.

Lead with changes or findings, then executed and reused check results, skips, and blockers, in short plain prose without stock headings or repeated summaries. Do not claim implementation verification from document validators, or fresh review from reused check evidence. Save a report only on request.

## Temporary files

Keep scratch notes in context. Create a temporary file only when an agent needs it; track it, delete it after use (also after failure or abandonment), and verify the deletion. If a file must stay for continuing agent work, name its cleanup owner and report its path. Never delete requested deliverables (including `.local/` plans), pre-existing files, unrelated work, or shared directories.
