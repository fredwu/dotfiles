---
name: upstream-merge
description: "Carefully merge the `upstream` branch into `main`: prioritize the current project's existing behavior in locally customized code while otherwise preserving upstream changes as fully as practical. Use when synchronizing main with upstream or handling conflicts from that merge."
---

# Upstream Merge

1. Read repository instructions. Inspect status, refs, remotes, ancestry, and branch divergence before changing anything.
2. Preserve all dirty and untracked work. Stop and report a blocker if the merge cannot proceed without risking it.
3. Compare `main` and `upstream`. Identify project-owned or locally modified behavior from repository evidence such as history, diffs, documentation, and nearby tests; do not infer ownership from names alone.
4. Ensure `main` is checked out safely, then merge `upstream` with the repository's normal strategy. Never use a global ours/theirs strategy option and never push.
5. Resolve conflicts semantically. In project-customized code, such as branding or landing pages, prioritize main/ours behavior while incorporating compatible upstream improvements. Elsewhere, bring in upstream changes as fully as practical.
6. Regenerate lockfiles and other derived files with canonical project tooling. Refactor code, configuration, and tests to resolve compatibility issues introduced by the merge.
7. Inspect the result against both parents and search for unresolved conflict markers, dropped behavior, accidental reversions, and unrelated changes.
8. Run relevant project-standard formatting, static analysis, tests, and builds for every affected area.
9. Complete the local merge only after reviewing the full result. Report conflict resolutions, checks and outcomes, unresolved blockers, and anything not verified.
