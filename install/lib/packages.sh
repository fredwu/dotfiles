#!/bin/bash

# Homebrew installs the same command-line tools on macOS and Linux. `brew install`
# also upgrades outdated formulae, so each run brings them to their latest release.
HOMEBREW_FORMULAE=(
  direnv fd fzf git gnupg lazygit libyaml mise neovim openssl@3
  node ripgrep skillshare tree-sitter-cli zoxide
)
HOMEBREW_CASKS=(claude-code codex font-hack-nerd-font grok-build)
RETIRED_LINUX_RELEASE_INSTALLS=(mise neovim skillshare tree-sitter)

homebrew_binary() {
  local candidate

  if have brew; then
    command -v brew
    return 0
  fi
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_homebrew() {
  local brew_binary

  if ! brew_binary=$(homebrew_binary); then
    log "Installing Homebrew"
    require_command curl
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew_binary=$(homebrew_binary) || die "Homebrew installed but brew was not found"
  fi

  eval "$("$brew_binary" shellenv)"
}

install_homebrew_packages() {
  ensure_homebrew
  log "Reconciling Homebrew formulae"
  brew install "${HOMEBREW_FORMULAE[@]}"
  require_command node
  require_command npm

  if [[ "$PLATFORM" == macos ]]; then
    log "Reconciling Homebrew casks"
    brew install --cask "${HOMEBREW_CASKS[@]}"
  fi
}

apt_package_exists() {
  apt-cache show "$1" >/dev/null 2>&1
}

# The distribution provides the base system and Homebrew's prerequisites.
install_apt_packages() {
  local package
  local -a packages=(
    build-essential ca-certificates curl file fontconfig git gzip libffi-dev libssl-dev
    libyaml-dev procps tar unzip xz-utils zlib1g-dev zsh
  )

  as_root apt-get update
  for package in "${packages[@]}"; do
    apt_package_exists "$package" || die "required apt package unavailable: $package"
  done
  as_root apt-get install -y "${packages[@]}"
}

install_dnf_packages() {
  as_root dnf install -y \
    ca-certificates curl file fontconfig gcc gcc-c++ git gzip libffi-devel libyaml-devel \
    make openssl-devel procps-ng tar unzip xz zlib-devel zsh
}

install_pacman_packages() {
  as_root pacman -S --needed --noconfirm \
    base-devel ca-certificates curl file fontconfig git gzip libffi libyaml openssl \
    procps-ng tar unzip xz zlib zsh
}

# Earlier installers placed pinned release builds under ~/.local/opt and linked them
# from ~/.local/bin, ahead of Homebrew on PATH. Archive them so Homebrew's builds run.
retire_linux_release_installs() {
  local name
  local link

  for link in "$HOME"/.local/bin/*; do
    [[ -L "$link" ]] || continue
    for name in "${RETIRED_LINUX_RELEASE_INSTALLS[@]}"; do
      if [[ "$(readlink "$link")" == "$HOME/.local/opt/$name/"* ]]; then
        rm -f "$link"
        log "Removed retired release link $link"
      fi
    done
  done

  for name in "${RETIRED_LINUX_RELEASE_INSTALLS[@]}"; do
    archive_path "$HOME/.local/opt/$name"
  done
}

install_linux_packages() {
  case "$PACKAGE_MANAGER" in
    apt) install_apt_packages ;;
    dnf) install_dnf_packages ;;
    pacman) install_pacman_packages ;;
  esac

  retire_linux_release_installs
  install_homebrew_packages
}

install_packages() {
  case "$PLATFORM" in
    macos) install_homebrew_packages ;;
    linux) install_linux_packages ;;
  esac
}
