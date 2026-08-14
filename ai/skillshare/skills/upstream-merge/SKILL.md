---
name: upstream-merge
description: "Carefully merge the `upstream` branch into `main`: prioritize the current project's existing behavior in locally customized code while otherwise preserving upstream changes as fully as practical. Use when synchronizing main with upstream or handling conflicts from that merge."
---

# Upstream Merge

1. Read repository instructions. Inspect status, refs, remotes, ancestry, and divergence; preserve dirty and untracked work. Stop if merging would risk it.
2. Compare `main` and `upstream`. Identify project-owned or modified behavior from history, diffs, documentation, and nearby tests—not names alone.
3. Safely check out `main` and merge `upstream` with the repository's normal strategy. Never use a global ours/theirs option or push.
4. Resolve conflicts semantically. In customized code such as branding or landing pages, preserve main/ours behavior while incorporating compatible upstream improvements; elsewhere, retain upstream changes as fully as practical.
5. Regenerate lockfiles and derived files with canonical tooling. Repair merge-introduced compatibility issues in code, configuration, and tests.
6. Compare the result with both parents. Check for conflict markers, dropped behavior, accidental reversions, and unrelated changes. Run project-standard formatting, static analysis, tests, and builds for every affected area.
7. Complete the local merge only after full review. Report conflict resolutions, check outcomes, blockers, and anything unverified.
