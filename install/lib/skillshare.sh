#!/bin/bash

ensure_skillshare_extension() {
  local source=$1
  local target=$2
  local source_file

  [[ -d "$source" ]] || die "cannot install missing Skillshare extension: $source"

  # Skillshare's extension picker enumerates only real directories. Keep the
  # directory itself local while linking each implementation file to the repo.
  if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
    archive_path "$target"
  fi
  mkdir -p "$target"

  for source_file in "$source"/*; do
    [[ -e "$source_file" || -L "$source_file" ]] || continue
    ensure_symlink "$source_file" "$target/${source_file##*/}"
  done
}

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
  ensure_skillshare_extension \
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
