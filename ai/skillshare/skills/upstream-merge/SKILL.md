---
name: upstream-merge
description: Merge the upstream branch into main while preserving intentional project customizations and incorporating compatible upstream changes. Use for this synchronization or its conflicts.
---

# Upstream Merge

1. Read repository instructions. Inspect status, refs, remotes, ancestry, and divergence. Preserve dirty/untracked work; use an isolated worktree when appropriate or stop if the merge would risk it.
2. Compare `main` and `upstream`. Identify intentional project behavior from history, diffs, documentation, and tests, not names alone.
3. Safely check out `main` and merge `upstream` using the normal repository strategy, with commit deferred until review. Never use a global ours/theirs strategy or push.
4. Resolve conflicts semantically: preserve customized main behavior, such as branding, while incorporating compatible improvements. Elsewhere retain upstream changes as fully as practical.
5. Regenerate locks and derived files with canonical tooling. Repair merge-introduced source, configuration, and test issues.
6. Compare the result against both parents for conflict markers, dropped behavior, accidental reversions, and unrelated changes. Remove confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs only in the merge-changed or directly affected surface. Preserve required behavior, explicit compatibility, intentional customization, and unrelated work; a clean result is valid.
7. Run project-standard formatting, static analysis, tests, and builds for affected areas. Complete the local merge only after review and required checks pass; report resolutions, checks, blockers, and anything unverified.
