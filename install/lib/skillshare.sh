#!/bin/bash

require_supported_skillshare() {
  local output installed_version

  output=$(env -u NODE_OPTIONS skillshare --version 2>&1) || \
    die "cannot determine installed Skillshare version"
  installed_version=$(printf '%s\n' "$output" | sed -nE 's/^skillshare v([0-9]+\.[0-9]+\.[0-9]+)([[:space:]].*)?$/\1/p' | tail -1)
  [[ -n "$installed_version" ]] || die "cannot determine installed Skillshare version"
  version_at_least "$installed_version" 0.26.4 || \
    die "Skillshare 0.26.4 or newer is required (found $installed_version)"
}

configure_skillshare() (
  unset CLAUDE_CONFIG_DIR CODEX_HOME OPENCODE_CONFIG_DIR PI_CODING_AGENT_DIR GROK_HOME NODE_OPTIONS

  require_command skillshare
  require_command node
  require_command npm
  require_supported_skillshare
  [[ -x "$DOTFILES_ROOT/scripts/skillshare-sync" ]] || \
    die "managed Skillshare command is missing or not executable: $DOTFILES_ROOT/scripts/skillshare-sync"

  # shellcheck source=install/lib/skillshare-deps.sh
  source "$DOTFILES_ROOT/install/lib/skillshare-deps.sh" || \
    die "cannot load Skillshare dependency bootstrap"
  log "Preparing Skillshare dependencies"
  ensure_skillshare_node_dependencies "$DOTFILES_ROOT" >/dev/null || \
    die "Skillshare dependency bootstrap failed"

  log "Preparing and syncing managed Skillshare resources"
  "$DOTFILES_ROOT/scripts/skillshare-sync" --bootstrap || \
    die "Managed Skillshare bootstrap failed"
)
