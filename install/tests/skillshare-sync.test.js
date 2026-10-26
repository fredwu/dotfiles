'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const config = require('../lib/skillshare-config');
const sync = require('../lib/skillshare-sync');

const repository = path.resolve(__dirname, '../..');
const depsDir = process.env.SKILLSHARE_TEST_DEPS || path.join(repository, '.local/skillshare-node');
const roots = [];
const parentEnvironment = { ...process.env };
const realHomeGuard = require('./skillshare-home-guard');
const realHomeState = realHomeGuard.snapshot;

const realBefore = realHomeState();
test.after(() => {
  try {
    assert(require('node:util').isDeepStrictEqual({ ...process.env }, parentEnvironment), 'parent environment must remain unchanged');
    realHomeGuard.assertUnchanged(realBefore, realHomeState());
  } finally { for (const root of roots) fs.rmSync(root, { recursive: true, force: true }); }
});
function write(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, typeof value === 'string' ? value : `${JSON.stringify(value, null, 2)}\n`);
}

function fixture(sharedRoot) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare lifecycle '));
  roots.push(temporary);
  const root = sharedRoot || path.join(temporary, 'repository');
  const home = path.join(temporary, 'home');
  fs.mkdirSync(home);
  if (!sharedRoot) {
    for (const relative of ['ai/skillshare/agents', 'ai/skillshare/extensions', 'install/skillshare-deps']) {
      fs.cpSync(path.join(repository, relative), path.join(root, relative), { recursive: true });
    }
    fs.copyFileSync(path.join(repository, 'ai/skillshare/agent-models.json'), path.join(root, 'ai/skillshare/agent-models.json'));
    write(path.join(root, 'ai/skillshare/skills/example/SKILL.md'), '---\nname: example\ndescription: Use when testing local skill distribution.\n---\nRead the example.\n');
  }
  const options = config.paths({ root, home, depsDir, env: { ...process.env, APPDATA: path.join(home, 'AppData/Roaming') } });
  const target = (name, provider = name) => ({
    ...(name === 'claude-gamma' ? { agent: 'claude', config_dir: path.join(home, '.claude-gamma') } : {}),
    skills: { path: path.join(home, `.${name}/skills`), mode: 'merge' },
    agents: { path: path.join(home, `.${name}/agents`), mode: 'copy', extension: path.join(root, `ai/skillshare/extensions/dotfiles-${provider}-agents`) },
  });
  const intent = { version: 1, config: {
    sources: { skills: path.join(root, 'ai/skillshare/skills'), agents: path.join(root, 'ai/skillshare/agents'), mcp: options.mcpFile },
    mode: 'merge', targets: { claude: target('claude'), codex: target('codex'), 'claude-gamma': target('claude-gamma', 'claude') },
    mcp: { targets: ['claude', 'codex', 'opencode', 'grok', 'claude-desktop'] },
  }, executables: { node: process.execPath }, external: [{ name: 'shared', kind: 'mcp', from: 'claude', path: path.join(home, '.claude.json') }] };
  // Separate intent files let two homes use the same canonical MCP definitions.
  options.intentFile = path.join(home, 'intent.json');
  write(options.intentFile, intent);
  if (!sharedRoot) write(path.join(root, 'ai/skillshare/mcp.json'), { version: 1, servers: {
    shared: { transport: 'stdio', command: { executable: 'node' }, args: ['server-v1'] },
    other: { transport: 'stdio', command: { executable: 'node' }, args: ['other-v1'] },
  } });
  write(path.join(home, '.claude.json'), { keep: true, mcpServers: { shared: { type: 'stdio', command: process.execPath, args: ['server-v1'] } } });
  return options;
}

test('three-way decisions never recapture a tracked-only change', () => {
  assert.equal(sync.decision(undefined, 'v1', undefined), 'pending');
  assert.equal(sync.decision(undefined, 'v1', 'v1'), 'ready');
  assert.equal(sync.decision(undefined, 'v1', 'v2'), 'adoption-required');
  assert.equal(sync.decision('v1', 'v1', 'v2'), 'capture');
  assert.equal(sync.decision('v1', 'v2', 'v1'), 'hold');
  assert.equal(sync.decision('v1', 'v2', 'v2'), 'ready');
  assert.equal(sync.decision('v1', 'v2', 'v3'), 'conflict');
});

test('native JSON error trailers do not discard a valid plan', () => {
  assert.deepEqual(sync.jsonOutput('{"changes":[{"message":"[literal]"}]}\nError'), { changes: [{ message: '[literal]' }] });
  assert.deepEqual(sync.jsonOutput('[{"x":1}]\n'), [{ x: 1 }]);
});

