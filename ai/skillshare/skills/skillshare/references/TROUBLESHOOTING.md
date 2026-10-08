# Troubleshooting

## Start with evidence

Select the intended scope (`-p` or `-g`) and inspect before changing configuration:

```bash
skillshare status --json
skillshare doctor --json
skillshare diff --no-tui
skillshare log --no-tui --status error
```

`doctor` can exit 1 because it found issues. Inspect the output rather than assuming
execution failed. Use the configured source paths; XDG settings and custom sources can
make the default `~/.config/skillshare/skills` path incorrect.

| Symptom | Check and next step |
|---------|---------------------|
| Config not found | Confirm scope and config location, then use `init` or `init -p` if setup is needed. |
| Wrong project selected | Check `.skillshare/config.yaml` and `skillshare/config.yaml`; hidden wins. Force scope with `-p` or `-g`. |
| Skill or agent missing from target | Inspect source discovery, ignore rules, target include/exclude filters, and skill `metadata.targets`; preview sync for that resource. |
| Target differs from source | Inspect `diff`; decide whether to distribute source with `sync` or collect target-local changes with `collect`. |
| Audit blocks install/update | Read findings and the effective threshold. Fix the issue or use an explicitly intended override; do not automatically retry with `--force`. |
| Accidentally uninstalled | Find the item in skill/agent trash, restore it, then sync the same resource. |
| Ambiguous short name | Use the full source-relative name shown by `list`. |
| Git push/pull fails | Inspect the configured `git_root`, repository status, remote, and exact error. See [sync.md](sync.md). |
| MCP conflict | Inspect `mcp --json`; use the import/replacement workflow in [mcp.md](mcp.md). Ordinary `sync --force` is not an MCP override. |
| Custom rules missing | Check global/project `audit-rules.yaml` and `audit rules --no-tui`; do not overwrite existing rules with a starter file. |
| CLI waits for input | Provide names/selections and the command's supported noninteractive flags. Do not use `--force` as a universal prompt bypass. |

## Source recovery

For an uninstall, prefer [trash recovery](trash.md). For tracked source files, inspect
the actual repository and restore only the intended file:

```bash
git -C <repository> status --short
git -C <repository> diff -- <source-relative-file>
git -C <repository> log --oneline -- <source-relative-file>
```

After identifying the version and confirming local edits may be replaced:

```bash
git -C <repository> restore --source=<commit> -- <source-relative-file>
```

Avoid broad `git checkout -- .` recovery: it discards unrelated edits. Remote dependencies
can also be rehydrated with `skillshare install -p` in a project. Preview and sync after
source recovery; target backups do not replace source version control.

## Target recovery and symlinks

- Merge/symlink targets reference the source; editing through them changes source files.
- Copy targets contain separate files; inspect differences before collecting or overwriting.
- Removing a symlink itself is different from traversing its destination. Use
  `target remove` for detaching targets and `uninstall` for removing source resources.
- A symlink or junction placed directly under the skills source is ignored unless
  `follow_source_links: true` is set; then it is followed one level under its link name,
  `skillshare link <path> [--name <name>] [--enable]` creates one after the same safety
  checks (a junction on Windows). `skillshare unlink <name>` or dashboard **Unlink**
  moves only the link to trash. `uninstall <link>/<skill>` trashes the skill
  from the real checkout, and an unavailable link target holds back pruning, including
  read failures while traversing the target or its subdirectories, even after some
  skills have been discovered. When the linked folder itself contains `SKILL.md`,
  `uninstall <link>` is refused; use `unlink` or dashboard **Unlink** to keep the
  checkout untouched.
  Dashboard file lists include
  `SKILL.md` and attachments even when the followed link itself is the skill root.
  Git worktrees and submodules with a `.git` file have the same checkout guards:
  `update --all` skips them and the dashboard refuses to update them.
  Doctor identifies waiting target links by their stored destination, including
  when `target_naming: standard` uses a frontmatter name.
- Use [backup/restore](backup.md) for target snapshots and [MCP restore](mcp.md) for
  managed MCP entries. Choose the resource and scope before restoring.

Replacing a skill behind a followed link keeps the old skill until the replacement succeeds; a copy failure restores it. Links in incoming staged content are copied as real files or directories, and dangling links are skipped.

When dashboard target assignment writes frontmatter, it also uses this boundary: a nested `SKILL.md` link is refused without changing its target. Batch assignment reports the refusal for that skill and continues with regular skills.
