'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const runtime = require('../lib/skillshare-runtime');

const repository = path.resolve(__dirname, '../..');
const fixtures = [];
const write = (file, text) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, text); };
const link = (destination, file) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.symlinkSync(destination, file); };
const read = file => fs.readFileSync(file, 'utf8');
const snapshot = file => runtime.inventory(file).map(entry => ({ ...entry, mtimeMs: fs.lstatSync(path.join(file, entry.path)).mtimeMs }));
const parentEnvironment = { ...process.env };

function fixture() {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare-runtime-'));
  fixtures.push(temporary);
  const home = path.join(temporary, 'home with spaces');
  const root = path.join(home, 'repository with spaces');
  fs.mkdirSync(root, { recursive: true });
  return { temporary, root, home, env: { ...process.env, APPDATA: path.join(home, 'AppData/Roaming') }, configDir: path.join(home, 'config with spaces/skillshare'),
    stateDir: path.join(home, 'state with spaces/dotfiles'), timeout: 30000 };
}

function copyAgents(p) {
  const source = path.join(p.root, 'ai/skillshare');
  fs.mkdirSync(source, { recursive: true });
  for (const item of ['agents', 'extensions', 'agent-models.json']) fs.cpSync(path.join(repository, 'ai/skillshare', item), path.join(source, item), { recursive: true });
  return path.join(source, 'agents');
}

function identity(file, number) {
  const id = `${String(number).padStart(8, '0')}-1111-2222-3333-444444444444`;
  const organization = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  write(file, JSON.stringify({ oauthAccount: { accountUuid: id, organizationUuid: organization, accessToken: 'PRIVATE-NOT-PRINTED' } }));
  return `${organization}_${id}`;
}

function migrationFixture() {
  const p = fixture();
  const source = path.join(p.root, 'ai/skillshare/skills');
  const claude = path.join(p.home, '.claude/skills');
  const gamma = path.join(p.home, '.claude-gamma/skills');
  const codex = path.join(p.home, '.codex/skills');
  const primaryAgents = path.join(p.home, '.claude/agents');
  const gammaAgents = path.join(p.home, '.claude-gamma/agents');
  const alias = path.join(p.configDir, 'skills');
  write(path.join(source, 'maintained/SKILL.md'), 'shared\n');
  link(source, alias);
  for (const target of [claude, gamma, codex]) link(alias, target);
  write(path.join(primaryAgents, 'personal.md'), 'primary-only\n');
  link(primaryAgents, gammaAgents);
  const primaryAccount = path.join(p.home, '.claude.json');
  const gammaAccount = path.join(p.home, '.claude-gamma/.claude.json');
  const primaryBucket = identity(primaryAccount, 1);
  const gammaBucket = identity(gammaAccount, 2);
  write(path.join(source, '.system/vendor/SKILL.md'), 'vendor\0bytes\n');
  fs.chmodSync(path.join(source, '.system/vendor/SKILL.md'), 0o640);
  link('../missing-target', path.join(source, '.system/vendor/broken'));
  write(path.join(source, 'synced', primaryBucket, 'primary/SKILL.md'), 'primary account\n');
  write(path.join(source, 'synced', gammaBucket, 'gamma/SKILL.md'), 'Gamma account\n');
  write(path.join(source, 'synced', `.bucket-${primaryBucket}`), '');
  write(path.join(source, 'synced', `.bucket-${gammaBucket}`), '');
  write(path.join(source, '.trash/old/SKILL.md'), 'quarantined\n');
  const updaterPath = path.join(p.home, '.cua-driver/skills/cua-driver');
  write(path.join(updaterPath, 'SKILL.md'), 'updater owned\n');
  const sourceLink = path.join(source, 'cua-driver');
  link(updaterPath, sourceLink);
  return { ...p, source, claude, gamma, codex, gammaAgents, primaryAgents, primaryBucket, gammaBucket,
    skillsTargets: [claude, gamma, codex].map(file => ({ path: file, knownLinks: [source] })),
    agentTargets: [{ path: gammaAgents, knownLinks: [primaryAgents] }], codexSkillsPath: codex,
    accounts: [{ accountFile: primaryAccount, skillsPath: claude }, { accountFile: gammaAccount, skillsPath: gamma }],
    cuaDriver: { sourceLink, updaterPath } };
}

const realHomeGuard = require('./skillshare-home-guard');
const homeGuard = realHomeGuard.snapshot;

