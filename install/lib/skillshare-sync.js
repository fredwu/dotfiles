'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { isDeepStrictEqual: equal } = require('node:util');
const config = require('./skillshare-config');
const runtime = require('./skillshare-runtime');
const plugins = require('./skillshare-plugins');

const copy = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value));
const sharedServer = value => value === undefined ? undefined : Object.fromEntries(Object.entries(value).filter(([key]) => !['targets', 'options', 'piOptions'].includes(key)));

function decision(base, tracked, external) {
  if (external === undefined) return 'pending';
  if (equal(tracked, external)) return 'ready';
  if (base === undefined) return 'adoption-required';
  if (equal(tracked, base)) return 'capture';
  if (equal(external, base)) return 'hold';
  return 'conflict';
}

function jsonOutput(text) {
  const start = text.search(/[\[{]/);
  if (start < 0) return null;
  let depth = 0;
  let quoted = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const char = text[i];
    if (quoted) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === '"') quoted = false;
    } else if (char === '"') quoted = true;
    else if (char === '{' || char === '[') depth++;
    else if ((char === '}' || char === ']') && --depth === 0) return JSON.parse(text.slice(start, i + 1));
  }
  throw new Error('Incomplete native JSON output');
}

function native(args, options, allowFailure = false) {
  let result;
  try { result = runtime.runNative([...args, '-g'], options); }
  catch (error) {
    if (!allowFailure || !error.result) throw error;
    result = error.result;
  }
  return { ...result, data: jsonOutput(result.stdout || '') };
}

function yamlValue(file, options) {
  if (!fs.existsSync(file)) return {};
  const doc = config.parser(options).parseDocument(fs.readFileSync(file, 'utf8'), { uniqueKeys: true });
  if (doc.errors.length) throw new Error('Invalid local Skillshare YAML');
  return doc.toJS({ maxAliasCount: 0 }) || {};
}

function externalMcp(resource, options) {
  if (!fs.existsSync(resource.path)) return undefined;
  // An unnamed import only reads candidates; the native parser handles each client's format.
  const result = native(['mcp', 'import', '--file', resource.path, '--from', resource.from, '--json'], { ...options, dryRun: false });
  const candidate = result.data?.find(item => item.name === resource.name);
  if (!candidate) return undefined;
  if (candidate.problems?.length) throw new Error(`Invalid external MCP resource: ${resource.name}`);
  return config.captureServer(candidate.server, options);
}

function treeHash(directory) {
  if (!fs.existsSync(directory)) return undefined;
  const hash = crypto.createHash('sha256');
  function visit(file, relative) {
    const info = fs.lstatSync(file);
    if (info.isSymbolicLink()) throw new Error('External skill snapshots cannot contain symlinks');
    if (info.isDirectory()) {
      for (const name of fs.readdirSync(file).sort()) {
        if (name !== '.git' && name !== '.DS_Store') visit(path.join(file, name), path.join(relative, name));
      }
    } else if (info.isFile()) hash.update(`${relative}\0`).update(fs.readFileSync(file));
    else throw new Error('Unsupported external skill file');
  }
  visit(directory, '');
  return hash.digest('hex');
}

function planExternal(options, intent, canonical, state) {
  const servers = copy(canonical);
  const next = copy(state);
  const changes = [];
  const observedInputs = [];
  for (const resource of intent.external || []) {
    const key = `${resource.kind}:${resource.name}`;
    if (resource.kind === 'mcp') {
      const tracked = canonical[resource.name];
      if (!tracked) throw new Error(`Missing canonical external resource: ${resource.name}`);
      const observed = externalMcp(resource, { ...options, executables: intent.executables });
      observedInputs.push({ resource, value: observed });
      const base = state.external[key]?.baseline;
      const action = decision(sharedServer(base), sharedServer(tracked), observed);
      changes.push({ name: resource.name, kind: resource.kind, action });
      if (action === 'capture') {
        // Destination selection and per-client options remain centrally owned.
        servers[resource.name] = { ...observed, ...Object.fromEntries(['targets', 'options', 'piOptions'].filter(k => Object.hasOwn(tracked, k)).map(k => [k, tracked[k]])) };
      } else if (action === 'ready') servers[resource.name] = tracked;
      else if (base !== undefined) servers[resource.name] = base;
      else delete servers[resource.name];
      if (action === 'capture' || action === 'ready') next.external[key] = { baseline: copy(servers[resource.name]) };
    } else if (resource.kind === 'skill') {
      const destination = path.resolve(intent.config.sources.skills, resource.name);
      if (!destination.startsWith(`${path.resolve(intent.config.sources.skills)}${path.sep}`)) throw new Error('External skill name escapes source');
      const tracked = treeHash(destination);
      const observed = treeHash(resource.path);
      observedInputs.push({ resource, value: observed });
      const action = decision(state.external[key]?.baseline, tracked, observed);
      changes.push({ name: resource.name, kind: resource.kind, action, path: resource.path });
      if (action === 'capture' || action === 'ready') next.external[key] = { baseline: observed };
    } else throw new Error(`Unsupported external resource kind: ${resource.kind}`);
  }
  return { servers, state: next, changes, observedInputs };
}

