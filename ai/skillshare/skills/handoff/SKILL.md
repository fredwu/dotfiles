---
name: handoff
description: Write a concise .local/YYMMDD-handoff-<topic>.md file to resume in a fresh session or fork parallel work (explicit requests only).
metadata:
  origin: custom
---

# Handoff

Capture verified session state into a short handoff file so work can resume cleanly in a fresh thread without lossy mid-task compaction, or branch a parallel track into a forked thread. This skill is opt-in (explicit requests only); it never weakens `execute-plan` or `ship-plan`'s default single-session autonomous execution when no session boundary is set.

## When to hand off vs. fork

- **Phase or stage boundary (fresh session):** Write a handoff file when moving between major stages (such as planning → execution or between heavy phases) and the user wants a clean context window instead of compacting.
- **Parallel track (session fork):** When a second independent track branches off mid-session (such as visual polish, docs, or a side investigation that benefits from already-loaded context), fork the thread (`t3_thread_transfer` with `action: "fork"` in T3 Code, or the harness's fork control) rather than running unrelated tracks sequentially in one context.

## Write the handoff file

- **Destination:** Save under `.local/YYMMDD-handoff-<topic>.md` at the repository root (workspace root when outside Git) using the current local date `YYMMDD` and a short kebab-case `<topic>`. On collision, append `-v2`, `-v3`, and never overwrite an existing file. Honor an explicit user path if given.
- **Schema:** Populate the exact canonical fields defined in [State packet](../execute-plan/references/state-packet.md) (mark non-applicable plan/review fields `N/A` cleanly) and include a pointer to `execute-plan/references/state-packet.md#resume-validation` so any resumed session applies the resume rules.
- **Keep it lean:** Cite exact file paths, commit SHAs, and concise verified facts; never inline diffs, full plans, source files, or conversation transcripts. Verify `git rev-parse HEAD` and content identities (hashes or diff digests of relevant dirty/untracked inputs) before recording `Verified checks` so the next session can safely validate reuse under [Check evidence and reuse](../final-pass/references/check-evidence.md).

## Finish

Link the saved handoff file and give a concise one-line resume prompt in the active harness's invocation syntax (for example `/...` in Claude/T3 or `$...` in Codex):
- Mid-`ship-plan` Stages 1–3 (before execution starts): route back to `ship-plan` (for example `/ship-plan .local/261126-handoff-<topic>.md` or `$ship-plan .local/261126-handoff-<topic>.md`) so pending plan review or plan `final-pass` is not bypassed.
- Stage 4 or standalone `execute-plan`: route to `execute-plan` (for example `/execute-plan .local/261126-handoff-<topic>.md` or `$execute-plan .local/261126-handoff-<topic>.md`).
- Other work: give a direct resume line (for example `Resume from .local/261126-handoff-<topic>.md`).

Do not start the next phase automatically once a handoff boundary has been requested.
