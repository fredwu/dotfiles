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
# shellcheck source=../lib/skillshare.sh
source "$TEST_ROOT/install/lib/skillshare.sh"
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
    ensure_skillshare_on_linux() { :; }
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
  local name version asset checksum url executable

  (
    have() { return 1; }
    linux_architecture() { printf 'arm64\n'; }
    install_linux_tarball() { printf '%s\n' "$*" > "$marker"; }
    ensure_mise_on_linux
  )

  read -r name version asset checksum url executable < "$marker"
  assert_eq mise "$name" "mise should select the mise installer"
  assert_eq "$MISE_VERSION" "$version" "mise should select the configured version"
  assert_eq "mise-v$MISE_VERSION-linux-arm64.tar.gz" "$asset" \
    "mise should select the ARM64 asset"
  [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]] || fail "mise should require a SHA-256 checksum"
  assert_eq \
    "https://github.com/jdx/mise/releases/download/v$MISE_VERSION/$asset" \
    "$url" "mise should construct the configured release URL"
  assert_eq bin/mise "$executable" "mise should select the executable within the archive"
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

test_skillshare_release_selection() {
  local marker="$HOME/skillshare-release"
  local name version asset checksum url executable

  (
    linux_architecture() { printf 'arm64\n'; }
    install_linux_flat_tarball() { printf '%s\n' "$*" > "$marker"; }
    ensure_skillshare_on_linux
  )

  read -r name version asset checksum url executable < "$marker"
  assert_eq skillshare "$name" "Skillshare should select the Skillshare installer"
  assert_eq 0.20.25 "$SKILLSHARE_VERSION" \
    "Skillshare's supported Linux release should remain pinned"
  assert_eq "$SKILLSHARE_VERSION" "$version" \
    "Skillshare should select the configured version"
  assert_eq "skillshare_${SKILLSHARE_VERSION}_linux_arm64.tar.gz" "$asset" \
    "Skillshare should select the ARM64 asset"
  [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]] || \
    fail "Skillshare should require a SHA-256 checksum"
  assert_eq \
    "https://github.com/runkids/skillshare/releases/download/v$SKILLSHARE_VERSION/$asset" \
    "$url" "Skillshare should construct the configured release URL"
  assert_eq skillshare "$executable" \
    "Skillshare should select the executable within the archive"
  finish_test "Skillshare release selection is pinned and architecture-aware"
}

test_linux_flat_tarball_install() {
  local fixture="$HOME/fixture"
  local fixture_archive="$HOME/fixture.tar.gz"

  mkdir -p "$fixture"
  printf '#!/bin/sh\nprintf "fixture\\n"\n' > "$fixture/skillshare"
  chmod +x "$fixture/skillshare"
  tar -czf "$fixture_archive" -C "$fixture" skillshare

  (
    download_checked() { cp "$fixture_archive" "$3"; }
    install_linux_flat_tarball \
      skillshare 1.2.3 fixture.tar.gz unused https://example.invalid/fixture skillshare
    install_linux_flat_tarball \
      skillshare 1.2.3 fixture.tar.gz unused https://example.invalid/fixture skillshare
  )

  assert_eq fixture "$("$HOME/.local/bin/skillshare")" \
    "installed flat-tarball executable should run"
  assert_eq "$HOME/.local/opt/skillshare/1.2.3/skillshare" \
    "$(readlink "$HOME/.local/bin/skillshare")" \
    "flat-tarball executable should be linked from the local bin directory"
  assert_false "repeat flat-tarball install should create no backup" \
    test -e "$DOTFILES_BACKUP_ROOT"
  finish_test "pinned Linux flat tarballs install idempotently"
}

test_apt_missing_required_package_fails() {
  assert_false "apt install should fail when a required package is unavailable" \
    run_apt_with_missing_required_package
  finish_test "apt refuses an incomplete required package set"
}

run_apt_with_missing_required_package() (
  as_root() { "$@"; }
  apt-get() { :; }
  apt_package_exists() { return 1; }
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
  assert_true "Claude config should be a directory" test -d "$HOME/.claude"
  assert_false "Claude config should not be linked" test -L "$HOME/.claude"
  assert_true "Codex config should be a directory" test -d "$HOME/.codex"
  assert_false "Codex config should not be linked" test -L "$HOME/.codex"
  assert_true "Grok config should be a directory" test -d "$HOME/.grok"
  assert_false "Grok config should not be linked" test -L "$HOME/.grok"
  assert_eq "$DOTFILES_ROOT/ai/shared/AGENTS.md" "$(readlink "$HOME/.claude/CLAUDE.md")" \
    "Claude instructions should link to shared instructions"
  assert_eq "$DOTFILES_ROOT/ai/shared/AGENTS.md" "$(readlink "$HOME/.codex/AGENTS.md")" \
    "Codex instructions should link to shared instructions"
  assert_eq "$DOTFILES_ROOT/ai/shared/AGENTS.md" "$(readlink "$HOME/.grok/AGENTS.md")" \
    "Grok instructions should link to shared instructions"
  assert_eq 700 "$(stat -f '%Lp' "$HOME/.ssh" 2>/dev/null || stat -c '%a' "$HOME/.ssh")" \
    "SSH directory should have mode 700"
  assert_eq 0 "$(find "$DOTFILES_BACKUP_ROOT" -type f 2>/dev/null | awk 'END { print NR + 0 }')" \
    "repeat install should create no backups"
  finish_test "dotfiles install twice without touching real HOME"
}