function assertInputsUnchanged(options, intent, external) {
  for (const input of external.observedInputs) {
    const current = input.resource.kind === 'mcp'
      ? externalMcp(input.resource, { ...options, executables: intent.executables }) : treeHash(input.resource.path);
    if (!equal(current, input.value)) throw new Error(`External input changed during synchronization: ${input.resource.name}`);
  }
}

function backups(options) {
  const base = path.join(options.stateDir, 'skillshare-backups', `${Date.now()}-${process.pid}`);
  const saved = new Map();
  return {
    directory: base,
    save(file) {
      if (saved.has(file) || !fs.existsSync(file)) return;
      fs.mkdirSync(base, { recursive: true, mode: 0o700 });
      const destination = path.join(base, `${saved.size}-${path.basename(file)}`);
      fs.copyFileSync(file, destination);
      fs.chmodSync(destination, 0o600);
      saved.set(file, destination);
      config.writeAtomic(path.join(base, 'manifest.json'), `${JSON.stringify([...saved].map(([original, backup]) => ({ original, backup })), null, 2)}\n`);
    },
  };
}

function checkDestinations(plan, options) {
  const intent = options.intent || config.loadIntent(options);
  const openCodePath = directory => {
    const json = path.join(directory, 'opencode.json');
    const jsonc = path.join(directory, 'opencode.jsonc');
    if (fs.existsSync(json) && fs.existsSync(jsonc)) throw new Error('OpenCode has two competing configuration files');
    return fs.existsSync(jsonc) ? jsonc : json;
  };
  const local = yamlValue(options.configFile, options);
  const servers = local.mcp?.servers || yamlValue(local.sources?.mcp || options.mcpFile, options).servers || {};
  const platform = options.platform || process.platform;
  const appData = (options.env || process.env).APPDATA;
  const expected = {
    claude: path.join(options.home, '.claude.json'),
    codex: path.join(options.home, '.codex/config.toml'),
    opencode: openCodePath(path.join(path.dirname(options.configDir), 'opencode')),
    pi: path.join(options.home, '.pi/agent/mcp.json'),
    omp: path.join(options.home, '.omp/agent/mcp.json'),
    grok: path.join(options.home, '.grok/config.toml'),
    'claude-desktop': platform === 'darwin'
      ? path.join(options.home, 'Library/Application Support/Claude/claude_desktop_config.json')
      : platform === 'win32'
        ? path.join(appData || path.join(options.home, 'AppData/Roaming'), 'Claude/claude_desktop_config.json') : undefined,
  };
  const accountPath = account => {
    if (!account?.agent || !account.config_dir) return undefined;
    const names = { claude: '.claude.json', codex: 'config.toml', pi: 'mcp.json', omp: 'mcp.json' };
    return account.agent === 'opencode' ? openCodePath(account.config_dir)
      : names[account.agent] ? path.join(account.config_dir, names[account.agent]) : undefined;
  };
  for (const change of plan.changes || []) {
    const removing = change.action === 'remove';
    const selected = servers[change.name]?.targets || intent.config.mcp.targets;
    const destination = accountPath(intent.config.targets[change.target] || local.targets?.[change.target]) ||
      expected[change.target] || intent.mcpPaths?.[change.target];
    const destinations = [destination, ...(removing ? [accountPath(options.previousTargets?.[change.target])] : [])];
    if ((!removing && !selected.includes(change.target)) || !destinations.some(file => path.isAbsolute(file || '') &&
        path.resolve(change.path) === path.resolve(file))) throw new Error(`Unexpected native MCP destination: ${change.target}`);
  }
}

