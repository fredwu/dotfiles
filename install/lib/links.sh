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

install_dotfiles() {
  local template
  local name
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
  for name in claude codex grok; do
    ensure_symlink "$DOTFILES_ROOT/ai/$name" "$HOME/.$name"
  done

  copy_if_missing "$DOTFILES_ROOT/zsh/custom.example" "$HOME/.zsh_custom"
  if [[ ! -e "$HOME/.zsh_pre_custom" && ! -L "$HOME/.zsh_pre_custom" ]]; then
    touch "$HOME/.zsh_pre_custom"
    log "Created $HOME/.zsh_pre_custom"
  fi
}
