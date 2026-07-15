#!/bin/bash

set -euo pipefail

DOTFILES_ROOT="$(
  CDPATH=''
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
  pwd -P
)"
export DOTFILES_ROOT

for module in common platform packages cleanup prezto links neovim login_shell; do
  # shellcheck source=/dev/null
  source "$DOTFILES_ROOT/install/lib/$module.sh"
done

usage() {
  cat <<'EOF'
Usage: ./install.sh [--cleanup] [--help]

Install packages and reconcile this dotfiles setup. Re-running the installer is
safe. Use --cleanup once to archive or remove recognised legacy Vim/spf13 files
before performing the normal installation.
EOF
}

main() {
  local cleanup=false

  while (( $# > 0 )); do
    case "$1" in
      --cleanup) cleanup=true ;;
      --help|-h)
        usage
        return 0
        ;;
      *)
        usage >&2
        die "unknown option: $1"
        ;;
    esac
    shift
  done

  if (( EUID == 0 )); then
    die "run this installer as your regular user, without sudo"
  fi

  detect_platform
  log "Installing dotfiles on $PLATFORM${PACKAGE_MANAGER:+ ($PACKAGE_MANAGER)}"

  if [[ "$cleanup" == true ]]; then
    cleanup_legacy_v1
  fi

  install_packages
  install_hack_nerd_font
  install_prezto
  install_dotfiles
  sync_neovim_plugins
  ensure_zsh_login_shell

  log "Installation complete. Open a new terminal to use the updated environment."
}

main "$@"
