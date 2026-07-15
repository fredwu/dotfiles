#!/bin/bash

SPF13_URL=https://github.com/spf13/spf13-vim.git

remove_known_symlink() {
  local path=$1
  shift
  local actual
  local expected

  [[ -L "$path" ]] || return 0
  actual=$(readlink "$path")
  for expected in "$@"; do
    if [[ "$actual" == "$expected" ]]; then
      rm "$path"
      log "Removed legacy symlink $path"
      return 0
    fi
  done

  warn "Preserving unrecognised symlink $path -> $actual"
}

cleanup_spf13_checkout() {
  local path="$HOME/.spf13-vim-3"
  local status

  [[ -e "$path" || -L "$path" ]] || return 0
  if is_expected_git_repository "$path" "$SPF13_URL" && \
      status=$(git -C "$path" status --porcelain --untracked-files=all --ignored=matching 2>/dev/null) && \
      [[ -z "$status" ]]; then
    rm -rf "$path"
    log "Removed the clean spf13-vim checkout"
  else
    archive_path "$path"
  fi
}

cleanup_vim_bundle() {
  local path="$HOME/.vim"

  [[ -e "$path" || -L "$path" ]] || return 0
  # Plugin managers generate files inside otherwise clean checkouts, and users
  # can modify or add plugins under this tree. Preserve it for manual review.
  archive_path "$path"
}

cleanup_empty_vimrc_local() {
  local path="$HOME/.vimrc.local"

  [[ -e "$path" || -L "$path" ]] || return 0
  if [[ -f "$path" && ! -s "$path" ]]; then
    rm "$path"
    log "Removed empty $path"
  else
    archive_path "$path"
  fi
}

cleanup_obsolete_gpg_use_agent() {
  local path="$HOME/.gnupg/gpg.conf"
  local archived
  local temporary

  [[ -f "$path" ]] || return 0
  grep -Eq '^[[:space:]]*use-agent[[:space:]]*$' "$path" || return 0

  archive_path "$path"
  archived=$LAST_ARCHIVED_PATH
  temporary=$(mktemp "${TMPDIR:-/tmp}/gpg.conf.XXXXXX")
  awk '!/^[[:space:]]*use-agent[[:space:]]*$/' "$archived" > "$temporary"
  cp -p "$archived" "$path"
  cat "$temporary" > "$path"
  rm -f "$temporary"
  log "Removed obsolete use-agent from $path (original archived)"
}

cleanup_old_nerd_font() {
  local path="$HOME/.local/share/fonts/Droid Sans Mono for Powerline Nerd Font Complete.otf"

  [[ -f "$path" ]] || return 0
  archive_path "$path"
  have fc-cache && fc-cache -f "$HOME/.local/share/fonts"
  log "Archived the legacy Droid Sans Mono Nerd Font"
}

cleanup_homebrew_vim() {
  local dependants

  [[ "$PLATFORM" == macos ]] || return 0
  have brew || return 0
  brew list --formula vim >/dev/null 2>&1 || return 0

  if ! brew leaves | grep -Fqx vim; then
    warn "Preserving Homebrew vim because it is not a direct leaf formula"
    return 0
  fi

  if ! dependants=$(brew uses --installed vim 2>/dev/null); then
    warn "Preserving Homebrew vim because its dependency query failed"
    return 0
  fi
  if [[ -n "$dependants" ]]; then
    warn "Preserving Homebrew vim; installed formulae depend on it: $dependants"
    return 0
  fi

  brew uninstall vim
}

report_historical_backups() {
  local count
  count=$(find "$HOME" -maxdepth 1 -name '*.backup.*' -print 2>/dev/null | awk 'END { print NR + 0 }')
  if (( count > 0 )); then
    warn "Preserved $count historical *.backup.* file(s) for manual review"
  fi
}

cleanup_legacy_v1() {
  log "Running legacy cleanup v1"
  cleanup_spf13_checkout
  cleanup_vim_bundle
  remove_known_symlink "$HOME/.vimrc" \
    "$HOME/.spf13-vim-3/.vimrc"
  remove_known_symlink "$HOME/.vimrc.bundles" \
    "$HOME/.spf13-vim-3/.vimrc.bundles"
  remove_known_symlink "$HOME/.vimrc.before" \
    "$DOTFILES_ROOT/templates/vimrc.before" "$HOME/.dotfiles/templates/vimrc.before" \
    "templates/vimrc.before"
  remove_known_symlink "$HOME/.vimrc.after" \
    "$DOTFILES_ROOT/templates/vimrc.after" "$HOME/.dotfiles/templates/vimrc.after" \
    "templates/vimrc.after"
  cleanup_empty_vimrc_local
  cleanup_old_nerd_font
  cleanup_obsolete_gpg_use_agent
  cleanup_homebrew_vim
  report_historical_backups
}
