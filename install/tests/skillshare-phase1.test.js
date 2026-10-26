'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const m = require('../lib/skillshare-config');
const root = path.resolve(__dirname, '../..');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare phase1 '));
const depsDir = process.env.SKILLSHARE_TEST_DEPS || path.join(root, '.local/skillshare-node');
let checks = 0;
function check(name, fn) { fn(); checks++; console.log(`ok ${checks} - ${name}`); }
function file(name, text, mode) { fs.mkdirSync(path.dirname(name), { recursive: true }); fs.writeFileSync(name, text, { mode }); }
function fixture(name) {
  const home = path.join(temporary, name, 'home with spaces');
  const fixtureRoot = path.join(temporary, name, 'repo with spaces');
  fs.mkdirSync(home, { recursive: true });
  for (const relative of ['ai/skillshare/intent.json', 'ai/skillshare/mcp.json', 'ai/skillshare/agent-models.json',
    'ai/skillshare/agents', 'ai/skillshare/extensions', 'install/skillshare-deps']) {
    const dest = path.join(fixtureRoot, relative);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.cpSync(path.join(root, relative), dest, { recursive: true });
  }
  file(path.join(fixtureRoot, 'ai/skillshare/skills/example/SKILL.md'), '---\nname: example\ndescription: Fixture skill.\n---\nFixture.\n');
  const executables = {};
  for (const name of ['uvx', 'npx', 'docker']) {
    executables[name] = path.join(home, 'tools with spaces', name);
    file(executables[name], '#!/bin/sh\nexit 0\n', 0o755);
  }
  return m.paths({ root: fixtureRoot, home, depsDir, executables, env: { ...process.env, APPDATA: path.join(home, 'AppData/Roaming') } });
}
function native(options, args) {
  const env = m.nativeEnv(options, options.env);
  const result = spawnSync(options.skillshare || 'skillshare', args, {
    env, cwd: options.home, encoding: 'utf8', timeout: 30000,
  });
  assert.equal(result.status, 0, `${args.join(' ')}: ${result.stderr}\n${result.stdout}`);
  return result.stdout;
}
function snapshot(files) {
  const output = {};
  function visit(full) {
    if (!fs.existsSync(full)) return;
    const stat = fs.lstatSync(full);
    output[full] = { mtime: stat.mtimeMs, size: stat.size, link: stat.isSymbolicLink() ? fs.readlinkSync(full) : null,
      sha: stat.isFile() ? crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex') : null };
    if (stat.isDirectory()) for (const name of fs.readdirSync(full)) visit(path.join(full, name));
  }
  for (const full of files) visit(full);
  return output;
}
const homeGuard = require('./skillshare-home-guard');
const liveSnapshot = homeGuard.snapshot;

const before = liveSnapshot();
try {
  const a = fixture('clean');
  const yaml = m.parser(a);
  check('portable intent retains selected targets and separates Gamma and universal delivery', () => {
    const intent = m.loadIntent(a);
    assert.deepEqual(Object.keys(intent.config.targets), ['Mimo', 'claude', 'claude-gamma', 'codex', 'grok', 'universal']);
    assert.equal(intent.config.targets.codex.skills.enabled, false);
    assert.equal(intent.config.targets.grok.skills.enabled, false);
    assert.equal(intent.config.targets['claude-gamma'].agent, 'claude');
    assert(!intent.config.mcp.targets.includes('claude-gamma'));
    const raw = fs.readFileSync(path.join(a.root, 'ai/skillshare/intent.json'), 'utf8') + fs.readFileSync(path.join(a.root, 'ai/skillshare/mcp.json'), 'utf8');
    assert(!/\/Users\/|\/home\/|\/Applications\/|node_repl|@openai-bundled/.test(raw));
  });
  check('native environments clear all account overrides without changing the parent', () => {
    const base = Object.fromEntries(m.ACCOUNT_OVERRIDES.map(key => [key, '/poison']));
    const env = m.nativeEnv(a, base);
    for (const key of m.ACCOUNT_OVERRIDES) { assert(!Object.hasOwn(env, key)); assert(base[key] === '/poison'); }
    assert(env.HOME === a.home);
    assert(env.XDG_CONFIG_HOME === path.dirname(a.configDir));
    assert(env.XDG_STATE_HOME === path.dirname(a.stateDir));
    assert(env.SKILLSHARE_CONFIG === a.configFile);
  });
  check('platform defaults and bounded Desktop delivery retain portable inheritance', () => {
    const b = fixture('delivery-selection');
    const canonicalFile = path.join(b.root, 'ai/skillshare/mcp.json');
    const intentFile = path.join(b.root, 'ai/skillshare/intent.json');
    const before = snapshot([canonicalFile, intentFile]);
    const linux = m.loadIntent({ ...b, platform: 'linux' });
    const compatible = ['claude', 'codex', 'opencode', 'grok'];
    assert.deepEqual(linux.config.mcp.targets, compatible);
    assert.deepEqual(linux.metadata.omittedMcpDefaults, [{ target: 'claude-desktop', reason: 'unsupported-platform' }]);
    for (const platform of ['darwin', 'win32']) {
      const intent = m.loadIntent({ ...b, platform });
      assert.deepEqual(intent.config.mcp.targets, [...compatible, 'claude-desktop']);
      assert.deepEqual(intent.metadata.omittedMcpDefaults, []);
    }
    assert.deepEqual(m.loadIntent(b).config.mcp.targets,
      m.loadIntent({ ...b, platform: process.platform }).config.mcp.targets);
    const intent = m.loadIntent({ ...b, platform: 'darwin' });
    const servers = {
      'godot-ai': m.loadCanonicalMcp(b)['godot-ai'],
      remote: { url: 'https://example.com/mcp' },
      env: { command: { executable: 'uvx' }, env: { FIXTURE_VALUE: { fromEnv: 'FIXTURE_VALUE' } } },
      explicit: { url: 'https://example.com/explicit', targets: ['claude-desktop', 'codex'] },
      none: { url: 'https://example.com/none', targets: [] },
      desktop: { url: 'https://example.com/desktop', targets: ['claude-desktop'] },
    };
    const prepared = m.prepare({ ...b, intent, servers, platform: 'darwin' });
    const generated = yaml.parse(prepared.mcp.text).servers;
    assert(!Object.hasOwn(generated['godot-ai'], 'targets'));
    assert.deepEqual(generated.remote.targets, compatible);
    assert.deepEqual(generated.env.targets, compatible);
    assert.deepEqual(generated.explicit.targets, ['codex']);
    assert.deepEqual(generated.none.targets, []);
    assert.deepEqual(generated.desktop.targets, []);
    assert.deepEqual(prepared.mcp.omitted, [
      { server: 'remote', target: 'claude-desktop', reason: 'stdio-only' },
      { server: 'env', target: 'claude-desktop', reason: 'from-env-unsupported' },
      { server: 'explicit', target: 'claude-desktop', reason: 'stdio-only' },
      { server: 'desktop', target: 'claude-desktop', reason: 'stdio-only' },
    ]);
    assert.deepEqual(m.mcpDeliveryTargets(intent, servers.remote, { platform: 'darwin' }), {
      targets: compatible, omitted: [{ target: 'claude-desktop', reason: 'stdio-only' }],
    });
    assert.deepEqual(m.mcpDeliveryTargets(intent, { targets: ['claude-desktop', 'claude'] }, { platform: 'linux' }), {
      targets: ['claude'], omitted: [{ target: 'claude-desktop', reason: 'unsupported-platform' }],
    });
    for (const targets of [undefined, null, false, 'claude']) {
      assert.throws(() => m.mcpDeliveryTargets(intent, { targets }), /Invalid MCP targets/);
      assert.throws(() => m.renderServer({ ...servers.remote, targets }, b), /Invalid MCP targets/);
    }
    m.applyPrepared(prepared); m.writeState(b, prepared.state);
    if (process.platform === 'darwin') {
      native(b, ['sync', 'mcp', '--json', '-g']);
      const desktop = JSON.parse(fs.readFileSync(path.join(b.home,
        'Library/Application Support/Claude/claude_desktop_config.json'))).mcpServers;
      assert(Object.hasOwn(desktop, 'godot-ai'));
      assert(!Object.hasOwn(desktop, 'remote'));
      assert(!Object.hasOwn(desktop, 'env'));
    }
    intent.config.mcp.targets.push('pi');
    const expanded = m.prepare({ ...b, intent, servers, platform: 'darwin' });
    const next = yaml.parse(expanded.mcp.text).servers;
    assert.deepEqual(next.remote.targets, [...compatible, 'pi']);
    assert.deepEqual(next.env.targets, [...compatible, 'pi']);
    assert.deepEqual(next.explicit.targets, ['codex']);
    assert(!Object.hasOwn(next['godot-ai'], 'targets'));
    assert.deepEqual(snapshot([canonicalFile, intentFile]), before);
  });
  check('simulated Linux source syncs to four compatible clients through the host CLI', () => {
    const b = { ...fixture('linux-delivery'), platform: 'linux' };
    const servers = { 'godot-ai': m.loadCanonicalMcp(b)['godot-ai'], remote: { url: 'https://example.com/mcp' } };
    const prepared = m.prepare({ ...b, servers });
    assert.deepEqual(prepared.intent.metadata.omittedMcpDefaults, [{ target: 'claude-desktop', reason: 'unsupported-platform' }]);
    const generated = yaml.parse(prepared.mcp.text).servers;
    assert(!Object.hasOwn(generated['godot-ai'], 'targets'));
    assert(!Object.hasOwn(generated.remote, 'targets'));
    m.applyPrepared(prepared); m.writeState(b, prepared.state);
    native(b, ['sync', 'mcp', '--json', '-g']);
    for (const [relative, needle] of [
      ['.claude.json', '"remote"'], ['.codex/config.toml', '[mcp_servers.remote]'],
      ['.config/opencode/opencode.json', '"remote"'], ['.grok/config.toml', '[mcp_servers.remote]'],
    ]) {
      const text = fs.readFileSync(path.join(b.home, relative), 'utf8');
      assert(text.includes(needle));
      assert(text.includes('godot-ai'));
    }
    for (const relative of ['Library/Application Support/Claude/claude_desktop_config.json',
      '.config/Claude/claude_desktop_config.json', 'AppData/Roaming/Claude/claude_desktop_config.json']) {
      assert(!fs.existsSync(path.join(b.home, relative)));
    }
    const again = m.prepare({ ...b, servers });
    assert.equal(again.config.changed, false);
    assert.equal(again.mcp.changed, false);
  });
  check('clean configuration uses one real generated MCP source and loads through the actual CLI', () => {
    const p = m.prepare(a);
    assert.equal(fs.existsSync(p.paths.configFile), false);
    assert.equal(fs.existsSync(p.paths.stateFile), false);
    m.applyPrepared(p);
    m.writeState(a, p.state);
    assert.equal(fs.lstatSync(p.paths.mcpFile).isSymbolicLink(), false);
    const config = yaml.parse(fs.readFileSync(p.paths.configFile, 'utf8'));
    assert.equal(config.sources.mcp, p.paths.mcpFile);
    assert(!config.mcp.servers);
    const status = JSON.parse(native(a, ['status', '--json', '-g']));
    assert(status);
    const mcp = native(a, ['mcp', '--json', '-g']);
    for (const name of Object.keys(m.loadCanonicalMcp(a))) assert(mcp.includes(name));
    assert(!mcp.includes('node_repl'));
    const again = m.prepare(a);
    assert.equal(again.config.changed, false);
    assert.equal(again.mcp.changed, false);
    assert.equal(again.config.text, fs.readFileSync(p.paths.configFile, 'utf8'));
  });
  check('native account targets execute the configured converters and exclude neutral delivery', () => {
    const p = m.paths(a);
    // Converters resolve the shared map from their repository location.
    for (const name of ['dotfiles-agent-transform', 'dotfiles-claude-agents', 'dotfiles-codex-agents']) {
      const dest = path.join(p.configDir, 'extensions', name);
      fs.mkdirSync(dest, { recursive: true });
      for (const entry of fs.readdirSync(path.join(a.root, 'ai/skillshare/extensions', name))) {
        fs.symlinkSync(path.join(a.root, 'ai/skillshare/extensions', name, entry), path.join(dest, entry));
      }
    }
    native(a, ['sync', 'agents', '--json', '-g']);
    for (const account of ['.claude', '.claude-gamma']) {
      assert(fs.readFileSync(path.join(a.home, account, 'agents/worker.md'), 'utf8').includes('model:'));
      assert(fs.readFileSync(path.join(a.home, account, 'agents/fastworker.md'), 'utf8').includes('model:'));
    }
    assert(fs.readFileSync(path.join(a.home, '.codex/agents/worker.toml'), 'utf8').includes('model ='));
    assert(!fs.existsSync(path.join(a.home, '.grok/agents/worker.md')));
    assert(!fs.existsSync(path.join(a.home, '.agents/agents/worker.md')));
    native(a, ['sync', '--json', '-g']);
    for (const rel of ['.claude/skills/example', '.claude-gamma/skills/example', '.agents/skills/example', '.config/mimocode/skills/example']) {
      assert(fs.lstatSync(path.join(a.home, rel)).isSymbolicLink());
    }
    assert(!fs.existsSync(path.join(a.home, '.codex/skills/example')));
    assert(!fs.existsSync(path.join(a.home, '.grok/skills/example')));
  });
  check('existing configuration preserves comments, unrelated settings and native metadata', () => {
    const b = fixture('existing');
    const p = m.paths(b);
    file(p.configFile, '# retained comment\naudit: {block_threshold: CRITICAL}\nplugins:\n  packages:\n    local:\n      bindings:\n        codex: {id: local@fixture, installed_version: v1, enabled: false}\ntargets:\n  extra: {skills: {path: /local-only}, cli_metadata: keep}\n');
    assert.throws(() => m.prepare(b), /explicit adoption/);
    const prepared = m.prepare({ ...b, adoptExisting: true });
    m.applyPrepared(prepared); m.writeState(b, prepared.state);
    const value = yaml.parse(fs.readFileSync(p.configFile, 'utf8'));
    assert.equal(value.plugins.packages.local.bindings.codex.id, 'local@fixture');
    assert.equal(value.plugins.packages.local.bindings.codex.enabled, false);
    assert.equal(value.targets.extra.cli_metadata, 'keep');
    assert(fs.readFileSync(p.configFile, 'utf8').includes('# retained comment'));
    native(b, ['status', '--json', '-g']);
    native(b, ['mcp', '--json', '-g']);
    value.plugins.packages.local.bindings.codex.installed_version = '2.0';
    file(p.configFile, yaml.stringify(value));
    assert.doesNotThrow(() => m.prepare(b));
    value.source = '/dashboard-source'; file(p.configFile, yaml.stringify(value));
    assert.throws(() => m.prepare(b), /retired owned source/);
    delete value.source;
    value.mode = 'copy'; file(p.configFile, yaml.stringify(value));
    const unchanged = fs.readFileSync(p.configFile, 'utf8');
    assert.throws(() => m.prepare(b), /Local edit/);
    assert.equal(fs.readFileSync(p.configFile, 'utf8'), unchanged);
  });
  check('named-resource owned fields preserve native bindings and detect owned edits', () => {
    const original = '# comment\nplugins:\n  - name: deliberate\n    source: old\n    native_id: retain\n    enabled: false\n  - name: unrelated\n    source: local\n';
    const desired = { plugins: [{ name: 'deliberate', source: 'new', targets: ['claude'] }] };
    const projected = m.projectYaml(original, desired, null, { ...a, adoptExisting: true });
    const data = yaml.parse(projected.text);
    assert.equal(data.plugins[0].native_id, 'retain');
    assert.equal(data.plugins[0].enabled, false);
    assert.equal(data.plugins[1].source, 'local');
    assert.equal(m.projectYaml(projected.text, desired, projected.snapshot, a).changed, false);
    data.plugins[0].source = 'dashboard';
    assert.throws(() => m.projectYaml(yaml.stringify(data), desired, projected.snapshot, a), /Local edit/);
  });
  check('canonical capture and render round trip across homes and executable paths with spaces', () => {
    const b = fixture('second-home');
    const canonical = m.loadCanonicalMcp(a)['godot-ai'];
    const one = m.renderServer(canonical, a);
    assert(one.command.includes('tools with spaces'));
    const captured = m.captureServer({ ...one, timeout: 500, private_client_field: 'local', targets: ['claude'] }, a);
    assert.deepEqual(captured, canonical);
    const two = m.renderServer(captured, b);
    assert.notEqual(one.command, two.command);
    assert.deepEqual(m.captureServer(two, b), canonical);
    assert(!Object.hasOwn(captured, 'targets'));
    assert.throws(() => m.captureServer({ command: '/some/unknown', args: [] }, a), /binding/);
    assert.throws(() => m.captureServer({ ...one, args: ['/home/private/model'] }, a), /Machine-specific/);
    assert.throws(() => m.captureServer({ ...one, args: ['/workspace/private/model'] }, a), /Machine-specific/);
    assert.equal(m.captureServer(one, { executables: { absent: '/does/not/exist', uvx: a.executables.uvx } }).command.executable, 'uvx');
    assert.throws(() => m.captureServer({ ...one, env: { TOKEN: 'secret' } }, a), /environment references/);
    assert.throws(() => m.captureServer({ ...one, extra: '/native' }, { ...a, fields: ['command', 'args', 'extra'] }), /Unsupported MCP field/);
  });
  check('unrelated local MCP definitions survive and edits to owned MCP fields stop preparation', () => {
    const p = m.paths(a);
    const value = yaml.parse(fs.readFileSync(p.mcpFile, 'utf8'));
    value.servers.local = { command: '/local/tool', args: ['private'] };
    value.servers['godot-ai'].options = { claude: { timeout: 500 } };
    file(p.mcpFile, yaml.stringify(value));
    const projected = m.prepare(a);
    assert.equal(yaml.parse(projected.mcp.text).servers.local.command, '/local/tool');
    assert.equal(yaml.parse(projected.mcp.text).servers['godot-ai'].options.claude.timeout, 500);
    value.servers['godot-ai'].args.push('--local-edit');
    file(p.mcpFile, yaml.stringify(value));
    assert.throws(() => m.prepare(a), /Local edit/);
  });
  check('server retirement removes option-only remnants and native entries with recoverable backups', () => {
    const b = fixture('source-retirement');
    const intent = m.loadIntent(b);
    intent.config.mcp.targets = ['claude', 'pi'];
    const servers = {
      retired: { command: { executable: 'uvx' }, args: ['retired'] },
      replacement: { command: { executable: 'uvx' }, args: ['replacement'] },
      kept: { command: { executable: 'uvx' }, args: ['kept'] },
    };
    const first = m.prepare({ ...b, intent, servers });
    m.applyPrepared(first); m.writeState(b, first.state);
    const local = yaml.parse(first.mcp.text);
    local.servers.retired.options = { claude: { timeout: 725 } };
    local.servers.retired.piOptions = { timeout: 45 };
    local.servers.kept.options = { claude: { timeout: 800 } };
    local.servers.personal = { command: process.execPath, args: ['personal'], targets: ['claude'],
      options: { claude: { timeout: 900 } } };
    file(b.mcpFile, yaml.stringify(local));
    native(b, ['sync', 'mcp', '--json', '-g']);
    const claudeFile = path.join(b.home, '.claude.json');
    const piFile = path.join(b.home, '.pi/agent/mcp.json');
    const originalClaude = JSON.parse(fs.readFileSync(claudeFile)).mcpServers;
    const originalPi = JSON.parse(fs.readFileSync(piFile)).mcpServers;
    assert.equal(originalClaude.retired.timeout, 725);
    assert.equal(originalPi.retired.timeout, 45);
    // A complete local replacement must survive after the owned command is removed.
    local.servers.replacement.url = 'https://example.com/replacement';
    file(b.mcpFile, yaml.stringify(local));
    const canonicalFile = path.join(b.root, 'ai/skillshare/mcp.json');
    const canonicalBefore = snapshot([canonicalFile]);
    const before = snapshot([b.home]);
    const retired = m.prepare({ ...b, intent, servers: { kept: servers.kept } });
    assert.deepEqual(snapshot([b.home]), before);
    const projected = yaml.parse(retired.mcp.text).servers;
    assert(!Object.hasOwn(projected, 'retired'));
    assert.deepEqual(projected.replacement, { url: 'https://example.com/replacement' });
    assert.deepEqual(projected.personal, local.servers.personal);
    assert.equal(projected.kept.options.claude.timeout, 800);
    assert(!JSON.stringify(retired.state).includes('725'));
    assert.deepEqual(snapshot([canonicalFile]), canonicalBefore);
    m.applyPrepared(retired); m.writeState(b, retired.state);
    native(b, ['mcp', '--json', '-g']);
    const sync = JSON.parse(native(b, ['sync', 'mcp', '--json', '-g']));
    const afterClaude = JSON.parse(fs.readFileSync(claudeFile)).mcpServers;
    const afterPi = JSON.parse(fs.readFileSync(piFile)).mcpServers;
    assert(!Object.hasOwn(afterClaude, 'retired'));
    assert(!Object.hasOwn(afterPi, 'retired'));
    assert.deepEqual(afterClaude.personal, originalClaude.personal);
    assert.deepEqual(afterClaude.kept, originalClaude.kept);
    assert.equal(afterClaude.replacement.url, 'https://example.com/replacement');
    assert.equal(sync.backupIds.length, 2);
    for (const id of sync.backupIds) native(b, ['mcp', 'restore', id, '--no-tui', '-g']);
    assert.deepEqual(JSON.parse(fs.readFileSync(claudeFile)).mcpServers.retired, originalClaude.retired);
    assert.deepEqual(JSON.parse(fs.readFileSync(piFile)).mcpServers.retired, originalPi.retired);
    assert.equal(fs.readFileSync(b.mcpFile, 'utf8'), retired.mcp.text);
    assert.equal(m.prepare({ ...b, intent, servers: { kept: servers.kept } }).mcp.changed, false);
  });
  check('actual CLI retains personal inline definitions and shared options across a source switch', () => {
    const b = fixture('inline-migration');
    const intent = m.loadIntent(b);
    intent.config.mcp.targets = ['claude', 'codex', 'pi'];
    const servers = { shared: { command: { executable: 'uvx' }, args: ['shared'], options: { claude: { timeout: 900 } } } };
    const shared = { ...m.renderServer(servers.shared, b), targets: ['claude'],
      options: { claude: { timeout: 900, local_setting: 'keep' } }, piOptions: { timeout: 45 } };
    const personal = { command: process.execPath, args: ['personal'], env: { LOCAL_VALUE: 'fixture-local-secret' },
      targets: ['claude'], options: { claude: { timeout: 725 } }, piOptions: { timeout: 40 } };
    file(b.configFile, yaml.stringify({ mcp: { targets: ['claude'], servers: {
      shared, personal, node_repl: { command: process.execPath, args: ['vendor'], targets: [] },
    } } }));
    file(b.mcpFile, yaml.stringify({ servers: {
      existing: { command: process.execPath, args: ['existing'], targets: ['claude'] },
      shared: { options: { claude: { generated_setting: 'keep' } } },
    } }));
    file(path.join(b.home, '.claude.json'), JSON.stringify({ mcpServers: {
      personal: { type: 'stdio', command: personal.command, args: personal.args, env: personal.env, timeout: 725 },
    } }));
    const originalPersonal = fs.readFileSync(path.join(b.home, '.claude.json'), 'utf8');
    native(b, ['sync', 'mcp', '--json', '-g']);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(b.home, '.claude.json'))).mcpServers.personal,
      JSON.parse(originalPersonal).mcpServers.personal);
    const canonicalBefore = fs.readFileSync(path.join(b.root, 'ai/skillshare/mcp.json'), 'utf8');
    const options = { ...b, intent, servers, adoptExisting: true, allowInlineMigration: true };
    const before = snapshot([b.home]);
    const prepared = m.prepare(options);
    assert.deepEqual(snapshot([b.home]), before);
    const generated = yaml.parse(prepared.mcp.text);
    assert.deepEqual(generated.servers.personal, personal);
    assert.equal(generated.servers.existing.args[0], 'existing');
    assert.deepEqual(generated.servers.shared.options.claude, { timeout: 900, generated_setting: 'keep', local_setting: 'keep' });
    assert.deepEqual(generated.servers.shared.piOptions, { timeout: 45 });
    assert(!Object.hasOwn(generated.servers.shared, 'targets'));
    assert(!Object.hasOwn(generated.servers, 'node_repl'));
    assert(!JSON.stringify(prepared.state).includes('fixture-local-secret'));
    assert(prepared.mcp.snapshot.entries.every(entry => entry.path[1] === 'shared'));
    // Retry after publishing the source but before replacing inline configuration.
    file(b.mcpFile, prepared.mcp.text);
    const retry = m.prepare(options);
    assert.equal(retry.mcp.changed, false);
    assert.deepEqual(retry.mcp.snapshot, prepared.mcp.snapshot);
    m.applyPrepared(retry); m.writeState(b, retry.state);
    native(b, ['sync', 'mcp', '--json', '-g']);
    const client = JSON.parse(fs.readFileSync(path.join(b.home, '.claude.json'))).mcpServers;
    assert.deepEqual(client.personal, JSON.parse(originalPersonal).mcpServers.personal);
    assert.equal(client.shared.local_setting, 'keep');
    assert.equal(client.shared.generated_setting, 'keep');
    assert(fs.readFileSync(path.join(b.home, '.codex/config.toml'), 'utf8').includes('[mcp_servers.shared]'));
    const ledger = fs.readFileSync(path.join(path.dirname(b.stateDir), 'skillshare/mcp/state.json'), 'utf8');
    assert(ledger.includes(b.configFile));
    assert(!ledger.includes(b.mcpFile));
    assert(ledger.includes('personal'));
    assert.equal(fs.readFileSync(path.join(b.root, 'ai/skillshare/mcp.json'), 'utf8'), canonicalBefore);
    const again = m.prepare({ ...b, intent, servers });
    assert.equal(again.config.changed, false);
    assert.equal(again.mcp.changed, false);
    const edited = yaml.parse(again.mcp.text);
    edited.servers.personal.args.push('local-edit');
    edited.servers.shared.piOptions.timeout = 60;
    file(b.mcpFile, yaml.stringify(edited));
    assert.doesNotThrow(() => m.prepare({ ...b, intent, servers }));
    native(b, ['sync', 'mcp', '--json', '-g']);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(b.home, '.claude.json'))).mcpServers.personal.args, ['personal', 'local-edit']);
    edited.servers.shared.targets = ['claude'];
    file(b.mcpFile, yaml.stringify(edited));
    assert.throws(() => m.prepare({ ...b, intent, servers }), /Local edit/);
    delete edited.servers.shared.targets;
    edited.servers.shared.options.claude.timeout = 901;
    file(b.mcpFile, yaml.stringify(edited));
    assert.throws(() => m.prepare({ ...b, intent, servers }), /Local edit/);
  });
  check('inline migration rejects local collisions, restores inherited targets and excludes omitted canonical names', () => {
    const b = fixture('inline-collisions');
    const servers = { shared: { command: { executable: 'uvx' }, args: ['canonical'], options: { claude: { timeout: 900 } } } };
    const inline = {
      shared: { command: '/old/shared', args: ['old'], targets: ['claude'], options: { claude: { timeout: 800, local_setting: 'inline' } } },
      personal: { command: '/personal/tool', targets: ['claude'], env: { KEY: 'local' } },
      pending: { command: '/pending/tool', targets: ['claude'] },
    };
    file(b.configFile, yaml.stringify({ mcp: { servers: inline } }));
    const options = { ...b, servers, canonicalNames: ['shared', 'pending'], adoptExisting: true, allowInlineMigration: true };
    file(b.mcpFile, yaml.stringify({ servers: { personal: { ...inline.personal, args: ['different'] } } }));
    const before = snapshot([b.home]);
    assert.throws(() => m.prepare(options), /Local MCP entry collision: personal/);
    assert.deepEqual(snapshot([b.home]), before);
    file(b.mcpFile, yaml.stringify({ servers: { personal: inline.personal,
      shared: { targets: ['claude'], options: { claude: { local_setting: 'generated' } } } } }));
    assert.throws(() => m.prepare(options), /Local MCP entry collision: shared/);
    file(b.mcpFile, yaml.stringify({ servers: { personal: inline.personal, shared: { targets: ['claude'] } } }));
    const prepared = m.prepare(options);
    const generated = yaml.parse(prepared.mcp.text).servers;
    assert.equal(generated.shared.args[0], 'canonical');
    assert.equal(generated.shared.options.claude.timeout, 900);
    assert.equal(generated.shared.options.claude.local_setting, 'inline');
    assert(!Object.hasOwn(generated.shared, 'targets'));
    assert(!Object.hasOwn(generated, 'pending'));
    file(b.mcpFile, `${prepared.before.mcp}# changed after preparation\n`);
    assert.throws(() => m.applyPrepared(prepared), /changed after/);
    assert.equal(fs.readFileSync(b.configFile, 'utf8'), prepared.before.config);
    const empty = m.prepare({ ...options, servers: {} });
    assert.deepEqual(yaml.parse(empty.mcp.text).servers.personal, inline.personal);
    assert(!Object.hasOwn(yaml.parse(empty.mcp.text).servers, 'pending'));
  });
  check('external MCP source switches stop before configuration or target writes', () => {
    const b = fixture('external-source-switch');
    const existing = path.join(b.home, 'existing-mcp.yaml');
    file(existing, yaml.stringify({ servers: { personal: { command: process.execPath, args: ['personal'], targets: ['claude'] } } }));
    file(b.configFile, yaml.stringify({ sources: { skills: path.join(b.root, 'ai/skillshare/skills'), mcp: existing },
      targets: { claude: { skills: { path: path.join(b.home, '.claude/skills') } } }, mcp: { targets: ['claude'] } }));
    native(b, ['sync', 'mcp', '--json', '-g']);
    const before = snapshot([b.home]);
    assert(JSON.parse(fs.readFileSync(path.join(b.home, '.claude.json'))).mcpServers.personal);
    assert.throws(() => m.prepare({ ...b, adoptExisting: true }), /Existing external MCP source requires explicit migration/);
    assert.deepEqual(snapshot([b.home]), before);
    assert(!fs.existsSync(b.mcpFile));
    const deferred = m.prepare({ ...b, adoptExisting: true, deferMcp: true });
    assert.equal(yaml.parse(deferred.config.text).sources.mcp, existing);
    assert.equal(deferred.mcp.changed, false);
    const clean = fixture('mismatched-generated-source');
    const intent = m.loadIntent(clean);
    intent.config.sources.mcp = path.join(clean.home, 'different-generated.yaml');
    assert.throws(() => m.prepare({ ...clean, intent }), /Generated MCP source must match sources.mcp/);
    assert(!fs.existsSync(clean.configFile));
    assert(!fs.existsSync(clean.mcpFile));
  });
  check('deferred MCP keeps inline configuration while native skills and agents can synchronize', () => {
    const b = fixture('deferred-inline');
    const intent = m.loadIntent(b);
    intent.config.targets = { claude: intent.config.targets.claude };
    intent.config.targets.claude.agents.extension = path.join(b.root, 'ai/skillshare/extensions/dotfiles-claude-agents');
    const inline = { personal: { command: '/personal/tool', targets: ['claude'] },
      node_repl: { command: '/vendor/tool', targets: ['codex'] } };
    file(b.configFile, yaml.stringify({ mcp: { targets: ['claude'], servers: inline } }));
    const before = snapshot([b.home]);
    const prepared = m.prepare({ ...b, intent, deferMcp: true, adoptExisting: true, executables: { uvx: '/absent' } });
    assert.deepEqual(snapshot([b.home]), before);
    assert.equal(prepared.mcp.changed, false);
    assert(!Object.hasOwn(prepared.state.projections, 'mcp'));
    m.applyPrepared(prepared); m.writeState(b, prepared.state);
    assert(!fs.existsSync(b.mcpFile));
    const config = yaml.parse(fs.readFileSync(b.configFile, 'utf8'));
    assert.deepEqual(config.mcp, { targets: ['claude'], servers: inline });
    assert(!Object.hasOwn(config.sources, 'mcp'));
    native(b, ['sync', '--json', '-g']);
    native(b, ['sync', 'agents', '--json', '-g']);
    assert(fs.lstatSync(path.join(b.home, '.claude/skills/example')).isSymbolicLink());
    assert(fs.readFileSync(path.join(b.home, '.claude/agents/worker.md'), 'utf8').includes('model:'));
    assert(!fs.existsSync(path.join(b.home, '.claude.json')));
    const ready = m.prepare({ ...b, intent, allowInlineMigration: true });
    m.applyPrepared(ready); m.writeState(b, ready.state);
    assert(!yaml.parse(ready.config.text).mcp.servers);
    assert.deepEqual(yaml.parse(ready.mcp.text).servers.personal, inline.personal);
    assert(!Object.hasOwn(yaml.parse(ready.mcp.text).servers, 'node_repl'));
  });
  check('deferred MCP retains prior ownership and checks drift while skills settings change', () => {
    const b = fixture('deferred-owned');
    const prepared = m.prepare(b);
    m.applyPrepared(prepared); m.writeState(b, prepared.state);
    const intent = m.loadIntent(b);
    intent.config.mode = 'copy';
    intent.config.sources.mcp = `${b.mcpFile}.different`;
    intent.config.mcp.targets = ['claude'];
    const frozen = snapshot([b.mcpFile]);
    const deferred = m.prepare({ ...b, intent, deferMcp: true });
    assert.deepEqual(deferred.state.projections.mcp, prepared.state.projections.mcp);
    const config = yaml.parse(deferred.config.text);
    assert.equal(config.mode, 'copy');
    assert.equal(config.sources.mcp, b.mcpFile);
    assert.deepEqual(config.mcp.targets, prepared.intent.config.mcp.targets);
    m.applyPrepared(deferred); m.writeState(b, deferred.state);
    assert.deepEqual(snapshot([b.mcpFile]), frozen);
    const unchanged = fs.readFileSync(b.configFile, 'utf8');
    for (const field of ['source', 'targets']) {
      const edited = yaml.parse(unchanged);
      if (field === 'source') edited.sources.mcp = '/local/source';
      else edited.mcp.targets = [];
      file(b.configFile, yaml.stringify(edited));
      assert.throws(() => m.prepare({ ...b, intent, deferMcp: true }), /Local edit/);
    }
    file(b.configFile, unchanged);
    const edited = yaml.parse(deferred.mcp.text);
    edited.servers['godot-ai'].args.push('owned-edit');
    file(b.mcpFile, yaml.stringify(edited));
    assert.throws(() => m.prepare({ ...b, intent, deferMcp: true }), /Local edit/);
    file(b.mcpFile, deferred.mcp.text);
    intent.config.sources.mcp = b.mcpFile;
    const ready = m.prepare({ ...b, intent });
    assert.deepEqual(yaml.parse(ready.config.text).mcp.targets, ['claude']);
    assert.deepEqual(ready.mcp.snapshot, prepared.mcp.snapshot);
  });
  check('obsolete/missing CLI, parser or launcher fails before configuration writes', () => {
    for (const kind of ['old', 'missing', 'parser', 'launcher']) {
      const b = fixture(kind);
      if (kind === 'old') { b.skillshare = path.join(b.home, 'old-cli'); file(b.skillshare, '#!/bin/sh\necho "skillshare v0.20.25"\n', 0o755); }
      if (kind === 'missing') b.skillshare = path.join(b.home, 'absent');
      if (kind === 'parser') b.depsDir = path.join(b.home, 'absent');
      if (kind === 'launcher') b.executables.uvx = path.join(b.home, 'absent');
      assert.throws(() => m.prepare(b));
      const p = m.paths(b);
      assert(!fs.existsSync(p.configFile)); assert(!fs.existsSync(p.mcpFile)); assert(!fs.existsSync(p.stateFile));
    }
  });
  check('inline ownership, duplicate YAML, aliases and changed previews fail closed', () => {
    const b = fixture('rejections'); const p = m.paths(b);
    assert.throws(() => m.paths({ ...b, configFile: 'relative.yaml' }), /absolute path/);
    assert.throws(() => m.paths({ ...b, stateFile: p.configFile }), /distinct/);
    for (const text of ['mcp: {servers: {local: {command: local}}}\n', 'mode: copy\nmode: merge\n', 'x: &x {value: 1}\ny: *x\n']) {
      file(p.configFile, text);
      assert.throws(() => m.prepare({ ...b, adoptExisting: true }));
    }
    fs.unlinkSync(p.configFile);
    const prepared = m.prepare(b);
    file(p.configFile, 'unrelated: changed\n');
    assert.throws(() => m.applyPrepared(prepared), /changed after/);
    assert(!fs.existsSync(p.mcpFile));
    fs.unlinkSync(p.configFile);
    fs.symlinkSync(path.join(b.home, 'outside'), p.mcpFile);
    assert.throws(() => m.applyPrepared(prepared), /real configuration/);
    assert(!fs.existsSync(path.join(b.home, 'outside')));
  });
  check('state commits preserve external baselines and occur only at caller success', () => {
    const b = fixture('state'); const p = m.prepare(b);
    m.applyPrepared(p);
    assert(!fs.existsSync(p.paths.stateFile));
    p.state.external['godot-ai'] = { portable: m.loadCanonicalMcp(b)['godot-ai'] };
    m.writeState(b, p.state);
    const next = m.prepare(b);
    assert.deepEqual(next.state.external, p.state.external);
  });
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
  homeGuard.assertUnchanged(before, liveSnapshot());
}
console.log(`${checks} phase 1 checks passed; real-home guard passed`);
