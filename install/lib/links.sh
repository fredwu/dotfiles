#!/bin/bash

copy_if_missing() {
  local source=$1
  local target=$2

  if [[ -e "$target" || -L "$target" ]]; then
    return 0
  fi

  mkdir -p "$(dirname -- "$target")"
  cp "$source" "$target"
  log "Created $target"
}

ensure_ai_directory() {
  local name=$1
  local target="$HOME/.$name"
  local legacy="$DOTFILES_ROOT/ai/$name"

  if [[ -L "$target" && -e "$target" && -e "$legacy" && "$target" -ef "$legacy" ]]; then
    unlink "$target"
    mv "$legacy" "$target"
    log "Moved $legacy to $target"
  elif [[ -L "$target" ]]; then
    die "cannot replace unexpected AI config link: $target -> $(readlink "$target")"
  elif [[ -e "$target" && ! -d "$target" ]]; then
    archive_path "$target"
  fi

  mkdir -p "$target"
}

ensure_claude_pre_tool_guard_registered() {
  local settings="$HOME/.claude/settings.json"
  local hook_cmd="'$HOME/.claude/hooks/pre-tool-guard.sh'"

  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  python3 - "$settings" "$hook_cmd" <<'PY'
import json, os, sys

settings_path, hook_cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if not isinstance(loaded, dict):
            sys.stderr.write(f"[dotfiles] warning: {settings_path} is not a JSON object; skipping pre-tool-guard hook registration\n")
            sys.exit(0)
        data = loaded
    except Exception as exc:
        sys.stderr.write(f"[dotfiles] warning: could not parse {settings_path} ({exc}); skipping pre-tool-guard hook registration\n")
        sys.exit(0)

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    sys.stderr.write(f"[dotfiles] warning: {settings_path} 'hooks' is not a JSON object; skipping pre-tool-guard hook registration\n")
    sys.exit(0)
pre_list = hooks.setdefault("PreToolUse", [])
if not isinstance(pre_list, list):
    sys.stderr.write(f"[dotfiles] warning: {settings_path} 'hooks.PreToolUse' is not a JSON list; skipping pre-tool-guard hook registration\n")
    sys.exit(0)

changed = False
found = False
for entry in pre_list:
    if isinstance(entry, dict) and entry.get("matcher") == "Bash":
        for h in entry.get("hooks", []):
            if isinstance(h, dict) and "pre-tool-guard.sh" in str(h.get("command", "")):
                found = True
                if h.get("onFailure") != "block":
                    h["onFailure"] = "block"
                    changed = True
                if "timeout" not in h:
                    h["timeout"] = 10
                    changed = True

if not found:
    pre_list.append({
        "matcher": "Bash",
        "hooks": [
            {
                "type": "command",
                "command": hook_cmd,
                "timeout": 10,
                "onFailure": "block",
            }
        ],
    })
    changed = True

if changed:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
}

install_ai_links() {
  local name
  local instructions

  for name in claude codex grok; do
    ensure_ai_directory "$name"
    if [[ "$name" == claude ]]; then
      instructions=CLAUDE.md
    else
      instructions=AGENTS.md
    fi
    ensure_symlink "$DOTFILES_ROOT/ai/shared/AGENTS.md" "$HOME/.$name/$instructions"
  done
  ensure_symlink "$DOTFILES_ROOT/ai/hooks/pre-tool-guard.sh" "$HOME/.claude/hooks/pre-tool-guard.sh"
  ensure_claude_pre_tool_guard_registered
}

install_dotfiles() {
  local template
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local -a templates

  templates=(
    ackrc gemrc gitconfig gitignore_global railsrc zlogin zpreztorc zprofile
    zshenv zshrc
  )

  for name in "${templates[@]}"; do
    template="$DOTFILES_ROOT/templates/$name"
    ensure_symlink "$template" "$HOME/.$name"
  done

  ensure_private_directory "$HOME/.ssh"
  ensure_private_directory "$HOME/.gnupg"
  ensure_symlink "$DOTFILES_ROOT/templates/ssh/config" "$HOME/.ssh/config"
  ensure_symlink "$DOTFILES_ROOT/templates/gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
  ensure_symlink "$DOTFILES_ROOT/config/nvim" "$config_home/nvim"
  install_ai_links

  copy_if_missing "$DOTFILES_ROOT/zsh/custom.example" "$HOME/.zsh_custom"
  if [[ ! -e "$HOME/.zsh_pre_custom" && ! -L "$HOME/.zsh_pre_custom" ]]; then
    touch "$HOME/.zsh_pre_custom"
    log "Created $HOME/.zsh_pre_custom"
  fi
}
