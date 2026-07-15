---
name: compare-worktree
description: >
  Compare the current worktree (this session's changes) against another
  specified git worktree (e.g. Codex or another agent). Read this file for
  instructions. Slash-command only: /compare-worktree [target_worktree].
disable-model-invocation: true
metadata:
  short-description: "Compare our worktree to another agent's"
---

# /compare-worktree — Cross-Agent Worktree Comparison

Compare **our** worktree (current session / this agent) to a **target** worktree
(Codex or another agent). Goal: find deficiencies in *our* work — things we got
wrong, missed, or should improve — informed by the original requirement and by
what the other agent did differently.

This is **not** a full dual code review. Be concise: final output is a
**bullet list only**. Prefer actionable fixes over praise or style nits.

## Usage

```
/compare-worktree [target_worktree]
```

`[target_worktree]` is required: absolute path, relative path, or a path
resolvable from the current workspace. Examples:

- `/compare-worktree ../feedbun-codex`
- `/compare-worktree /Users/me/Code/Wuit/feedbun-wt-codex`
- `/compare-worktree .claude/worktrees/feature-x`

If the argument is missing or the path does not exist / is not a git worktree,
ask once for a valid path and stop. Do not invent a target.

## Principles

1. **Our tree is the subject.** The target is a reference implementation, not
   the thing to rewrite. Every finding must answer: *what should we change here?*
2. **Requirements first.** Diffs without the user prompt are noise. Reconstruct
   the original ask from this session before judging either tree.
3. **Evidence over vibes.** Cite concrete files/hunks from both trees. Do not
   claim the other agent is better without pointing at their code.
4. **Actionable and ranked.** Output only things worth pursuing. Skip pure
   style, churn, or differences that are equally valid.
5. **Do not modify either worktree** unless the user explicitly asks to apply
   fixes after the comparison.

## Steps

### 1. Resolve worktrees

```bash
# Ours
pwd
git rev-parse --show-toplevel
git worktree list
git status -sb
git branch -vv

# Theirs (TARGET is the user-provided path)
TARGET="<resolved path>"
test -d "$TARGET" && git -C "$TARGET" rev-parse --show-toplevel
git -C "$TARGET" status -sb
git -C "$TARGET" branch -vv
```

Record for both sides:

| Field | Ours | Theirs |
|-------|------|--------|
| Root | | |
| Branch | | |
| HEAD | | |
| Dirty? | | |

If either side is not a git repo, stop and report the error.

### 2. Establish a shared comparison base

Prefer a common ancestor so both diffs are comparable:

```bash
OURS=$(git rev-parse --show-toplevel)
THEIRS=$(git -C "$TARGET" rev-parse --show-toplevel)

# Shared merge-base of the two HEADs (best when both branched from same point)
BASE=$(git merge-base HEAD "$(git -C "$THEIRS" rev-parse HEAD)")

# Fallbacks if merge-base fails or is too shallow:
# - merge-base of each HEAD with origin/main (or main/master)
# - if both dirty on the same branch name, still diff each against BASE
```

Use `origin/main` / `main` / `master` only as fallback when the two HEADs do
not share a useful ancestor. State which base you used in one line.

### 3. Collect each worktree's change set

For **ours** (include uncommitted work — that is usually this session's output):

```bash
git status --short
git diff --stat "$BASE"
git diff "$BASE"                    # committed + unstaged relative to base needs:
git diff "$BASE" -- .               # working tree vs base:
# Full picture vs base including index + worktree:
git diff "$BASE" HEAD
git diff HEAD                       # unstaged
git diff --cached                   # staged
# Combined patch of everything not in BASE:
git diff "$BASE"
# Also list files only in working tree changes:
git diff --name-status "$BASE"
git diff --name-status HEAD
git status --short
```

Practical combined view for "what our tree looks like right now vs base":

```bash
# Committed commits on our branch since BASE
git log --oneline "$BASE"..HEAD
# Patch of committed + uncommitted (approximate: show all local divergence)
git diff "$BASE"
git diff HEAD
git diff --cached
```

For **theirs**, run the same with `git -C "$THEIRS" ...`.

Also produce file lists:

```bash
git diff --name-only "$BASE"
git -C "$THEIRS" diff --name-only "$BASE"
```

If either side has **no** meaningful diff vs base, say so and still check the
other side for requirement coverage (a green empty tree can mean "did nothing").

### 4. Reconstruct the requirement

From **this conversation only** (user messages, not agent speculation):

- Original ask and any follow-ups / corrections
- Explicit constraints (tests, docs, no commits, scope limits)
- Acceptance criteria the user stated

Restate privately as a short checklist (5–12 items) for comparison; put only
a **one-line** requirement summary in the report under **Context**. If the
session has no clear requirement (user only ran the slash command), note that
and compare implementation quality only — do not invent product goals.

Optional: if a plan file, Linear/GitHub issue, or PR body was referenced in the
session, read it and fold constraints into the checklist. Do not go hunting
unrelated tickets.

### 5. Compare approaches

Read the important diffs and surrounding source on **both** sides. Focus on
files that:

- Appear only on one side
- Differ in substance (logic, API, schema, tests, error handling)
- Map directly to a checklist item

For each checklist item, judge:

| Outcome | Meaning |
|---------|---------|
| **Both cover** | Note only if their approach is clearly safer/simpler/more complete and we should adopt something specific |
| **They only** | We missed it — high priority if it maps to the requirement |
| **We only** | We may have extra work; flag only if excess is harmful or their omission reveals we over-scoped |
| **Both wrong / incomplete** | Call out if evidence is clear; do not assume their tree is ground truth |
| **Divergent valid** | Different but equivalent — **omit** from the report |

When their code is better, extract the **idea** (pattern, edge case, test,
API shape), not a demand to copy-paste their tree.

### 6. Write the report

**Output shape is non-negotiable:** only markdown bullet lists. No essay
intro, no numbered sections with prose, no `###` headings per finding.
Keep the whole report scannable in under a minute.

Use this exact structure:

```markdown
## Context
- Requirement: <one short line, or "none in session — quality-only compare">
- Ours: `<path>` @ `<branch>` (`<short sha>`, dirty/clean)
- Theirs: `<path>` @ `<branch>` (`<short sha>`, dirty/clean)
- Base: `<sha or ref>`

## Pursue
- **P1** — <actionable title>: <what to change in our tree>. Evidence: `our/path` vs `their/path`.
- **P2** — …
- **P3** — …

## Skip
- <one-line: large equivalent/out-of-scope divergence you noticed>   # omit section if none

## Do not copy
- <one-line: their approach we should not adopt, and why>   # omit section if none
```

Rules for bullets:

- **Pursue** is the only required findings section. Ordered by impact.
- One bullet per item. Title + action + brief evidence on the **same line**
  (or wrap once; never a multi-paragraph block).
- Prefer **≤ 7** pursue bullets. Merge related gaps.
- Severity: **P1** correctness / missing requirement / security; **P2** weaker
  design or missing important edge/test; **P3** small polish worth stealing.
- No generic "add more tests" without naming the behavior.
- No formatting/import-order/comment nits.
- If nothing material to pursue: one bullet under **Pursue** —
  `- None — our tree covers the requirement; no actionable gaps.`
- Do **not** start implementing fixes unless the user asks after the report.

### 7. Stop

End after the report. Optional final single bullet only if useful, e.g.
`- Next: say if you want P1–P2 applied in this worktree.`

## Edge cases

- **Same branch, two dirty worktrees:** still compare working trees vs shared
  base; file-level `diff -ru` between paths is allowed when git base is identical:
  ```bash
  diff -rq "$OURS" "$THEIRS" --exclude=.git
  # then targeted: diff -u "$OURS/path" "$THEIRS/path"
  ```
- **Target has commits we lack (or reverse):** use file lists from both
  `git diff --name-only $BASE` outputs; read unique files fully enough to judge
  requirement coverage.
- **Binary / generated / lockfile-only diffs:** ignore unless the requirement
  was about them.
- **Huge diffs:** sample by checklist relevance; state that you sampled and
  which areas you did not fully read.
- **Unrelated dirty files on our side:** ignore files clearly outside the
  session's task (note "left out of comparison: …" in one line).

## Anti-patterns

- Do not rewrite the report as "what Codex did better" without tying each
  point to a change we should make.
- Do not treat the target worktree as automatically correct.
- Do not auto-merge, cherry-pick, or copy files from the target.
- Do not run the full test suite unless a pursue-item depends on verifying a
  behavioral claim and a cheap check is available; this skill is comparative,
  not `/check-work`.
