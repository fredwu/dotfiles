'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { isDeepStrictEqual: equal } = require('node:util');
const runtime = require('./skillshare-runtime');

const namePattern = /^[a-zA-Z0-9][a-zA-Z0-9._-]*$/;
const commitPattern = /^[a-f0-9]{40}$/;
const vendorPattern = /^openai-(bundled|curated|primary)(?:-|$)/;

function identity(selection) {
  const parts = (selection.nativeId || '').split('@');
  if (!namePattern.test(selection.name || '') || parts.length !== 2 || parts.some(part => !namePattern.test(part))) {
    throw new Error('A logical name and exact native plugin identity are required');
  }
  return { plugin: parts[0], marketplace: parts[1] };
}

function portableSource(source) {
  try {
    const url = new URL(source);
    return url.protocol === 'https:' && url.hostname && !url.username && !url.password && !url.search && !url.hash && !/\s/.test(source);
  } catch { return false; }
}

function json(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return undefined; throw new Error('Cannot read native plugin provenance'); }
}

// Inspect only installed provenance. A current marketplace HEAD or version label is not an installed ref.
function inspectPlugin(selection, options) {
  const { plugin, marketplace } = identity(selection);
  runtime.nativeEnv(options);
  const local = reason => ({ name: selection.name, target: selection.target, nativeId: selection.nativeId, classification: 'local', reason });
  if (vendorPattern.test(marketplace)) return local('Vendor-managed plugin');
  if (!['claude', 'codex'].includes(selection.target)) return local('Native provenance adapter is not qualified for this target');
  const directory = path.join(options.home, `.${selection.target}/plugins`);
  if (selection.target === 'codex') {
    return local('Codex marketplace revisions do not prove the installed plugin ref; exact installed provenance is unavailable');
  }
  const installed = json(path.join(directory, 'installed_plugins.json'));
  if (!installed) return local('Native installed-plugin provenance is missing');
  if (installed.version !== 2 || !installed.plugins || typeof installed.plugins !== 'object') return local('Unsupported installed-plugin provenance schema');
  const records = installed.plugins[selection.nativeId];
  const users = Array.isArray(records) ? records.filter(record => record.scope === 'user') : [];
  if (users.length !== 1) return local('Exactly one user-scope installed record is required');
  const record = users[0];
  if (record.auto) return local('Native automatic dependency is not a deliberate shared selection');
  const enabled = json(path.join(options.home, '.claude/settings.json'))?.enabledPlugins?.[selection.nativeId];
  if (enabled !== true) return local(enabled === false
    ? 'Native plugin is disabled; preserve it locally because add does not preserve disabled state'
    : 'Native enabled state is unknown; preserve the local selection');
  if (!commitPattern.test(record.gitCommitSha || '')) return local('Native installed record has no exact commit');
  if (!record.installPath || !fs.existsSync(record.installPath)) return local('Native installed plugin content is missing');
  const market = json(path.join(directory, 'known_marketplaces.json'))?.[marketplace];
  const origin = market?.source;
  const source = origin?.source === 'github' && /^[\w.-]+\/[\w.-]+$/.test(origin.repo || '')
    ? `https://github.com/${origin.repo}.git` : origin?.source === 'git' ? origin.url : undefined;
  if (!portableSource(source)) return local('Native marketplace has no portable credential-free Git source');
  if (!path.isAbsolute(market.installLocation || '')) return local('Native marketplace checkout is unavailable');
  const ref = record.gitCommitSha;
  const catalog = json(path.join(market.installLocation, '.claude-plugin/marketplace.json'));
  if (catalog) {
    const entries = Array.isArray(catalog.plugins) ? catalog.plugins.filter(entry => entry.name === plugin) : [];
    const relative = entries[0]?.source;
    if (entries.length !== 1 || typeof relative !== 'string' || !relative.startsWith('./') || relative.split('/').includes('..')) {
      return local('Native marketplace does not prove a unique in-repository plugin source');
    }
  } else {
    return local('Native marketplace catalog is unavailable');
  }
  return { name: selection.name, target: selection.target, nativeId: selection.nativeId,
    classification: 'portable', source, sourceRef: ref, plugin };
}

function validateRecipe(recipe) {
  const { plugin, marketplace } = identity(recipe);
  if (recipe.classification !== 'portable' || vendorPattern.test(marketplace) ||
      !['claude', 'codex'].includes(recipe.target) || !portableSource(recipe.source) ||
      !commitPattern.test(recipe.sourceRef || '') || recipe.plugin !== plugin) throw new Error('An exact portable plugin recipe is required');
}

function nativeJson(args, options) {
  let value;
  try { value = JSON.parse(runtime.runNative(args, options).stdout); }
  catch (error) { throw new Error('Native plugin operation failed; inspect private native diagnostics', { cause: error }); }
  return value;
}

function adoptPlugin(selection, options) {
  const recipe = inspectPlugin(selection, options);
  if (recipe.classification === 'local') return { action: 'local', recipe };
  if (selection.source && !equal(recipe, selection)) throw new Error('Installed plugin does not match the pinned recipe');
  const args = ['plugin', 'import', recipe.nativeId, '--name', recipe.name, '--from', recipe.target, '--json', '-g'];
  if (options.dryRun) return { action: 'adopt', recipe, args, dryRun: true };
  runtime.requireSupportedSkillshare(options);
  const result = nativeJson(args, options);
  return { action: 'adopt', recipe, result };
}

function rebuildPlugin(recipe, options) {
  validateRecipe(recipe);
  const args = ['plugin', 'add', recipe.source, '--source-ref', recipe.sourceRef,
    '--plugin', recipe.plugin, '--name', recipe.name, '--target', recipe.target, '--json', '-g'];
  if (options.dryRun) return { action: 'add', recipe, args, dryRun: true };
  runtime.requireSupportedSkillshare(options);
  const preview = nativeJson([...args, '--dry-run'], options);
  if (preview.blocked || !preview.revision || !Array.isArray(preview.changes) || preview.changes.length !== 1 ||
      !preview.changes.every(change => change.target === recipe.target && change.name === recipe.name &&
        ['install', 'noop'].includes(change.action) && change.binding?.sourceRef === recipe.sourceRef &&
        change.binding?.commit === recipe.sourceRef && !(change.action === 'install' && change.binding.sync === false))) {
    throw new Error('Native add cannot prove a clean pinned installation; adopt existing plugins explicitly');
  }
  const result = nativeJson([...args, '--revision', preview.revision], options);
  return { action: 'add', recipe, result };
}

function loadPlugins(file) {
  const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (manifest.version !== 1 || !Array.isArray(manifest.plugins)) throw new Error('Unsupported portable plugin manifest');
  const identities = new Set();
  for (const recipe of manifest.plugins) {
    identity(recipe);
    const key = `${recipe.target}/${recipe.name}`;
    if (identities.has(key)) throw new Error('Duplicate portable plugin selection');
    identities.add(key);
    if (recipe.classification === 'portable') validateRecipe(recipe);
    else if (recipe.classification !== 'local' || typeof recipe.reason !== 'string' || !recipe.reason) throw new Error('Explicit local plugin classification is required');
  }
  return manifest;
}

module.exports = { inspectPlugin, adoptPlugin, rebuildPlugin, loadPlugins };
