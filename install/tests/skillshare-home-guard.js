'use strict';

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { isDeepStrictEqual: equal } = require('node:util');

const digest = content => crypto.createHash('sha256').update(content).digest('hex');

function snapshot(home = process.env.SKILLSHARE_TEST_REAL_HOME || os.homedir()) {
  const result = {};
  function visit(file) {
    let info;
    try { info = fs.lstatSync(file); }
    catch (error) { if (error.code !== 'ENOENT') throw error; result[file] = { absent: true }; return; }
    const entry = { mode: info.mode, mtime: info.mtimeMs };
    if (info.isSymbolicLink()) entry.link = fs.readlinkSync(file);
    else if (info.isFile()) {
      const content = fs.readFileSync(file);
      entry.sha = digest(content);
      if ([path.join(home, '.claude.json'), path.join(home, '.claude-gamma/.claude.json')].includes(file)) {
        const value = JSON.parse(content);
        entry.topLevelShas = Object.fromEntries(Object.entries(value).map(([key, item]) => [key, digest(JSON.stringify(item))]));
        if (file !== path.join(home, '.claude.json')) { result[file] = entry; return; }
        const metadataKeys = ['pluginUsage', 'cachedGrowthBookFeaturesAt'];
        entry.metadataSha = digest(JSON.stringify(metadataKeys.map(key => value[key] ?? null)));
        for (const key of metadataKeys) delete value[key];
        entry.stableSha = digest(JSON.stringify(value));
      }
    } else if (info.isDirectory()) {
      entry.directory = true;
      for (const name of fs.readdirSync(file).sort()) visit(path.join(file, name));
    }
    result[file] = entry;
  }
  const files = ['.claude.json', '.config/skillshare/config.yaml', '.config/skillshare/mcp.generated.yaml',
    'Library/Application Support/Claude/claude_desktop_config.json', '.config/Claude/claude_desktop_config.json',
    'AppData/Roaming/Claude/claude_desktop_config.json',
    '.local/state/dotfiles/skillshare-applied.json',
    '.local/state/skillshare/mcp/state.json', '.config/opencode/opencode.json', '.config/opencode/opencode.jsonc',
    '.config/opencode/agents', '.pi/agent/settings.json', '.pi/agent/mcp.json', '.pi/agent/agents', '.omp/agent/mcp.json'];
  for (const client of ['.claude', '.claude-gamma', '.codex', '.grok']) {
    files.push(`${client}/config.toml`, `${client}/settings.json`, `${client}/agents`,
      `${client}/plugins/installed_plugins.json`, `${client}/plugins/known_marketplaces.json`);
  }
  files.push('.claude-gamma/.claude.json');
  for (const file of files) visit(path.join(home, file));
  if (!arguments.length && path.isAbsolute(process.env.APPDATA || '')) {
    visit(path.join(process.env.APPDATA, 'Claude/claude_desktop_config.json'));
  }
  return result;
}

function assertUnchanged(before, after) {
  const expected = { ...before };
  const metadataUpdates = [];
  for (const [file, actual] of Object.entries(after)) {
    const prior = before[file];
    if (prior?.stableSha && prior.sha !== actual.sha && prior.stableSha === actual.stableSha && prior.metadataSha !== actual.metadataSha && prior.mode === actual.mode) {
      expected[file] = actual;
      metadataUpdates.push(file);
    }
  }
  const changedPaths = [...new Set([...Object.keys(expected), ...Object.keys(after)])].filter(file => !equal(after[file], expected[file]));
  const details = changedPaths.map(file => {
    const prior = before[file]?.topLevelShas || {};
    const actual = after[file]?.topLevelShas || {};
    const keys = [...new Set([...Object.keys(prior), ...Object.keys(actual)])].filter(key => prior[key] !== actual[key]);
    return `${file}${keys.length ? ` (changed keys: ${keys.join(', ')})` : ''}`;
  });
  assert(!changedPaths.length, `Real-home files changed outside observed Claude runtime metadata: ${details.join('; ')}`);
  if (metadataUpdates.length) process.stdout.write('Observed concurrent Claude runtime metadata update; other real-home content and file metadata are unchanged.\n');
  return metadataUpdates;
}

module.exports = { snapshot, assertUnchanged };
