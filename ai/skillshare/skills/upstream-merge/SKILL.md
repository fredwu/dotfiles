---
name: upstream-merge
description: Merge upstream into main while preserving intentional project customizations and incorporating compatible upstream changes.
---

# Upstream Merge

1. Inspect repository instructions, status, refs, remotes, ancestry, and divergence. Preserve dirty/untracked work; use an isolated worktree when useful, or stop if the merge would risk it.
2. Compare `main` and `upstream`. Identify intentional project behavior from history, diffs, documentation, and tests, not names alone.
3. Safely check out `main` and merge `upstream` with the repository's normal strategy, deferring the commit until review. Never use a global ours/theirs strategy. Push only if explicitly authorized.
4. Resolve conflicts semantically: preserve intentional customizations while incorporating compatible improvements. Regenerate locks and derived files with canonical tooling; repair merge-caused issues.
5. Compare the result against both parents for conflict markers, dropped behavior, reversions, and unrelated changes. Remove confirmed obsolete or redundant code and related tests/configuration/docs only within the changed and directly affected surface. Preserve required behavior and explicit compatibility.
6. Run required project checks and additional checks proportional to the affected behavior. Complete the local merge after review and required checks pass. Report material resolutions, check results, and blockers or unverified behavior in short, plain prose. Skip stock headings and repeated summaries; save a user report only if requested. Logs follow the temporary-file rules.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