let guard;
before(() => { guard = homeGuard(); });
after(() => {
  try {
    assert(require('node:util').isDeepStrictEqual({ ...process.env }, parentEnvironment), 'parent environment must remain unchanged');
    realHomeGuard.assertUnchanged(guard, homeGuard());
  }
  finally { for (const directory of fixtures) fs.rmSync(directory, { recursive: true, force: true }); }
});

test('native environment pins fixture roots and removes inherited routing and Node injection', () => {
  const p = fixture();
  const base = { ...process.env, CLAUDE_CONFIG_DIR: 'gamma', CODEX_HOME: 'other', OPENCODE_CONFIG_DIR: 'other', PI_CODING_AGENT_DIR: 'other', GROK_HOME: 'other', NODE_OPTIONS: '--require=missing' };
  const before = { ...base };
  const env = runtime.nativeEnv(p, base);
  for (const key of [...runtime.ACCOUNT_OVERRIDES, 'NODE_OPTIONS']) assert.equal(env[key], undefined);
  assert.equal(env.HOME, p.home);
  assert.equal(env.SKILLSHARE_CONFIG, path.join(p.configDir, 'config.yaml'));
  assert.equal(env.XDG_CONFIG_HOME, path.dirname(p.configDir));
  assert(require('node:util').isDeepStrictEqual(base, before), 'input environment must remain unchanged');
  assert.throws(() => runtime.runNative(['sync', '-g'], { ...p, dryRun: true }), /Dry-run cannot execute/);
});

test('migration dry-run has no writes, preserves all types, and isolates vendor/account content', () => {
  const p = migrationFixture();
  const before = snapshot(p.temporary);
  const sourceBefore = runtime.inventory(p.source);
  const system = runtime.inventory(path.join(p.source, '.system'));
  const trash = runtime.inventory(path.join(p.source, '.trash'));
  const updater = runtime.inventory(p.cuaDriver.updaterPath);
  const preview = runtime.migrateRuntime({ ...p, dryRun: true });
  assert.equal(preview.moves.length, 5);
  assert.deepEqual(snapshot(p.temporary), before);
  const result = runtime.migrateRuntime(p);
  for (const target of [p.claude, p.gamma, p.codex, p.gammaAgents]) {
    assert.ok(fs.lstatSync(target).isDirectory()); assert.ok(!fs.lstatSync(target).isSymbolicLink());
  }
  assert.deepEqual(runtime.inventory(path.join(p.codex, '.system')), system);
  assert.equal(read(path.join(p.claude, 'synced', p.primaryBucket, 'primary/SKILL.md')), 'primary account\n');
  assert.equal(read(path.join(p.gamma, 'synced', p.gammaBucket, 'gamma/SKILL.md')), 'Gamma account\n');
  assert.equal(read(path.join(p.gamma, 'synced', `.bucket-${p.gammaBucket}`)), '');
  assert.ok(!fs.existsSync(path.join(p.gamma, 'synced', p.primaryBucket)));
  assert.equal(read(path.join(p.primaryAgents, 'personal.md')), 'primary-only\n');
  assert.ok(!fs.existsSync(path.join(p.gammaAgents, 'personal.md')));
  for (const name of ['.system', 'synced', '.trash']) assert.ok(!fs.existsSync(path.join(p.source, name)));
  const records = JSON.parse(read(path.join(result.backupDir, 'manifest.json')));
  const trashBackup = records.find(record => record.file === path.join(p.source, '.trash'));
  assert.deepEqual(runtime.inventory(trashBackup.saved), trash);
  assert.deepEqual(runtime.inventory(p.cuaDriver.updaterPath), updater);
  assert.ok(!path.isAbsolute(fs.readlinkSync(p.cuaDriver.sourceLink)));
  assert.equal(fs.realpathSync(p.cuaDriver.sourceLink), fs.realpathSync(p.cuaDriver.updaterPath));
  const migrated = snapshot(p.temporary);
  assert.equal(runtime.migrateRuntime(p).changed, false);
  assert.deepEqual(snapshot(p.temporary), migrated);
  runtime.restoreBackup(result.backupDir, { ...p, dryRun: true });
  assert.deepEqual(snapshot(p.temporary), migrated);
  runtime.restoreBackup(result.backupDir, p);
  assert.deepEqual(runtime.inventory(p.source), sourceBefore);
  assert.ok(fs.lstatSync(p.gammaAgents).isSymbolicLink());
});

