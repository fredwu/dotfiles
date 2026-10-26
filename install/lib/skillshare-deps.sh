#!/bin/bash

# Returns the private dependency directory. Configuration writes happen elsewhere.
ensure_skillshare_node_dependencies() {
  local root=${1:?repository root required}
  local dependency_dir=${2:-$root/.local/skillshare-node}
  local manifest="$root/install/skillshare-deps"

  command -v node >/dev/null 2>&1 || { printf 'Node.js is required\n' >&2; return 1; }
  command -v npm >/dev/null 2>&1 || { printf 'npm is required\n' >&2; return 1; }
  env -u NODE_OPTIONS node -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || {
    printf 'Node.js 18 or newer is required\n' >&2; return 1;
  }
  [[ -f "$manifest/package.json" && -f "$manifest/package-lock.json" ]] || return 1
  if [[ ! -f "$dependency_dir/package-lock.json" ]] || \
    ! cmp -s "$manifest/package.json" "$dependency_dir/package.json" || \
    ! cmp -s "$manifest/package-lock.json" "$dependency_dir/package-lock.json" || \
    ! env -u NODE_OPTIONS node - "$dependency_dir" <<'JS'
const path = require('node:path');
try {
  const dir = process.argv[2];
  const wanted = require(path.join(dir, 'package.json')).dependencies.yaml;
  const installed = require(path.join(dir, 'node_modules/yaml/package.json')).version;
  if (wanted !== installed) process.exit(1);
  require(path.join(dir, 'node_modules/yaml'));
} catch { process.exit(1); }
JS
  then
    mkdir -p "$dependency_dir" || return 1
    cp "$manifest/package.json" "$manifest/package-lock.json" "$dependency_dir/" || return 1
    (cd -- "$dependency_dir" && env -u NODE_OPTIONS npm ci --ignore-scripts --no-audit --no-fund) >&2 || return 1
  fi
  printf '%s\n' "$dependency_dir"
}
