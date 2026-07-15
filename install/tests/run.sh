#!/bin/bash
# The test doubles below are invoked indirectly by the sourced installer code.
# shellcheck disable=SC1091,SC2016,SC2030,SC2031,SC2034,SC2329

set -euo pipefail

TEST_ROOT="$(
  CDPATH=''
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
  pwd -P
)"
TESTS_RUN=0

# shellcheck source=../lib/common.sh
source "$TEST_ROOT/install/lib/common.sh"
# shellcheck source=../lib/platform.sh
source "$TEST_ROOT/install/lib/platform.sh"
# shellcheck source=../lib/packages.sh
source "$TEST_ROOT/install/lib/packages.sh"
# shellcheck source=../lib/cleanup.sh
source "$TEST_ROOT/install/lib/cleanup.sh"
# shellcheck source=../lib/links.sh
source "$TEST_ROOT/install/lib/links.sh"
# shellcheck source=../lib/prezto.sh
source "$TEST_ROOT/install/lib/prezto.sh"
# shellcheck source=../lib/login_shell.sh
source "$TEST_ROOT/install/lib/login_shell.sh"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_true() {
  local message=$1
  shift
  "$@" || fail "$message"
}

assert_false() {
  local message=$1
  shift
  if "$@"; then
    fail "$message"
  fi
}

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3
  [[ "$expected" == "$actual" ]] || fail "$message (expected '$expected', got '$actual')"
}

new_home() {
  HOME=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles test.XXXXXX")
  export HOME
  DOTFILES_BACKUP_ROOT="$HOME/backups"
  BACKUP_SESSION_DIR=
  LAST_ARCHIVED_PATH=
}

finish_test() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf 'ok %d - %s\n' "$TESTS_RUN" "$1"
  rm -rf "$HOME"
}

test_versions() {
  assert_true "equal versions should pass" version_at_least 0.12.0 "$NEOVIM_MIN_VERSION"
  assert_true "newer versions should pass" version_at_least 0.12.4 "$NEOVIM_MIN_VERSION"
  assert_false "older versions should fail" version_at_least 0.11.6 "$NEOVIM_MIN_VERSION"
  finish_test "semantic version comparison"
}

test_platform_detection() {
  (
    uname() { printf 'Linux\n'; }
    have() { [[ "$1" == apt-get ]]; }
    detect_platform
    assert_eq linux "$PLATFORM" "Linux should be detected"
    assert_eq apt "$PACKAGE_MANAGER" "apt should be selected"
  )

  (
    uname() { printf 'Darwin\n'; }
    detect_platform
    assert_eq macos "$PLATFORM" "macOS should be detected"
    assert_eq brew "$PACKAGE_MANAGER" "Homebrew should be selected"
  )
  finish_test "platform and package-manager detection"
}

test_package_dispatch_without_package_manager() {
  local marker="$HOME/dispatched"

  (
    install_apt_packages() { printf 'apt\n' > "$marker"; }
    ensure_mise_on_linux() { :; }
    ensure_neovim_on_linux() { :; }
    ensure_tree_sitter_on_linux() { :; }
    PLATFORM=linux
    PACKAGE_MANAGER=apt
    install_packages
  )
  assert_eq apt "$(cat "$marker")" "Linux package dispatch should call apt implementation"
  finish_test "package dispatch uses stubs and no network or root"
}

test_mise_release_selection() {
  local marker="$HOME/mise-release"

  (
    have() { return 1; }
    linux_architecture() { printf 'arm64\n'; }
    install_linux_tarball() { printf '%s\n' "$*" > "$marker"; }
    ensure_mise_on_linux
  )

  assert_eq \
    "mise $MISE_VERSION mise-v$MISE_VERSION-linux-arm64.tar.gz 1e5d2181bad9b897437e8227200fe661339bad7d66a3cd1828b22c48156ac73a https://github.com/jdx/mise/releases/download/v$MISE_VERSION/mise-v$MISE_VERSION-linux-arm64.tar.gz bin/mise" \
    "$(cat "$marker")" "mise should select the pinned ARM64 release"
  finish_test "mise release selection is pinned and architecture-aware"
}