test('unknown account bucket and unknown whole-directory links stop before any writes', () => {
  const p = migrationFixture();
  write(path.join(p.source, 'synced/unknown/SKILL.md'), 'unknown account');
  const before = snapshot(p.temporary);
  assert.throws(() => runtime.migrateRuntime(p), /Unknown Claude synced bucket ownership/);
  assert.deepEqual(snapshot(p.temporary), before);
  fs.rmSync(path.join(p.source, 'synced/unknown'), { recursive: true });
  fs.unlinkSync(p.gamma);
  link(p.primaryAgents, p.gamma);
  const changed = snapshot(p.temporary);
  assert.throws(() => runtime.migrateRuntime(p), /Unknown whole-directory link/);
  assert.deepEqual(snapshot(p.temporary), changed);
});

test('migration preserves existing local collisions and backs up original source bytes', () => {
  const p = migrationFixture();
  fs.unlinkSync(p.codex);
  write(path.join(p.codex, '.system/vendor/SKILL.md'), 'local vendor stays');
  link('/outside/keep-destination', path.join(p.codex, '.system/vendor/broken'));
  const before = snapshot(p.temporary);
  assert.equal(runtime.migrateRuntime({ ...p, dryRun: true }).collisions.length, 2);
  assert.deepEqual(snapshot(p.temporary), before);
  const result = runtime.migrateRuntime(p);
  assert.equal(result.collisions.length, 2);
  assert.equal(read(path.join(p.codex, '.system/vendor/SKILL.md')), 'local vendor stays');
  assert.equal(fs.readlinkSync(path.join(p.codex, '.system/vendor/broken')), '/outside/keep-destination');
  const records = JSON.parse(read(path.join(result.backupDir, 'manifest.json')));
  const original = records.find(record => record.file === path.join(p.source, '.system'));
  assert.equal(read(path.join(original.saved, 'vendor/SKILL.md')), 'vendor\0bytes\n');
});

function nativeFixture() {
  const p = fixture();
  const source = copyAgents(p);
  const targets = [
    { name: 'claude', provider: 'claude', path: path.join(p.home, '.claude/agents') },
    { name: 'claude-gamma', provider: 'claude', path: path.join(p.home, '.claude-gamma/agents') },
    { name: 'codex', provider: 'codex', path: path.join(p.home, '.codex/agents') },
  ];
  const extensionDir = path.join(p.configDir, 'extensions');
  for (const provider of ['claude', 'codex']) {
    const name = `dotfiles-${provider}-agents`;
    fs.mkdirSync(path.join(extensionDir, name), { recursive: true });
    for (const file of ['extension.yaml', 'convert.js']) link(path.join(p.root, 'ai/skillshare/extensions', name, file), path.join(extensionDir, name, file));
  }
  // Config is a fixture literal. The runtime helpers do not parse or duplicate YAML intent.
  const q = JSON.stringify;
  const lines = ['sources:', `  skills: ${q(path.join(p.root, 'ai/skillshare/skills'))}`, `  agents: ${q(source)}`, 'mode: merge', 'follow_source_links: true', 'targets:'];
  for (const target of targets) lines.push(`  ${target.name}:`, ...(target.name === 'claude-gamma' ? ['    agent: claude', `    config_dir: ${q(path.join(p.home, '.claude-gamma'))}`] : []), '    skills:', `      path: ${q(path.join(p.home, target.name === 'codex' ? '.codex' : target.name === 'claude' ? '.claude' : '.claude-gamma', 'skills'))}`, '      mode: merge', '    agents:', `      path: ${q(target.path)}`, '      mode: copy', `      extension: dotfiles-${target.provider}-agents`);
  lines.push('  universal:', '    skills:', `      path: ${q(path.join(p.home, '.agents/skills'))}`, '      mode: merge', '    agents:', '      exclude: ["*"]');
  write(path.join(p.configDir, 'config.yaml'), `${lines.join('\n')}\n`);
  write(path.join(p.root, 'ai/skillshare/skills/shared/SKILL.md'), '---\nname: shared\ndescription: Fixture skill\n---\nShared fixture.\n');
  for (const target of targets) {
    write(path.join(target.path, target.provider === 'codex' ? 'personal.toml' : 'personal.md'), 'personal stays\n');
    write(path.join(target.path, target.provider === 'codex' ? 'worker.toml' : 'worker.md'), `legacy ${target.name}\n`);
  }
  const overrides = {};
  for (const key of runtime.ACCOUNT_OVERRIDES) overrides[key] = path.join(p.home, 'wrong account', key);
  return { ...p, source, targets, env: { ...p.env, ...overrides, NODE_OPTIONS: '--require=/must/not/load' } };
}