test_skillshare_configuration() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository"
  local XDG_CONFIG_HOME="$HOME/xdg config"
  local invocation_log="$HOME/skillshare.log"
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/ai/skillshare/skills/example" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$DOTFILES_ROOT/install/lib" \
    "$XDG_CONFIG_HOME/skillshare/extensions/codex-agents"
  printf 'fixture skill\n' > "$DOTFILES_ROOT/ai/skillshare/skills/example/SKILL.md"
  printf 'built-in extension\n' \
    > "$XDG_CONFIG_HOME/skillshare/extensions/codex-agents/owned-by-skillshare"
  cp "$source_root/ai/skillshare/agent-models.json" "$DOTFILES_ROOT/ai/skillshare/"
  cp -R "$source_root/ai/skillshare/extensions" "$DOTFILES_ROOT/ai/skillshare/"
  cp "$source_root/install/lib/configure-skillshare-extra.js" "$DOTFILES_ROOT/install/lib/"
  cp "$source_root/ai/skillshare/agents/"*.md "$DOTFILES_ROOT/ai/skillshare/agents/"

  skillshare() {
    if [[ "$1" == --version ]]; then
      printf 'skillshare v0.20.25\n'
    elif [[ "$1" == init ]]; then
      printf '%s\n' "$*" >> "$invocation_log"
      mkdir -p "$XDG_CONFIG_HOME/skillshare"
      printf '%s\n' \
        'sources:' \
        "  skills: \"$XDG_CONFIG_HOME/skillshare/skills\"" \
        "  agents: \"$XDG_CONFIG_HOME/skillshare/agents\"" \
        'mode: symlink' \
        'targets:' \
        '  claude:' \
        '    skills: {}' \
        '  codex:' \
        '    skills: {}' \
        '  grok:' \
        '    skills: {}' \
        'ignore:' > "$XDG_CONFIG_HOME/skillshare/config.yaml"
    else
      printf '%s\n' "$*" >> "$invocation_log"
    fi
  }

  configure_skillshare
  configure_skillshare

  assert_eq "$DOTFILES_ROOT/ai/skillshare/skills" \
    "$(readlink "$XDG_CONFIG_HOME/skillshare/skills")" \
    "Skillshare skills source should link to the repository"
  assert_true "Skillshare native agents source should be a real directory" \
    test -d "$XDG_CONFIG_HOME/skillshare/agents"
  assert_false "Skillshare native agents source should not link to the repository" \
    test -L "$XDG_CONFIG_HOME/skillshare/agents"
  assert_eq 0 \
    "$(find "$XDG_CONFIG_HOME/skillshare/agents" -mindepth 1 | awk 'END { print NR + 0 }')" \
    "Skillshare native agents source should remain empty"
  assert_true "Skillshare's built-in extension should remain untouched" \
    grep -Fxq 'built-in extension' \
    "$XDG_CONFIG_HOME/skillshare/extensions/codex-agents/owned-by-skillshare"
  for extension in dotfiles-claude-agents dotfiles-codex-agents; do
    assert_true "custom extension should use a discoverable real directory" \
      test -d "$XDG_CONFIG_HOME/skillshare/extensions/$extension"
    assert_false "custom extension directory should not itself be linked" \
      test -L "$XDG_CONFIG_HOME/skillshare/extensions/$extension"
  done
  assert_false "shared transformer support should not be installed as an extension" \
    test -e "$XDG_CONFIG_HOME/skillshare/extensions/dotfiles-agent-transform"
  assert_eq \
    "$DOTFILES_ROOT/ai/skillshare/extensions/dotfiles-codex-agents/extension.yaml" \
    "$(readlink "$XDG_CONFIG_HOME/skillshare/extensions/dotfiles-codex-agents/extension.yaml")" \
    "custom extension files should remain repository-backed"
  assert_eq 1 "$(grep -c '^init ' "$invocation_log")" \
    "Skillshare should initialize only when config is absent"
  assert_eq \
    "init --source $XDG_CONFIG_HOME/skillshare/skills --no-copy --targets claude,codex,grok --mode symlink --no-git --no-skill" \
    "$(grep '^init ' "$invocation_log")" \
    "Skillshare init should use deterministic noninteractive flags"
  assert_eq 2 "$(grep -c '^sync -g$' "$invocation_log")" \
    "Skillshare should sync skills on every completed run"
  assert_eq 2 "$(grep -c '^sync extras --force -g$' "$invocation_log")" \
    "Skillshare should force-refresh generated extras on every completed run"
  assert_eq 1 "$(grep -c '^  - name: dotfiles-agents$' "$XDG_CONFIG_HOME/skillshare/config.yaml")" \
    "repeat setup should configure one namespaced agents extra"
  assert_true "generated agent sync should use the real repository source" \
    grep -Fq "source: \"$DOTFILES_ROOT/ai/skillshare/agents\"" \
    "$XDG_CONFIG_HOME/skillshare/config.yaml"
  assert_true "native agent discovery should use the empty Skillshare source" \
    grep -Fq "agents: \"$XDG_CONFIG_HOME/skillshare/agents\"" \
    "$XDG_CONFIG_HOME/skillshare/config.yaml"
  assert_true "Claude generation should use the namespaced extension" \
    grep -Fq "extension: dotfiles-claude-agents" \
    "$XDG_CONFIG_HOME/skillshare/config.yaml"
  assert_true "Codex generation should use the namespaced extension" \
    grep -Fq "extension: dotfiles-codex-agents" "$XDG_CONFIG_HOME/skillshare/config.yaml"
  assert_true "generated agents extra should target Claude" \
    grep -Fq "path: \"$HOME/.claude/agents\"" "$XDG_CONFIG_HOME/skillshare/config.yaml"
  assert_true "generated agents extra should target Codex" \
    grep -Fq "path: \"$HOME/.codex/agents\"" "$XDG_CONFIG_HOME/skillshare/config.yaml"
  assert_false "Skillshare setup should not create nested Git metadata" \
    test -e "$DOTFILES_ROOT/ai/skillshare/skills/.git"
  assert_eq 4 \
    "$(find "$HOME/.local/state/dotfiles/skillshare-agents.manifest" -type f -exec awk 'END { print NR + 0 }' {} \;)" \
    "successful sync should record both outputs for every managed agent"
  finish_test "Skillshare sources, init, and global sync are idempotent"
}

