#!/bin/bash

HACK_NERD_FONT_VERSION=3.4.0
HACK_NERD_FONT_SHA256=8ca33a60c791392d872b80d26c42f2bfa914a480f9eb2d7516d9f84373c36897

install_hack_nerd_font() {
  local data_home
  local font_root
  local font_dir
  local archive
  local staging

  [[ "$PLATFORM" == linux ]] || return 0

  data_home=${XDG_DATA_HOME:-$HOME/.local/share}
  font_root="$data_home/fonts"
  font_dir="$font_root/HackNerdFont-$HACK_NERD_FONT_VERSION"
  [[ -f "$font_dir/HackNerdFont-Regular.ttf" ]] && return 0

  log "Installing Hack Nerd Font $HACK_NERD_FONT_VERSION"
  archive=$(mktemp "${TMPDIR:-/tmp}/hack-nerd-font.XXXXXX")
  download_checked \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v$HACK_NERD_FONT_VERSION/Hack.zip" \
    "$HACK_NERD_FONT_SHA256" "$archive"
  mkdir -p "$font_root"
  staging=$(mktemp -d "$font_root/.HackNerdFont-$HACK_NERD_FONT_VERSION.XXXXXX")
  unzip -q "$archive" -d "$staging"
  rm -f "$archive"
  if [[ -e "$font_dir" || -L "$font_dir" ]]; then
    archive_path "$font_dir"
  fi
  mv "$staging" "$font_dir"
  fc-cache -f "$font_root"
}

sync_neovim_plugins() {
  local current_version

  require_command nvim
  current_version=$(nvim_version)
  version_at_least "$current_version" "$NEOVIM_MIN_VERSION" || \
    die "Neovim $NEOVIM_MIN_VERSION or newer is required (found $current_version)"

  log "Restoring LazyVim plugins from the lockfile"
  nvim --headless "+Lazy! restore" +qa
}