test_linux_tarball_install() {
  local fixture="$HOME/fixture"
  local fixture_archive="$HOME/fixture.tar.gz"

  mkdir -p "$fixture/mise/bin"
  printf '#!/bin/sh\nprintf "fixture\\n"\n' > "$fixture/mise/bin/mise"
  chmod +x "$fixture/mise/bin/mise"
  tar -czf "$fixture_archive" -C "$fixture" mise

  (
    download_checked() { cp "$fixture_archive" "$3"; }
    install_linux_tarball mise 1.2.3 fixture.tar.gz unused https://example.invalid/fixture bin/mise
    install_linux_tarball mise 1.2.3 fixture.tar.gz unused https://example.invalid/fixture bin/mise
  )

  assert_eq fixture "$("$HOME/.local/bin/mise")" "installed tarball executable should run"
  assert_eq "$HOME/.local/opt/mise/1.2.3/bin/mise" "$(readlink "$HOME/.local/bin/mise")" \
    "tarball executable should be linked from the local bin directory"
  assert_false "repeat tarball install should create no backup" test -e "$DOTFILES_BACKUP_ROOT"
  finish_test "pinned Linux tarballs install idempotently"
}

test_apt_missing_required_package_fails() {
  assert_false "apt install should fail when a required package is unavailable" \
    run_apt_with_missing_required_package
  finish_test "apt refuses an incomplete required package set"
}

run_apt_with_missing_required_package() (
  as_root() { "$@"; }
  apt-get() { :; }
  apt_package_exists() { [[ "$1" != zoxide ]]; }
  install_apt_packages
)

test_idempotent_links() {
  local source="$HOME/source"
  local target="$HOME/.example"
  local backup_count

  printf 'source\n' > "$source"
  printf 'original\n' > "$target"
  ensure_symlink "$source" "$target"
  assert_true "target should be a symlink" test -L "$target"
  assert_eq "source" "$(cat "$target")" "symlink should resolve to source"
  backup_count=$(find "$DOTFILES_BACKUP_ROOT" -type f | awk 'END { print NR + 0 }')
  assert_eq 1 "$backup_count" "existing target should be archived once"

  ensure_symlink "$source" "$target"
  assert_eq "$backup_count" "$(find "$DOTFILES_BACKUP_ROOT" -type f | awk 'END { print NR + 0 }')" \
    "second run should not create another backup"
  finish_test "link reconciliation is idempotent"
}

test_dangling_link() {
  local source="$HOME/source"
  local target="$HOME/.example"

  printf 'source\n' > "$source"
  ln -s "$HOME/missing" "$target"
  ensure_symlink "$source" "$target"
  assert_eq "$source" "$(readlink "$target")" "dangling link should be replaced"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -type l | awk 'END { print NR + 0 }')" \
    "dangling link should be archived"
  finish_test "dangling links are archived"
}

test_dotfile_install() {
  local DOTFILES_ROOT=$TEST_ROOT
  local XDG_CONFIG_HOME="$HOME/xdg config"
  export DOTFILES_ROOT XDG_CONFIG_HOME

  install_dotfiles
  install_dotfiles
  assert_true "zshrc should be linked" test -L "$HOME/.zshrc"
  assert_true "SSH config should be linked" test -L "$HOME/.ssh/config"
  assert_true "GPG agent config should be linked" test -L "$HOME/.gnupg/gpg-agent.conf"
  assert_true "Neovim config should be linked" test -L "$XDG_CONFIG_HOME/nvim"
  assert_true "Claude config should be linked" test -L "$HOME/.claude"
  assert_true "Codex config should be linked" test -L "$HOME/.codex"
  assert_true "Grok config should be linked" test -L "$HOME/.grok"
  assert_eq 700 "$(stat -f '%Lp' "$HOME/.ssh" 2>/dev/null || stat -c '%a' "$HOME/.ssh")" \
    "SSH directory should have mode 700"
  assert_eq 0 "$(find "$DOTFILES_BACKUP_ROOT" -type f 2>/dev/null | awk 'END { print NR + 0 }')" \
    "repeat install should create no backups"
  finish_test "dotfiles install twice without touching real HOME"
}