test_skillshare_existing_config_is_preserved() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository"
  local XDG_CONFIG_HOME="$HOME/xdg config"
  local invocation_log="$HOME/skillshare.log"
  local skillshare_home="$XDG_CONFIG_HOME/skillshare"
  local agent_file managed_agent
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/ai/skillshare/skills" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$DOTFILES_ROOT/install/lib" \
    "$skillshare_home/skills/local-only" \
    "$skillshare_home/agents" \
    "$skillshare_home/extensions/codex-agents"
  printf '%s\n' \
    'targets:' \
    '  claude:' \
    '    skills:' \
    '      path: /tmp/claude-skills' \
    '    agents:' \
    "      path: \"$HOME/.claude/agents\"" \
    '  codex:' \
    '    skills:' \
    '      path: /tmp/codex-skills' \
    '    agents:' \
    '      path: /tmp/custom-codex-agents' \
    'extras:' \
    '  - name: codex-agents' \
    "    source: \"$DOTFILES_ROOT/ai/skillshare/agents\"" \
    '    targets:' \
    "      - path: \"$HOME/.codex/agents\"" \
    '        mode: copy' \
    '        extension: codex-agents' \
    'ignore:' > "$skillshare_home/config.yaml"
  printf 'local skill\n' > "$skillshare_home/skills/local-only/SKILL.md"
  printf 'local agent\n' > "$skillshare_home/agents/local.md"
  printf 'built-in extension\n' \
    > "$skillshare_home/extensions/codex-agents/owned-by-skillshare"
  cp "$source_root/ai/skillshare/agent-models.json" "$DOTFILES_ROOT/ai/skillshare/"
  cp -R "$source_root/ai/skillshare/extensions" "$DOTFILES_ROOT/ai/skillshare/"
  cp "$source_root/install/lib/configure-skillshare-extra.js" "$DOTFILES_ROOT/install/lib/"
  managed_agent=
  for agent_file in "$source_root/ai/skillshare/agents/"*.md; do
    [[ -e "$agent_file" ]] || continue
    cp "$agent_file" "$DOTFILES_ROOT/ai/skillshare/agents/"
    if [[ -z "$managed_agent" ]]; then
      managed_agent=${agent_file##*/}
      managed_agent=${managed_agent%.md}
    fi
  done
  [[ -n "$managed_agent" ]] || fail "Skillshare migration fixture requires a managed agent"
  mkdir -p "$HOME/.claude/agents" "$HOME/.codex/agents"
  printf 'stale generated agent\n' > "$HOME/.claude/agents/$managed_agent.md"
  printf 'stale generated agent\n' > "$HOME/.codex/agents/$managed_agent.toml"
  printf 'unrelated local agent\n' > "$HOME/.codex/agents/local-only.toml"

  skillshare() {
    if [[ "$1" == --version ]]; then
      printf 'skillshare v0.20.25\n'
    else
      printf '%s\n' "$*" >> "$invocation_log"
    fi
  }

  configure_skillshare

  assert_true "existing Skillshare skill target should remain intact" \
    grep -Fq 'path: /tmp/claude-skills' "$skillshare_home/config.yaml"
  assert_false "existing Skillshare config should skip init" \
    grep -q '^init ' "$invocation_log"
  assert_eq 1 "$(grep -c '^sync -g$' "$invocation_log")" \
    "existing Skillshare config should sync skills"
  assert_eq 1 "$(grep -c '^sync extras --force -g$' "$invocation_log")" \
    "existing Skillshare config should force-refresh generated extras"
  assert_true "existing config should gain the namespaced agents extra" \
    grep -Fq "name: dotfiles-agents" "$skillshare_home/config.yaml"
  assert_false "old Codex-only extra should be removed" \
    grep -Fq "name: codex-agents" "$skillshare_home/config.yaml"
  assert_eq 1 \
    "$(grep -Fc "path: \"$HOME/.claude/agents\"" "$skillshare_home/config.yaml")" \
    "colliding Claude path should remain only in the managed extra"
  assert_true "unrelated native Codex agent ownership should be preserved" \
    grep -Fq "path: /tmp/custom-codex-agents" "$skillshare_home/config.yaml"
  assert_eq "$DOTFILES_ROOT/ai/skillshare/skills" "$(readlink "$skillshare_home/skills")" \
    "existing skills source should be replaced by the repository link"
  assert_true "existing native agents source should become a real directory" \
    test -d "$skillshare_home/agents"
  assert_false "existing native agents source should not remain linked" \
    test -L "$skillshare_home/agents"
  assert_eq 0 "$(find "$skillshare_home/agents" -mindepth 1 | awk 'END { print NR + 0 }')" \
    "native agent discovery should find zero agents"
  assert_true "existing config should point native discovery at the empty source" \
    grep -Fq "agents: \"$skillshare_home/agents\"" "$skillshare_home/config.yaml"
  assert_true "pre-existing skills should be archived before relinking" \
    test -f "$DOTFILES_BACKUP_ROOT"/*/xdg\ config/skillshare/skills/local-only/SKILL.md
  assert_true "pre-existing agents should be archived before relinking" \
    test -f "$DOTFILES_BACKUP_ROOT"/*/xdg\ config/skillshare/agents/local.md
  assert_true "overlapping Claude agents should be archived for migration" \
    test -f "$DOTFILES_BACKUP_ROOT"/*/.claude/agents/"$managed_agent.md"
  assert_true "overlapping Codex agents should be archived for first migration" \
    test -f "$DOTFILES_BACKUP_ROOT"/*/.codex/agents/"$managed_agent.toml"
  assert_false "overlapping Codex agent should be clear for Skillshare generation" \
    test -e "$HOME/.codex/agents/$managed_agent.toml"
  assert_true "unrelated Codex agents should not be touched" \
    test -f "$HOME/.codex/agents/local-only.toml"
  assert_true "Skillshare's built-in extension should remain untouched" \
    test -f "$skillshare_home/extensions/codex-agents/owned-by-skillshare"
  finish_test "existing Skillshare config and source data are preserved"
}

