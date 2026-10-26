'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const { ACCOUNT_OVERRIDES } = require('./skillshare-config');

function settings(options) {
  for (const key of ['root', 'home']) {
    if (!path.isAbsolute(options[key] || '')) throw new Error(`${key} must be an absolute path`);
  }
  const configDir = absolute(options.configDir || path.join(options.home, '.config/skillshare'));
  const stateDir = absolute(options.stateDir || path.join(options.home, '.local/state/dotfiles'));
  if (options.configFile) absolute(options.configFile);
  return { ...options, configDir, stateDir, configFile: options.configFile || path.join(configDir, 'config.yaml') };
}

function nativeEnv(options, base = process.env) {
  const p = settings(options);
  const env = { ...base, HOME: p.home, SKILLSHARE_CONFIG: p.configFile,
    XDG_CONFIG_HOME: p.xdgConfigHome || path.dirname(p.configDir),
    XDG_STATE_HOME: p.xdgStateHome || path.dirname(p.stateDir),
    XDG_CACHE_HOME: p.xdgCacheHome || path.join(p.home, '.cache'),
    XDG_DATA_HOME: p.xdgDataHome || path.join(p.home, '.local/share') };
  for (const key of [...ACCOUNT_OVERRIDES, 'NODE_OPTIONS']) delete env[key];
  return env;
}

function execute(command, args, options, extra = {}) {
  const result = spawnSync(command, args, { cwd: options.home, env: nativeEnv(options, options.env || process.env),
    encoding: 'utf8', timeout: options.timeout || 120000, maxBuffer: 16 * 1024 * 1024, ...extra });
  if (result.error || result.status !== 0) {
    // Native output can include private configuration. Leave it available to the caller, not in the message.
    const error = new Error(`Subprocess failed: ${path.basename(command)} (status ${result.status})`);
    error.result = result;
    throw error;
  }
  return result;
}

function runNative(args, options) {
  if (options.dryRun && !['--version', 'status', 'list', 'analyze', 'diff'].includes(args[0])) {
    throw new Error('Dry-run cannot execute a native mutation; use a managed render preview');
  }
  return execute(options.skillshare || 'skillshare', args, settings(options));
}

function requireSupportedSkillshare(options) {
  const result = runNative(['--version'], options);
  const match = /^skillshare v(\d+)\.(\d+)\.(\d+)(?:\s|$)/m.exec(result.stdout);
  if (!match) throw new Error('Cannot determine Skillshare version');
  const actual = match.slice(1).map(Number);
  const minimum = [0, 26, 4];
  const different = actual.findIndex((value, index) => value !== minimum[index]);
  if (different !== -1 && actual[different] < minimum[different]) throw new Error('Skillshare 0.26.4 or newer is required');
  return actual.join('.');
}

function stat(file) {
  try { return fs.lstatSync(file); } catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}

function absolute(file) {
  if (!path.isAbsolute(file || '')) throw new Error('An absolute resource path is required');
  return path.normalize(file);
}

