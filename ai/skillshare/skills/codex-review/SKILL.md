---
name: codex-review
description: >
  After finishing the current task, run an external Codex CLI review, return its
  feedback verbatim, and add your own independent assessment of the findings.
  Use when the user says "Codex review", "ask Codex to review", or runs
  /codex-review. Codex is a second opinion — not ground truth.
metadata:
  short-description: "Codex review + independent assessment"
compatibility: Requires `codex` CLI on PATH (`codex login`). Shell + `mktemp` only.
---

# Codex Review

Finish any in-progress work first, then run Codex on the **current branch /
working tree**. Paste Codex's output **verbatim**, then give your **own
independent assessment** of each finding (Accept / Partial / Decline). Codex is
a second opinion — not ground truth. Never auto-fix unless asked (then apply
only Accepted / Partial findings).

## Flow

1. **Same-turn** (work + "Codex review"): finish the work, then review.
2. **Standalone** ("Codex review" alone): recover the **original user task**
   from history.

Stop if there is nothing plausible to review (no changes on the current branch
or working tree, and no named paths outside git).

## What to send Codex

**Only** the original task request (not the whole chat). Strip a trailing bare
"Codex review". Optional one-line focus from the trigger. Non-git work: name
absolute paths in that same prompt text.

Do **not** send summaries, inventories, diffs, logs, tool traces, or prior
reviews. `cd` to the repo root (or parent of named paths); Codex discovers
changes on the current branch and working tree itself.

## Run

One shell, tool `timeout: 600000`. Transcript goes to the log; Codex text is
stdout from `cat "$out_file"`. Full user reply is that text **plus** Assessment.

```bash
command -v codex >/dev/null || { echo "codex not on PATH"; exit 1; }

umask 077
scratch="${TMPDIR:-/tmp}/grok-$(id -u)"
mkdir -p "$scratch" && chmod 700 "$scratch"
out_file="$(mktemp "$scratch/out.md.XXXXXX")"
log_file="$(mktemp "$scratch/stream.log.XXXXXX")"
echo "out_file=$out_file"
echo "log_file=$log_file"

cd "/ABS/REPO_ROOT_OR_PATHS_PARENT"

# Inline the real task text into the heredoc body when constructing this
# command. Use a quoted delimiter that does NOT appear as a line in the task
# (default below; change it if the task contains that line). Quoted form
# prevents shell expansion of $ / backticks / quotes in the task.
codex exec review --ephemeral --skip-git-repo-check \
  -o "$out_file" - >"$log_file" 2>&1 <<'CODEX_REVIEW_PROMPT_EOF'
You are performing an independent code review.

## Original user request

…inline original task here…

Discover the changes yourself on the current branch and working tree
(git status/diff/log and/or by reading any paths named above).
Do not assume a change list was provided.

## Review criteria

- Focus on missing items, fixes, and real improvements.
- Be unbiased and concise. No praise-only summaries.
- Skip low-value nits. If nothing material, say so briefly.
- **No markdown links.** Reference files as relative `path/to/file.ext:LINE`
  (line optional when not applicable), e.g. `src/app.ts:42`. Never use
  `file://`, absolute paths, or `[text](url)` link syntax for code locations.

## Output

Review feedback only. No tool chatter or preamble. No markdown links.
CODEX_REVIEW_PROMPT_EOF

if [ -s "$out_file" ]; then
  cat "$out_file"
else
  echo "FAILED: empty out_file" >&2
  tail -n 30 "$log_file" >&2
  echo "try: codex doctor / codex login" >&2
fi
rm -f "$out_file" "$log_file"
```

### Rules

- Custom prompt ⇔ **no** `--base` / `--uncommitted` / `--commit` (CLI rejects
  the combination). Do not pass `-m` unless the user asked.
- No git mutations while the review runs (Codex holds git locks).
- Success = non-empty `$out_file` (ignore exit code alone). On empty: use the
  stderr log tail; do not invent findings.
- If the shell times out: **never kill** Codex. Poll the printed `out_file`
  until non-empty (bounded wait), then `cat` and `rm -f` both printed paths.
  If still empty when the bound expires: report both printed paths, do not
  delete, do not invent findings. Do not inspect or match `codex` processes.

## Reply to the user

Always both parts — never Codex alone:

```markdown
## Codex review

<full cat of out_file — zero edits>

## Assessment

For each Codex finding (or the review as a whole if clean), triage:
- **Accept** — valid; short reason grounded in the actual code or task
- **Partial** — partly right; what holds and what does not
- **Decline** — false positive, wrong severity, or out of scope; short reason

Also note anything material Codex missed. Do not restate Codex.
If the user asked to fix: change code only for Accept / Partial findings.
```

Do not skip Assessment when findings look obvious or empty. A clean Codex pass
still needs a brief Accept (confirmed clean) or Decline (you disagree).
