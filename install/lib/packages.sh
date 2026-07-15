#!/bin/bash

NEOVIM_MIN_VERSION=0.12.0
NEOVIM_FALLBACK_VERSION=0.12.4
MISE_VERSION=2026.7.6
TREE_SITTER_VERSION=0.26.11

ensure_homebrew() {
  local brew_binary

  brew_binary=
  if have brew; then
    brew_binary=$(command -v brew)
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_binary=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_binary=/usr/local/bin/brew
  else
    log "Installing Homebrew"
    require_command curl
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for brew_binary in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [[ -x "$brew_binary" ]] && break
    done
    [[ -x "$brew_binary" ]] || die "Homebrew installed but brew was not found"
  fi

  eval "$("$brew_binary" shellenv)"
}

install_macos_packages() {
  local -a formulae
  local -a casks

  ensure_homebrew
  formulae=(
    direnv fd fzf git gnupg lazygit libyaml mise neovim openssl@3
    ripgrep tree-sitter-cli zoxide
  )
  casks=(claude-code codex font-hack-nerd-font grok-build)

  log "Reconciling Homebrew formulae"
  brew install "${formulae[@]}"
  log "Reconciling Homebrew casks"
  brew install --cask "${casks[@]}"
}

apt_package_exists() {
  apt-cache show "$1" >/dev/null 2>&1
}

install_apt_packages() {
  local package
  local -a candidates
  local -a packages

  packages=()
  candidates=(
    build-essential ca-certificates curl direnv fd-find fontconfig fzf git gnupg
    gzip libffi-dev libssl-dev libyaml-dev neovim ripgrep tar unzip xz-utils
    zlib1g-dev zoxide zsh
  )

  as_root apt-get update
  for package in "${candidates[@]}"; do
    if apt_package_exists "$package"; then
      packages+=("$package")
    elif [[ "$package" == neovim ]]; then
      warn "apt package unavailable; skipping $package"
    else
      die "required apt package unavailable: $package"
    fi
  done
  as_root apt-get install -y "${packages[@]}"

  if ! have fd && have fdfind; then
    ensure_symlink "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
}

install_dnf_packages() {
  as_root dnf install -y \
    ca-certificates curl direnv fd-find fontconfig fzf gcc gcc-c++ git gnupg2 \
    gzip libffi-devel libyaml-devel make neovim openssl-devel ripgrep tar unzip \
    xz zlib-devel zoxide zsh
}

install_pacman_packages() {
  as_root pacman -S --needed --noconfirm \
    base-devel ca-certificates curl direnv fd fontconfig fzf git gnupg gzip \
    libffi libyaml neovim openssl ripgrep tar unzip xz zlib zoxide zsh
}

ensure_mise_on_linux() {
  local arch
  local asset
  local checksum

  if have mise || [[ -x "$HOME/.local/bin/mise" ]]; then
    return 0
  fi

  arch=$(linux_architecture)
  case "$arch" in
    x86_64)
      asset="mise-v$MISE_VERSION-linux-x64.tar.gz"
      checksum=fbd2f36a5d726822e997b83b9ca29f66411de2acb2935dcabacd4df51a0dade3
      ;;
    arm64)
      asset="mise-v$MISE_VERSION-linux-arm64.tar.gz"
      checksum=1e5d2181bad9b897437e8227200fe661339bad7d66a3cd1828b22c48156ac73a
      ;;
  esac

  install_linux_tarball mise "$MISE_VERSION" "$asset" "$checksum" \
    "https://github.com/jdx/mise/releases/download/v$MISE_VERSION/$asset" bin/mise
}

install_linux_tarball() {
  local name=$1
  local version=$2
  local asset=$3
  local checksum=$4
  local url=$5
  local executable=$6
  local archive
  local install_dir="$HOME/.local/opt/$name/$version"
  local install_parent="$HOME/.local/opt/$name"
  local staging

  if [[ ! -x "$install_dir/$executable" ]]; then
    archive=$(mktemp "${TMPDIR:-/tmp}/$name.XXXXXX")
    download_checked "$url" "$checksum" "$archive"
    mkdir -p "$install_parent"
    staging=$(mktemp -d "$install_parent/.${version}.XXXXXX")
    tar -xzf "$archive" --strip-components=1 -C "$staging"
    rm -f "$archive"
    [[ -x "$staging/$executable" ]] || die "$asset did not contain $executable"
    if [[ -e "$install_dir" || -L "$install_dir" ]]; then
      archive_path "$install_dir"
    fi
    mv "$staging" "$install_dir"
    log "Installed $name $version ($asset)"
  fi

  ensure_symlink "$install_dir/$executable" "$HOME/.local/bin/$name"
}