function previewMcp(options) {
  const preview = native(['sync', 'mcp', '--dry-run', '--json'], { ...options, dryRun: false }, true);
  const plan = preview.data?.plan || preview.data;
  if (!plan || !Array.isArray(plan.changes)) throw new Error('Native MCP preview unavailable');
  checkDestinations(plan, options);
  if (preview.status !== 0 && !plan.blocked) throw new Error('Native MCP preview failed');
  return plan;
}

function syncMcp(options, dryRun = false) {
  const plan = previewMcp(options);
  if (plan.blocked) throw new Error(`MCP conflicts: ${plan.changes.filter(c => c.action === 'conflict').map(c => `${c.target}/${c.name}`).join(', ')}`);
  if (!dryRun) native(['sync', 'mcp', '--revision', plan.revision, '--json'], options);
  return plan;
}

function detachBundled(doc) {
  for (const name of ['browser', 'chrome', 'unified-computer-use']) {
    const route = ['plugins', 'packages', name, 'bindings', 'codex'];
    const binding = doc.getIn(route)?.toJSON?.() || doc.getIn(route);
    if (!binding) continue;
    if (binding.id !== `${name}@openai-bundled`) throw new Error(`Unexpected plugin binding: ${name}`);
    doc.deleteIn(route);
    const left = doc.getIn(['plugins', 'packages', name, 'bindings'])?.toJSON?.() || {};
    if (!Object.keys(left).length) doc.deleteIn(['plugins', 'packages', name]);
  }
}

function migrateLegacy(options, intent, backup, external) {
  if (!fs.existsSync(options.configFile)) return;
  const yaml = config.parser(options);
  let doc = yaml.parseDocument(fs.readFileSync(options.configFile, 'utf8'));
  if (doc.errors.length) throw new Error('Invalid legacy configuration');
  const before = doc.toString();
  detachBundled(doc);
  if (doc.toString() !== before) { backup.save(options.configFile); config.writeAtomic(options.configFile, doc.toString()); }
  if (!doc.hasIn(['mcp', 'servers'])) return;
  if (options.deferMcp) return;
  backup.save(options.configFile);
  const originalConfig = fs.readFileSync(options.configFile);
  const ledger = path.join(options.xdgStateHome || path.dirname(options.stateDir), 'skillshare/mcp/state.json');
  const ledgerStats = fs.existsSync(ledger) ? fs.statSync(ledger) : undefined;
  const originalLedger = fs.existsSync(ledger) ? fs.readFileSync(ledger) : undefined;
  backup.save(ledger);
  const restore = () => {
    config.writeAtomic(options.configFile, originalConfig);
    if (originalLedger) {
      config.writeAtomic(ledger, originalLedger);
      fs.chmodSync(ledger, ledgerStats.mode & 0o777);
      fs.utimesSync(ledger, ledgerStats.atime, ledgerStats.mtime);
    }
    else fs.rmSync(ledger, { force: true });
  };
  const normalize = server => {
    const value = copy(sharedServer(server));
    if (value?.command && !value.transport) value.transport = 'stdio';
    if (value?.url && !value.transport) value.transport = 'streamable-http';
    if (value?.env && !Object.keys(value.env).length) delete value.env;
    return value;
  };
  const stageImport = (args, name, expected, targets, portable) => {
    native(args, options, true);
    const staged = yamlValue(options.configFile, options).mcp?.servers?.[name];
    const actual = staged && portable ? config.captureServer(normalize(staged), { ...options, executables: intent.executables }) : normalize(staged);
    if (!equal(actual, normalize(expected)) || !Array.isArray(staged?.targets) ||
        !equal([...staged.targets].sort(), [...targets].sort())) throw new Error(`Native MCP import did not stage the declared definition: ${name}`);
  };
  let publishing = false;
  try {
    doc.setIn(['mcp', 'targets'], intent.config.mcp.targets);
    for (const name of options.canonicalNames || []) {
      const server = doc.getIn(['mcp', 'servers', name])?.toJSON?.();
      if (!server) continue;
      const delivery = config.mcpDeliveryTargets(intent, server, options);
      if (delivery.omitted.length) doc.setIn(['mcp', 'servers', name, 'targets'], delivery.targets);
    }
    config.writeAtomic(options.configFile, doc.toString());
    for (const resource of (intent.external || []).filter(r => r.kind === 'mcp')) {
      if (external.changes.some(change => change.kind === 'mcp' && change.name === resource.name && change.action === 'pending')) continue;
      const args = ['mcp', 'import', resource.name, '--from', resource.from, '--file', resource.path, '--replace', '--json'];
      const local = Object.fromEntries(['options', 'piOptions'].filter(key => doc.hasIn(['mcp', 'servers', resource.name, key]))
        .map(key => [key, doc.getIn(['mcp', 'servers', resource.name, key])?.toJSON?.() || doc.getIn(['mcp', 'servers', resource.name, key])]));
      const observed = external.observedInputs.find(input => input.resource.kind === 'mcp' && input.resource.name === resource.name)?.value;
      const delivery = config.mcpDeliveryTargets(intent, observed, options);
      for (const target of delivery.targets.length ? delivery.targets : ['none']) args.push('--target', target);
      stageImport(args, resource.name, observed, delivery.targets, true);
      doc = yaml.parseDocument(fs.readFileSync(options.configFile, 'utf8'));
      for (const [key, value] of Object.entries(local)) doc.setIn(['mcp', 'servers', resource.name, key], value);
      if (Object.keys(local).length) config.writeAtomic(options.configFile, doc.toString({ lineWidth: 0 }));
    }
    doc = yaml.parseDocument(fs.readFileSync(options.configFile, 'utf8'));
    const node = doc.hasIn(['mcp', 'servers', 'node_repl']);
    if (node) {
      const current = native(['mcp', 'import', '--from', 'codex', '--json'], options).data.find(candidate => candidate.name === 'node_repl');
      if (!current || current.problems?.length) throw new Error('Cannot read the current Codex node_repl definition');
      stageImport(['mcp', 'import', 'node_repl', '--from', 'codex', '--replace', '--target', 'codex', '--json'],
        'node_repl', current.server, ['codex'], false);
    }
    assertInputsUnchanged(options, intent, external);
    const plan = previewMcp(options);
    if (plan.blocked) {
      restore();
      const names = [...new Set(plan.changes.filter(change => change.action === 'conflict').map(change => change.name))];
      return { blocked: names.length ? names : ['MCP plan'] };
    }
    publishing = true;
    native(['sync', 'mcp', '--revision', plan.revision, '--json'], options);
    if (node) native(['mcp', 'remove', 'node_repl', '--keep-files', '--json'], options);
  } catch (error) {
    if (!publishing) restore();
    throw error;
  }
}