test('actual Skillshare >=0.26.4: native accounts, mapping drift, direct edits, pruning, and local skills', () => {
  const p = nativeFixture();
  assert.match(runtime.requireSupportedSkillshare(p), /^\d+\.\d+\.\d+$/);
  const before = snapshot(p.temporary);
  assert.equal(runtime.syncNativeAgents({ ...p, dryRun: true }).changed.length, 6);
  assert.deepEqual(snapshot(p.temporary), before);
  const first = runtime.syncNativeAgents(p);
  for (const output of runtime.renderAgents(p)) assert.equal(read(output.path), output.content);
  for (const target of p.targets) assert.equal(read(path.join(target.path, target.provider === 'codex' ? 'personal.toml' : 'personal.md')), 'personal stays\n');
  const records = JSON.parse(read(path.join(first.backupDir, 'manifest.json')));
  for (const [index, target] of p.targets.entries()) assert.equal(read(path.join(records[index].saved, target.provider === 'codex' ? 'worker.toml' : 'worker.md')), `legacy ${target.name}\n`);
  const mappingFile = path.join(p.root, 'ai/skillshare/agent-models.json');
  const mapping = JSON.parse(read(mappingFile));
  mapping.worker.claude.effort = 'max';
  mapping.worker.codex.model_reasoning_effort = 'max';
  write(mappingFile, JSON.stringify(mapping));
  runtime.syncNativeAgents(p);
  assert.match(read(path.join(p.targets[1].path, 'worker.md')), /effort: "max"/);
  write(path.join(p.targets[0].path, 'worker.md'), 'direct output edit');
  runtime.syncNativeAgents(p);
  assert.match(read(path.join(p.targets[0].path, 'worker.md')), /effort: "max"/);
  fs.unlinkSync(path.join(p.source, 'fastworker.md'));
  delete mapping.fastworker;
  write(mappingFile, JSON.stringify(mapping));
  runtime.syncNativeAgents(p);
  for (const target of p.targets) assert.ok(!fs.existsSync(path.join(target.path, target.provider === 'codex' ? 'fastworker.toml' : 'fastworker.md')));
  runtime.runNative(['sync', '-g', '--json'], p);
  assert.equal(fs.realpathSync(path.join(p.home, '.claude-gamma/skills/shared')), fs.realpathSync(path.join(p.root, 'ai/skillshare/skills/shared')));
  write(path.join(p.home, '.claude-gamma/skills/local/SKILL.md'), 'Gamma local stays');
  write(path.join(p.root, 'ai/skillshare/skills/shared/SKILL.md'), 'source update');
  assert.equal(read(path.join(p.home, '.claude-gamma/skills/shared/SKILL.md')), 'source update');
  assert.equal(read(path.join(p.home, '.claude-gamma/skills/local/SKILL.md')), 'Gamma local stays');
  write(path.join(p.root, 'ai/skillshare/skills/added/SKILL.md'), '---\nname: added\ndescription: Added fixture\n---\nNew.\n');
  runtime.runNative(['sync', '-g', '--json'], p);
  assert.ok(fs.lstatSync(path.join(p.home, '.claude-gamma/skills/added')).isSymbolicLink());
  fs.rmSync(path.join(p.root, 'ai/skillshare/skills/added'), { recursive: true });
  runtime.runNative(['sync', '-g', '--json'], p);
  assert.ok(!fs.existsSync(path.join(p.home, '.claude-gamma/skills/added')));
  assert.ok(!fs.existsSync(path.join(p.home, '.agents/agents/worker.md')));
  assert.ok(!fs.existsSync(path.join(p.home, 'wrong account')));
});

test('invalid mapping leaves current outputs untouched; native publication failure restores working directories', () => {
  const p = nativeFixture();
  runtime.syncNativeAgents(p);
  const mapFile = path.join(p.root, 'ai/skillshare/agent-models.json');
  const validMap = read(mapFile);
  const before = p.targets.map(target => runtime.inventory(target.path));
  write(mapFile, '{}');
  assert.throws(() => runtime.syncNativeAgents(p), /Subprocess failed/);
  assert.deepEqual(p.targets.map(target => runtime.inventory(target.path)), before);
  write(mapFile, validMap);
  // Pre-render uses the real converter; native extension execution fails after removing an existing output.
  const extensionFile = path.join(p.root, 'ai/skillshare/extensions/dotfiles-claude-agents/extension.yaml');
  const validExtension = read(extensionFile);
  write(extensionFile, 'run: ["sh", "-c", "exit 7"]\noutput_ext: md\n');
  let failure;
  try { runtime.syncNativeAgents(p); } catch (error) { failure = error; }
  assert.ok(failure, 'native conversion failure must be reported');
  assert.equal(failure.recoveryError, undefined);
  assert.deepEqual(p.targets.map(target => runtime.inventory(target.path)), before);
  assert.ok(fs.existsSync(path.join(failure.backupDir, 'manifest.json')));
  write(extensionFile, validExtension);
  runtime.syncNativeAgents(p);
  assert.deepEqual(p.targets.map(target => runtime.inventory(target.path)), before);
});


