#!/bin/bash

detect_platform() {
  local kernel
  kernel=$(uname -s)

  case "$kernel" in
    Darwin)
      PLATFORM=macos
      PACKAGE_MANAGER=brew
      ;;
    Linux)
      PLATFORM=linux
      if have apt-get; then
        PACKAGE_MANAGER=apt
      elif have dnf; then
        PACKAGE_MANAGER=dnf
      elif have pacman; then
        PACKAGE_MANAGER=pacman
      else
        die "unsupported Linux package manager (supported: apt, dnf, pacman)"
      fi
      ;;
    *) die "unsupported operating system: $kernel" ;;
  esac

  export PLATFORM PACKAGE_MANAGER
}

linux_architecture() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x86_64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) die "unsupported Linux architecture: $(uname -m)" ;;
  esac
}