test_skillshare_empty_agents_source_reconciliation() {
  local target="$HOME/.config/skillshare/agents"
  local legacy="$HOME/legacy-agents"
  local backup_count

  mkdir -p "$legacy" "$(dirname -- "$target")"
  printf 'legacy agent\n' > "$legacy/legacy.md"
  ln -s "$legacy" "$target"

  ensure_empty_skillshare_agents_source "$target"
  assert_true "legacy agents symlink should become a real directory" test -d "$target"
  assert_false "legacy agents symlink should be removed" test -L "$target"
  assert_eq 0 "$(find "$target" -mindepth 1 | awk 'END { print NR + 0 }')" \
    "replacement native source should be empty"
  assert_eq 1 "$(find "$DOTFILES_BACKUP_ROOT" -type l | awk 'END { print NR + 0 }')" \
    "legacy agents symlink should be archived"

  backup_count=$(find "$DOTFILES_BACKUP_ROOT" -mindepth 1 | awk 'END { print NR + 0 }')
  ensure_empty_skillshare_agents_source "$target"
  assert_eq "$backup_count" \
    "$(find "$DOTFILES_BACKUP_ROOT" -mindepth 1 | awk 'END { print NR + 0 }')" \
    "repeat reconciliation should leave an empty real directory unchanged"

  printf 'local native agent\n' > "$target/local.md"
  ensure_empty_skillshare_agents_source "$target"
  assert_eq 0 "$(find "$target" -mindepth 1 | awk 'END { print NR + 0 }')" \
    "native source content should be archived before the directory is cleared"
  assert_eq 1 \
    "$(find "$DOTFILES_BACKUP_ROOT" -path '*/.config/skillshare/agents*/local.md' -type f | awk 'END { print NR + 0 }')" \
    "native source content should be recoverable"
  finish_test "Skillshare native agents source stays empty and migration is recoverable"
}

test_skillshare_preflight_failures_do_not_mutate_state() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository"
  local XDG_CONFIG_HOME="$HOME/xdg"
  local skillshare_home="$XDG_CONFIG_HOME/skillshare"
  local error_log="$HOME/preflight-error.log"
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/ai/skillshare/skills" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$DOTFILES_ROOT/install/lib" \
    "$skillshare_home/extensions/dotfiles-claude-agents" \
    "$skillshare_home/extensions/dotfiles-codex-agents" \
    "$HOME/.claude/agents" "$HOME/.codex/agents" "$HOME/legacy-native-agents"
  cp "$source_root/ai/skillshare/agent-models.json" "$DOTFILES_ROOT/ai/skillshare/"
  cp -R "$source_root/ai/skillshare/extensions" "$DOTFILES_ROOT/ai/skillshare/"
  cp "$source_root/install/lib/configure-skillshare-extra.js" "$DOTFILES_ROOT/install/lib/"
  printf '%s\n' \
    '---' \
    'name: fastworker' \
    'description: invalid provider-specific source' \
    'model: opus' \
    '---' \
    'Do work.' > "$DOTFILES_ROOT/ai/skillshare/agents/fastworker.md"
  printf '%s\n' \
    'sources:' \
    "  skills: \"$skillshare_home/skills\"" \
    "  agents: \"$skillshare_home/agents\"" \
    'targets:' \
    '  claude:' \
    '    skills: {}' \
    'ignore:' > "$skillshare_home/config.yaml"
  cp "$skillshare_home/config.yaml" "$HOME/config.before"
  ln -s "$HOME/legacy-native-agents" "$skillshare_home/agents"
  printf 'Claude extension marker\n' \
    > "$skillshare_home/extensions/dotfiles-claude-agents/marker"
  printf 'Codex extension marker\n' \
    > "$skillshare_home/extensions/dotfiles-codex-agents/marker"
  printf 'Claude agent\n' > "$HOME/.claude/agents/fastworker.md"
  printf 'Codex agent\n' > "$HOME/.codex/agents/fastworker.toml"

  skillshare() {
    if [[ "$1" == --version ]]; then
      printf 'skillshare v0.20.25\n'
    else
      fail "Skillshare commands should not run after invalid agent validation"
    fi
  }

  if (configure_skillshare > /dev/null 2> "$error_log"); then
    fail "invalid provider-specific source should stop Skillshare setup"
  fi
  assert_true "invalid source should fail for the expected validation reason" \
    grep -Fq "provider field 'model'" "$error_log"
  assert_true "invalid source should leave config byte-for-byte unchanged" \
    cmp -s "$HOME/config.before" "$skillshare_home/config.yaml"
  assert_eq "$HOME/legacy-native-agents" "$(readlink "$skillshare_home/agents")" \
    "invalid source should leave the native source link unchanged"
  assert_true "invalid source should leave installed extensions unchanged" \
    grep -Fxq 'Claude extension marker' \
    "$skillshare_home/extensions/dotfiles-claude-agents/marker"
  assert_true "invalid source should leave generated Claude agents unchanged" \
    grep -Fxq 'Claude agent' "$HOME/.claude/agents/fastworker.md"
  assert_true "invalid source should leave generated Codex agents unchanged" \
    grep -Fxq 'Codex agent' "$HOME/.codex/agents/fastworker.toml"
  assert_false "invalid source should create no backup state" test -e "$DOTFILES_BACKUP_ROOT"
  assert_false "invalid source should create no ownership manifest" \
    test -e "$HOME/.local/state/dotfiles/skillshare-agents.manifest"

  skillshare() {
    if [[ "$1" == --version ]]; then
      printf 'skillshare v0.20.24\n'
    else
      fail "Skillshare commands should not run with an unsupported version"
    fi
  }
  if (configure_skillshare > /dev/null 2> "$error_log"); then
    fail "Skillshare older than 0.20.25 should stop setup"
  fi
  assert_true "old Skillshare should fail with a minimum-version error" \
    grep -Fq 'Skillshare 0.20.25 or newer is required' "$error_log"
  assert_true "old Skillshare should leave config unchanged" \
    cmp -s "$HOME/config.before" "$skillshare_home/config.yaml"
  finish_test "Skillshare version and agent validation fail before all mutations"
}

