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
6. Run required project checks and additional checks proportional to the affected behavior. Complete the local merge after review and required checks pass. Briefly report material resolutions, check results, blockers, and unverified behavior. Give results in chat; save reports for the user only when explicitly requested. Treat agent logs as temporary files.

## Temporary files

Prefer context or in-memory tracking. Create temporary or transit files only for a concrete agent need, such as tool input, verification, or an active handoff; never create them only for user presentation. Track exact task-owned paths and remove them once their consumers finish, on success, failure, or abandonment; verify removal before returning. Retain scratch only for active agent continuation, with an explicit cleanup owner and removal point. Report cleanup failures or active handoff paths. Preserve requested durable deliverables, including saved plans in `.local/`, and pre-existing or unrelated files; never clean a shared directory wholesale.
