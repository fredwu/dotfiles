---
name: compare-worktree
description: Compare the current Git worktree with one explicitly supplied peer worktree and identify only material improvements to apply to the current worktree. Use only when the user explicitly invokes this skill with exactly one target worktree path; never invoke implicitly, from a general comparison request, or without that path.
---

# Compare Worktree

Perform an independent, read-only review of two implementations. Treat the current worktree as the implementation to improve and the supplied worktree only as evidence or inspiration.

## Guardrails

- Accept exactly one target worktree path supplied with the explicit skill invocation.
- Run only read-only discovery commands. Never edit files, apply patches, install dependencies, run formatters or tests that may write artifacts, or run Git commands that change refs, the index, or either working tree.
- Never checkout, switch, reset, restore, stash, clean, commit, merge, rebase, cherry-pick, fetch, pull, or push.
- Quote paths and pass them as command arguments; never interpolate an untrusted path into executable shell text.
- Preserve staged, unstaged, untracked, and ignored content exactly as found.
- Do not use worktree names, branch names, author identities, tool/model attribution, commit authorship, or claims of quality as evidence. Judge observable behavior, correctness, tests, maintainability, security, and fit to requirements.

## Workflow

### 1. Validate the inputs

1. Resolve the current repository root with `git rev-parse --show-toplevel`.
2. Resolve the target path to an existing directory, then obtain its repository root with `git -C <target> rev-parse --show-toplevel`.
3. Confirm that the roots are distinct. If the argument is missing, invalid, not a Git worktree, or resolves to the current root, stop with one concise actionable correction.
4. Capture each side's `HEAD`, branch or detached state, and Git common directory using read-only `git rev-parse` calls. Do not assume the worktrees belong to the same repository merely because their names look related.

### 2. Establish a defensible shared base

Prefer the merge base of the two `HEAD` commits when both commits are visible from the same Git object database. Use `git merge-base --all` and, if multiple best bases exist, account for all of them rather than selecting one arbitrarily.

For separate object databases, identify a commit hash that is reachable from both `HEAD`s and verify its commit metadata and tree hash independently in both repositories before using it. Prefer the nearest common ancestor by graph distance. Do not treat matching branch names, commit subjects, timestamps, patch similarity, or empty-tree diffs as a shared base.

If no common reachable commit can be verified, stop. Output one actionable item explaining that a reliable comparison requires worktrees with shared Git history. Never fabricate a base or silently compare unrelated snapshots.

### 3. Recover the requirements

Read the visible conversation from the earliest user request through the current invocation. Include referenced task or plan text only when it is already available or can be read without mutation. Build a compact internal checklist of:

- explicit requested behavior and constraints;
- acceptance criteria and edge cases;
- later user corrections or scope changes;
- reasonable implications, kept distinct from explicit requirements.

Do not invent inaccessible prompts or let either implementation redefine the request. If the original or core requirements are not visible or otherwise available, stop and ask for one concise restatement instead of issuing intent-fit recommendations. If visible requirements remain ambiguous, favor recommendations that are valid under every plausible reading.

### 4. Inventory both implementations

For each worktree, inspect all four layers separately:

1. **Committed changes:** diff the shared base against `HEAD`.
2. **Staged changes:** diff `HEAD` against the index with `git diff --cached`.
3. **Unstaged changes:** diff the index against the working tree with `git diff`.
4. **Untracked files:** list with `git status --short --untracked-files=all`, then read relevant files directly.

Start with status, name-status, and diff-stat summaries. Inspect focused patches and relevant full files only as needed. Include deletions, renames, mode changes, submodules, generated files, and tests in the assessment. Treat binary files and unreadable submodules as limited evidence, and do not expose secrets from untracked or configuration files.

Also compare each effective implementation from the shared base through its committed and local changes so interactions across layers are not missed. Keep each layer's provenance clear; never mistake a target-only untracked file for committed design.

### 5. Evaluate independently

Evaluate the current implementation and the target implementation separately against the requirements checklist before comparing them. For each relevant difference, ask:

- Does the target fix a concrete correctness, security, compatibility, UX, performance, or maintainability issue in the current worktree?
- Does it cover a requirement or meaningful edge case the current worktree misses?
- Does it provide a stronger test or simpler design without introducing regressions, needless scope, or complexity?
- Does the difference inspire a better solution for the current worktree even when its exact code should not be copied?

Treat materially equivalent approaches as yielding no action. The current worktree is the destination for recommendations, not a presumptively superior implementation. Recommend borrowing only the smallest useful idea or change. Do not recommend wholesale replacement, aesthetic churn, or changes based merely on different style.

### 6. Report only actions

Output a short prioritized bullet list of concrete actions for the current worktree. Each item must state what to change, why it materially improves requirement fulfillment, and the relevant current/target file locations when known. Distinguish direct borrowing from an improvement merely inspired by the target when that affects implementation.

Do not include process narration, diff summaries, scorecards, praise, criticism, or recommendations for editing the target worktree. If the target offers no material improvement, output exactly:

`No action — the target worktree offers no material improvement.`