test_skillshare_config_helper_fails_closed() {
  local helper="$TEST_ROOT/install/lib/configure-skillshare-extra.js"
  local source="$HOME/repository/ai/skillshare/agents"
  local claude_target="$HOME/.claude/agents"
  local codex_target="$HOME/.codex/agents"
  local native_source="$HOME/.config/skillshare/agents"
  local fixture snapshot
  local -a unsupported

  unsupported=(flow-sources quoted-sources indented-sources indented-targets flow-extras crlf)
  for fixture in "${unsupported[@]}"; do
    case "$fixture" in
      flow-sources) printf '%s\n' 'sources: {}' 'targets:' > "$HOME/$fixture.yaml" ;;
      quoted-sources) printf '%s\n' '"sources":' '  agents: /tmp/agents' > "$HOME/$fixture.yaml" ;;
      indented-sources) printf '%s\n' '  sources:' '    agents: /tmp/agents' > "$HOME/$fixture.yaml" ;;
      indented-targets) printf '%s\n' 'sources:' '  skills: /tmp/skills' '  targets:' > "$HOME/$fixture.yaml" ;;
      flow-extras) printf '%s\n' 'targets:' 'extras: []' > "$HOME/$fixture.yaml" ;;
      crlf) printf 'sources:\r\n  agents: /tmp/agents\r\n' > "$HOME/$fixture.yaml" ;;
    esac
    snapshot="$HOME/$fixture.before"
    cp "$HOME/$fixture.yaml" "$snapshot"
    if env -u NODE_OPTIONS node "$helper" "$HOME/$fixture.yaml" "$source" \
      "$claude_target" "$codex_target" "$native_source" >/dev/null 2>&1; then
      fail "config helper should reject unsupported $fixture YAML"
    fi
    assert_true "config helper should not modify rejected $fixture YAML" \
      cmp -s "$snapshot" "$HOME/$fixture.yaml"
  done

  fixture="$HOME/conflict.yaml"
  printf '%s\n' \
    'sources:' \
    '  skills: /tmp/skills' \
    'targets:' \
    '  claude:' \
    '    skills: {}' \
    'extras:' \
    '  - name: personal-agents' \
    '    source: /tmp/personal' \
    '    targets:' \
    "      - path: \"$claude_target\"" \
    '        mode: copy' > "$fixture"
  cp "$fixture" "$HOME/conflict.before"
  if env -u NODE_OPTIONS node "$helper" "$fixture" "$source" \
    "$claude_target" "$codex_target" "$native_source" >/dev/null 2>&1; then
    fail "config helper should reject a preserved extra target conflict"
  fi
  assert_true "target conflict refusal should not modify config" \
    cmp -s "$HOME/conflict.before" "$fixture"
  finish_test "Skillshare config helper rejects unsupported or conflicting YAML without mutation"
}

test_skillshare_config_preflight_fails_before_mutation() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository"
  local XDG_CONFIG_HOME="$HOME/xdg"
  local skillshare_home="$XDG_CONFIG_HOME/skillshare"
  local error_log="$HOME/config-preflight-error.log"
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/ai/skillshare/skills" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$DOTFILES_ROOT/install/lib" \
    "$skillshare_home/extensions/dotfiles-claude-agents" \
    "$skillshare_home/extensions/dotfiles-codex-agents" \
    "$HOME/.claude/agents" "$HOME/.codex/agents" "$HOME/legacy-native-agents"
  cp "$source_root/ai/skillshare/agent-models.json" "$DOTFILES_ROOT/ai/skillshare/"
  cp -R "$source_root/ai/skillshare/extensions" "$DOTFILES_ROOT/ai/skillshare/"
  cp "$source_root/install/lib/configure-skillshare-extra.js" "$DOTFILES_ROOT/install/lib/"
  cp "$source_root/ai/skillshare/agents/"*.md "$DOTFILES_ROOT/ai/skillshare/agents/"
  printf '%s\n' \
    'sources:' \
    '  skills: /tmp/skills' \
    '  targets:' > "$skillshare_home/config.yaml"
  cp "$skillshare_home/config.yaml" "$HOME/config.before"
  ln -s "$HOME/legacy-native-agents" "$skillshare_home/agents"
  printf 'Claude extension marker\n' \
    > "$skillshare_home/extensions/dotfiles-claude-agents/marker"
  printf 'Codex extension marker\n' \
    > "$skillshare_home/extensions/dotfiles-codex-agents/marker"
  printf 'Claude agent\n' > "$HOME/.claude/agents/fastworker.md"
  printf 'Codex agent\n' > "$HOME/.codex/agents/fastworker.toml"

  skillshare() {
    if [[ "$1" == --version ]]; then
      printf 'skillshare v0.20.25\n'
    else
      fail "Skillshare commands should not run after config preflight failure"
    fi
  }

  if (configure_skillshare > /dev/null 2> "$error_log"); then
    fail "unsupported existing YAML should stop Skillshare setup"
  fi
  assert_true "unsupported YAML should fail during configuration preflight" \
    grep -Fq 'Skillshare agent configuration preflight failed' "$error_log"
  assert_true "unsupported YAML should leave config byte-for-byte unchanged" \
    cmp -s "$HOME/config.before" "$skillshare_home/config.yaml"
  assert_eq "$HOME/legacy-native-agents" "$(readlink "$skillshare_home/agents")" \
    "unsupported YAML should leave the native source link unchanged"
  assert_true "unsupported YAML should leave the Claude extension unchanged" \
    grep -Fxq 'Claude extension marker' \
    "$skillshare_home/extensions/dotfiles-claude-agents/marker"
  assert_true "unsupported YAML should leave the Codex extension unchanged" \
    grep -Fxq 'Codex extension marker' \
    "$skillshare_home/extensions/dotfiles-codex-agents/marker"
  assert_true "unsupported YAML should leave generated Claude agents unchanged" \
    grep -Fxq 'Claude agent' "$HOME/.claude/agents/fastworker.md"
  assert_true "unsupported YAML should leave generated Codex agents unchanged" \
    grep -Fxq 'Codex agent' "$HOME/.codex/agents/fastworker.toml"
  assert_false "unsupported YAML should not install the skills source" \
    test -e "$skillshare_home/skills"
  assert_false "unsupported YAML should create no backup state" \
    test -e "$DOTFILES_BACKUP_ROOT"
  assert_false "unsupported YAML should create no ownership manifest" \
    test -e "$HOME/.local/state/dotfiles/skillshare-agents.manifest"
  finish_test "Skillshare config preflight fails before filesystem or target mutation"
}

