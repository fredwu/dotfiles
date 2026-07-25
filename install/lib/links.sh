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

  mkdir -p "$target/skills"
}

install_ai_links() {
  local name
  local instructions
  local skill

  for name in claude codex grok; do
    ensure_ai_directory "$name"
    if [[ "$name" == claude ]]; then
      instructions=CLAUDE.md
    else
      instructions=AGENTS.md
    fi
    ensure_symlink "$DOTFILES_ROOT/ai/shared/AGENTS.md" "$HOME/.$name/$instructions"
    for skill in "$DOTFILES_ROOT"/ai/shared/skills/*; do
      ensure_symlink "$skill" "$HOME/.$name/skills/$(basename -- "$skill")"
    done
  done
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
