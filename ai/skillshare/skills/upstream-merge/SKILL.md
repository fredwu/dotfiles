---
name: upstream-merge
description: Merge upstream into the default branch while preserving intentional project customizations and incorporating compatible upstream changes.
metadata:
  origin: custom
---

# Upstream Merge

1. Inspect repository instructions, status, refs, remotes, ancestry, and divergence. Identify the default branch (`main` or `master`, or an explicit target branch) and resolve which ref `upstream` names (a local branch or a remote-tracking branch); for a remote-tracking branch, fetch first so the merge uses the current upstream. Preserve dirty/untracked work; use an isolated worktree when useful (merging on a temporary branch if the default branch is already checked out in the primary worktree, then fast-forwarding the default branch in its own worktree with `git merge --ff-only` once verified—never use `git update-ref` on a checked-out branch—and removing the task-owned worktree and deleting the temporary branch once the fast-forward succeeds; if local changes block the fast-forward, keep both and report their names), or stop if the merge would risk uncommitted work.
2. Compare the default branch and `upstream`. Identify intentional project behavior from history, diffs, documentation, and tests, not names alone.
3. Safely check out the default branch (or the isolated temporary branch) and merge `upstream` with the repository's normal strategy, deferring the commit until review. Never use a global ours/theirs strategy. Push only if explicitly authorized.
4. Resolve conflicts semantically: preserve intentional customizations while incorporating compatible improvements. Regenerate locks and derived files with canonical tooling; repair merge-caused issues.
5. Compare the result against both parents for conflict markers, dropped behavior, reversions, and unrelated changes.
6. Run `final-pass` over the merged result (including its cleanup round, full testing and quality checks, evidence reuse, repair, and stop rules, plus checks proportional to the affected behavior). Complete the local merge commit after review and required checks pass. Report the merge commit, material resolutions, check results, and blockers or unverified behavior in short, plain prose. Skip stock headings and repeated summaries; save a user report only if requested. Logs follow `final-pass` (`Temporary files`).
