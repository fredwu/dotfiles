---
name: upstream-merge
description: Merge upstream into main while preserving intentional project customizations and incorporating compatible upstream changes.
metadata:
  origin: custom
---

# Upstream Merge

1. Inspect repository instructions, status, refs, remotes, ancestry, and divergence. Resolve which ref `upstream` names (a local branch or a remote-tracking branch); for a remote-tracking branch, fetch first so the merge uses the current upstream. Preserve dirty/untracked work; use an isolated worktree when useful, or stop if the merge would risk it.
2. Compare `main` and `upstream`. Identify intentional project behavior from history, diffs, documentation, and tests, not names alone.
3. Safely check out `main` and merge `upstream` with the repository's normal strategy, deferring the commit until review. Never use a global ours/theirs strategy. Push only if explicitly authorized.
4. Resolve conflicts semantically: preserve intentional customizations while incorporating compatible improvements. Regenerate locks and derived files with canonical tooling; repair merge-caused issues.
5. Compare the result against both parents for conflict markers, dropped behavior, reversions, and unrelated changes. Remove confirmed obsolete or redundant code and related tests/configuration/docs only within the changed and directly affected surface. Preserve required behavior and explicit compatibility.
6. Run required project checks and additional checks proportional to the affected behavior. Complete the local merge after review and required checks pass. Report material resolutions, check results, and blockers or unverified behavior in short, plain prose. Skip stock headings and repeated summaries; save a user report only if requested. Logs follow the temporary-file rules.

## Temporary files

Keep scratch notes in context. Create a temporary file only when an agent needs it; track it, delete it after use (also after failure or abandonment), and verify the deletion. If a file must stay for continuing agent work, name its cleanup owner and report its path. Never delete requested deliverables (including `.local/` plans), pre-existing files, unrelated work, or shared directories.