test('real CLI captures a local vendor update and another home holds its baseline', () => {
  const first = fixture();
  config.requireSupportedSkillshare(first);
  sync.synchronize({ ...first, bootstrap: true });
  const second = fixture(first.root);
  sync.synchronize({ ...second, bootstrap: true });
  const primary = path.join(first.home, '.claude.json');
  const client = JSON.parse(fs.readFileSync(primary));
  client.mcpServers.shared.args = ['server-v2'];
  write(primary, client);
  const dryBefore = fs.readFileSync(path.join(first.root, 'ai/skillshare/mcp.json'), 'utf8');
  const preview = sync.synchronize({ ...first, dryRun: true });
  assert.equal(preview.external[0].action, 'capture');
  assert.equal(fs.readFileSync(path.join(first.root, 'ai/skillshare/mcp.json'), 'utf8'), dryBefore);
  sync.synchronize(first);
  const canonicalFile = path.join(first.root, 'ai/skillshare/mcp.json');
  const canonical = JSON.parse(fs.readFileSync(canonicalFile));
  assert.deepEqual(canonical.servers.shared.args, ['server-v2']);
  assert(!fs.readFileSync(canonicalFile, 'utf8').includes(first.home));
  const before = fs.readFileSync(second.mcpFile, 'utf8');
  const secondClient = fs.readFileSync(path.join(second.home, '.claude.json'), 'utf8');
  const held = sync.synchronize(second);
  assert.equal(held.external[0].action, 'hold');
  assert.equal(fs.readFileSync(second.mcpFile, 'utf8'), before);
  assert.equal(fs.readFileSync(path.join(second.home, '.claude.json'), 'utf8'), secondClient);
  assert.deepEqual(JSON.parse(fs.readFileSync(canonicalFile)).servers.shared.args, ['server-v2']);
  assert(sync.synchronize(first).agents.changed.length === 0);
});

