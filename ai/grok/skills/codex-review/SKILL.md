---
name: codex-review
description: >
  After finishing the current task, run an external Codex CLI review and return
  its feedback verbatim. Use when the user says "Codex review", "ask Codex to
  review", or runs /codex-review. Codex is a second opinion — evaluate findings;
  do not treat them as ground truth.
metadata:
  short-description: "Finish task, then Codex reviews changes"
compatibility: Requires `codex` CLI (`codex login`). Shell + `mktemp` only.
---

# Codex Review

Complete any in-progress task first, then run Codex on the changes. Paste
Codex's output to the user **verbatim**. Treat findings as a second opinion —
judge them before acting; never auto-fix unless asked (then triage
Accept / Partial / Decline).

## Flow

1. **Same-turn** (work + "Codex review"): finish the work, then review.
   Before edits, note `SESSION_START_HEAD=$(git rev-parse HEAD 2>/dev/null)`
   if in git.
2. **Standalone** ("Codex review" alone): recover the **original user task
   prompt** from history; use any paths they name as the location.

If there is nothing plausible to review (no git delta, no session files, no
named paths), say so and stop.

## Prompt Codex with almost nothing

Send **only**:

| Field | Content |
|-------|---------|
| User prompt | Original task request (not the whole chat). Strip a trailing bare "Codex review". Standalone: prior task text from history. Optional one-line focus from the trigger. |
| Location | **Git (usual):** absolute repo root; optional `compare to <TARGET_BASE>`; include uncommitted if dirty; optional session-start SHA. **Non-git / named paths:** absolute file or dir paths. |

Do **not** send summaries, inventories, diffs, logs, tool traces, or prior
reviews. Codex discovers changes itself.

**Target base** (for the one-line location hint only — prefer integration
branch, not `@{upstream}`): `origin/HEAD` → `origin/main` → `origin/master`
→ local `main`/`master` → session start SHA.

## Run (one shell; timeout ~600000ms)

```bash
command -v codex || { echo "Install: brew install codex || npm i -g @openai/codex; codex login"; exit 1; }

umask 077
scratch="${TMPDIR:-/tmp}/grok-$(id -u)"
mkdir -p "$scratch" && chmod 700 "$scratch"
prompt_file="$(mktemp "$scratch/prompt.md.XXXXXX")"
out_file="$(mktemp "$scratch/out.md.XXXXXX")"
log_file="$(mktemp "$scratch/stream.log.XXXXXX")"
: > "$out_file"
echo "out_file=$out_file log_file=$log_file"

# Write $prompt_file from the template below, then:
cd "$CODEX_WORKDIR"   # repo root or dir of non-git targets — never pass -C
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  codex exec review --ephemeral -o "$out_file" - < "$prompt_file" > "$log_file" 2>&1
else
  codex exec review --ephemeral --skip-git-repo-check \
    -o "$out_file" - < "$prompt_file" > "$log_file" 2>&1
fi
```

- Custom PROMPT ⇒ do **not** also pass `--base` / `--uncommitted` / `--commit`.
- `XXXXXX` must be at the **end** of `mktemp` templates (macOS/BSD).
- Prefer one shell so paths stay set; else print absolute paths and reuse them.
- Success = non-empty `$out_file` (ignore exit code alone).
- On failure: last ~30 lines of `$log_file`; try `codex doctor` / `codex login`;
  do not invent findings.

### Prompt template

```markdown
You are performing an independent code review.

## Original user request

<USER_PROMPT>

## Where the changes are

<LOCATION>

Discover the changes yourself (git status/diff/log and/or by reading the paths).
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
```

## Reply to the user

```markdown
## Codex review

<full $out_file contents — zero edits>
```

Short wrapper outside the block is fine (task done; second opinion). Optional
judgment **after** the block only. Cleanup: `rm -f` prompt/log/out when done.
