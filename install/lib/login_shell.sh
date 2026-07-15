#!/bin/bash

configured_login_shell() {
  local install_user=${USER:-$(id -un)}

  if [[ "$PLATFORM" == macos ]] && have dscl; then
    dscl . -read "/Users/$install_user" UserShell 2>/dev/null | awk '{ print $2 }'
  elif have getent; then
    getent passwd "$install_user" | awk -F: '{ print $7 }'
  else
    printf '%s\n' "${SHELL:-}"
  fi
}

ensure_zsh_is_allowed() {
  local zsh_path=$1

  if grep -Fqx "$zsh_path" /etc/shells; then
    return 0
  fi

  log "Adding $zsh_path to /etc/shells"
  if (( EUID == 0 )); then
    printf '%s\n' "$zsh_path" >> /etc/shells
  else
    require_command sudo
    printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
}

ensure_zsh_login_shell() {
  local zsh_path
  local current_shell
  local install_user=${USER:-$(id -un)}

  require_command zsh
  zsh_path=$(command -v zsh)
  current_shell=$(configured_login_shell)
  if [[ "$current_shell" == "$zsh_path" ]]; then
    return 0
  fi

  ensure_zsh_is_allowed "$zsh_path"
  log "Changing the login shell from ${current_shell:-unknown} to $zsh_path"
  chsh -s "$zsh_path" "$install_user"
}