test('native target mismatch stops before publication or backup', () => {
  const p = nativeFixture();
  const configFile = path.join(p.configDir, 'config.yaml');
  write(configFile, read(configFile).replace(p.targets[1].path, path.join(p.home, 'wrong-output')));
  const before = snapshot(p.temporary);
  assert.throws(() => runtime.syncNativeAgents(p), /destination does not match intent/);
  assert.deepEqual(snapshot(p.temporary), before);
});

test('symlink parents and non-file agent output collisions are rejected without writes', () => {
  const p = nativeFixture();
  fs.mkdirSync(path.join(p.home, 'elsewhere'), { recursive: true });
  fs.rmSync(path.join(p.home, '.claude-gamma'), { recursive: true });
  link(path.join(p.home, 'elsewhere'), path.join(p.home, '.claude-gamma'));
  const before = snapshot(p.temporary);
  assert.throws(() => runtime.syncNativeAgents(p), /Unsafe resource parent/);
  assert.deepEqual(snapshot(p.temporary), before);
  fs.unlinkSync(path.join(p.home, '.claude-gamma'));
  fs.mkdirSync(path.join(p.targets[1].path, 'worker.md'), { recursive: true });
  assert.throws(() => runtime.syncNativeAgents(p), /non-file resource/);
  p.targets[1].path = path.join(p.targets[0].path, 'nested');
  assert.throws(() => runtime.syncNativeAgents(p), /directories overlap/);
});


test('actual Skillshare discovers the portable cua-driver link without vendor-source leakage', () => {
  const p = migrationFixture();
  runtime.requireSupportedSkillshare(p);
  runtime.migrateRuntime(p);
  write(path.join(p.configDir, 'config.yaml'), [
    'sources:', `  skills: ${JSON.stringify(p.source)}`, 'mode: merge', 'follow_source_links: true',
    'ignore: [".system/", "synced/", ".trash/"]', 'targets:', '  claude:', '    skills:',
    `      path: ${JSON.stringify(p.claude)}`, '      mode: merge',
  ].join('\n') + '\n');
  const listed = runtime.runNative(['list', '--json', '-g'], p).stdout;
  assert.match(listed, /cua-driver/);
  assert.ok(!listed.includes('quarantined'));
  runtime.runNative(['sync', '-g', '--json'], p);
  assert.equal(fs.realpathSync(path.join(p.claude, 'cua-driver')), fs.realpathSync(p.cuaDriver.updaterPath));
  assert.equal(read(path.join(p.claude, 'cua-driver/SKILL.md')), 'updater owned\n');
  // A native updater replaces its own directory; the generated source and managed target links survive.
  fs.rmSync(p.cuaDriver.updaterPath, { recursive: true });
  write(path.join(p.cuaDriver.updaterPath, 'SKILL.md'), 'native rewrite simulation\n');
  assert.equal(read(path.join(p.claude, 'cua-driver/SKILL.md')), 'native rewrite simulation\n');
});


test('generated output symlinks are backed up and replaced without writing through to source', () => {
  const p = nativeFixture();
  const output = path.join(p.targets[0].path, 'worker.md');
  fs.unlinkSync(output);
  link(path.join(p.source, 'worker.md'), output);
  const source = snapshot(p.source);
  const result = runtime.syncNativeAgents(p);
  assert.deepEqual(snapshot(p.source), source);
  assert.ok(fs.lstatSync(output).isFile());
  const records = JSON.parse(read(path.join(result.backupDir, 'manifest.json')));
  const saved = records.find(record => record.file === p.targets[0].path).saved;
  assert.equal(fs.readlinkSync(path.join(saved, 'worker.md')), path.join(p.source, 'worker.md'));
});


test('a target cannot authorize its own unknown directory link', () => {
  const p = fixture();
  const source = path.join(p.root, 'skills');
  const target = path.join(p.home, '.claude/skills');
  const foreign = path.join(p.home, 'unowned');
  write(path.join(source, 'shared/SKILL.md'), 'shared');
  write(path.join(foreign, 'private.md'), 'private');
  link(foreign, target);
  assert.throws(() => runtime.migrateRuntime({ ...p, source, skillsTargets: [{ path: target, knownLinks: [target] }] }), /Unknown whole-directory link/);
  assert(fs.lstatSync(target).isSymbolicLink());
  assert.equal(read(path.join(foreign, 'private.md')), 'private');
});
