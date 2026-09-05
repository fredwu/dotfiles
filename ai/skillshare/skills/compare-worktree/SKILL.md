---
name: compare-worktree
description: Compare the current worktree with one explicitly supplied peer and recommend material improvements, read-only. Use only on explicit skill invocation with exactly one target worktree path.
---

# Compare Worktree

Evaluate both implementations independently against the user's requirements. Recommend improvements to the current worktree; the target provides evidence or ideas, not authority.

## Boundaries

- Require explicit invocation and exactly one target path. Quote/pass paths as arguments, never interpolate untrusted paths into shell code.
- Stay read-only: do not edit files, install dependencies, run artifact-writing checks, fetch, or change refs, indexes, worktrees, or external state. Preserve committed, staged, unstaged, untracked, and ignored content.
- Judge observable behavior and requirement fit. Branch/worktree names, authors, model attribution, and quality claims are not evidence.

## Establish history and requirements

1. Resolve both Git roots with `git rev-parse --show-toplevel` (using `git -C <target>` for the peer). Require existing, distinct worktrees. For a missing/invalid/same-root target, request one concise actionable correction.
2. Record each `HEAD`, branch/detached state, and Git common directory. For a shared object database, use `git merge-base --all` and account for multiple best bases.
3. For separate object databases, verify a commit reachable from both `HEAD`s with matching commit metadata and tree hashes in both repositories; prefer the nearest shared ancestor by graph distance. Names, subjects, dates, similar patches, or empty-tree comparisons do not establish ancestry. If no common reachable commit is verifiable, return one actionable request for worktrees with shared history.
4. Recover the original request, later updates, and referenced plans available read-only. Make an internal checklist of explicit behavior, constraints, acceptance criteria, and edge cases; label implications separately. Neither implementation redefines the request. Ask for a concise restatement if core requirements are missing; otherwise recommend only actions valid under unresolved plausible readings.

## Inspect and compare

Cover each worktree's layers separately and its combined effective implementation, retaining provenance:

- Committed: verified base to `HEAD`.
- Staged: `HEAD` to index (`git diff --cached`).
- Unstaged: index to working files (`git diff`).
- Untracked: `git status --short --untracked-files=all`, then relevant file reads.

Start with status and diff names/stats; read focused patches and complete files as needed. Include deletions, renames, modes, submodules, generated files, and tests. Treat binaries/unreadable submodules as evidence limits and do not expose secrets.

After establishing history, prefer parallel read-only inspection for independent components/layers. Supply the same verified bases and requirements with distinct ownership. Wait for every result, independently validate evidence, reconcile and deduplicate; delegation does not replace full layer coverage.

Recommend only material gains in correctness, security, compatibility, UX, performance, maintainability, requirement coverage, tests, or design without regressions or needless complexity. Equivalent approaches need no action. Prefer the smallest useful change; avoid wholesale replacement and style churn.

Recommend confirmed obsolete, duplicate, dead, or unnecessary compatibility code removal only within the current changed/directly affected surface, with evidence that required behavior and explicit compatibility survive. Do not edit either worktree or invent cleanup.

## Output

Return only prioritized bullets of concrete current-worktree actions, each with the change, material requirement benefit, and known current/target file locations. Distinguish direct borrowing from target-inspired improvement when useful. Omit process narration, diff summaries, scorecards, and target edits.

If there is no material improvement, output exactly:

`No action — the target worktree offers no material improvement.`
