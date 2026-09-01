---
name: compare-worktree
description: Compare the current Git worktree with one explicitly supplied peer worktree and identify only material improvements to apply to the current worktree. Use only when the user explicitly invokes this skill with exactly one target worktree path; never invoke implicitly, from a general comparison request, or without that path.
---

# Compare Worktree

Independently compare two implementations, read-only. Improve the current worktree; treat the target only as evidence or inspiration.

## Guardrails

- Accept exactly one target path supplied with the explicit skill invocation.
- Use only read-only discovery. Do not edit, patch, install dependencies, run commands that may write artifacts, or change repository/external state.
- Never checkout, switch, reset, restore, stash, clean, commit, merge, rebase, cherry-pick, fetch, pull, push, or otherwise change refs, indexes, or worktrees. Preserve committed, staged, unstaged, untracked, and ignored content.
- Quote paths and pass them as arguments; never interpolate an untrusted path into shell text.
- Compare identity-blind. Worktree/branch names, authors, tool/model attribution, and quality claims are not evidence. Judge observable behavior, correctness, tests, maintainability, security, and requirement fit.

## Workflow

### 1. Validate inputs and history

1. Resolve the current root with `git rev-parse --show-toplevel`. Resolve the target to an existing directory and its root with `git -C <target> rev-parse --show-toplevel`. Require distinct roots; otherwise stop with one concise actionable correction.
2. Record each `HEAD`, branch/detached state, and Git common directory with read-only `git rev-parse`. Do not infer shared history from names.
3. When both commits use one object database, obtain all best bases with `git merge-base --all`; account for multiple bases rather than choosing arbitrarily.
4. For separate object databases, use only a commit reachable from both `HEAD`s whose commit metadata and tree hash match independently in both repositories; prefer the common ancestor nearest by graph distance. Branch names, subjects, timestamps, patch similarity, and empty-tree diffs do not establish a base.

If the path is missing, invalid, not a Git worktree, or resolves to the current root, request the specific correction. If no common reachable commit can be verified, output one actionable item requesting worktrees with shared Git history; never fabricate a base or compare unrelated snapshots.

### 2. Recover requirements

Read the visible conversation from the original request through this invocation, plus referenced task/plan text available read-only. Build an internal checklist of explicit behavior, constraints, acceptance criteria, edge cases, later corrections or scope changes, and separately labeled reasonable implications. Neither implementation may redefine the request. If core requirements are unavailable, request one concise restatement instead of making intent-fit recommendations. For unresolved ambiguity, favor actions valid under every plausible reading.

### 3. Inventory both implementations

Inspect these layers separately in each worktree:

1. committed: shared base to `HEAD`;
2. staged: `HEAD` to index (`git diff --cached`);
3. unstaged: index to working tree (`git diff`);
4. untracked: `git status --short --untracked-files=all`, then read relevant files directly.

Start with status, name-status, and diff-stat; inspect focused patches and full files as needed. Include deletions, renames, modes, submodules, generated files, and tests. Treat binaries and unreadable submodules as limited evidence, and never expose secrets from untracked or configuration files. Also evaluate each effective implementation from base through all committed and local changes, preserving layer provenance.

### 4. Evaluate and report

Evaluate each implementation independently against the checklist, then compare. Recommend a target idea only when it materially improves the current worktree's correctness, security, compatibility, UX, performance, maintainability, requirement coverage, edge-case handling, tests, or design without adding regressions, needless scope, or complexity. Treat equivalent approaches as no action. The target may inspire a better solution without its code being copied; recommend the smallest useful change, never wholesale replacement or stylistic churn.

Treat confirmed legacy, redundant, duplicate, dead or unused, obsolete, superseded, and no-longer-needed compatibility code within the current change and directly affected task surface as a material improvement only when evidence supports safe removal. Preserve required behavior, explicitly required compatibility, unrelated work, and scope. A clean result is acceptable; do not invent work. Recommend rather than edit either worktree.

Output only a short prioritized bullet list of concrete current-worktree actions. Each item must state the change, its material requirement benefit, and known current/target file locations. Distinguish direct borrowing from target-inspired improvement when relevant. Do not include process narration, diff summaries, scorecards, praise, criticism, or target-worktree edits.

If the target offers no material improvement, output exactly:

`No action — the target worktree offers no material improvement.`
