---
name: code-review-loop
description: Review, repair, and verify code, plans, or docs in bounded rounds (internal or external panel, with optional two-pass waves). Use code-review for read-only review.
metadata:
  origin: custom
---

# Code Review Loop

Own assessment, repairs, verification, and completion for code, planning, or documentation targets—both standalone and when invoked by `execute-plan` or `ship-plan`. Read `code-review` and the original requirements. Preserve requested target, exclusions, authority, and unrelated work. Do not commit, push, publish comments, change branches, stash, reset, or clean the checkout without authorization.

## Select reviewers

Resolve the reviewer sequence under [Reviewer selection](../code-review/references/reviewer-selection.md) (loop mode) and [Two-pass review](../code-review/references/two-pass-review.md). Each sequential stage (internal, Wave 1 external loop/panel, Wave 2 external loop/panel) runs as its own loop invocation with its own target-based round cap (**5 rounds** for code/implementation; **3 rounds** for plans/documentation); all reviewers in one external panel share that stage's cap.

Examples: `/code-review-loop` (internal), `/code-review-loop claude` (Claude), `/code-review-loop claude, codex, and grok` (combined panel), `/code-review-loop internal and claude & codex` (internal, then combined panel), `/code-review-loop claude and codex x 2` (Wave 1 Opus + Sol panel, then Wave 2 Astra).

## Coordinate review

Every round reviews under `code-review`. External loops (Codex, Claude, Grok, Gemini) dispatch each reviewer through its one-shot `*-review` skill—never `*-review-loop`—with the caller's selected provider, pass family, and options. Run multiple named external reviewers together as one combined panel loop; keep internal review sequential before an external panel when both are requested, and keep two-pass waves sequential. Use [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md) first to choose the runtime control (native subagent for an eligible same-provider internal review vs. T3 `delegate_task` or ACP fallback); once that selector chooses an external or orchestrated delegated review (or ACP fallback), apply [delegated review runtime](../code-review/references/external-runtime.md) for transport, handoff, and fresh per-round tasks.

Reviewers and repair agents reason independently from requirements and current evidence. Give later rounds only concise prior findings, responses, and open objections as unattributed claims to verify; omit unrelated repair history. Report reviewer independence accurately.

## Assess findings

Assess all completed reviews and retained partial findings from the round together with open findings before editing. Deduplicate overlapping claims across panel reviewers first; cross-reviewer agreement is a triage signal, not proof. Check each distinct claim against the requirement or invariant, reachable trigger, impact, and attribution, then accept, partially accept, or reject with a concise evidence-backed reason. Separate valid defects from proposed fixes, verify disputed facts directly, do not implement a suggestion only because a reviewer repeats it or gives it high priority, do not reject a valid defect only because its repair is inconvenient, and reject unsupported claims, preferences, and scope expansion without routine user confirmation.

Resolve material requirement ambiguity from existing authority; ask the user only when still necessary, continuing independent work meanwhile. Keep a compact finding ledger in context (findings, decisions, repairs, check evidence). Partial acceptance leaves the valid part open; partial coverage cannot establish a clean result.

## Repair

Group accepted defects across the round by root cause. Trace affected ownership, boundaries, callers, data flow, and invariants before editing; refactor when local patches would duplicate rules or leave the cause intact. Keep required behavior, data, explicit compatibility, and scope; do not add unrelated redesign or cleanup. Repair agents verify diagnoses independently and return evidence for any disagreement.

**Planning anti-bloat rule:** Resolve valid architectural, requirement, boundary, feasibility, or sequencing findings by tightening invariants, boundary contracts, phase outcomes, or observable acceptance criteria—never by adding prose pseudo-code, wire/byte-level parser specs, internal helper signatures, literal internal tags/keys, exact SQL predicates, or exhaustive test matrices unless fixed by an explicit requirement or external contract (matching `write-plan/references/plan-standards.md`). Reject micro-implementation findings as out-of-layer for planning, adding at most a one-line constraint or acceptance check when a real risk would otherwise be missed.

Finish all repairs, regression coverage, and directly related cleanup for the round and inspect the combined diff before running checks:
- **Code targets:** Verify repairs and affected consumers with fast targeted checks during intermediate rounds; inside `execute-plan`, defer full-suite verification to the closing `final-pass`; in a standalone loop, establish required full gates once repairs settle.
- **Saved plans, session scopes, & docs:** For saved plans, run repository document validators and check `plan-standards.md` conformance; for session-only scopes, check requirement, boundary, phase, and acceptance consistency; for non-plan docs, verify document contracts, references, and repository validators—without running unrelated application suites.
- Apply [Check evidence and reuse](../final-pass/references/check-evidence.md) and report passing checks to subsequent read-only reviewers so they do not rerun them.

If accepted defects persist after two repair stages, reassess cumulative changes and shared invariants before the next edit. If the same finding fails verification twice in the same way, stop repeating local patches: reassess the shared invariant, or if missing authority/input blocks repair, record the open finding or objection with blocker evidence and ask the user or finish `incomplete`/`capped` (without marking a functioning reviewer `blocked`). Repeated rejected suggestions do not trigger refactoring or scope expansion. Reassessment does not reset the round cap.

## Rounds

Keep review and remediation sequential; never edit the target during a review. Apply [Round state and convergence](references/round-state.md) for per-reviewer state (`blocked`, `open`, `broad coverage`), seeded coverage, Round 1 broad vs Rounds 2+ focused progression (re-broadening only after cross-cutting structural refactors), P3 convergence tail-off (closing without extra rounds once 0 open P0–P2 defects remain and only safe P3 tweaks/clarifications stay), and unresolved objections.

### Recover failed attempts

Apply [Recover failed attempts](references/failure-recovery.md) for format normalization, 3-attempt per-round retries, independent per-reviewer panel tracking, blocked accounting (never charging zero-completion rounds), and transport coordination.

## Finish

The loop stage is `clean` when every requested reviewer is non-blocked, holds `broad coverage`, and has no `open` P0–P2 findings, risky/structural P3 repairs, or unresolved objections; every finding has an evidence-backed disposition; and required repair verification passes (safe tail P3 fixes under P3 convergence still close `clean`, identified as check-verified without fresh review). When all non-blocked reviewers are clear and hold `broad coverage` but one or more requested reviewers are `blocked`, finish `incomplete` with each reviewer's status, rounds used, and missing coverage preserved.

After the cap or a real blocker: inside `execute-plan` or `ship-plan`, hand residuals and missing coverage to `final-pass` for authorized direct repair and verification; standalone, complete authorized direct repairs and verification yourself (or run `final-pass`) before concluding. Preserve the loop's actual `capped` or `incomplete` status and identify repairs verified without fresh review. Never call direct inspection a clean review.

During plan execution, follow `execute-plan` (`Completion and review checkpoints`). Report material findings, fixes, rejected claims with reasons, rounds used, per-reviewer resolved model, coverage, terminal status, check-verified tail P3 tweaks, checks, and limits concisely. Remove only task-owned scratch and verify cleanup. Save reports or transcripts only on request.
