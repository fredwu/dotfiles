#!/bin/bash

ensure_skillshare_extension() {
  local source=$1
  local target=$2
  local source_file

  [[ -d "$source" ]] || die "cannot install missing Skillshare extension: $source"
  if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
    archive_path "$target"
  fi
  mkdir -p "$target"

  for source_file in "$source"/*; do
    [[ -e "$source_file" || -L "$source_file" ]] || continue
    ensure_symlink "$source_file" "$target/${source_file##*/}"
  done
}

ensure_empty_skillshare_agents_source() {
  local target=$1

  if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
    archive_path "$target"
  elif [[ -d "$target" && -n "$(find "$target" -mindepth 1 -print -quit)" ]]; then
    archive_path "$target"
  fi

  mkdir -p "$target"
}

require_supported_skillshare() {
  local installed_version

  installed_version=$(skillshare --version 2>&1 | sed -nE 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | tail -1)
  [[ -n "$installed_version" ]] || die "cannot determine installed Skillshare version"
  version_at_least "$installed_version" 0.20.25 || \
    die "Skillshare 0.20.25 or newer is required (found $installed_version)"
}

generated_agent_is_expected() {
  local sought=$1
  local expected

  shift
  for expected in "$@"; do
    [[ "$sought" == "$expected" ]] && return 0
  done
  return 1
}

generated_agent_path() {
  local entry=$1
  local relative

  case "$entry" in
    claude/*.md)
      relative=${entry#claude/}
      [[ -n "$relative" && "$relative" != */* ]] || return 1
      printf '%s\n' "$HOME/.claude/agents/$relative"
      ;;
    codex/*.toml)
      relative=${entry#codex/}
      [[ -n "$relative" && "$relative" != */* ]] || return 1
      printf '%s\n' "$HOME/.codex/agents/$relative"
      ;;
    *) return 1 ;;
  esac
}

reconcile_generated_agents_manifest() {
  local manifest=$1
  local entry
  local generated_path
  local temporary
  local -a expected

  shift
  expected=("$@")

  if [[ -f "$manifest" ]]; then
    while IFS= read -r entry || [[ -n "$entry" ]]; do
      [[ -n "$entry" ]] || continue
      generated_path=$(generated_agent_path "$entry") || \
        die "invalid entry in generated agent manifest: $entry"
      if ! generated_agent_is_expected "$entry" "${expected[@]}" && \
        [[ -e "$generated_path" || -L "$generated_path" ]]; then
        archive_path "$generated_path"
      fi
    done < "$manifest"
  fi

  mkdir -p "$(dirname -- "$manifest")"
  temporary=$(mktemp "$manifest.tmp.XXXXXX")
  if ((${#expected[@]})); then
    printf '%s\n' "${expected[@]}" > "$temporary"
  fi
  mv "$temporary" "$manifest"
}

configure_skillshare() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local skillshare_home="$config_home/skillshare"
  local skills_source="$skillshare_home/skills"
  local agents_source="$skillshare_home/agents"
  local extensions_source="$DOTFILES_ROOT/ai/skillshare/extensions"
  local extensions_target="$skillshare_home/extensions"
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  local agents_manifest="$state_home/dotfiles/skillshare-agents.manifest"
  local agents_config_state
  local config_preflight
  local agent_file
  local agent_name
  local claude_agent_file
  local codex_agent_file
  local -a generated_agents

  require_command skillshare
  require_command node
  require_supported_skillshare

  log "Validating Skillshare agent mappings"
  if ! env -u NODE_OPTIONS node \
    "$extensions_source/dotfiles-agent-transform/validate.js" \
    "$DOTFILES_ROOT/ai/skillshare/agents"; then
    die "Skillshare agent mapping validation failed"
  fi

  generated_agents=()
  for agent_file in "$DOTFILES_ROOT/ai/skillshare/agents/"*.md; do
    [[ -e "$agent_file" ]] || continue
    agent_name=${agent_file##*/}
    generated_agents+=("claude/$agent_name" "codex/${agent_name%.md}.toml")
  done

  if [[ -f "$skillshare_home/config.yaml" ]]; then
    config_preflight=$(mktemp "${TMPDIR:-/tmp}/dotfiles-skillshare-config.XXXXXX")
    cp "$skillshare_home/config.yaml" "$config_preflight"
    if ! env -u NODE_OPTIONS node \
      "$DOTFILES_ROOT/install/lib/configure-skillshare-extra.js" \
      "$config_preflight" \
      "$DOTFILES_ROOT/ai/skillshare/agents" \
      "$HOME/.claude/agents" \
      "$HOME/.codex/agents" \
      "$agents_source" >/dev/null; then
      rm -f "$config_preflight"
      die "Skillshare agent configuration preflight failed"
    fi
    rm -f "$config_preflight"
  fi

  ensure_symlink "$DOTFILES_ROOT/ai/skillshare/skills" "$skills_source"
  ensure_empty_skillshare_agents_source "$agents_source"
  ensure_skillshare_extension \
    "$extensions_source/dotfiles-claude-agents" \
    "$extensions_target/dotfiles-claude-agents"
  ensure_skillshare_extension \
    "$extensions_source/dotfiles-codex-agents" \
    "$extensions_target/dotfiles-codex-agents"

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

  if ! agents_config_state=$(env -u NODE_OPTIONS node \
    "$DOTFILES_ROOT/install/lib/configure-skillshare-extra.js" \
    "$skillshare_home/config.yaml" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$HOME/.claude/agents" \
    "$HOME/.codex/agents" \
    "$agents_source"); then
    die "Skillshare agent configuration failed"
  fi

  if [[ "$agents_config_state" == changed ]]; then
    for agent_file in "$DOTFILES_ROOT/ai/skillshare/agents/"*.md; do
      [[ -e "$agent_file" ]] || continue
      agent_name=${agent_file##*/}
      claude_agent_file="$HOME/.claude/agents/$agent_name"
      codex_agent_file="$HOME/.codex/agents/${agent_name%.md}.toml"
      if [[ -e "$claude_agent_file" || -L "$claude_agent_file" ]]; then
        archive_path "$claude_agent_file"
      fi
      if [[ -e "$codex_agent_file" || -L "$codex_agent_file" ]]; then
        archive_path "$codex_agent_file"
      fi
    done
  fi

  log "Syncing Skillshare targets"
  skillshare sync -g || die "Skillshare skill sync failed"
  skillshare sync extras --force -g || die "Skillshare agent generation failed"
  reconcile_generated_agents_manifest "$agents_manifest" "${generated_agents[@]}"
}