function acquireLock(directory) {
  const file = path.join(directory, 'skillshare-sync.lock');
  const temporary = `${file}.${process.pid}-${crypto.randomUUID()}`;
  fs.writeFileSync(temporary, `${process.pid}\n`, { mode: 0o600, flag: 'wx' });
  try {
    for (let attempt = 0; attempt < 3; attempt++) {
      try { fs.linkSync(temporary, file); return () => fs.unlinkSync(file); }
      catch (error) { if (error.code !== 'EEXIST') throw error; }
      const before = fs.lstatSync(file);
      if (!before.isFile() || before.isSymbolicLink()) throw new Error('Unexpected Skillshare sync lock type');
      const pid = Number(fs.readFileSync(file, 'utf8').trim());
      if (!Number.isSafeInteger(pid) || pid < 1) throw new Error('Skillshare sync lock has no valid owner; inspect it before removal');
      try { process.kill(pid, 0); throw new Error(`Another Skillshare sync is active (pid ${pid})`); }
      catch (error) { if (error.code !== 'ESRCH') throw error; }
      if (fs.lstatSync(file).ino === before.ino) fs.unlinkSync(file);
    }
    throw new Error('Skillshare sync lock changed; retry the command');
  } finally { fs.unlinkSync(temporary); }
}

function retireExtra(options, backup) {
  if (!fs.existsSync(options.configFile)) return;
  const doc = config.parser(options).parseDocument(fs.readFileSync(options.configFile, 'utf8'));
  const extras = doc.get('extras')?.toJSON?.() || [];
  const legacy = extras.find(item => item.name === 'dotfiles-agents');
  if (!legacy) return;
  if (path.resolve(legacy.source) !== path.join(options.root, 'ai/skillshare/agents')) throw new Error('Unexpected legacy agent extra source');
  backup.save(options.configFile);
  doc.set('extras', extras.filter(item => item.name !== 'dotfiles-agents'));
  config.writeAtomic(options.configFile, doc.toString());
}

