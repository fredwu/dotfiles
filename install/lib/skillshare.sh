#!/bin/bash

configure_skillshare() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local skillshare_home="$config_home/skillshare"
  local skills_source="$skillshare_home/skills"
  local agents_source="$skillshare_home/agents"
  local codex_agents_extension="$skillshare_home/extensions/codex-agents"
  local codex_agents_config_state
  local agent_file
  local agent_name
  local codex_agent_file

  require_command skillshare
  require_command node
  ensure_symlink "$DOTFILES_ROOT/ai/skillshare/skills" "$skills_source"
  ensure_symlink "$DOTFILES_ROOT/ai/skillshare/agents" "$agents_source"
  ensure_symlink \
    "$DOTFILES_ROOT/ai/skillshare/extensions/codex-agents" \
    "$codex_agents_extension"

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

  codex_agents_config_state=$(env -u NODE_OPTIONS node \
    "$DOTFILES_ROOT/install/lib/configure-skillshare-extra.js" \
    "$skillshare_home/config.yaml" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$HOME/.codex/agents")

  if [[ "$codex_agents_config_state" == changed ]]; then
    for agent_file in "$DOTFILES_ROOT/ai/skillshare/agents/"*.md; do
      [[ -e "$agent_file" ]] || continue
      agent_name=${agent_file##*/}
      codex_agent_file="$HOME/.codex/agents/${agent_name%.md}.toml"
      if [[ -e "$codex_agent_file" || -L "$codex_agent_file" ]]; then
        archive_path "$codex_agent_file"
      fi
    done
  fi

  log "Validating Skillshare agent model mappings"
  env -u NODE_OPTIONS node "$codex_agents_extension/validate.js" "$agents_source"

  log "Syncing Skillshare targets"
  skillshare sync --all -g
}
