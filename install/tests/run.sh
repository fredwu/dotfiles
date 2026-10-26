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
export SKILLSHARE_TEST_REAL_HOME="${SKILLSHARE_TEST_REAL_HOME:-$HOME}"
TEST_SUITE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles suite.XXXXXX")
trap 'rm -rf "$TEST_SUITE_ROOT"' EXIT

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
  HOME=$(mktemp -d "$TEST_SUITE_ROOT/home.XXXXXX")
  export HOME
  export DOTFILES_ROOT="$TEST_ROOT"
  export XDG_CONFIG_HOME="$HOME/config" XDG_STATE_HOME="$HOME/state"
  export XDG_CACHE_HOME="$HOME/cache" XDG_DATA_HOME="$HOME/data"
  export SKILLSHARE_CONFIG="$XDG_CONFIG_HOME/skillshare/config.yaml"
  unset CLAUDE_CONFIG_DIR CODEX_HOME OPENCODE_CONFIG_DIR PI_CODING_AGENT_DIR GROK_HOME NODE_OPTIONS
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
  assert_eq 0.26.4 "$SKILLSHARE_VERSION" \
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

make_skillshare_bootstrap_fixture() {
  export DOTFILES_ROOT="$HOME/repository with spaces"
  export TEST_DEPS_DIR="$TEST_SUITE_ROOT/dependencies"
  mkdir -p "$DOTFILES_ROOT/install/lib" "$DOTFILES_ROOT/install/skillshare-deps" \
    "$DOTFILES_ROOT/scripts" "$HOME/bin"
  cp "$TEST_ROOT/install/lib/skillshare.sh" "$TEST_ROOT/install/lib/skillshare-deps.sh" \
    "$TEST_ROOT/install/lib/common.sh" "$DOTFILES_ROOT/install/lib/"
  cp "$TEST_ROOT/install/skillshare-deps/"package*.json "$DOTFILES_ROOT/install/skillshare-deps/"
  cat > "$HOME/bin/skillshare" <<'SH'
#!/bin/bash
printf 'skillshare %s\n' "$*" >> "$HOME/invocations"
[[ "$*" == --version ]] || exit 91
printf '%s\n' "${FIXTURE_VERSION:-skillshare v0.26.4}"
exit "${FIXTURE_VERSION_EXIT:-0}"
SH
  cat > "$HOME/bin/npm" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'npm %s\n' "$*" >> "$HOME/invocations"
[[ "$*" == 'ci --ignore-scripts --no-audit --no-fund' ]] || exit 92
[[ "$PWD" -ef "$DOTFILES_ROOT/.local/skillshare-node" ]] || exit 93
[[ -z "${NODE_OPTIONS+x}" ]] || exit 94
[[ "${FIXTURE_NPM_FAIL:-0}" == 0 ]] || exit 42
cp -R "$TEST_DEPS_DIR/node_modules" ./
SH
  cat > "$DOTFILES_ROOT/scripts/skillshare-sync" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'bootstrap %s\n' "$*" >> "$HOME/invocations"
[[ "$#" == 1 && "$1" == --bootstrap ]] || exit 95
for key in CLAUDE_CONFIG_DIR CODEX_HOME OPENCODE_CONFIG_DIR PI_CODING_AGENT_DIR GROK_HOME NODE_OPTIONS; do
  [[ -z "${!key+x}" ]] || exit 96
done
node - "$DOTFILES_ROOT" <<'JS'
const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.argv[2];
const deps = path.join(root, '.local/skillshare-node');
const wanted = require(path.join(root, 'install/skillshare-deps/package.json')).dependencies.yaml;
assert.equal(require(path.join(deps, 'node_modules/yaml/package.json')).version, wanted);
assert.equal(require(path.join(deps, 'node_modules/yaml')).parse('ready: true').ready, true);
JS
exit "${FIXTURE_BOOTSTRAP_EXIT:-0}"
SH
  chmod +x "$HOME/bin/skillshare" "$HOME/bin/npm" "$DOTFILES_ROOT/scripts/skillshare-sync"
}

run_skillshare_bootstrap_fixture() {
  PATH="$HOME/bin:$PATH" /bin/bash -c '
    set -euo pipefail
    source "$DOTFILES_ROOT/install/lib/common.sh"
    source "$DOTFILES_ROOT/install/lib/skillshare.sh"
    configure_skillshare
  '
}