function agentTargets(intent) {
  return Object.entries(intent.config.targets).filter(([, target]) => target.agents?.extension).map(([name, target]) => ({
    name, path: target.agents.path, provider: (target.agent || name) === 'codex' ? 'codex' : 'claude',
  }));
}

function retireLegacyFiles(options, backup) {
  const manifest = path.join(options.stateDir, 'skillshare-agents.manifest');
  if (fs.existsSync(manifest)) { backup.save(manifest); fs.unlinkSync(manifest); }
  const emptySource = path.join(options.configDir, 'agents');
  if (fs.existsSync(emptySource) && fs.lstatSync(emptySource).isDirectory() && !fs.lstatSync(emptySource).isSymbolicLink() && !fs.readdirSync(emptySource).length) fs.rmdirSync(emptySource);
  for (const name of ['dotfiles-claude-agents', 'dotfiles-codex-agents']) {
    const directory = path.join(options.configDir, 'extensions', name);
    if (!fs.existsSync(directory) || !fs.lstatSync(directory).isDirectory() || fs.lstatSync(directory).isSymbolicLink()) continue;
    const files = fs.readdirSync(directory);
    if (!files.every(file => {
      const target = path.join(directory, file);
      return fs.lstatSync(target).isSymbolicLink() && path.resolve(path.dirname(target), fs.readlinkSync(target)) === path.join(options.root, 'ai/skillshare/extensions', name, file);
    })) continue;
    for (const file of files) { backup.save(path.join(directory, file)); fs.unlinkSync(path.join(directory, file)); }
    fs.rmdirSync(directory);
  }
}

function assertSkillLinks(options, intent, requirePresent = false) {
  const skills = native(['list', '--json'], options).data.filter(item => item.kind === 'skill');
  for (const [name, target] of Object.entries(intent.config.targets)) {
    if (!target.skills?.path || target.skills.enabled === false) continue;
    for (const skill of skills) {
      const destination = path.join(target.skills.path, skill.name);
      const source = path.join(intent.config.sources.skills, skill.relPath);
      let info;
      try { info = fs.lstatSync(destination); } catch (error) { if (error.code !== 'ENOENT') throw error; }
      if (!info && !requirePresent) continue;
      if (!info?.isSymbolicLink() || path.resolve(path.dirname(destination), fs.readlinkSync(destination)) !== path.resolve(source)) {
        throw new Error(`Shared skill link needs attention; local files preserved: ${name}/${skill.name}`);
      }
    }
  }
}