test('legacy node cleanup uses native ownership before changing the MCP source', () => {
  const options = fixture();
  const intent = config.loadIntent(options);
  const yaml = config.parser(options);
  const legacy = { sources: { skills: intent.config.sources.skills, agents: path.join(options.home, 'empty-agents') },
    targets: { claude: { skills: { path: path.join(options.home, '.claude/skills') } } },
    mcp: { targets: intent.config.mcp.targets, servers: {
      shared: { command: process.execPath, args: ['server-v1'], options: { claude: { local_setting: 'keep' } } },
      node_repl: { command: process.execPath, args: ['node-old'] },
      personal: { command: process.execPath, args: ['personal-v1'], targets: ['claude'], options: { claude: { personal_setting: 'keep' } } },
    } }, plugins: { packages: { browser: { bindings: { codex: { id: 'browser@openai-bundled', version: 'old' } } } } } };
  write(options.configFile, yaml.stringify(legacy));
  fs.mkdirSync(legacy.sources.agents, { recursive: true });
  sync.syncMcp(options);
  const codexFile = path.join(options.home, '.codex/config.toml');
  write(codexFile, fs.readFileSync(codexFile, 'utf8').replace('node-old', 'node-current'));
  const originalCodexNode = fs.readFileSync(codexFile, 'utf8').match(/\[mcp_servers\.node_repl\][\s\S]*?(?=\n\[|$)/)?.[0];
  sync.synchronize({ ...options, bootstrap: true });
  const native = JSON.parse(fs.readFileSync(path.join(options.home, '.claude.json')));
  assert.equal(native.mcpServers.node_repl, undefined);
  assert.equal(native.mcpServers.personal.personal_setting, 'keep');
  assert.equal(native.mcpServers.shared.local_setting, 'keep');
  assert.equal(sync.yamlValue(options.mcpFile, options).servers.personal.targets[0], 'claude');
  assert(fs.readFileSync(codexFile, 'utf8').includes('node-current'));
  if (originalCodexNode) assert(fs.readFileSync(codexFile, 'utf8').includes(originalCodexNode));
  assert.equal(sync.yamlValue(options.configFile, options).mcp.servers, undefined);
  assert.equal(sync.yamlValue(options.configFile, options).plugins.packages.browser, undefined);
  for (const relative of ['.claude.json', '.config/opencode/opencode.json', '.grok/config.toml']) {
    assert(!fs.readFileSync(path.join(options.home, relative), 'utf8').includes('node_repl'), relative);
  }
  if (process.platform === 'darwin' || process.platform === 'win32') {
    const desktop = process.platform === 'darwin'
      ? path.join(options.home, 'Library/Application Support/Claude/claude_desktop_config.json')
      : path.join(options.env.APPDATA, 'Claude/claude_desktop_config.json');
    assert(!fs.readFileSync(desktop, 'utf8').includes('node_repl'));
  } else {
    for (const relative of ['Library/Application Support/Claude/claude_desktop_config.json',
      '.config/Claude/claude_desktop_config.json', 'AppData/Roaming/Claude/claude_desktop_config.json']) {
      assert(!fs.existsSync(path.join(options.home, relative)));
    }
  }
  const ledger = JSON.parse(fs.readFileSync(path.join(path.dirname(options.stateDir), 'skillshare/mcp/state.json')));
  const owners = JSON.stringify(ledger);
  assert(owners.includes(options.configFile));
  assert(!owners.includes(options.mcpFile));
  assert(!fs.readFileSync(path.join(options.root, 'ai/skillshare/mcp.json'), 'utf8').includes('node_repl'));
  assert(sync.synchronize(options).agents.changed.length === 0);
});

test('external local skill capture uses the native audit-preserving install path', () => {
  const options = fixture();
  const intent = JSON.parse(fs.readFileSync(options.intentFile));
  const upstream = path.join(options.home, 'upstream/example');
  fs.cpSync(path.join(options.root, 'ai/skillshare/skills/example'), upstream, { recursive: true });
  intent.external.push({ kind: 'skill', name: 'example', path: upstream });
  write(options.intentFile, intent);
  sync.synchronize({ ...options, bootstrap: true });
  fs.appendFileSync(path.join(upstream, 'SKILL.md'), '\nUse the refreshed example.\n');
  const result = sync.synchronize(options);
  assert.equal(result.external.find(x => x.kind === 'skill').action, 'capture');
  assert.equal(fs.readFileSync(path.join(options.root, 'ai/skillshare/skills/example/SKILL.md'), 'utf8'), fs.readFileSync(path.join(upstream, 'SKILL.md'), 'utf8'));
});

test('missing external input stays pending without seeding the designated vendor', () => {
  const options = fixture();
  fs.unlinkSync(path.join(options.home, '.claude.json'));
  const first = sync.synchronize({ ...options, bootstrap: true });
  assert.deepEqual(first.mcp.pending, ['shared']);
  const primary = JSON.parse(fs.readFileSync(path.join(options.home, '.claude.json')));
  assert.equal(primary.mcpServers.shared, undefined);
  assert.deepEqual(primary.mcpServers.other.args, ['other-v1']);
  assert(fs.existsSync(path.join(options.home, '.claude/agents/worker.md')));
  assert.equal(config.readState(options).external['mcp:shared'], undefined);
  assert.deepEqual(sync.synchronize(options).mcp.pending, ['shared']);
});

test('a pending resource still has a pure managed preview after configuration exists', () => {
  const options = fixture();
  fs.unlinkSync(path.join(options.home, '.claude.json'));
  sync.synchronize({ ...options, bootstrap: true });
  const plan = sync.syncMcp(options, true);
  const files = [...new Set([options.configFile, options.mcpFile,
    path.join(options.root, 'ai/skillshare/mcp.json'), ...plan.changes.map(change => change.path)])];
  const snapshot = () => files.map(file => [file, fs.statSync(file).mtimeMs, fs.readFileSync(file, 'utf8')]);
  const before = snapshot();
  const result = sync.synchronize({ ...options, dryRun: true });
  assert.equal(result.external[0].action, 'pending');
  assert.deepEqual(result.mcp.blocked, []);
  assert.deepEqual(snapshot(), before);
});

test('unequal first adoption and conflicting changes stop without overwriting either source', () => {
  const options = fixture();
  const primary = path.join(options.home, '.claude.json');
  const changeVendor = value => {
    const data = JSON.parse(fs.readFileSync(primary));
    data.mcpServers.shared.args = [value]; write(primary, data);
  };
  changeVendor('different-first');
  assert.deepEqual(sync.synchronize({ ...options, bootstrap: true }).mcp.blocked, ['shared']);
  assert(fs.existsSync(path.join(options.home, '.claude/agents/worker.md')));
  changeVendor('server-v1');
  sync.synchronize({ ...options, bootstrap: true });
  const canonicalFile = path.join(options.root, 'ai/skillshare/mcp.json');
  const canonical = JSON.parse(fs.readFileSync(canonicalFile));
  canonical.servers.shared.args = ['tracked-v2']; write(canonicalFile, canonical);
  changeVendor('vendor-v3');
  const before = [canonicalFile, primary, options.mcpFile].map(file => fs.readFileSync(file, 'utf8'));
  const blocked = sync.synchronize(options);
  assert.deepEqual(blocked.mcp.blocked, ['shared']);
  assert.deepEqual([canonicalFile, primary, options.mcpFile].map(file => fs.readFileSync(file, 'utf8')), before);
  changeVendor('tracked-v2');
  assert.equal(sync.synchronize(options).external[0].action, 'ready');
});

test('held MCP entries retain baseline while other resources and a new destination synchronize', () => {
  const options = fixture();
  sync.synchronize({ ...options, bootstrap: true });
  const primary = path.join(options.home, '.claude.json');
  const before = JSON.parse(fs.readFileSync(primary)).mcpServers.shared;
  const canonicalFile = path.join(options.root, 'ai/skillshare/mcp.json');
  const canonical = JSON.parse(fs.readFileSync(canonicalFile));
  canonical.servers.shared.args = ['newer-tracked'];
  canonical.servers.other.args = ['other-v2']; write(canonicalFile, canonical);
  const intent = JSON.parse(fs.readFileSync(options.intentFile));
  intent.config.mcp.targets.push('pi'); write(options.intentFile, intent);
  const overrides = Object.fromEntries(config.ACCOUNT_OVERRIDES.map(key => [key, path.join(options.home, 'wrong', key)]));
  const result = sync.synchronize({ ...options, env: { ...options.env, ...overrides } });
  assert.equal(result.external[0].action, 'hold');
  assert.deepEqual(JSON.parse(fs.readFileSync(primary)).mcpServers.shared, before);
  assert.deepEqual(JSON.parse(fs.readFileSync(primary)).mcpServers.other.args, ['other-v2']);
  assert(result.mcp.changes.some(change => change.target === 'pi' && change.name === 'shared'));
  assert(!fs.existsSync(path.join(options.home, 'wrong')));
  assert.equal(sync.yamlValue(options.mcpFile, options).servers.shared.targets, undefined);
});

test('the tracked intent bootstraps all runtime targets and detects replaced shared links', () => {
  const options = fixture();
  write(options.intentFile, fs.readFileSync(path.join(repository, 'ai/skillshare/intent.json'), 'utf8'));
  fs.copyFileSync(path.join(repository, 'ai/skillshare/mcp.json'), path.join(options.root, 'ai/skillshare/mcp.json'));
  const intent = config.loadIntent(options);
  const godot = config.renderServer(config.loadCanonicalMcp(options)['godot-ai'], { ...options, executables: intent.executables });
  write(path.join(options.home, '.claude.json'), { mcpServers: { 'godot-ai': { type: 'stdio', command: godot.command, args: godot.args } } });
  write(path.join(options.home, '.cua-driver/skills/cua-driver/SKILL.md'), '---\nname: cua-driver\ndescription: Fixture updater-owned skill\n---\nUse the updater.\n');
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.equal(result.external[0].action, 'ready');
  for (const relative of ['.claude/skills', '.claude-gamma/skills', '.agents/skills', '.config/mimocode/skills']) {
    assert(fs.lstatSync(path.join(options.home, relative, 'example')).isSymbolicLink());
    assert(fs.lstatSync(path.join(options.home, relative, 'cua-driver')).isSymbolicLink());
  }
  for (const client of ['.codex', '.grok']) assert(!fs.existsSync(path.join(options.home, client, 'skills/example')));
  const collision = path.join(options.home, '.claude/skills/example');
  fs.unlinkSync(collision);
  write(path.join(collision, 'SKILL.md'), 'vendor replaced this link');
  assert.throws(() => sync.synchronize(options), /local files preserved/);
  assert.equal(fs.readFileSync(path.join(collision, 'SKILL.md'), 'utf8'), 'vendor replaced this link');
});

test('OpenCode JSONC and every selected destination are checked positively', () => {
  const options = fixture();
  const jsonc = path.join(options.home, '.config/opencode/opencode.jsonc');
  write(jsonc, '// Keep this comment.\n{"private": true}\n');
  sync.synchronize({ ...options, bootstrap: true });
  assert(fs.readFileSync(jsonc, 'utf8').includes('Keep this comment'));
  assert(!fs.existsSync(path.join(options.home, '.config/opencode/opencode.json')));
  const plan = (target, file) => ({ changes: [{ target, path: file, action: 'add' }] });
  assert.throws(() => sync.checkDestinations(plan('claude-gamma', path.join(options.home, '.claude-gamma/.claude.json')), options), /Unexpected/);
  const intent = config.loadIntent(options);
  intent.config.mcp.targets.push('pi');
  sync.checkDestinations(plan('pi', path.join(options.home, '.pi/agent/mcp.json')), { ...options, intent });
  assert.throws(() => sync.checkDestinations(plan('pi', path.join(options.home, 'wrong/mcp.json')), { ...options, intent }), /Unexpected/);
});

test('pending legacy input leaves inline ownership intact while agents continue', () => {
  const options = fixture();
  const intent = config.loadIntent(options);
  write(options.configFile, config.parser(options).stringify({ sources: { skills: intent.config.sources.skills },
    targets: { claude: { skills: { path: path.join(options.home, '.claude/skills') } } },
    mcp: { targets: intent.config.mcp.targets, servers: { shared: { command: process.execPath, args: ['server-v1'] }, other: { command: process.execPath, args: ['other-v1'] } } } }));
  fs.unlinkSync(path.join(options.home, '.claude.json'));
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.deepEqual(result.mcp.blocked, ['shared']);
  assert(sync.yamlValue(options.configFile, options).mcp.servers.shared);
  assert(!fs.existsSync(path.join(options.home, '.claude.json')));
  assert(fs.existsSync(path.join(options.home, '.claude/agents/worker.md')));
  write(path.join(options.home, '.claude.json'), { mcpServers: { shared: { type: 'stdio', command: process.execPath, args: ['server-v1'] } } });
  const resumed = sync.synchronize(options);
  assert.equal(resumed.mcp.blocked, undefined);
  assert.equal(sync.yamlValue(options.configFile, options).mcp.servers, undefined);
});

test('first adoption of an existing inline setup requires bootstrap', () => {
  const options = fixture();
  write(options.configFile, config.parser(options).stringify({ sources: { skills: path.join(options.home, 'personal-skills') },
    mcp: { targets: ['claude'], servers: { personal: { command: process.execPath, args: ['personal'] } } } }));
  const before = fs.readFileSync(options.configFile, 'utf8');
  assert.throws(() => sync.synchronize(options), /Reconcile inline|explicit adoption/);
  assert.equal(fs.readFileSync(options.configFile, 'utf8'), before);
  assert(!fs.existsSync(options.stateFile));
  assert(!fs.existsSync(path.join(options.home, '.claude/agents')));
});

test('a post-import native MCP block restores the source and ownership ledger while agents continue', () => {
  const options = fixture();
  const intent = config.loadIntent(options);
  const legacy = { sources: { skills: intent.config.sources.skills }, targets: {
    claude: { skills: { path: path.join(options.home, '.claude/skills') } } },
    mcp: { targets: intent.config.mcp.targets, servers: {
      shared: { command: process.execPath, args: ['server-legacy'] },
      node_repl: { command: process.execPath, args: ['node-old'] },
      personal: { command: process.execPath, args: ['personal-v1'], targets: ['claude'] },
    } }, plugins: { packages: { browser: { bindings: { codex: { id: 'browser@openai-bundled' } } } } } };
  write(options.configFile, config.parser(options).stringify(legacy));
  write(path.join(options.home, '.claude.json'), { mcpServers: {} });
  sync.syncMcp(options);
  const primary = path.join(options.home, '.claude.json');
  const data = JSON.parse(fs.readFileSync(primary));
  data.mcpServers.shared.args = ['server-v1'];
  data.mcpServers.personal.args = ['personal-user-edit']; write(primary, data);
  const codex = path.join(options.home, '.codex/config.toml');
  write(codex, fs.readFileSync(codex, 'utf8').replace('node-old', 'node-current'));
  const paths = [...new Set(sync.native(['sync', 'mcp', '--dry-run', '--json'], options, true).data.changes.map(change => change.path))];
  const before = paths.map(file => fs.readFileSync(file, 'utf8'));
  const ledger = path.join(path.dirname(options.stateDir), 'skillshare/mcp/state.json');
  const oldLedger = fs.readFileSync(ledger, 'utf8');
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert(result.mcp.blocked.includes('personal'));
  assert.deepEqual(sync.yamlValue(options.configFile, options).mcp, legacy.mcp);
  assert.equal(fs.readFileSync(ledger, 'utf8'), oldLedger);
  assert.deepEqual(paths.map(file => fs.readFileSync(file, 'utf8')), before);
  assert(fs.existsSync(path.join(options.home, '.claude/agents/worker.md')));
  assert.equal(sync.yamlValue(options.configFile, options).plugins.packages.browser, undefined);
  assert.equal(config.readState(options).external['mcp:shared'], undefined);
  sync.native(['mcp', 'import', 'personal', '--from', 'claude', '--target', 'claude', '--replace', '--json'], options, true);
  assert.deepEqual(sync.yamlValue(options.configFile, options).mcp.servers.personal.args, ['personal-user-edit']);
  assert.equal(sync.synchronize(options).mcp.blocked, undefined);
  assert.equal(sync.yamlValue(options.configFile, options).mcp.servers, undefined);
  assert(fs.readFileSync(codex, 'utf8').includes('node-current'));
});

test('legacy external refresh also stages a native HTTP definition without executable rewriting', () => {
  const options = fixture();
  const intent = config.loadIntent(options);
  const canonicalFile = path.join(options.root, 'ai/skillshare/mcp.json');
  const canonical = JSON.parse(fs.readFileSync(canonicalFile));
  canonical.servers.shared = { transport: 'streamable-http', url: 'https://example.com/v1' }; write(canonicalFile, canonical);
  write(options.configFile, config.parser(options).stringify({ sources: { skills: intent.config.sources.skills },
    targets: { claude: { skills: { path: path.join(options.home, '.claude/skills') } } },
    mcp: { targets: intent.config.mcp.targets, servers: { shared: { url: 'https://example.com/old', targets: intent.config.mcp.targets.filter(target => target !== 'claude-desktop') } } } }));
  write(path.join(options.home, '.claude.json'), { mcpServers: {} });
  sync.syncMcp(options);
  write(path.join(options.home, '.claude.json'), { mcpServers: { shared: { type: 'http', url: 'https://example.com/v1' } } });
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.equal(result.mcp.blocked, undefined);
  assert.equal(sync.yamlValue(options.mcpFile, options).servers.shared.url, 'https://example.com/v1');
  assert(!sync.yamlValue(options.mcpFile, options).servers.shared.targets.includes('claude-desktop'));
  assert(result.mcp.omitted.some(item => item.server === 'shared' && item.target === 'claude-desktop' && item.reason === 'stdio-only'));
});

test('a missing established vendor input is held without reseeding it or blocking agents', () => {
  const options = fixture();
  sync.synchronize({ ...options, bootstrap: true });
  const primary = path.join(options.home, '.claude.json');
  const data = JSON.parse(fs.readFileSync(primary));
  delete data.mcpServers.shared; write(primary, data);
  const preview = sync.native(['sync', 'mcp', '--dry-run', '--json'], options, true).data;
  const nativePlan = preview.plan || preview;
  assert.equal(nativePlan.blocked, true);
  assert(nativePlan.changes.some(change => change.target === 'claude' && change.name === 'shared' && change.action === 'conflict'));
  const source = fs.readFileSync(options.mcpFile, 'utf8');
  write(path.join(options.home, '.claude/agents/worker.md'), 'direct output edit');
  const result = sync.synchronize(options);
  assert.deepEqual(result.mcp.blocked, ['shared']);
  assert.equal(JSON.parse(fs.readFileSync(primary)).mcpServers.shared, undefined);
  assert.equal(fs.readFileSync(options.mcpFile, 'utf8'), source);
  assert(!fs.readFileSync(path.join(options.home, '.claude/agents/worker.md'), 'utf8').includes('direct output edit'));
});

test('dead lock owners recover, and an active owner remains protected', () => {
  const options = fixture();
  fs.mkdirSync(options.stateDir, { recursive: true });
  const lock = path.join(options.stateDir, 'skillshare-sync.lock');
  write(lock, `${process.pid}\n`);
  assert.throws(() => sync.acquireLock(options.stateDir), /Another Skillshare sync/);
  assert(fs.existsSync(lock));
  write(lock, '2147483647\n');
  const release = sync.acquireLock(options.stateDir);
  assert.equal(fs.readFileSync(lock, 'utf8'), `${process.pid}\n`);
  release();
  assert(!fs.existsSync(lock));
});

test('bootstrap preserves an explicit disabled plugin choice even without installation records', () => {
  const options = fixture();
  write(path.join(options.root, 'ai/skillshare/plugins.json'), { version: 1, plugins: [{ name: 'demo', target: 'claude', nativeId: 'demo@team',
    classification: 'portable', source: 'https://github.com/example/plugins.git', sourceRef: 'a'.repeat(40), plugin: 'demo' }] });
  write(path.join(options.home, '.claude/settings.json'), { enabledPlugins: { 'demo@team': false } });
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.equal(result.plugins[0].action, 'local');
  assert.equal(JSON.parse(fs.readFileSync(path.join(options.home, '.claude/settings.json'))).enabledPlugins['demo@team'], false);
  assert(!fs.existsSync(path.join(options.home, '.claude/plugins/installed_plugins.json')));
});

test('managed bootstrap adopts a plugin and preserves owned projections through the second preparation', () => {
  const options = fixture();
  const nativeId = 'demo@team';
  const commit = 'a'.repeat(40);
  const upstream = path.join(options.home, 'upstream');
  const plugin = path.join(upstream, 'demo');
  write(path.join(upstream, '.claude-plugin/marketplace.json'), { name: 'team', plugins: [{ name: 'demo', source: './demo' }] });
  write(path.join(plugin, '.claude-plugin/plugin.json'), { name: 'demo', version: '1.2.3' });
  write(path.join(options.home, '.claude/plugins/installed_plugins.json'), { version: 2, plugins: { [nativeId]: [{ scope: 'user', installPath: plugin, version: '1.2.3', gitCommitSha: commit }] } });
  write(path.join(options.home, '.claude/plugins/known_marketplaces.json'), { team: { source: { source: 'github', repo: 'example/plugins' }, installLocation: upstream } });
  write(path.join(options.home, '.claude/settings.json'), { enabledPlugins: { [nativeId]: true }, private: 'preserve' });
  write(path.join(options.root, 'ai/skillshare/plugins.json'), { version: 1, plugins: [{ name: 'demo', target: 'claude', nativeId,
    classification: 'portable', source: 'https://github.com/example/plugins.git', sourceRef: commit, plugin: 'demo' }] });
  const binary = path.join(options.home, 'bin/claude');
  write(binary, `#!${process.execPath}\nconst fs=require('fs'),p=require('path'),a=process.argv.slice(2),h=process.env.HOME;
fs.appendFileSync(p.join(h,'plugin-calls'),JSON.stringify(a)+'\\n');
if(a[0]==='--version'){console.log('claude 99.0.0');process.exit(0);}
if(a.includes('--help')){console.log('plugin install --json');process.exit(0);}
if(a.join(' ')==='plugin list --json'){console.log(JSON.stringify([{id:'demo@team',pluginId:'demo@team',name:'demo',version:'1.2.3',scope:'user',installed:true,enabled:true}]));process.exit(0);}
if(a.join(' ')==='plugin marketplace list --json'){console.log(JSON.stringify([{name:'team',installLocation:p.join(h,'upstream'),root:p.join(h,'upstream')}]));process.exit(0);}
process.exit(99);\n`);
  fs.chmodSync(binary, 0o700);
  options.env = { ...options.env, PATH: `${path.dirname(binary)}${path.delimiter}${process.env.PATH}` };
  const before = ['.claude/settings.json', '.claude/plugins/installed_plugins.json'].map(file => fs.readFileSync(path.join(options.home, file), 'utf8'));
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.equal(result.plugins[0].action, 'adopt');
  assert.deepEqual(sync.yamlValue(options.configFile, options).plugins.packages.demo.bindings.claude, { id: nativeId, version: '1.2.3' });
  assert.deepEqual(['.claude/settings.json', '.claude/plugins/installed_plugins.json'].map(file => fs.readFileSync(path.join(options.home, file), 'utf8')), before);
  assert.equal(sync.synchronize(options).plugins[0].action, 'managed');
  const calls = fs.readFileSync(path.join(options.home, 'plugin-calls'), 'utf8').trim().split('\n').map(JSON.parse);
  assert(calls.every(args => args[0] === '--version' || args.includes('list') || args.includes('--help')));
});


test('Linux delivery omits Desktop and publishes the remaining native clients', () => {
  const options = { ...fixture(), platform: 'linux' };
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.deepEqual(result.mcp.omittedDefaults, [{ target: 'claude-desktop', reason: 'unsupported-platform' }]);
  assert.deepEqual([...new Set(result.mcp.changes.map(item => item.target))].sort(), ['claude', 'codex', 'grok', 'opencode']);
  assert(!fs.existsSync(path.join(options.home, 'Library/Application Support/Claude/claude_desktop_config.json')));
  assert(sync.synchronize({ ...options, dryRun: true }).mcp.omittedDefaults.length === 1);
});

test('native target retirement and private per-server selections preserve their ownership', () => {
  const options = fixture();
  sync.synchronize({ ...options, bootstrap: true });
  const intent = config.loadIntent(options);
  intent.config.mcp.targets = intent.config.mcp.targets.filter(target => target !== 'grok');
  write(options.intentFile, intent);
  const source = sync.yamlValue(options.mcpFile, options);
  source.servers.personal = { command: process.execPath, args: ['personal'], targets: ['pi'] };
  write(options.mcpFile, config.parser(options).stringify(source));
  const result = sync.synchronize(options);
  assert(result.mcp.changes.some(change => change.target === 'grok' && change.action === 'remove'));
  assert(result.mcp.changes.some(change => change.target === 'pi' && change.name === 'personal' && change.action === 'add'));
  assert(!result.mcp.changes.some(change => change.target === 'pi' && change.name === 'shared'));
  assert.equal(JSON.parse(fs.readFileSync(path.join(options.home, '.pi/agent/mcp.json'))).mcpServers.personal.command, process.execPath);
});

test('managed migration rejects unowned source aliases and primary agent links before writes', () => {
  for (const kind of ['skills', 'agents']) {
    const options = fixture();
    const foreign = path.join(options.home, 'vendor-owned');
    write(path.join(foreign, 'private.md'), 'preserve');
    const target = path.join(options.home, '.claude', kind);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    if (kind === 'skills') {
      const alias = path.join(options.configDir, 'skills');
      fs.mkdirSync(options.configDir, { recursive: true }); fs.symlinkSync(foreign, alias); fs.symlinkSync(alias, target);
    } else fs.symlinkSync(foreign, target);
    assert.throws(() => sync.synchronize({ ...options, bootstrap: true }), /Unknown whole-directory link/);
    assert(!fs.existsSync(options.configFile));
    assert.equal(fs.readFileSync(path.join(foreign, 'private.md'), 'utf8'), 'preserve');
    assert(fs.lstatSync(target).isSymbolicLink());
  }
});


test('legacy bootstrap stages platform-compatible defaults before native MCP publication', () => {
  const options = { ...fixture(), platform: 'linux' };
  const intent = JSON.parse(fs.readFileSync(options.intentFile));
  write(options.configFile, config.parser(options).stringify({
    sources: { skills: intent.config.sources.skills },
    targets: { claude: { skills: { path: path.join(options.home, '.claude/skills') } } },
    mcp: { targets: intent.config.mcp.targets, servers: {
      shared: { command: process.execPath, args: ['server-v1'], targets: [...intent.config.mcp.targets] },
      other: { command: process.execPath, args: ['other-v1'], targets: [...intent.config.mcp.targets] },
    } },
  }));
  const result = sync.synchronize({ ...options, bootstrap: true });
  assert.equal(result.mcp.blocked, undefined);
  assert.deepEqual(sync.yamlValue(options.configFile, options).mcp.targets.sort(), ['claude', 'codex', 'grok', 'opencode']);
  assert(!result.mcp.changes.some(change => change.target === 'claude-desktop'));
  assert(fs.existsSync(path.join(options.home, '.grok/config.toml')));
});


test('Desktop destination checks follow native platform paths and the Windows fallback', () => {
  const options = fixture();
  const preview = file => ({ changes: [{ target: 'claude-desktop', name: 'other', action: 'add', path: file }] });
  for (const appData of [undefined, '', path.join(options.home, 'custom-appdata')]) {
    const expected = path.join(appData || path.join(options.home, 'AppData/Roaming'), 'Claude/claude_desktop_config.json');
    const nativeOptions = { ...options, platform: 'win32', env: { APPDATA: appData } };
    sync.checkDestinations(preview(expected), nativeOptions);
    assert.throws(() => sync.checkDestinations(preview(path.join(options.home, '.config/Claude/claude_desktop_config.json')), nativeOptions), /Unexpected native MCP destination/);
  }
  sync.checkDestinations(preview(path.join(options.home, 'Library/Application Support/Claude/claude_desktop_config.json')), { ...options, platform: 'darwin' });
  assert.throws(() => sync.checkDestinations(preview(path.join(options.home, '.config/Claude/claude_desktop_config.json')), { ...options, platform: 'linux' }), /Unexpected native MCP destination/);
});


test('inherited Grok homes cannot redirect managed MCP publication or change outside files', () => {
  const options = fixture();
  const outside = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare-outside-grok-'));
  roots.push(outside);
  const outsideFile = path.join(outside, 'config.toml');
  write(outsideFile, '# External Grok configuration stays untouched.\n');
  const before = fs.readFileSync(outsideFile, 'utf8');
  const beforeStats = fs.statSync(outsideFile);
  const original = process.env.GROK_HOME;
  try {
    const { env, ...inheritedOptions } = options;
    for (const [index, override] of [outside, 'relative-grok-home'].entries()) {
      process.env.GROK_HOME = override;
      const result = sync.synchronize({ ...inheritedOptions, env: { ...process.env, APPDATA: env.APPDATA }, bootstrap: index === 0 });
      assert(result.mcp.changes.some(change => change.target === 'grok'));
      assert(result.mcp.changes.filter(change => change.target === 'grok').every(change => change.path === path.join(options.home, '.grok/config.toml')));
      assert(process.env.GROK_HOME === override, 'managed sync must preserve the caller environment');
      assert.equal(fs.readFileSync(outsideFile, 'utf8'), before);
      const afterStats = fs.statSync(outsideFile);
      assert.equal(afterStats.mtimeMs, beforeStats.mtimeMs);
      assert.equal(afterStats.mode, beforeStats.mode);
      assert.deepEqual(fs.readdirSync(outside), ['config.toml']);
    }
  } finally {
    if (original === undefined) delete process.env.GROK_HOME;
    else process.env.GROK_HOME = original;
  }
});