test_skillshare_bootstrap_dependencies_and_invocation() {
  make_skillshare_bootstrap_fixture
  (
    export CLAUDE_CONFIG_DIR="$HOME/gamma" CODEX_HOME="$HOME/codex-override"
    export OPENCODE_CONFIG_DIR="$HOME/opencode-override" PI_CODING_AGENT_DIR="$HOME/pi-override" GROK_HOME="$HOME/grok-override"
    export NODE_OPTIONS="--require=$HOME/must-not-load.js"
    run_skillshare_bootstrap_fixture
    run_skillshare_bootstrap_fixture
    assert_eq "$HOME/gamma" "$CLAUDE_CONFIG_DIR" "bootstrap should preserve the caller's Claude override"
    assert_eq "$HOME/codex-override" "$CODEX_HOME" "bootstrap should preserve the caller's Codex override"
    assert_eq "$HOME/opencode-override" "$OPENCODE_CONFIG_DIR" "bootstrap should preserve the caller's OpenCode override"
    assert_eq "$HOME/pi-override" "$PI_CODING_AGENT_DIR" "bootstrap should preserve the caller's Pi override"
    assert_eq "$HOME/grok-override" "$GROK_HOME" "bootstrap should preserve the caller's Grok override"
    assert_eq "--require=$HOME/must-not-load.js" "$NODE_OPTIONS" "bootstrap should preserve the caller's Node options"
  )
  assert_eq $'skillshare --version\nnpm ci --ignore-scripts --no-audit --no-fund\nbootstrap --bootstrap\nskillshare --version\nbootstrap --bootstrap' \
    "$(cat "$HOME/invocations")" "bootstrap should prepare dependencies once and invoke only the managed command"
  assert_false "shell integration should not create an empty agent source" test -e "$XDG_CONFIG_HOME/skillshare/agents"
  assert_false "shell integration should not create extension-install links" test -e "$XDG_CONFIG_HOME/skillshare/extensions"
  assert_false "shell integration should not create a generated-agent manifest" test -e "$XDG_STATE_HOME/dotfiles/skillshare-agents.manifest"
  finish_test "Skillshare bootstrap prepares locked dependencies before the managed command and isolates overrides"
}

test_skillshare_bootstrap_dependency_failure() {
  make_skillshare_bootstrap_fixture
  if FIXTURE_NPM_FAIL=1 run_skillshare_bootstrap_fixture > "$HOME/output" 2>&1; then
    fail "dependency bootstrap failure should stop installer setup"
  fi
  assert_eq $'skillshare --version\nnpm ci --ignore-scripts --no-audit --no-fund' \
    "$(cat "$HOME/invocations")" "dependency failure should stop before the managed command"
  assert_true "dependency failure should report its cause" grep -Fq 'Skillshare dependency bootstrap failed' "$HOME/output"
  assert_false "dependency failure should not write config" test -e "$XDG_CONFIG_HOME"
  assert_false "dependency failure should not write state" test -e "$XDG_STATE_HOME"
  finish_test "Skillshare dependency failure stops before configuration and synchronization"
}

test_skillshare_bootstrap_command_failure() {
  make_skillshare_bootstrap_fixture
  if FIXTURE_BOOTSTRAP_EXIT=23 run_skillshare_bootstrap_fixture > "$HOME/output" 2>&1; then
    fail "managed bootstrap failure should stop installer setup"
  fi
  assert_eq $'skillshare --version\nnpm ci --ignore-scripts --no-audit --no-fund\nbootstrap --bootstrap' \
    "$(cat "$HOME/invocations")" "managed bootstrap failure should not fall back to native synchronization"
  assert_true "managed bootstrap failure should report its cause" grep -Fq 'Managed Skillshare bootstrap failed' "$HOME/output"
  finish_test "Skillshare managed bootstrap failure propagates without a native sync fallback"
}