function preparePlugins(options) {
  const file = options.pluginsFile || path.join(options.root, 'ai/skillshare/plugins.json');
  if (!fs.existsSync(file)) return [];
  const packages = yamlValue(options.configFile, options).plugins?.packages || {};
  return plugins.loadPlugins(file).plugins.map(recipe => {
    const summary = { name: recipe.name, target: recipe.target };
    if (recipe.classification === 'local') return { ...summary, action: 'local', reason: recipe.reason };
    const binding = packages[recipe.name]?.bindings?.[recipe.target];
    const settings = path.join(options.home, '.claude/settings.json');
    const enablement = recipe.target === 'claude' && fs.existsSync(settings) ? JSON.parse(fs.readFileSync(settings, 'utf8')).enabledPlugins : {};
    if (binding?.sync === false || enablement?.[recipe.nativeId] === false || (binding?.id && enablement?.[binding.id] === false)) {
      return { ...summary, action: 'local', reason: 'Native plugin is disabled; preserve the local selection.' };
    }
    if (binding?.source === recipe.source && binding.source_ref === recipe.sourceRef && binding.commit === recipe.sourceRef) {
      const preview = native(['sync', 'plugins', recipe.name, '--dry-run', '--json'], { ...options, dryRun: false }).data;
      const plan = preview.plan || preview;
      const selected = plan.changes?.find(change => change.target === recipe.target && change.name === recipe.name);
      if (!plan.blocked && selected?.action === 'noop') return { ...summary, action: 'managed' };
      if (plan.blocked || selected?.action !== 'install') return { ...summary, action: 'hold', reason: 'Native plugin selection needs attention; installation preserved.' };
      if (options.bootstrap) { plugins.rebuildPlugin(recipe, options); return { ...summary, action: 'add' }; }
      return { ...summary, action: 'pending', reason: 'Run --bootstrap to restore the pinned selection.' };
    }
    const observed = plugins.inspectPlugin(recipe, options);
    if (observed.classification === 'portable') {
      if (!equal(observed, recipe)) return { ...summary, action: 'hold', reason: 'Installed provenance differs from the pinned recipe; retain the native installation.' };
      if (options.bootstrap) plugins.adoptPlugin(recipe, options);
      if (options.bootstrap) return { ...summary, action: 'adopt' };
      return binding?.id === recipe.nativeId ? { ...summary, action: 'managed' }
        : { ...summary, action: 'pending', reason: 'Run --bootstrap to adopt the matching native installation.' };
    }
    const registry = path.join(options.home, `.${recipe.target}/plugins/installed_plugins.json`);
    const installed = fs.existsSync(registry) ? JSON.parse(fs.readFileSync(registry, 'utf8')) : undefined;
    if (installed && (installed.version !== 2 || !installed.plugins || typeof installed.plugins !== 'object')) return { ...summary, action: 'local', reason: observed.reason };
    const records = installed?.plugins?.[recipe.nativeId];
    if (records?.length) return { ...summary, action: 'local', reason: observed.reason };
    if (options.bootstrap) {
      plugins.rebuildPlugin(recipe, options);
      return { ...summary, action: 'add' };
    }
    return { ...summary, action: 'pending', reason: 'Run --bootstrap to install the pinned selection.' };
  });
}

function migrationOptions(options, intent) {
  const source = intent.config.sources.skills;
  const skillsTargets = Object.values(intent.config.targets).filter(t => t.skills?.path).map(t => ({ path: t.skills.path, knownLinks: [source] }));
  const targets = agentTargets(intent);
  const accounts = [{ accountFile: path.join(options.home, '.claude.json'), skillsPath: path.join(options.home, '.claude/skills') },
    { accountFile: path.join(options.home, '.claude-gamma/.claude.json'), skillsPath: path.join(options.home, '.claude-gamma/skills') }];
  const updaterPath = path.join(options.home, '.cua-driver/skills/cua-driver');
  return { ...options, source, skillsTargets, agentTargets: targets.map(t => ({ ...t, knownLinks: t.provider === 'claude' && t.name !== 'claude' ? [path.join(options.home, '.claude/agents')] : [] })),
    codexSkillsPath: path.join(options.home, '.codex/skills'), accounts,
    ...(fs.existsSync(updaterPath) ? { cuaDriver: { sourceLink: path.join(source, 'cua-driver'), updaterPath } } : {}) };
}