install_linux_binary() {
  local name=$1
  local version=$2
  local asset=$3
  local checksum=$4
  local url=$5
  local compressed
  local install_dir="$HOME/.local/opt/$name/$version"
  local install_parent="$HOME/.local/opt/$name"
  local staging

  if [[ ! -x "$install_dir/$name" ]]; then
    compressed=$(mktemp "${TMPDIR:-/tmp}/$name.XXXXXX")
    download_checked "$url" "$checksum" "$compressed"
    mkdir -p "$install_parent"
    staging=$(mktemp -d "$install_parent/.${version}.XXXXXX")
    gzip -dc "$compressed" > "$staging/$name"
    chmod 755 "$staging/$name"
    rm -f "$compressed"
    if [[ -e "$install_dir" || -L "$install_dir" ]]; then
      archive_path "$install_dir"
    fi
    mv "$staging" "$install_dir"
    log "Installed $name $version ($asset)"
  fi

  ensure_symlink "$install_dir/$name" "$HOME/.local/bin/$name"
}

ensure_tree_sitter_on_linux() {
  local arch
  local asset
  local checksum

  arch=$(linux_architecture)
  case "$arch" in
    x86_64)
      asset=tree-sitter-linux-x64.gz
      checksum=8dac3c89bb632eece700ea7a261ad963b251f2228c4aef3b58458ebea8dbe4eb
      ;;
    arm64)
      asset=tree-sitter-linux-arm64.gz
      checksum=e47dd59bf2f21ad7c15771546a724464ee3c008a60fbb61c6860bd19a44b3060
      ;;
  esac

  install_linux_binary tree-sitter "$TREE_SITTER_VERSION" "$asset" "$checksum" \
    "https://github.com/tree-sitter/tree-sitter/releases/download/v$TREE_SITTER_VERSION/$asset"
}

nvim_version() {
  nvim --version 2>/dev/null | awk 'NR == 1 { sub(/^v/, "", $2); print $2 }'
}

ensure_neovim_on_linux() {
  local current_version
  local arch
  local asset
  local checksum
  local archive
  local install_parent="$HOME/.local/opt/neovim"
  local install_dir="$install_parent/$NEOVIM_FALLBACK_VERSION"
  local staging

  current_version=$(nvim_version || true)
  if [[ -n "$current_version" ]] && version_at_least "$current_version" "$NEOVIM_MIN_VERSION"; then
    return 0
  fi

  arch=$(linux_architecture)
  case "$arch" in
    x86_64)
      asset=nvim-linux-x86_64.tar.gz
      checksum=012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628
      ;;
    arm64)
      asset=nvim-linux-arm64.tar.gz
      checksum=ceb7e88c6b681f0515d135dcdfad54f5eb4373b25ce6172197cd9a69c758063f
      ;;
  esac

  if [[ ! -x "$install_dir/bin/nvim" ]]; then
    log "Installing Neovim $NEOVIM_FALLBACK_VERSION because the distro version is older than $NEOVIM_MIN_VERSION"
    archive=$(mktemp "${TMPDIR:-/tmp}/neovim.XXXXXX")
    download_checked \
      "https://github.com/neovim/neovim/releases/download/v$NEOVIM_FALLBACK_VERSION/$asset" \
      "$checksum" "$archive"
    mkdir -p "$install_parent"
    staging=$(mktemp -d "$install_parent/.${NEOVIM_FALLBACK_VERSION}.XXXXXX")
    tar -xzf "$archive" --strip-components=1 -C "$staging"
    if [[ -e "$install_dir" || -L "$install_dir" ]]; then
      archive_path "$install_dir"
    fi
    mv "$staging" "$install_dir"
    rm -f "$archive"
  fi

  ensure_symlink "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"
}

install_linux_packages() {
  case "$PACKAGE_MANAGER" in
    apt) install_apt_packages ;;
    dnf) install_dnf_packages ;;
    pacman) install_pacman_packages ;;
  esac

  export PATH="$HOME/.local/bin:$PATH"
  ensure_mise_on_linux
  ensure_neovim_on_linux
  ensure_tree_sitter_on_linux
}

install_packages() {
  case "$PLATFORM" in
    macos) install_macos_packages ;;
    linux) install_linux_packages ;;
  esac
}
