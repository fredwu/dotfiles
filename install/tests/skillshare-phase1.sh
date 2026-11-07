#!/bin/bash
# Test doubles are called by the sourced installer functions.
# shellcheck disable=SC1091,SC2329
set -euo pipefail

root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/skillshare dependency test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
# shellcheck source=../lib/common.sh
source "$root/install/lib/common.sh"
# shellcheck source=../lib/skillshare-deps.sh
source "$root/install/lib/skillshare-deps.sh"
# shellcheck source=../lib/packages.sh
source "$root/install/lib/packages.sh"
mkdir -p "$fixture/home"

# This is the same private, locked install used by bootstrap; no global modules.
(
  export HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/home/config" XDG_STATE_HOME="$fixture/home/state"
  export XDG_CACHE_HOME="$fixture/home/cache" XDG_DATA_HOME="$fixture/home/data"
  unset CLAUDE_CONFIG_DIR CODEX_HOME OPENCODE_CONFIG_DIR PI_CODING_AGENT_DIR GROK_HOME NODE_OPTIONS
  ensure_skillshare_node_dependencies "$root" "$fixture/dependencies" >/dev/null
  npm() { printf 'unexpected reinstall\n' > "$fixture/reinstalled"; command npm "$@"; }
  ensure_skillshare_node_dependencies "$root" "$fixture/dependencies" >/dev/null
  [[ ! -e "$fixture/reinstalled" ]]
  env -u NODE_OPTIONS node - "$fixture/dependencies" <<'JS'
const path = require('node:path');
const assert = require('node:assert/strict');
const yaml = require(path.join(process.argv[2], 'node_modules/yaml'));
assert.equal(yaml.parse('value: true').value, true);
JS
)

# Simulate each supported Linux package manager without package installation.
(
  have() { return 1; }
  apt_package_exists() { return 0; }
  as_root() { printf '%s\n' "$*" >> "$fixture/packages"; }
  install_apt_packages
  install_dnf_packages
  install_pacman_packages
  [[ $(rg -c '(^| )zsh( |$)' "$fixture/packages") == 3 ]]
  [[ " ${HOMEBREW_FORMULAE[*]} " == *' node '* && " ${HOMEBREW_FORMULAE[*]} " == *' skillshare '* ]]
)

# Missing Node or npm must stop before dependency/configuration directories exist.
(
  command() {
    if [[ "$*" == "-v $missing" ]]; then return 1; fi
    builtin command "$@"
  }
  for missing in node npm; do
    if ensure_skillshare_node_dependencies "$root" "$fixture/must-not-exist" > /dev/null 2>&1; then exit 1; fi
    [[ ! -e "$fixture/must-not-exist" ]]
  done
)

SKILLSHARE_TEST_DEPS="$fixture/dependencies" env -u NODE_OPTIONS node "$root/install/tests/skillshare-phase1.test.js"
printf 'phase 1 dependency bootstrap and simulated Linux provisioning checks passed\n'