function synchronize(given) {
  let options = config.paths(given);
  config.requireSupportedSkillshare(options);
  const intent = config.loadIntent(options);
  const state = config.readState(options);
  const canonical = config.loadCanonicalMcp(options);
  const external = planExternal(options, intent, canonical, state);
  const localConfig = yamlValue(options.configFile, options);
  const inline = !!localConfig.mcp?.servers;
  const localServers = localConfig.mcp?.servers || yamlValue(options.mcpFile, options).servers || {};
  const blocked = external.changes.filter(c => c.kind === 'mcp' &&
    (['conflict', 'adoption-required'].includes(c.action) || (c.action === 'pending' && localServers[c.name])));
  if (fs.existsSync(options.configFile)) {
    const pending = external.changes.filter(change => change.kind === 'mcp' && change.action === 'pending' && !blocked.includes(change));
    if (pending.length) {
      const preview = previewMcp({ ...options, intent });
      for (const change of pending) if (preview.changes.some(item => item.name === change.name && item.action !== 'unchanged')) blocked.push(change);
    }
  }
  options = { ...options, intent, previousTargets: localConfig.targets, deferMcp: blocked.length > 0, canonicalNames: Object.keys(canonical) };
  const preparation = { ...options, intent, state, servers: external.servers,
    adoptExisting: !!options.bootstrap || (inline && !!state.projections.config),
    allowInlineMigration: inline && (!!options.bootstrap || !!state.projections.config) };
  if (options.dryRun) {
    const prepared = config.prepare(preparation);
    return { dryRun: true, external: external.changes, migration: options.bootstrap ? runtime.migrateRuntime(migrationOptions(options, intent)) : undefined,
      plugins: preparePlugins(options),
      mcp: { blocked: blocked.map(change => change.name), omittedDefaults: intent.metadata.omittedMcpDefaults, omitted: prepared.mcp.omitted },
      limitations: ['This render preview does not execute native publication, pruning, or agent converters.'] };
  }
  config.prepare(preparation);
  runtime.migrateRuntime({ ...migrationOptions(options, intent), dryRun: true });
  fs.mkdirSync(options.stateDir, { recursive: true, mode: 0o700 });
  const release = acquireLock(options.stateDir);
  const backup = backups(options);
  const blockedNames = new Set(blocked.map(change => change.name));
  try {
    assertInputsUnchanged(options, intent, external);
    if (options.bootstrap || inline) {
      const legacy = migrateLegacy(options, intent, backup, external);
      if (legacy?.blocked?.length) {
        for (const name of legacy.blocked) blockedNames.add(name);
        options.deferMcp = true;
        preparation.deferMcp = true;
      }
      retireExtra(options, backup);
    }
    const canonicalFile = options.mcpIntentFile || path.join(options.root, 'ai/skillshare/mcp.json');
    const captured = external.changes.filter(c => c.kind === 'mcp' && c.action === 'capture' && !options.deferMcp);
    if (captured.length) {
      const next = { version: 1, servers: { ...canonical } };
      for (const change of captured) next.servers[change.name] = external.servers[change.name];
      backup.save(canonicalFile);
      config.writeAtomic(canonicalFile, `${JSON.stringify(next, null, 2)}\n`);
    }
    const prepared = config.prepare(preparation);
    backup.save(options.configFile); backup.save(options.mcpFile); backup.save(options.stateFile);
    config.applyPrepared(prepared);
    // Record successful projection separately from external publication so a failed
    // native sync can be retried without mistaking our own writes for local edits.
    config.writeState(options, { ...prepared.state, external: state.external });
    const migration = runtime.migrateRuntime(migrationOptions(options, intent));
    const pluginResults = preparePlugins(options);
    for (const change of external.changes.filter(c => c.kind === 'skill' && c.action === 'capture')) {
      native(['install', change.path, '--name', change.name, '--update', '--json'], options);
    }
    const targets = agentTargets(intent);
    runtime.renderAgents({ ...options, targets });
    assertSkillLinks(options, intent);
    native(['sync', '--json'], options);
    assertSkillLinks(options, intent, true);
    const agents = runtime.syncNativeAgents({ ...options, targets });
    assertInputsUnchanged(options, intent, external);
    const pending = external.changes.filter(change => change.kind === 'mcp' && change.action === 'pending');
    const mcp = blockedNames.size ? { changes: [], blocked: [...blockedNames] } : syncMcp(options);
    config.prepare({ ...preparation, state: prepared.state });
    const next = { ...prepared.state, external: { ...state.external } };
    for (const change of external.changes) {
      if ((change.kind !== 'mcp' || !options.deferMcp) && ['ready', 'capture'].includes(change.action)) {
        next.external[`${change.kind}:${change.name}`] = external.state.external[`${change.kind}:${change.name}`];
      }
    }
    config.writeState(options, next);
    if (options.bootstrap) retireLegacyFiles(options, backup);
    return { external: external.changes, plugins: pluginResults, agents: { changed: agents.changed },
      mcp: { omittedDefaults: intent.metadata.omittedMcpDefaults, omitted: prepared.mcp.omitted, changes: mcp.changes.map(({ target, name, action, path: file }) => ({ target, name, action, path: file })),
        ...(pending.length ? { pending: pending.map(change => change.name) } : {}),
        ...(mcp.blocked ? { blocked: mcp.blocked } : {}) },
      ...(migration ? { migration: { collisions: migration.collisions, backupDir: migration.backupDir } } : {}),
      backupDir: backup.directory, agentsBackupDir: agents.backupDir };
  } finally { release(); }
}

module.exports = { decision, jsonOutput, native, yamlValue, externalMcp, treeHash, planExternal,
  assertInputsUnchanged, backups, checkDestinations, syncMcp, detachBundled, migrateLegacy, retireExtra, agentTargets, migrationOptions, preparePlugins, acquireLock, synchronize };