test_skillshare_bootstrap_preflight() {
  local version
  make_skillshare_bootstrap_fixture
  for version in 'skillshare v0.26.3' 'not a Skillshare version'; do
    if FIXTURE_VERSION="$version" run_skillshare_bootstrap_fixture > "$HOME/output" 2>&1; then
      fail "unsupported or unrecognized Skillshare should fail preflight"
    fi
  done
  if FIXTURE_VERSION_EXIT=7 run_skillshare_bootstrap_fixture > "$HOME/output" 2>&1; then
    fail "a failed version command should fail preflight"
  fi
  chmod -x "$DOTFILES_ROOT/scripts/skillshare-sync"
  if run_skillshare_bootstrap_fixture > "$HOME/output" 2>&1; then
    fail "a nonexecutable managed command should fail preflight"
  fi
  assert_true "missing executable should report the managed command" grep -Fq 'missing or not executable' "$HOME/output"
  rm "$DOTFILES_ROOT/scripts/skillshare-sync"
  if run_skillshare_bootstrap_fixture > "$HOME/output" 2>&1; then
    fail "a missing managed command should fail preflight"
  fi
  assert_false "failed preflight should not prepare dependencies" test -e "$DOTFILES_ROOT/.local"
  assert_false "failed preflight should not write configuration" test -e "$XDG_CONFIG_HOME"
  assert_false "failed preflight should not write state" test -e "$XDG_STATE_HOME"
  assert_false "failed preflight should not call npm or bootstrap" grep -Eq '^(npm|bootstrap) ' "$HOME/invocations"
  finish_test "Skillshare version and managed-command checks fail before writes"
}

test_skillshare_bootstrap_missing_tools() {
  local tool
  make_skillshare_bootstrap_fixture
  ln -s "$(type -P node)" "$HOME/bin/node"
  for tool in skillshare node npm; do
    mv "$HOME/bin/$tool" "$HOME/$tool.saved"
    if PATH="$HOME/bin" /bin/bash -c '
      set -euo pipefail
      source "$DOTFILES_ROOT/install/lib/common.sh"
      source "$DOTFILES_ROOT/install/lib/skillshare.sh"
      configure_skillshare
    ' > "$HOME/output" 2>&1; then
      fail "missing $tool should fail preflight"
    fi
    assert_true "missing $tool should report the required command" \
      grep -Fq "required command not found: $tool" "$HOME/output"
    mv "$HOME/$tool.saved" "$HOME/bin/$tool"
  done
  assert_false "missing tooling should not prepare dependencies" test -e "$DOTFILES_ROOT/.local"
  assert_false "missing tooling should not write configuration" test -e "$XDG_CONFIG_HOME"
  finish_test "Skillshare requires its CLI, Node, and npm before preparation"
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

  env -u NODE_OPTIONS node - "$TEST_ROOT/ai/skillshare/agent-models.json" \
    "$claude_output" "$codex_output" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const [mapPath, claudePath, codexPath] = process.argv.slice(2);
const expected = JSON.parse(fs.readFileSync(mapPath, "utf8")).fastworker;
for (const [provider, outputPath, separator] of [
  ["claude", claudePath, ": "],
  ["codex", codexPath, " = "],
]) {
  const lines = fs.readFileSync(outputPath, "utf8").split("\n");
  for (const [field, value] of Object.entries(expected[provider])) {
    assert.ok(
      lines.includes(`${field}${separator}${JSON.stringify(value)}`),
      `${provider} generation should use the mapped ${field}`,
    );
  }
}
NODE
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

# All native CLI checks use a disposable home and explicit config/state roots.
new_home
require_command skillshare
require_command node
require_command npm
require_supported_skillshare
# shellcheck source=../lib/skillshare-deps.sh
source "$TEST_ROOT/install/lib/skillshare-deps.sh"
ensure_skillshare_node_dependencies "$TEST_ROOT" "$TEST_SUITE_ROOT/dependencies" >/dev/null
rm -rf "$HOME"

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
new_home; test_skillshare_bootstrap_dependencies_and_invocation
new_home; test_skillshare_bootstrap_dependency_failure
new_home; test_skillshare_bootstrap_command_failure
new_home; test_skillshare_bootstrap_preflight
new_home; test_skillshare_bootstrap_missing_tools
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

new_home
suite_status=0
bash "$TEST_ROOT/install/tests/skillshare-phase1.sh" || suite_status=1
for suite in home-guard runtime sync plugin; do
  suite_files=("$TEST_ROOT/install/tests/skillshare-$suite"*.test.js)
  if [[ ! -f "${suite_files[0]}" ]]; then
    printf 'not ok - required Skillshare %s tests are missing\n' "$suite" >&2
    suite_status=1
    continue
  fi
  SKILLSHARE_TEST_DEPS="$TEST_SUITE_ROOT/dependencies" node --test "${suite_files[@]}" || suite_status=1
done
exit "$suite_status"