test_repository_path_with_spaces() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository with spaces"
  local XDG_CONFIG_HOME="$HOME/config with spaces"
  local name
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/templates/ssh" "$DOTFILES_ROOT/templates/gnupg" \
    "$DOTFILES_ROOT/config/nvim" "$DOTFILES_ROOT/zsh" \
    "$DOTFILES_ROOT/ai/claude" "$DOTFILES_ROOT/ai/codex" "$DOTFILES_ROOT/ai/grok"
  for name in ackrc gemrc gitconfig gitignore_global railsrc zlogin zpreztorc zprofile zshenv zshrc; do
    cp "$source_root/templates/$name" "$DOTFILES_ROOT/templates/$name"
  done
  cp "$source_root/templates/ssh/config" "$DOTFILES_ROOT/templates/ssh/config"
  cp "$source_root/templates/gnupg/gpg-agent.conf" "$DOTFILES_ROOT/templates/gnupg/gpg-agent.conf"
  cp "$source_root/zsh/custom.example" "$DOTFILES_ROOT/zsh/custom.example"

  install_dotfiles
  assert_eq "$DOTFILES_ROOT/templates/zshrc" "$(readlink "$HOME/.zshrc")" \
    "repository paths containing spaces should be preserved"
  assert_eq "$DOTFILES_ROOT/config/nvim" "$(readlink "$XDG_CONFIG_HOME/nvim")" \
    "XDG paths containing spaces should be preserved"
  assert_eq "$DOTFILES_ROOT/ai/codex" "$(readlink "$HOME/.codex")" \
    "AI config links should preserve repository paths containing spaces"
  finish_test "repository and HOME paths containing spaces"
}

