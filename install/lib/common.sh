#!/bin/bash

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

die() {
  printf '[dotfiles] error: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  have "$1" || die "required command not found: $1"
}

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    require_command sudo
    sudo "$@"
  fi
}

version_at_least() {
  local actual=$1
  local required=$2

  awk -v actual="$actual" -v required="$required" 'BEGIN {
    a_count = split(actual, a, ".")
    r_count = split(required, r, ".")
    count = a_count > r_count ? a_count : r_count
    for (i = 1; i <= count; i++) {
      a[i] += 0
      r[i] += 0
      if (a[i] > r[i]) exit 0
      if (a[i] < r[i]) exit 1
    }
    exit 0
  }'
}

sha256_file() {
  if have sha256sum; then
    sha256sum "$1" | awk '{ print $1 }'
  elif have shasum; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    die "sha256sum or shasum is required to verify downloads"
  fi
}

download_checked() {
  local url=$1
  local expected_sha256=$2
  local destination=$3
  local temporary
  local actual_sha256

  require_command curl
  temporary=$(mktemp "${TMPDIR:-/tmp}/dotfiles-download.XXXXXX")
  if ! curl -fL --retry 3 --connect-timeout 15 "$url" -o "$temporary"; then
    rm -f "$temporary"
    die "download failed: $url"
  fi

  actual_sha256=$(sha256_file "$temporary")
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -f "$temporary"
    die "checksum mismatch for $url (expected $expected_sha256, got $actual_sha256)"
  fi

  mkdir -p "$(dirname -- "$destination")"
  mv "$temporary" "$destination"
}

backup_session_dir() {
  if [[ -z "${BACKUP_SESSION_DIR:-}" ]]; then
    BACKUP_SESSION_DIR="${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backups}/$(date '+%Y%m%d-%H%M%S')"
    while [[ -e "$BACKUP_SESSION_DIR" ]]; do
      BACKUP_SESSION_DIR="${BACKUP_SESSION_DIR}.1"
    done
    mkdir -p "$BACKUP_SESSION_DIR"
  fi

  printf '%s\n' "$BACKUP_SESSION_DIR"
}

archive_path() {
  local source=$1
  local backup_root
  local relative
  local destination

  [[ -e "$source" || -L "$source" ]] || return 0

  backup_session_dir >/dev/null
  backup_root=$BACKUP_SESSION_DIR
  case "$source" in
    "$HOME"/*) relative=${source#"$HOME"/} ;;
    *) relative=$(basename -- "$source") ;;
  esac
  destination="$backup_root/$relative"
  mkdir -p "$(dirname -- "$destination")"
  while [[ -e "$destination" || -L "$destination" ]]; do
    destination="${destination}.1"
  done

  mv "$source" "$destination"
  # Used by cleanup functions after the original path has been moved.
  # shellcheck disable=SC2034
  LAST_ARCHIVED_PATH=$destination
  log "Archived $source to $destination"
}

ensure_symlink() {
  local source=$1
  local target=$2

  [[ -e "$source" || -L "$source" ]] || die "cannot link missing source: $source"

  if [[ -L "$target" && -e "$target" && "$target" -ef "$source" ]]; then
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    archive_path "$target"
  fi

  mkdir -p "$(dirname -- "$target")"
  ln -s "$source" "$target"
  log "Linked $target -> $source"
}

ensure_private_directory() {
  local path=$1

  if [[ -L "$path" && ! -e "$path" ]] || [[ -e "$path" && ! -d "$path" ]]; then
    archive_path "$path"
  fi

  mkdir -p "$path"
  chmod 700 "$path"
}

is_expected_git_repository() {
  local directory=$1
  local expected_url=$2
  local actual_url

  [[ -d "$directory/.git" ]] || return 1
  actual_url=$(git -C "$directory" remote get-url origin 2>/dev/null || true)
  case "$actual_url" in
    "$expected_url"|"${expected_url%.git}") return 0 ;;
    *) return 1 ;;
  esac
}