test_skillshare_config_helper_narrows_legacy_cleanup() {
  local helper="$TEST_ROOT/install/lib/configure-skillshare-extra.js"
  local config="$HOME/config.yaml"
  local source="$HOME/repository/ai/skillshare/agents"
  local claude_target="$HOME/.claude/agents"
  local codex_target="$HOME/.codex/agents"
  local native_source="$HOME/.config/skillshare/agents"

  printf '%s\n' \
    'sources:' \
    '  skills: /tmp/skills' \
    'targets:' \
    '  claude:' \
    '    skills: {}' \
    '    agents:' \
    '      mode: merge' \
    '  codex:' \
    '    skills: {}' \
    '    agents:' \
    '      path: /tmp/custom-codex-agents' \
    'extras:' \
    '  - name: codex-agents' \
    '    source: /tmp/unrelated-source' \
    '    targets:' \
    '      - path: /tmp/unrelated-target' \
    '        mode: copy' \
    '        extension: codex-agents' > "$config"

  env -u NODE_OPTIONS node "$helper" "$config" "$source" \
    "$claude_target" "$codex_target" "$native_source" >/dev/null
  assert_false "pathless native agent ownership should be removed" \
    grep -Fq 'mode: merge' "$config"
  assert_true "unrelated native agent path should remain" \
    grep -Fq 'path: /tmp/custom-codex-agents' "$config"
  assert_true "unrelated legacy-named extra should remain" \
    grep -Fq 'source: /tmp/unrelated-source' "$config"
  assert_eq 1 "$(grep -c '^  - name: dotfiles-agents$' "$config")" \
    "managed namespaced extra should be added once"
  finish_test "Skillshare cleanup removes only colliding native and former managed entries"
}

test_generated_agent_manifest_prunes_only_owned_outputs() {
  local manifest="$HOME/.local/state/dotfiles/skillshare-agents.manifest"
  local backup_count

  mkdir -p "$(dirname -- "$manifest")" "$HOME/.claude/agents" "$HOME/.codex/agents"
  printf '%s\n' 'claude/removed.md' 'codex/removed.toml' > "$manifest"
  printf 'managed Claude\n' > "$HOME/.claude/agents/removed.md"
  printf 'managed Codex\n' > "$HOME/.codex/agents/removed.toml"
  printf 'personal Claude\n' > "$HOME/.claude/agents/personal.md"
  printf 'personal Codex\n' > "$HOME/.codex/agents/personal.toml"

  reconcile_generated_agents_manifest "$manifest" \
    'claude/worker.md' 'codex/worker.toml'
  assert_false "removed managed Claude output should leave the live target" \
    test -e "$HOME/.claude/agents/removed.md"
  assert_false "removed managed Codex output should leave the live target" \
    test -e "$HOME/.codex/agents/removed.toml"
  assert_true "removed managed Claude output should be recoverable" \
    test -f "$DOTFILES_BACKUP_ROOT"/*/.claude/agents/removed.md
  assert_true "removed managed Codex output should be recoverable" \
    test -f "$DOTFILES_BACKUP_ROOT"/*/.codex/agents/removed.toml
  assert_true "unrelated Claude output should remain" \
    grep -Fxq 'personal Claude' "$HOME/.claude/agents/personal.md"
  assert_true "unrelated Codex output should remain" \
    grep -Fxq 'personal Codex' "$HOME/.codex/agents/personal.toml"
  assert_eq $'claude/worker.md\ncodex/worker.toml' "$(cat "$manifest")" \
    "manifest should update to the latest successful output set"

  backup_count=$(find "$DOTFILES_BACKUP_ROOT" -type f | awk 'END { print NR + 0 }')
  reconcile_generated_agents_manifest "$manifest" \
    'claude/worker.md' 'codex/worker.toml'
  assert_eq "$backup_count" \
    "$(find "$DOTFILES_BACKUP_ROOT" -type f | awk 'END { print NR + 0 }')" \
    "repeat manifest reconciliation should be idempotent"
  finish_test "generated agent manifest prunes only previously owned outputs"
}