test_ai_config_directories_are_archived() {
  local DOTFILES_ROOT=$TEST_ROOT
  local backup_count
  local name
  export DOTFILES_ROOT

  for name in claude codex grok; do
    mkdir -p "$HOME/.$name"
    printf '%s config\n' "$name" > "$HOME/.$name/preserved"
  done

  install_dotfiles
  for name in claude codex grok; do
    assert_eq "$DOTFILES_ROOT/ai/$name" "$(readlink "$HOME/.$name")" \
      "$name config should link to the repository"
    assert_true "$name config directory should be archived" \
      test -f "$DOTFILES_BACKUP_ROOT"/*/.$name/preserved
  done

  backup_count=$(find "$DOTFILES_BACKUP_ROOT" -name preserved -type f | awk 'END { print NR + 0 }')
  install_dotfiles
  assert_eq "$backup_count" "$(find "$DOTFILES_BACKUP_ROOT" -name preserved -type f | awk 'END { print NR + 0 }')" \
    "repeat install should not archive AI config links again"
  finish_test "AI config directories are archived before linking"
}

test_private_directories_replace_files_safely() {
  printf 'not a directory\n' > "$HOME/.ssh"
  ensure_private_directory "$HOME/.ssh"
  assert_true "SSH path should become a directory" test -d "$HOME/.ssh"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.ssh' -type f | awk 'END { print NR + 0 }')" \
    "non-directory SSH path should be archived"
  finish_test "private-directory reconciliation archives conflicts"
}

make_git_repository() {
  local directory=$1
  local remote=$2

  mkdir -p "$directory"
  git -C "$directory" init -q
  git -C "$directory" remote add origin "$remote"
  printf 'fixture\n' > "$directory/tracked"
  git -C "$directory" add tracked
  git -C "$directory" -c user.name=Test -c user.email=test@example.com commit -qm fixture
}

test_existing_git_checkout_is_idempotent() {
  local checkout="$HOME/checkout"
  local remote=https://example.com/fixture.git

  make_git_repository "$checkout" "$remote"
  install_git_checkout Fixture "$remote" "$checkout"
  install_git_checkout Fixture "$remote" "$checkout"
  assert_true "expected checkout should remain" test -d "$checkout/.git"
  assert_false "expected checkout should not be archived" test -e "$DOTFILES_BACKUP_ROOT"
  finish_test "existing expected Git checkout is reused"
}

test_cleanup_known_legacy_state() {
  local DOTFILES_ROOT=$TEST_ROOT
  local font="$HOME/.local/share/fonts/Droid Sans Mono for Powerline Nerd Font Complete.otf"
  export DOTFILES_ROOT
  PLATFORM=linux

  make_git_repository "$HOME/.spf13-vim-3" "$SPF13_URL"
  mkdir -p "$HOME/.vim/bundle/vundle/.git" "$HOME/.vim/bundle/nerdtree" \
    "$HOME/.vim/bundle/syntastic" "$HOME/.vim/bundle/vim-rails"
  ln -s "$HOME/.spf13-vim-3/.vimrc" "$HOME/.vimrc"
  ln -s "$DOTFILES_ROOT/templates/vimrc.before" "$HOME/.vimrc.before"
  ln -s templates/vimrc.after "$HOME/.vimrc.after"
  : > "$HOME/.vimrc.local"
  mkdir -p "$(dirname -- "$font")" "$HOME/.gnupg"
  printf 'legacy font\n' > "$font"
  printf 'personal-option\nuse-agent\n' > "$HOME/.gnupg/gpg.conf"
  printf 'keep\n' > "$HOME/.old.backup.123"

  cleanup_legacy_v1
  cleanup_legacy_v1
  assert_false "spf13 checkout should be removed" test -e "$HOME/.spf13-vim-3"
  assert_false "known Vundle tree should move out of the way" test -e "$HOME/.vim"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.vim/bundle/vim-rails' -type d | awk 'END { print NR + 0 }')" \
    "Vundle tree should be archived even when its layout is recognised"
  assert_false "known Vim symlink should be removed" test -L "$HOME/.vimrc"
  assert_false "known relative Vim symlink should be removed" test -L "$HOME/.vimrc.after"
  assert_false "empty vimrc.local should be removed" test -e "$HOME/.vimrc.local"
  assert_false "legacy font should move out of the way" test -e "$font"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -name 'Droid Sans Mono for Powerline Nerd Font Complete.otf' -type f | awk 'END { print NR + 0 }')" \
    "legacy font should be archived"
  assert_false "active use-agent should be removed" grep -Eq '^[[:space:]]*use-agent' "$HOME/.gnupg/gpg.conf"
  assert_true "other GPG settings should remain" grep -Fq personal-option "$HOME/.gnupg/gpg.conf"
  assert_true "historical backups should remain" test -f "$HOME/.old.backup.123"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.gnupg/gpg.conf' -type f | awk 'END { print NR + 0 }')" \
    "GPG file should be backed up only once"
  finish_test "cleanup removes only recognised legacy state and is repeatable"
}

test_cleanup_archives_ambiguous_state() {
  local DOTFILES_ROOT=$TEST_ROOT
  export DOTFILES_ROOT
  PLATFORM=linux

  mkdir -p "$HOME/.vim"
  printf 'custom\n' > "$HOME/.vim/custom.vim"
  printf 'custom\n' > "$HOME/.vimrc.local"
  cleanup_legacy_v1
  assert_false "ambiguous .vim should move out of the way" test -e "$HOME/.vim"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.vim/custom.vim' -type f | awk 'END { print NR + 0 }')" \
    "ambiguous Vim data should be archived"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.vimrc.local' -type f | awk 'END { print NR + 0 }')" \
    "custom vimrc.local should be archived"
  finish_test "cleanup archives ambiguous Vim data"
}

test_cleanup_archives_uncertain_spf13_state() {
  local checkout="$HOME/.spf13-vim-3"

  make_git_repository "$checkout" "$SPF13_URL"
  printf 'ignored-local\n' > "$checkout/.gitignore"
  git -C "$checkout" add .gitignore
  git -C "$checkout" -c user.name=Test -c user.email=test@example.com commit -qm ignore-fixture
  printf 'personal\n' > "$checkout/ignored-local"

  cleanup_spf13_checkout
  assert_false "spf13 checkout with ignored data should move out of the way" test -e "$checkout"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.spf13-vim-3/ignored-local' -type f | awk 'END { print NR + 0 }')" \
    "ignored spf13 data should be archived"

  BACKUP_SESSION_DIR=
  make_git_repository "$checkout" "$SPF13_URL"
  (
    git() {
      if [[ "$*" == *status* ]]; then
        return 1
      fi
      command git "$@"
    }
    cleanup_spf13_checkout
  )
  assert_false "spf13 checkout should be archived when Git status fails" test -e "$checkout"
  assert_eq 2 "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.spf13-vim-3/tracked' -type f | awk 'END { print NR + 0 }')" \
    "both uncertain spf13 checkouts should be archived"
  finish_test "cleanup preserves spf13 data when verification is uncertain"
}

test_cleanup_preserves_vim_when_brew_query_fails() {
  PLATFORM=macos

  brew() {
    case "$1 ${2:-}" in
      "list --formula") return 0 ;;
      "leaves ") printf 'vim\n' ;;
      "uses --installed") return 1 ;;
      "uninstall vim") : > "$HOME/uninstalled" ;;
      *) return 1 ;;
    esac
  }

  cleanup_homebrew_vim
  assert_false "Vim should not be uninstalled after a failed dependency query" test -e "$HOME/uninstalled"
  finish_test "cleanup fails closed when Homebrew dependency checks fail"
}

test_login_shell_reconciliation() {
  local bin_dir="$HOME/bin"

  mkdir -p "$bin_dir"
  printf '#!/bin/sh\nexit 0\n' > "$bin_dir/zsh"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "$HOME/chsh.log"\n' > "$bin_dir/chsh"
  chmod +x "$bin_dir/zsh" "$bin_dir/chsh"

  (
    PATH="$bin_dir:$PATH"
    USER=tester
    PLATFORM=linux
    configured_login_shell() { printf '/bin/bash\n'; }
    ensure_zsh_is_allowed() { printf '%s\n' "$1" > "$HOME/allowed-shell"; }
    ensure_zsh_login_shell
  )

  assert_eq "$bin_dir/zsh" "$(cat "$HOME/allowed-shell")" "Zsh should be allowed before chsh"
  assert_eq "-s $bin_dir/zsh tester" "$(cat "$HOME/chsh.log")" "chsh should receive the resolved Zsh path"

  rm "$HOME/chsh.log"
  (
    PATH="$bin_dir:$PATH"
    USER=tester
    PLATFORM=linux
    configured_login_shell() { printf '%s\n' "$bin_dir/zsh"; }
    ensure_zsh_is_allowed() { fail "allowed-shell check should be skipped"; }
    ensure_zsh_login_shell
  )
  assert_false "chsh should not run when Zsh is already configured" test -e "$HOME/chsh.log"
  finish_test "login-shell change is idempotent and stubbed"
}

new_home; test_versions
new_home; test_platform_detection
new_home; test_package_dispatch_without_package_manager
new_home; test_mise_release_selection
new_home; test_linux_tarball_install
new_home; test_apt_missing_required_package_fails
new_home; test_idempotent_links
new_home; test_dangling_link
new_home; test_dotfile_install
new_home; test_repository_path_with_spaces
new_home; test_ai_config_directories_are_archived
new_home; test_private_directories_replace_files_safely
new_home; test_existing_git_checkout_is_idempotent
new_home; test_cleanup_known_legacy_state
new_home; test_cleanup_archives_ambiguous_state
new_home; test_cleanup_archives_uncertain_spf13_state
new_home; test_cleanup_preserves_vim_when_brew_query_fails
new_home; test_login_shell_reconciliation

printf '1..%d\n' "$TESTS_RUN"
