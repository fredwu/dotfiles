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
  const alias = path.join(p.configDir, 'skills');
  write(path.join(source, 'maintained/SKILL.md'), 'shared\n');
  link(source, alias);
  for (const target of [claude, gamma, codex]) link(alias, target);
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
  return { ...p, source, claude, gamma, codex, primaryBucket, gammaBucket,
    skillsTargets: [claude, gamma, codex].map(file => ({ path: file, knownLinks: [source] })),
    codexSkillsPath: codex,
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
  for (const target of [p.claude, p.gamma, p.codex]) {
    assert.ok(fs.lstatSync(target).isDirectory()); assert.ok(!fs.lstatSync(target).isSymbolicLink());
  }
  assert.deepEqual(runtime.inventory(path.join(p.codex, '.system')), system);
  assert.equal(read(path.join(p.claude, 'synced', p.primaryBucket, 'primary/SKILL.md')), 'primary account\n');
  assert.equal(read(path.join(p.gamma, 'synced', p.gammaBucket, 'gamma/SKILL.md')), 'Gamma account\n');
  assert.equal(read(path.join(p.gamma, 'synced', `.bucket-${p.gammaBucket}`)), '');
  assert.ok(!fs.existsSync(path.join(p.gamma, 'synced', p.primaryBucket)));
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
});

test('unknown account bucket and unknown whole-directory links stop before any writes', () => {
  const p = migrationFixture();
  write(path.join(p.source, 'synced/unknown/SKILL.md'), 'unknown account');
  const before = snapshot(p.temporary);
  assert.throws(() => runtime.migrateRuntime(p), /Unknown Claude synced bucket ownership/);
  assert.deepEqual(snapshot(p.temporary), before);
  fs.rmSync(path.join(p.source, 'synced/unknown'), { recursive: true });
  fs.unlinkSync(p.gamma);
  const foreign = path.join(p.home, 'foreign-skills');
  write(path.join(foreign, 'personal.md'), 'keep\n');
  link(foreign, p.gamma);
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

function nativeSkillsFixture() {
  const p = fixture();
  const q = JSON.stringify;
  const lines = ['sources:', `  skills: ${q(path.join(p.root, 'ai/skillshare/skills'))}`, 'mode: merge', 'follow_source_links: true', 'targets:',
    '  claude:', '    skills:', `      path: ${q(path.join(p.home, '.claude/skills'))}`, '      mode: merge',
    '  claude-gamma:', '    agent: claude', `    config_dir: ${q(path.join(p.home, '.claude-gamma'))}`,
    '    skills:', `      path: ${q(path.join(p.home, '.claude-gamma/skills'))}`, '      mode: merge',
    '  universal:', '    skills:', `      path: ${q(path.join(p.home, '.agents/skills'))}`, '      mode: merge'];
  write(path.join(p.configDir, 'config.yaml'), `${lines.join('\n')}\n`);
  write(path.join(p.root, 'ai/skillshare/skills/shared/SKILL.md'), '---\nname: shared\ndescription: Fixture skill\n---\nShared fixture.\n');
  const overrides = {};
  for (const key of runtime.ACCOUNT_OVERRIDES) overrides[key] = path.join(p.home, 'wrong account', key);
  return { ...p, env: { ...p.env, ...overrides, NODE_OPTIONS: '--require=/must/not/load' } };
}

test('actual Skillshare >=0.29.1: native accounts sync shared skills while preserving local skills', () => {
  const p = nativeSkillsFixture();
  assert.match(runtime.requireSupportedSkillshare(p), /^\d+\.\d+\.\d+$/);
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
  assert.ok(!fs.existsSync(path.join(p.home, 'wrong account')));
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