test_generated_agent_manifest_waits_for_successful_sync() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository"
  local XDG_CONFIG_HOME="$HOME/xdg"
  local skillshare_home="$XDG_CONFIG_HOME/skillshare"
  local manifest="$HOME/.local/state/dotfiles/skillshare-agents.manifest"
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/ai/skillshare/skills" \
    "$DOTFILES_ROOT/ai/skillshare/agents" \
    "$DOTFILES_ROOT/install/lib" \
    "$skillshare_home/agents" \
    "$HOME/.claude/agents" \
    "$HOME/.local/state/dotfiles"
  cp "$source_root/ai/skillshare/agent-models.json" "$DOTFILES_ROOT/ai/skillshare/"
  cp -R "$source_root/ai/skillshare/extensions" "$DOTFILES_ROOT/ai/skillshare/"
  cp "$source_root/install/lib/configure-skillshare-extra.js" "$DOTFILES_ROOT/install/lib/"
  cp "$source_root/ai/skillshare/agents/"*.md "$DOTFILES_ROOT/ai/skillshare/agents/"
  printf '%s\n' \
    'sources:' \
    "  skills: \"$skillshare_home/skills\"" \
    "  agents: \"$skillshare_home/agents\"" \
    'targets:' \
    '  claude:' \
    '    skills: {}' \
    'ignore:' > "$skillshare_home/config.yaml"
  printf 'claude/removed.md\n' > "$manifest"
  printf 'previously managed\n' > "$HOME/.claude/agents/removed.md"

  skillshare() {
    if [[ "$1" == --version ]]; then
      printf 'skillshare v0.20.25\n'
    elif [[ "$*" == 'sync extras --force -g' ]]; then
      return 1
    fi
  }

  if (configure_skillshare >/dev/null 2>&1); then
    fail "failed Extras sync should fail Skillshare setup"
  fi
  assert_eq 'claude/removed.md' "$(cat "$manifest")" \
    "failed Extras sync should not update ownership state"
  assert_true "failed Extras sync should not prune prior managed output" \
    grep -Fxq 'previously managed' "$HOME/.claude/agents/removed.md"
  finish_test "generated agent manifest updates only after successful Extras sync"
}

