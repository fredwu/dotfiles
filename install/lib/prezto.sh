#!/bin/bash

PREZTO_URL=https://github.com/sorin-ionescu/prezto.git
PREZTO_CONTRIB_URL=https://github.com/belak/prezto-contrib.git

install_git_checkout() {
  local label=$1
  local url=$2
  local destination=$3

  if [[ -e "$destination" || -L "$destination" ]]; then
    if is_expected_git_repository "$destination" "$url"; then
      git -C "$destination" submodule update --init --recursive
      return 0
    fi

    warn "$destination is not the expected $label checkout"
    archive_path "$destination"
  fi

  log "Cloning $label"
  git clone --recursive "$url" "$destination"
}

install_prezto() {
  require_command git
  install_git_checkout Prezto "$PREZTO_URL" "$HOME/.zprezto"
  install_git_checkout prezto-contrib "$PREZTO_CONTRIB_URL" "$HOME/.zprezto/contrib"
}
