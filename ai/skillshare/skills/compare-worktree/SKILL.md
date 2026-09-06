---
name: compare-worktree
description: Compare the current worktree with one explicit peer and recommend material improvements read-only. Use only on explicit invocation with exactly one target worktree path.
---

# Compare Worktree

Evaluate both implementations against the user's requirements and recommend improvements to the current worktree. The peer supplies evidence or ideas, not authority. No report file is required.

## Boundaries and history

Require explicit invocation and exactly one target path, passed as a quoted argument. Stay read-only: do not edit files, install, fetch, run artifact-writing checks, or alter refs, indexes, worktrees, or external state. Preserve all existing content.

Resolve both Git roots with `git rev-parse --show-toplevel`, using `git -C <target>` for the peer. Require distinct existing worktrees. Establish each HEAD, branch/detached state, and Git common directory. For shared objects, use `git merge-base --all` and account for multiple best bases.

For separate object databases, verify a common reachable commit with matching commit metadata and tree hashes in both repositories; prefer the nearest by graph distance. Similar patches, names, subjects, or dates do not prove ancestry. If inputs or shared history cannot be established, request one actionable correction.

Recover the original request, updates, and referenced plans from available read-only context. Neither implementation redefines the task. Ask if core requirements are absent; otherwise limit recommendations to supported readings. Ignore author/model identity and branch names as quality evidence.

## Compare

Inspect each worktree's committed changes from the verified base, staged changes (`git diff --cached`), unstaged changes (`git diff`), and relevant untracked files (`git status --short --untracked-files=all`). Assess the combined effective implementation while retaining layer provenance.

Start with status and diff names/stats, then focused patches and complete files as needed. Account for deletions, renames, modes, submodules, generated files, and tests. Treat inaccessible content as an evidence limit and avoid exposing secrets. Delegate independent read-only scopes when useful after establishing shared bases and requirements; reconcile results without losing layer coverage.

Recommend only material requirement, correctness, security, compatibility, UX, performance, maintainability, or validation gains. Prefer the smallest useful change, preserve required behavior, and omit equivalent alternatives or style churn. Include confirmed obsolete or unnecessary code removal only within the changed/directly affected scope; do not invent cleanup.

Return prioritized action bullets with the change, requirement benefit, and known current/target locations. Distinguish direct borrowing from inspired improvements when useful. Include material evidence limits without a separate report. If no material improvement exists, say: `No action — the target worktree offers no material improvement.`