test_skillshare_real_cli_accepts_generated_config_when_available() {
  local binary
  local version
  local config_home="$HOME/xdg"
  local config="$config_home/skillshare/config.yaml"
  local status="$HOME/status.json"

  binary=$(type -P skillshare || true)
  if [[ -z "$binary" ]]; then
    finish_test "real Skillshare config validation skipped because the binary is unavailable"
    return
  fi
  version=$("$binary" --version | sed -nE 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
  if [[ "$version" != 0.20.25 ]]; then
    finish_test "real Skillshare config validation skipped because v0.20.25 is unavailable"
    return
  fi

  mkdir -p "$config_home/skillshare/skills" "$config_home/skillshare/agents"
  printf '%s\n' \
    'sources:' \
    "  skills: \"$config_home/skillshare/skills\"" \
    "  agents: \"$config_home/skillshare/agents\"" \
    'mode: merge' \
    'targets:' \
    '  claude:' \
    '    skills: {}' \
    'ignore:' > "$config"
  env -u NODE_OPTIONS node "$TEST_ROOT/install/lib/configure-skillshare-extra.js" \
    "$config" "$TEST_ROOT/ai/skillshare/agents" "$HOME/.claude/agents" \
    "$HOME/.codex/agents" "$config_home/skillshare/agents" >/dev/null
  HOME="$HOME" XDG_CONFIG_HOME="$config_home" "$binary" status --json -g > "$status"
  assert_true "real Skillshare should parse the generated config" grep -Fq '"version": "0.20.25"' "$status"
  assert_true "real Skillshare should see an empty native agent source" grep -Fq '"count": 0' "$status"
  assert_true "real Skillshare should report no native agent drift" grep -Fq '"drift": false' "$status"
  finish_test "real Skillshare v0.20.25 accepts generated config when available"
}

test_shared_agents_are_provider_neutral() {
  local agent_file="$TEST_ROOT/ai/skillshare/agents/fastworker.md"
  local claude_output="$HOME/fastworker.md"
  local codex_output="$HOME/fastworker.toml"
  local source

  for source in "$TEST_ROOT/ai/skillshare/agents/"*.md; do
    [[ -e "$source" ]] || continue
    if awk '
      NR == 1 { next }
      $0 == "---" { exit }
      /^(model|effort):/ { found = 1 }
      END { exit found ? 0 : 1 }
    ' "$source"; then
      fail "shared agent frontmatter should not select a provider model: $source"
    fi
  done

  env -u NODE_OPTIONS node \
    "$TEST_ROOT/ai/skillshare/extensions/dotfiles-agent-transform/validate.js" \
    "$TEST_ROOT/ai/skillshare/agents"
  SS_REL_PATH=fastworker.md env -u NODE_OPTIONS node \
    "$TEST_ROOT/ai/skillshare/extensions/dotfiles-claude-agents/convert.js" \
    < "$agent_file" > "$claude_output"
  SS_REL_PATH=fastworker.md env -u NODE_OPTIONS node \
    "$TEST_ROOT/ai/skillshare/extensions/dotfiles-codex-agents/convert.js" \
    < "$agent_file" > "$codex_output"

  assert_true "Claude generation should use the model map" \
    grep -Fxq 'model: "opus"' "$claude_output"
  assert_true "Claude generation should use the mapped effort" \
    grep -Fxq 'effort: "medium"' "$claude_output"
  assert_true "Codex generation should use the model map" \
    grep -Fxq 'model = "gpt-5.6-sol"' "$codex_output"
  assert_true "Codex generation should use the mapped reasoning effort" \
    grep -Fxq 'model_reasoning_effort = "medium"' "$codex_output"
  assert_false "generated agents should not include a service tier" \
    grep -q 'service_tier' "$codex_output"
  finish_test "neutral agents generate provider-specific model settings"
}

test_repository_path_with_spaces() {
  local source_root=$TEST_ROOT
  local DOTFILES_ROOT="$HOME/repository with spaces"
  local XDG_CONFIG_HOME="$HOME/config with spaces"
  local installed_template_link link template_name
  export DOTFILES_ROOT XDG_CONFIG_HOME

  mkdir -p "$DOTFILES_ROOT/config/nvim" "$DOTFILES_ROOT/zsh" \
    "$DOTFILES_ROOT/ai/shared" \
    "$DOTFILES_ROOT/ai/skillshare/skills/example" \
    "$DOTFILES_ROOT/ai/skillshare/agents"
  printf 'repository skill\n' > "$DOTFILES_ROOT/ai/skillshare/skills/example/SKILL.md"
  printf 'instructions\n' > "$DOTFILES_ROOT/ai/shared/AGENTS.md"
  cp -R "$source_root/templates" "$DOTFILES_ROOT/"
  cp "$source_root/zsh/custom.example" "$DOTFILES_ROOT/zsh/custom.example"

  install_dotfiles
  installed_template_link=
  for link in "$HOME"/.*; do
    [[ -L "$link" ]] || continue
    case "$(readlink "$link")" in
      "$DOTFILES_ROOT/templates/"*) installed_template_link=$link; break ;;
    esac
  done
  [[ -n "$installed_template_link" ]] || \
    fail "repository paths containing spaces should work for regular templates"
  template_name=${installed_template_link##*/.}
  assert_eq "$DOTFILES_ROOT/templates/$template_name" \
    "$(readlink "$installed_template_link")" \
    "regular template links should preserve repository paths containing spaces"
  assert_eq "$DOTFILES_ROOT/config/nvim" "$(readlink "$XDG_CONFIG_HOME/nvim")" \
    "XDG paths containing spaces should be preserved"
  assert_eq "$DOTFILES_ROOT/ai/shared/AGENTS.md" "$(readlink "$HOME/.codex/AGENTS.md")" \
    "shared instruction links should preserve repository paths containing spaces"
  assert_false "repository skills should not be installed" \
    test -e "$HOME/.codex/skills/example"
  finish_test "repository and HOME paths containing spaces"
}

test_ai_config_directories_preserve_provider_data() {
  local DOTFILES_ROOT=$TEST_ROOT
  local name
  export DOTFILES_ROOT

  for name in claude codex grok; do
    mkdir -p "$HOME/.$name/skills/provider-owned"
    printf '%s config\n' "$name" > "$HOME/.$name/preserved"
    printf '%s skill\n' "$name" > "$HOME/.$name/skills/provider-owned/SKILL.md"
  done

  install_dotfiles
  for name in claude codex grok; do
    assert_false "$name config should remain a real directory" test -L "$HOME/.$name"
    assert_true "$name config should be preserved" test -f "$HOME/.$name/preserved"
    assert_true "$name provider skill should be preserved" \
      test -f "$HOME/.$name/skills/provider-owned/SKILL.md"
  done
  install_dotfiles
  assert_false "repeat install should create no backup" test -e "$DOTFILES_BACKUP_ROOT"
  finish_test "AI config directories and provider-local skills are preserved"
}

test_legacy_ai_symlink_is_reversed() {
  local DOTFILES_ROOT="$HOME/repository"
  export DOTFILES_ROOT

  mkdir -p "$DOTFILES_ROOT/ai/claude/skills/provider-owned"
  printf 'preserved\n' > "$DOTFILES_ROOT/ai/claude/settings.json"
  printf 'provider skill\n' > "$DOTFILES_ROOT/ai/claude/skills/provider-owned/SKILL.md"
  ln -s "$DOTFILES_ROOT/ai/claude" "$HOME/.claude"

  ensure_ai_directory claude

  assert_true "legacy Claude config should become a real directory" test -d "$HOME/.claude"
  assert_false "legacy Claude config symlink should be removed" test -L "$HOME/.claude"
  assert_true "legacy provider data should be preserved" test -f "$HOME/.claude/settings.json"
  assert_true "legacy provider skills should be preserved" \
    test -f "$HOME/.claude/skills/provider-owned/SKILL.md"
  assert_false "legacy repository directory should be moved" test -e "$DOTFILES_ROOT/ai/claude"
  finish_test "legacy AI config symlink is reversed without losing provider data"
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

new_home; test_platform_detection
new_home; test_package_dispatch_without_package_manager
new_home; test_mise_release_selection
new_home; test_linux_tarball_install
new_home; test_skillshare_release_selection
new_home; test_linux_flat_tarball_install
new_home; test_apt_missing_required_package_fails
new_home; test_idempotent_links
new_home; test_dangling_link
new_home; test_dotfile_install
new_home; test_skillshare_configuration
new_home; test_skillshare_existing_config_is_preserved
new_home; test_skillshare_empty_agents_source_reconciliation
new_home; test_skillshare_preflight_failures_do_not_mutate_state
new_home; test_skillshare_config_helper_fails_closed
new_home; test_skillshare_config_preflight_fails_before_mutation
new_home; test_skillshare_config_helper_narrows_legacy_cleanup
new_home; test_generated_agent_manifest_prunes_only_owned_outputs
new_home; test_generated_agent_manifest_waits_for_successful_sync
new_home; test_skillshare_real_cli_accepts_generated_config_when_available
new_home; test_shared_agents_are_provider_neutral
new_home; test_repository_path_with_spaces
new_home; test_ai_config_directories_preserve_provider_data
new_home; test_legacy_ai_symlink_is_reversed
new_home; test_private_directories_replace_files_safely
new_home; test_existing_git_checkout_is_idempotent
new_home; test_cleanup_known_legacy_state
new_home; test_cleanup_archives_ambiguous_state
new_home; test_cleanup_archives_uncertain_spf13_state
new_home; test_cleanup_preserves_vim_when_brew_query_fails
new_home; test_login_shell_reconciliation

printf '1..%d\n' "$TESTS_RUN"
