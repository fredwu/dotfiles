# Round state and convergence

Detailed round-progression, coverage, and P3 convergence mechanics for [code-review-loop](../SKILL.md).

## Per-reviewer state

Track three orthogonal flags for every requested reviewer in the loop stage:

- **`blocked`:** unavailable or exhausted recovery attempts (`failure-recovery.md`).
- **`open`:** not yet reviewed, or has accepted P0–P2 findings, risky/structural repairs, or real unresolved objections not yet verified.
- **`broad coverage`:** has completed a full broad review over the target.

Every reviewer normally starts non-blocked, `open`, and lacking `broad coverage`.

- **Seeded coverage:** When a caller explicitly invokes a single-pass (or Wave 1) loop to verify localized edits after an equivalent non-blocked broad review of the same target in the same session (such as `ship-plan` Stage 2 after localized post-review plan edits), each matching reviewer that completed that prior broad review starts with `broad coverage` seeded and `open` set for focused verification, while any reviewer without that prior broad review starts unseeded. Wave 2 of a two-pass review never uses seeded coverage; it always starts broad over the current target including Wave 1 repairs.

## Round progression

Use at most **5 completed review rounds** per loop stage for code/implementation targets and **3 completed review rounds** for planning/documentation targets, regardless of panel size. Failed attempts do not consume a round. Parallel inspections launched against the same unchanged target count as one round. The cap is a limit, not a quota.

1. **Round 1:** Run all requested non-blocked reviewers in parallel—**broad** (`high` effort where warranted under `code-review/references/reviewer-settings.md`) for every reviewer lacking `broad coverage`, or **focused** on localized edits for reviewers with seeded `broad coverage`. Completing a broad review grants `broad coverage`.
2. **Localized repairs vs. structural refactors:** Localized repairs (targeted bug fixes, isolated edge cases, doc/test updates) preserve `broad coverage` for already-clean reviewers; only reviewers with repaired open findings or unresolved objections remain `open`, and clean reviewers sit out subsequent rounds. Clear `broad coverage` for all non-blocked reviewers **only** when a repair causes a cross-cutting structural or architectural refactor across the target (such as redesigning a shared boundary, data flow, or multi-module contract).
3. **Rounds 2..(cap − 1) (focused by default):** While any non-blocked reviewer is `open`, run **only** currently `open` non-blocked reviewers in parallel—**focused** on repairs, open defects, directly affected invariants/callers, and regressions (normally `medium` effort for localized repairs under `reviewer-settings.md`) when that reviewer already holds `broad coverage`, or **broad** if it lacks `broad coverage`. Once no non-blocked reviewer is `open`, if any non-blocked reviewer still lacks `broad coverage` (missed Round 1 or cleared by a structural refactor), run one **broad** review across only those reviewers. Do not re-run full-diff broad reviews after routine localized fixes.
4. **Final round (Round 3 for plans/docs, Round 5 for code):** Run focused across remaining `open` non-blocked reviewers holding `broad coverage`, and broad across any non-blocked reviewer still lacking `broad coverage`. After it completes, safe tail P3 fixes under the P3 convergence rule below are still allowed (closing `clean` if closing conditions hold, or `incomplete` if a reviewer is `blocked`); if any open P0–P2 defect, risky/structural P3, unresolved objection, or missing `broad coverage` among non-blocked reviewers remains, end `capped` and apply post-cap recovery.

## P3 convergence (tail-off)

- **Planning targets:** Every accepted P0–P2 defect (under `code-review`'s plan-review bar) keeps that reviewer `open` until resolved and verified; minor clarity/wording notes belong at P3 (reclassify if needed). Once a completed round leaves **0 open P0–P2 defects** across all non-blocked reviewers and only P3 clarity notes remain, fold in safe clarifications directly, verify with repository document validators and `write-plan/references/plan-standards.md` (or session-scope consistency), and clear `open` without reopening review.
- **Code and non-plan documentation targets:** Fix concrete P3s encountered alongside P0–P2 repairs during an active round. Once a completed round leaves **0 open P0–P2 defects** across all non-blocked reviewers and only P3 items remain, apply clearly safe, localized P3 fixes (doc wording, minor UI/tooltip polish, small test assertions) directly, verify them with checks, and clear `open` without launching another round (recording those final P3 fixes as check-verified without fresh review). Reopen focused review for a P3 only when its fix is non-trivial or touches core runtime, security, or data-integrity logic—and only for the reviewer that raised it while rounds remain.
- **Coverage check before closing:** P3 tail-off clears `open`, **not** missing `broad coverage`. If any non-blocked reviewer still lacks `broad coverage` (for example after a structural refactor), run its pending broad review while rounds remain; if no rounds remain, end `capped` with missing coverage recorded.

## Rejections and unresolved objections

Evidence-based rejection does not require reviewer agreement or another call merely to obtain `No findings`. Keep each reviewer's reported findings and disposition; do not describe a disputed review as having no findings. A real unresolved objection keeps that reviewer `open` and prevents a clean close; if no further authorized edits can clear it, do not loop endlessly on an unchanged target—ask the user if needed, or stop early and finish `incomplete` (or `capped` after the final round) with the objection recorded.
