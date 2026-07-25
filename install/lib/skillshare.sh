#!/bin/bash

configure_skillshare() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local skillshare_home="$config_home/skillshare"
  local skills_source="$skillshare_home/skills"
  local agents_source="$skillshare_home/agents"

  require_command skillshare
  ensure_symlink "$DOTFILES_ROOT/ai/skillshare/skills" "$skills_source"
  ensure_symlink "$DOTFILES_ROOT/ai/skillshare/agents" "$agents_source"

  if [[ ! -f "$skillshare_home/config.yaml" ]]; then
    log "Initializing Skillshare"
    skillshare init \
      --source "$skills_source" \
      --no-copy \
      --targets claude,codex,grok \
      --mode symlink \
      --no-git \
      --no-skill
  fi

  log "Syncing Skillshare targets"
  skillshare sync -g
}