function within(file, directory) {
  const relative = path.relative(directory, file);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function safeParents(file) {
  let current = path.dirname(absolute(file));
  while (current !== path.dirname(current)) {
    const info = stat(current);
    const systemAlias = process.platform === 'darwin' && ['/var', '/tmp', '/etc'].includes(current) &&
      info?.isSymbolicLink() && fs.realpathSync(current) === `/private${current}`;
    if (info && !systemAlias && (!info.isDirectory() || info.isSymbolicLink())) throw new Error(`Unsafe resource parent: ${current}`);
    current = path.dirname(current);
  }
}

// Inventory never follows links; it accounts for link destinations as stored, not resolved content.
function inventory(file) {
  const entries = [];
  function visit(current, relative) {
    const info = stat(current);
    if (!info) return;
    const entry = { path: relative, mode: info.mode & 0o7777 };
    if (info.isSymbolicLink()) Object.assign(entry, { type: 'link', link: fs.readlinkSync(current) });
    else if (info.isDirectory()) entry.type = 'directory';
    else if (info.isFile()) Object.assign(entry, { type: 'file', sha256: crypto.createHash('sha256').update(fs.readFileSync(current)).digest('hex') });
    else throw new Error(`Unsupported resource type: ${current}`);
    entries.push(entry);
    if (info.isDirectory()) for (const name of fs.readdirSync(current).sort()) visit(path.join(current, name), relative ? `${relative}/${name}` : name);
  }
  visit(file, '');
  return entries;
}

function same(left, right) { return JSON.stringify(inventory(left)) === JSON.stringify(inventory(right)); }

function copyNode(source, destination) {
  const info = fs.lstatSync(source);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.cpSync(source, destination, { recursive: true, dereference: false, verbatimSymlinks: true, preserveTimestamps: true });
  if (!info.isSymbolicLink()) fs.chmodSync(destination, info.mode & 0o7777);
  if (!same(source, destination)) throw new Error('Backup verification failed');
}

function backupNodes(files, options) {
  const p = settings(options);
  const unique = [...new Set(files.map(absolute))].filter((file, _, all) => !all.some(other => other !== file && within(file, other)));
  const parent = path.join(p.stateDir, 'skillshare-runtime-backups');
  if (unique.some(file => within(parent, file))) throw new Error('Backup storage overlaps an affected resource');
  safeParents(path.join(parent, 'snapshot'));
  fs.mkdirSync(parent, { recursive: true });
  const directory = fs.mkdtempSync(path.join(parent, 'snapshot-'));
  const records = unique.map((file, index) => {
    const content = inventory(file);
    const saved = path.join(directory, String(index));
    if (content.length) copyNode(file, saved);
    return { file, saved, content };
  });
  fs.writeFileSync(path.join(directory, 'manifest.json'), `${JSON.stringify(records, null, 2)}\n`, { mode: 0o600 });
  return { directory, records };
}

function restoreBackup(backup, options) {
  settings(options);
  const records = typeof backup === 'string' ? JSON.parse(fs.readFileSync(path.join(backup, 'manifest.json'), 'utf8')) : backup.records;
  for (const record of records) {
    absolute(record.file);
    safeParents(record.file);
    if (JSON.stringify(inventory(record.saved)) !== JSON.stringify(record.content)) throw new Error('Backup content changed; recovery stopped');
  }
  if (options.dryRun) return { dryRun: true, paths: records.map(record => record.file) };
  for (const record of records) {
    fs.rmSync(record.file, { recursive: true, force: true });
    if (record.content.length) copyNode(record.saved, record.file);
  }
}

function realDirectoryPlan(target) {
  absolute(target.path);
  safeParents(target.path);
  const info = stat(target.path);
  if (!info || (info.isDirectory() && !info.isSymbolicLink())) return { path: target.path, detach: false, create: !info };
  if (!info.isSymbolicLink()) throw new Error(`Runtime directory is not a directory: ${target.path}`);
  const destination = path.resolve(path.dirname(target.path), fs.readlinkSync(target.path));
  const known = (target.knownLinks || []).some(link => {
    absolute(link);
    if (path.resolve(link) === path.resolve(target.path)) return false;
    if (destination === path.normalize(link)) return true;
    try { return fs.realpathSync(destination) === fs.realpathSync(link); } catch { return false; }
  });
  if (!known) throw new Error(`Unknown whole-directory link: ${target.path}`);
  return { path: target.path, detach: true, link: fs.readlinkSync(target.path) };
}

function accountBuckets(accounts) {
  const owners = new Map();
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  for (const account of accounts) {
    absolute(account.accountFile);
    absolute(account.skillsPath);
    let identity;
    try { identity = JSON.parse(fs.readFileSync(account.accountFile, 'utf8')).oauthAccount; }
    catch { throw new Error('Cannot read a declared Claude account identity'); }
    if (!identity || !uuid.test(identity.accountUuid) || !uuid.test(identity.organizationUuid)) throw new Error('Declared Claude account has no valid bucket identity');
    const bucket = `${identity.organizationUuid}_${identity.accountUuid}`;
    if (owners.has(bucket)) throw new Error('Claude bucket ownership is ambiguous');
    owners.set(bucket, account.skillsPath);
  }
  return owners;
}

function findCollisions(source, destination) {
  const collisions = [];
  if (!stat(destination)) return collisions;
  if (stat(source).isDirectory() && stat(destination).isDirectory()) {
    for (const name of fs.readdirSync(source)) collisions.push(...findCollisions(path.join(source, name), path.join(destination, name)));
  } else if (!same(source, destination)) collisions.push({ source, destination });
  return collisions;
}

function mergePreserving(source, destination, collisions) {
  if (!stat(destination)) {
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    // Copy, verify and remove supports a source and a runtime on different filesystems.
    copyNode(source, destination);
    fs.rmSync(source, { recursive: true, force: true });
    return;
  }
  const sourceInfo = fs.lstatSync(source);
  const destinationInfo = fs.lstatSync(destination);
  if (sourceInfo.isDirectory() && destinationInfo.isDirectory()) {
    for (const name of fs.readdirSync(source)) mergePreserving(path.join(source, name), path.join(destination, name), collisions);
  } else if (!same(source, destination)) collisions.push({ source, destination });
  // The complete original source is in the verified backup, including colliding entries.
  fs.rmSync(source, { recursive: true, force: true });
}

function migrateRuntime(options) {
  const p = settings(options);
  const source = absolute(p.source || path.join(p.root, 'ai/skillshare/skills'));
  if (!stat(source)?.isDirectory() || stat(source).isSymbolicLink()) throw new Error('Skills source must be a real directory');
  safeParents(source);
  const directories = [...(p.skillsTargets || []), ...(p.agentTargets || [])].map(realDirectoryPlan);
  const paths = new Set(directories.map(target => path.normalize(target.path)));
  if (paths.size !== directories.length) throw new Error('Duplicate runtime directories');
  for (const left of directories) for (const right of directories) {
    if (left !== right && within(left.path, right.path)) throw new Error('Runtime directories overlap');
  }
  for (const target of directories) if (within(target.path, source) || within(source, target.path)) throw new Error('Runtime directory overlaps source');
  const moves = [];
  const system = path.join(source, '.system');
  if (stat(system)) {
    const destination = absolute(p.codexSkillsPath);
    if (!paths.has(destination)) throw new Error('Codex skills directory must be an explicit runtime target');
    moves.push({ source: system, destination: path.join(destination, '.system') });
  }
  const synced = path.join(source, 'synced');
  if (stat(synced)) {
    if (!stat(synced).isDirectory() || stat(synced).isSymbolicLink()) throw new Error('Synced buckets must be a real directory');
    const owners = accountBuckets(p.accounts || []);
    for (const bucket of fs.readdirSync(synced).sort()) {
      const identity = bucket.startsWith('.bucket-') ? bucket.slice(8) : bucket;
      const owner = owners.get(identity);
      if (!owner) throw new Error('Unknown Claude synced bucket ownership; migration stopped');
      if (bucket.startsWith('.bucket-') && !fs.lstatSync(path.join(synced, bucket)).isFile()) throw new Error('Unexpected Claude bucket marker');
      if (!paths.has(path.normalize(owner))) throw new Error('Account skills directory must be an explicit runtime target');
      moves.push({ source: path.join(synced, bucket), destination: path.join(owner, 'synced', bucket) });
    }
  }
  const trash = path.join(source, '.trash');
  const cua = p.cuaDriver;
  if (cua) {
    absolute(cua.sourceLink); absolute(cua.updaterPath);
    safeParents(cua.sourceLink);
    if (!within(cua.sourceLink, source) || cua.sourceLink === source) throw new Error('cua-driver source link must be inside the source');
    if (!stat(cua.updaterPath)?.isDirectory() || stat(cua.updaterPath).isSymbolicLink() || !stat(path.join(cua.updaterPath, 'SKILL.md'))?.isFile()) throw new Error('cua-driver updater-owned skill is unavailable');
    const current = stat(cua.sourceLink);
    if (current && (!current.isSymbolicLink() || path.resolve(path.dirname(cua.sourceLink), fs.readlinkSync(cua.sourceLink)) !== cua.updaterPath)) throw new Error('cua-driver source collision');
  }
  // Validate every path and supported file type before the first write.
  for (const move of moves) {
    inventory(move.source);
    const target = directories.find(directory => within(move.destination, directory.path));
    if (!target.detach) safeParents(move.destination);
  }
  const affected = [...directories.map(target => target.path), ...moves.map(move => move.source),
    ...(stat(synced) ? [synced] : []), ...(stat(trash) ? [trash] : []), ...(cua ? [cua.sourceLink] : [])];
  for (const file of affected) inventory(file);
  const collisions = moves.flatMap(move => directories.find(target => within(move.destination, target.path)).detach ? [] : findCollisions(move.source, move.destination));
  const changed = directories.some(target => target.detach || target.create) || moves.length > 0 || !!stat(trash) ||
    !!(cua && (!stat(cua.sourceLink) || fs.readlinkSync(cua.sourceLink) !== path.relative(path.dirname(cua.sourceLink), cua.updaterPath)));
  const result = { dryRun: !!p.dryRun, changed, directories, moves, quarantine: stat(trash) ? [trash] : [], collisions: p.dryRun ? collisions : [] };
  if (p.dryRun || !changed) return result;
  const backup = backupNodes(affected, p);
  result.backupDir = backup.directory;
  try {
    for (const target of directories) {
      if (target.detach) fs.unlinkSync(target.path);
      fs.mkdirSync(target.path, { recursive: true });
    }
    for (const move of moves) {
      safeParents(move.destination);
      mergePreserving(move.source, move.destination, result.collisions);
    }
    if (stat(synced)) fs.rmdirSync(synced);
    if (stat(trash)) fs.rmSync(trash, { recursive: true });
    if (cua) {
      if (stat(cua.sourceLink)) fs.unlinkSync(cua.sourceLink);
      fs.symlinkSync(path.relative(path.dirname(cua.sourceLink), cua.updaterPath), cua.sourceLink);
    }
    return result;
  } catch (error) {
    try { restoreBackup(backup, p); } catch (recoveryError) { error.recoveryError = recoveryError; }
    error.backupDir = backup.directory;
    throw error;
  }
}

function renderAgents(options) {
  const p = settings(options);
  const source = absolute(p.source || path.join(p.root, 'ai/skillshare/agents'));
  const extensions = path.join(p.root, 'ai/skillshare/extensions');
  execute(process.execPath, [path.join(extensions, 'dotfiles-agent-transform/validate.js'), source], p);
  const files = fs.readdirSync(source).filter(file => file.endsWith('.md')).sort();
  const outputs = [];
  const destinations = new Set();
  if (!(p.targets || []).length) throw new Error('Explicit native agent targets are required');
  for (const left of p.targets) for (const right of p.targets) {
    absolute(left.path); absolute(right.path);
    if (left !== right && within(left.path, right.path)) throw new Error('Native agent target directories overlap');
  }
  for (const target of p.targets) {
    absolute(target.path);
    safeParents(target.path);
    if (!['claude', 'codex'].includes(target.provider)) throw new Error('Unsupported agent provider');
    const info = stat(target.path);
    if (info && (!info.isDirectory() || info.isSymbolicLink())) throw new Error('Native agent targets must be real directories');
    const converter = path.join(extensions, `dotfiles-${target.provider}-agents/convert.js`);
    for (const file of files) {
      const input = path.join(source, file);
      if (!stat(input)?.isFile() || stat(input).isSymbolicLink()) throw new Error('Native agent source must be a regular file');
      const converted = execute(process.execPath, [converter], p, { input: fs.readFileSync(input), cwd: path.dirname(converter),
        env: { ...nativeEnv(p, p.env || process.env), SS_REL_PATH: file } }).stdout;
      if (!converted.trim()) throw new Error('Agent converter produced empty output');
      const output = path.join(target.path, `${path.basename(file, '.md')}.${target.provider === 'codex' ? 'toml' : 'md'}`);
      const existing = stat(output);
      if (existing && !existing.isFile() && !existing.isSymbolicLink()) throw new Error('Generated agent output collides with a non-file resource');
      if (destinations.has(output)) throw new Error('Duplicate generated agent output');
      destinations.add(output);
      outputs.push({ target: target.name, path: output, content: converted });
    }
  }
  return outputs;
}

function assertNativeAgentDestinations(options) {
  const p = settings(options);
  let status;
  try { status = JSON.parse(runNative(['status', '--json', '-g'], p).stdout); }
  catch (error) { throw new Error('Cannot verify native agent destinations', { cause: error }); }
  const source = absolute(p.source || path.join(p.root, 'ai/skillshare/agents'));
  if (!status.agents || path.resolve(status.agents.source || '') !== source || !Array.isArray(status.agents.targets)) throw new Error('Native agent source does not match intent');
  const expected = new Map((p.targets || []).map(target => [target.name, absolute(target.path)]));
  if (expected.size !== p.targets.length || expected.has(undefined)) throw new Error('Unique native target names are required');
  if (status.agents.targets.length !== expected.size) throw new Error('Native agent target selection does not match intent');
  const seen = new Set();
  for (const target of status.agents.targets) {
    if (seen.has(target.name)) throw new Error('Duplicate native agent target');
    seen.add(target.name);
    if (!expected.has(target.name) || path.resolve(target.path) !== expected.get(target.name)) throw new Error('Native agent destination does not match intent');
  }
  return status.agents;
}

function syncNativeAgents(options) {
  const p = settings(options);
  const outputs = renderAgents(p);
  const changed = outputs.filter(output => !stat(output.path)?.isFile() || stat(output.path).isSymbolicLink() || fs.readFileSync(output.path, 'utf8') !== output.content).map(output => output.path);
  if (p.dryRun) return { dryRun: true, changed, outputs, limitations: ['Native pruning and publication are not executed in render preview.'] };
  requireSupportedSkillshare(p);
  assertNativeAgentDestinations(p);
  const source = p.source || path.join(p.root, 'ai/skillshare/agents');
  const inputs = [source, path.join(p.root, 'ai/skillshare/agent-models.json'), path.join(p.root, 'ai/skillshare/extensions')];
  const before = inputs.map(inventory);
  const configBefore = inventory(p.configFile);
  const backup = backupNodes([...(p.targets || []).map(target => target.path), ...(p.nativeStatePaths || [])], p);
  try {
    if (JSON.stringify(inventory(p.configFile)) !== JSON.stringify(configBefore)) throw new Error('Native configuration changed before publication');
    for (const output of outputs) if (stat(output.path)?.isSymbolicLink()) fs.unlinkSync(output.path);
    const result = runNative(['sync', 'agents', '-g', '--json'], p);
    for (const [index, input] of inputs.entries()) if (JSON.stringify(inventory(input)) !== JSON.stringify(before[index])) throw new Error('Agent inputs changed during publication');
    for (const output of outputs) {
      const info = stat(output.path);
      if (!info?.isFile() || info.isSymbolicLink() || fs.readFileSync(output.path, 'utf8') !== output.content) throw new Error(`Native agent output does not match converter: ${output.path}`);
    }
    return { dryRun: false, changed, backupDir: backup.directory, result };
  } catch (error) {
    try { restoreBackup(backup, p); } catch (recoveryError) { error.recoveryError = recoveryError; }
    error.backupDir = backup.directory;
    throw error;
  }
}

module.exports = { ACCOUNT_OVERRIDES, nativeEnv, runNative, requireSupportedSkillshare, inventory,
  accountBuckets, migrateRuntime, renderAgents, assertNativeAgentDestinations, syncNativeAgents, restoreBackup };
