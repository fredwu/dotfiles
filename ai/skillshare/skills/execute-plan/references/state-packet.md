# State packet

Single canonical schema for session handoffs (`handoff`), stage transitions (`ship-plan`), and compaction continuity (`execute-plan`). Keep every field concise; reference file paths rather than pasting plans, diffs, source dumps, or transcripts.

## Canonical fields

1. **`Goal / Plan path or scope`:** Objective plus saved plan path (or concise session scope).
2. **`Progress`:** Current `N/T` phase and `~P% overall` estimate (when executing a plan or `ship-plan`).
3. **`Selected review sequence & pending stages`:** Exact resolved reviewers, explicit model IDs and effort/options (when user-specified or already resolved), model families/two-pass waves, and exact completed vs. pending stages (for example `claude + codex panel (pending)` or `Wave 1 done, Wave 2 Astra (gpt-6.2-astra, high) pending`).
4. **`Active file paths`:** Exact paths actively edited, under investigation, or needed immediately on resume.
5. **`Decisions & invariants`:** Accepted user decisions, architectural boundaries, authority limits, and scope exclusions.
6. **`Verified checks`:** Each passing/failed/reused gate bound to its exact checked state: command, result, commit (`HEAD`), and **content identities** (such as file hashes or diff digests) for relevant dirty and untracked inputs under [Check evidence and reuse](../../final-pass/references/check-evidence.md).
7. **`Review-stage & finding-ledger status`:** Rounds used, per-reviewer coverage/terminal status, and any open findings or objections (when applicable).
8. **`Open blockers`:** Missing authority, external dependencies, or unresolved questions (`None` if clear).
9. **`Next checkpoint`:** Immediate next action or resume entry point (and resume pointer `execute-plan/references/state-packet.md#resume-validation`).

## Resume validation

When resuming work from a state packet or `.local/YYMMDD-handoff-*.md` file in a fresh session (or after compaction):

- **Preserve review selection and pending stages:** Restore `Selected review sequence & pending stages` (including explicit models, options, and two-pass waves) verbatim, and dispatch **only pending stages** from the saved checkpoint. Never revert to the internal review default when external reviewers are pending, and never replay completed stages.
- **Re-validate check evidence by content identity:** Compare each recorded check's `HEAD` and content identities (hashes or diff digests of relevant dirty/untracked inputs) against the current worktree under `check-evidence.md`. A matching `HEAD` and dirty path list alone does not prove unchanged content; rerun whenever content identity is missing, differs, or cannot be verified.
- **Re-open active files directly:** Read listed `Active file paths` and the plan path rather than reconstructing details from memory.
