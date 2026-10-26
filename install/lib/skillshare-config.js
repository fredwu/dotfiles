'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { isDeepStrictEqual: equal } = require('node:util');
const { spawnSync } = require('node:child_process');

const ACCOUNT_OVERRIDES = ['CLAUDE_CONFIG_DIR', 'CODEX_HOME', 'OPENCODE_CONFIG_DIR', 'PI_CODING_AGENT_DIR', 'GROK_HOME'];
const MIN_VERSION = '0.26.4';
const plain = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const clone = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value));

function paths(options) {
  for (const key of ['root', 'home']) {
    if (!path.isAbsolute(options[key] || '')) throw new Error(`${key} must be an absolute path`);
  }
  const configDir = options.configDir || path.join(options.home, '.config/skillshare');
  const stateDir = options.stateDir || path.join(options.home, '.local/state/dotfiles');
  const resolved = {
    ...options, configDir, stateDir,
    configFile: options.configFile || path.join(configDir, 'config.yaml'),
    mcpFile: options.mcpFile || path.join(configDir, 'mcp.generated.yaml'),
    stateFile: options.stateFile || path.join(stateDir, 'skillshare-applied.json'),
    depsDir: options.depsDir || path.join(options.root, '.local/skillshare-node'),
  };
  for (const key of ['configDir', 'stateDir', 'configFile', 'mcpFile', 'stateFile', 'depsDir']) {
    if (!path.isAbsolute(resolved[key])) throw new Error(`${key} must be an absolute path`);
  }
  if (new Set([resolved.configFile, resolved.mcpFile, resolved.stateFile]).size !== 3) throw new Error('Configuration, MCP and state files must be distinct');
  return resolved;
}

function parser(options) {
  const dir = paths(options).depsDir;
  const pkg = require(path.join(dir, 'node_modules/yaml/package.json'));
  const expected = require(path.join(options.root, 'install/skillshare-deps/package.json')).dependencies.yaml;
  if (pkg.version !== expected) throw new Error(`Locked yaml ${expected} is required`);
  return require(path.join(dir, 'node_modules/yaml'));
}

function document(text, yaml, label) {
  const doc = yaml.parseDocument(text || '{}\n', { uniqueKeys: true, merge: false });
  if (doc.errors.length) throw new Error(`${label}: invalid YAML`);
  const value = doc.toJS({ maxAliasCount: 0 });
  if (!plain(value)) throw new Error(`${label} must be a YAML mapping`);
  return doc;
}

function expand(value, options) {
  const bindings = paths(options);
  if (typeof value === 'string') return value.replace(/\$\{(root|home|configDir|stateDir|mcpFile)\}/g, (_, key) => bindings[key]);
  if (Array.isArray(value)) return value.map(item => expand(item, options));
  if (plain(value)) return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, expand(item, options)]));
  return value;
}

function loadIntent(options) {
  const p = paths(options);
  const intent = JSON.parse(fs.readFileSync(options.intentFile || path.join(p.root, 'ai/skillshare/intent.json'), 'utf8'));
  if (intent.version !== 1 || !plain(intent.config) || !plain(intent.executables)) throw new Error('Unsupported Skillshare intent');
  return resolveMcpDefaults(expand(intent, p), p);
}

// Skillshare v0.26.4 internal/mcp/clients.go: Desktop has no Linux path,
// accepts only stdio, and has no verified environment-reference syntax.
function mcpDeliveryTargets(intent, server, options = {}) {
  const declared = Object.hasOwn(server, 'targets') ? server.targets : intent.config.mcp?.targets || [];
  if (!Array.isArray(declared) || declared.some(target => typeof target !== 'string')) throw new Error('Invalid MCP targets');
  const platform = options.platform || process.platform;
  const targets = [];
  const omitted = [];
  for (const target of declared) {
    let reason;
    if (target === 'claude-desktop') {
      if (!['darwin', 'win32'].includes(platform)) reason = 'unsupported-platform';
      else if (server.url) reason = 'stdio-only';
      else if (server.bearerToken?.fromEnv || [server.env, server.headers].some(values =>
        Object.values(values || {}).some(value => value?.fromEnv))) reason = 'from-env-unsupported';
    }
    if (reason) omitted.push({ target, reason });
    else targets.push(target);
  }
  return { targets, omitted };
}

function resolveMcpDefaults(intent, options) {
  const resolved = clone(intent);
  const { targets, omitted } = mcpDeliveryTargets(resolved, {}, options);
  if (resolved.config.mcp) resolved.config.mcp.targets = targets;
  resolved.metadata = { ...resolved.metadata, omittedMcpDefaults: [
    ...(resolved.metadata?.omittedMcpDefaults || []), ...omitted,
  ] };
  return resolved;
}

function nativeEnv(options, base = process.env) {
  const p = paths(options);
  const env = { ...base, HOME: p.home, XDG_CONFIG_HOME: options.xdgConfigHome || path.dirname(p.configDir),
    XDG_STATE_HOME: options.xdgStateHome || path.dirname(p.stateDir),
    XDG_CACHE_HOME: options.xdgCacheHome || path.join(p.home, '.cache'),
    XDG_DATA_HOME: options.xdgDataHome || path.join(p.home, '.local/share'),
    SKILLSHARE_CONFIG: p.configFile };
  for (const key of [...ACCOUNT_OVERRIDES, 'NODE_OPTIONS']) delete env[key];
  // Skillshare uses XDG_STATE_HOME; callers can supply additional fixture settings.
  return env;
}

function requireSupportedSkillshare(options) {
  const result = spawnSync(options.skillshare || 'skillshare', ['--version'], {
    env: nativeEnv(options), cwd: options.home, encoding: 'utf8', timeout: 15000,
  });
  const match = /^skillshare v(\d+)\.(\d+)\.(\d+)(?:\s|$)/m.exec(result.stdout || '');
  if (result.error || result.status !== 0 || !match) throw new Error('Cannot determine Skillshare version');
  const actual = match.slice(1).map(Number);
  const minimum = MIN_VERSION.split('.').map(Number);
  const newer = actual.findIndex((value, index) => value !== minimum[index]);
  if (newer !== -1 && actual[newer] < minimum[newer]) throw new Error(`Skillshare ${MIN_VERSION} or newer is required`);
  return actual.join('.');
}

function executable(binding, options) {
  const name = (options.executables || {})[binding];
  if (typeof name !== 'string' || !name) throw new Error(`Missing executable binding: ${binding}`);
  const candidates = path.isAbsolute(name) ? [name] : (options.path || process.env.PATH || '').split(path.delimiter).map(dir => path.join(dir, name));
  for (const candidate of candidates) {
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      if (fs.statSync(candidate).isFile()) return path.resolve(candidate);
    } catch { /* Try the next PATH entry. */ }
  }
  throw new Error(`Executable not found: ${binding}`);
}

function assertPortable(value, location = 'MCP') {
  if (typeof value === 'string') {
    if (/(?:\/Users\/|\/home\/|\/Applications\/|[A-Za-z]:\\|~\/)/.test(value) || value.startsWith('/') || /(?:^|\s)\/(?:tmp|opt|usr|var|private)\//.test(value)) {
      throw new Error(`Machine-specific value in ${location}`);
    }
    if (/(?:sk-[a-zA-Z0-9]{16}|Bearer\s+\S+)/.test(value)) throw new Error(`Literal credential in ${location}`);
    if (/^https?:\/\//.test(value)) {
      const url = new URL(value);
      if (url.username || url.password || [...url.searchParams.keys()].some(key => /token|secret|key|password|auth/i.test(key))) {
        throw new Error(`Private URL in ${location}`);
      }
    }
  } else if (Array.isArray(value)) value.forEach(item => assertPortable(item, location));
  else if (plain(value)) {
    if (Object.hasOwn(value, 'fromEnv')) {
      if (Object.keys(value).length !== 1 || !/^[A-Z_][A-Z0-9_]*$/.test(value.fromEnv)) throw new Error(`Invalid environment reference in ${location}`);
      return;
    }
    for (const [key, item] of Object.entries(value)) {
      if (/token|secret|password|authorization|api[_-]?key/i.test(key) && !plain(item)) throw new Error(`Literal credential in ${location}`);
      assertPortable(item, location);
    }
  }
}

function validateServer(server, name) {
  if (!plain(server)) throw new Error(`Invalid MCP server: ${name}`);
  const fields = ['transport', 'command', 'args', 'env', 'url', 'headers', 'bearerToken', 'tools', 'options', 'piOptions', 'targets', 'disabled'];
  if (Object.keys(server).some(key => !fields.includes(key))) throw new Error(`Unsupported MCP field: ${name}`);
  if (server.command && (!plain(server.command) || Object.keys(server.command).length !== 1 || typeof server.command.executable !== 'string')) {
    throw new Error(`MCP command requires an executable binding: ${name}`);
  }
  if (server.command && server.url) throw new Error(`Conflicting MCP transports: ${name}`);
  if (!server.command && !server.url && server.disabled !== true) throw new Error(`MCP connection missing: ${name}`);
  if (server.transport && !['stdio', 'streamable-http'].includes(server.transport)) throw new Error(`Unsupported MCP transport: ${name}`);
  if (server.url && (typeof server.url !== 'string' || !/^https?:\/\//.test(server.url))) throw new Error(`Invalid MCP URL: ${name}`);
  if (server.args && (!Array.isArray(server.args) || server.args.some(value => typeof value !== 'string'))) throw new Error(`Invalid MCP arguments: ${name}`);
  if (Object.hasOwn(server, 'targets') && (!Array.isArray(server.targets) || server.targets.some(value => typeof value !== 'string'))) throw new Error(`Invalid MCP targets: ${name}`);
  for (const section of ['env', 'headers']) {
    if (server[section] && (!plain(server[section]) || Object.values(server[section]).some(value => !plain(value) || Object.keys(value).length !== 1 || !/^[A-Z_][A-Z0-9_]*$/.test(value.fromEnv || '')))) {
      throw new Error(`Use environment references in MCP ${section}: ${name}`);
    }
  }
  assertPortable(server, name);
}

function renderServer(server, options) {
  validateServer(server, 'render');
  const out = clone(server);
  if (out.command) out.command = executable(out.command.executable, options);
  return out;
}

// Capture only the declared shared fields. Native client metadata stays native.
function captureServer(server, options = {}) {
  const allowed = options.fields || ['transport', 'command', 'args', 'env', 'url', 'headers', 'bearerToken', 'tools'];
  const out = {};
  for (const key of allowed) if (Object.hasOwn(server, key)) out[key] = clone(server[key]);
  if (out.command) {
    const bindings = options.executables || {};
    const binding = Object.keys(bindings).find(key => {
      if (out.command === bindings[key]) return true;
      try { return out.command === executable(key, options); } catch { return false; }
    });
    if (!binding) throw new Error('MCP command has no declared executable binding');
    out.command = { executable: binding };
  }
  if (out.env && Object.keys(out.env).length === 0) delete out.env;
  validateServer(out, 'capture');
  return out;
}

function loadCanonicalMcp(options) {
  const p = paths(options);
  const value = JSON.parse(fs.readFileSync(options.mcpIntentFile || path.join(p.root, 'ai/skillshare/mcp.json'), 'utf8'));
  if (value.version !== 1 || !plain(value.servers)) throw new Error('Unsupported canonical MCP source');
  for (const [name, server] of Object.entries(value.servers)) validateServer(server, name);
  return value.servers;
}

function entries(value, prefix = []) {
  if (plain(value) && Object.keys(value).length) return Object.entries(value).flatMap(([key, item]) => entries(item, [...prefix, key]));
  if (Array.isArray(value) && value.length && value.every(item => plain(item) && typeof item.name === 'string')) {
    if (new Set(value.map(item => item.name)).size !== value.length) throw new Error('Duplicate named resource');
    return value.flatMap(item => entries(item, [...prefix, { name: item.name }]));
  }
  return [{ path: prefix, ...(value === undefined ? { present: false } : { value: clone(value), present: true }) }];
}

function lookup(root, route) {
  let value = root;
  for (const part of route) {
    if (plain(part)) {
      if (!Array.isArray(value)) return { present: false };
      const matches = value.filter(item => item?.name === part.name);
      if (matches.length > 1) throw new Error('Duplicate named local resource');
      if (!matches.length) return { present: false };
      value = matches[0];
    } else {
      if (!plain(value) || !Object.hasOwn(value, part)) return { present: false };
      value = value[part];
    }
  }
  return { present: true, value };
}

function yamlRoute(doc, route, create) {
  const resolved = [];
  for (const part of route) {
    if (plain(part)) {
      let seq = doc.getIn(resolved, true);
      if (!seq && create) { doc.setIn(resolved, []); seq = doc.getIn(resolved, true); }
      if (!seq || !Array.isArray(seq.items)) throw new Error('Expected named resource sequence');
      let index = seq.items.findIndex(item => item?.get?.('name') === part.name);
      if (index === -1 && create) { seq.add({ name: part.name }); index = seq.items.length - 1; }
      if (index === -1) return null;
      resolved.push(index);
    } else resolved.push(part);
  }
  return resolved;
}

function assertOwned(current, entry) {
  if (!equal(lookup(current, entry.path), { present: entry.present !== false, ...(entry.present !== false ? { value: entry.value } : {}) })) {
    throw new Error(`Local edit to owned setting: ${JSON.stringify(entry.path)}`);
  }
}

function projectYaml(text, desired, previous, options) {
  const yaml = parser(options);
  const doc = document(text, yaml, 'configuration');
  const current = doc.toJS({ maxAliasCount: 0 });
  const next = Object.keys(desired).length ? entries(desired) : [];
  const prior = previous?.entries || [];
  if (!previous && Object.keys(current).length && !options.adoptExisting) {
    const differing = next.some(entry => !equal(lookup(current, entry.path), { present: entry.present !== false, ...(entry.present !== false ? { value: entry.value } : {}) }));
    if (differing) throw new Error('Existing owned settings require explicit adoption');
  }
  const changes = [...next];
  for (const entry of prior) {
    assertOwned(current, entry);
    if (!next.some(item => equal(item.path, entry.path))) changes.push({ path: entry.path, present: false });
  }
  for (const entry of changes) {
    const route = yamlRoute(doc, entry.path, entry.present !== false);
    if (route) {
      if (entry.present === false) {
        if (!doc.hasIn(route)) continue;
        doc.deleteIn(route);
        for (let depth = route.length - 1; depth > 0; depth--) {
          const parent = route.slice(0, depth);
          const node = doc.getIn(parent, true);
          if (!node || !Array.isArray(node.items) || node.items.length) break;
          doc.deleteIn(parent);
        }
      }
      else doc.setIn(route, entry.value);
    }
  }
  if (options.retireMcpServers) {
    const retired = new Set(prior.filter(entry => entry.path[0] === 'servers' && entry.path.length > 1 &&
      !Object.hasOwn(desired.servers || {}, entry.path[1])).map(entry => entry.path[1]));
    for (const name of retired) {
      const server = doc.getIn(['servers', name], true)?.toJSON();
      if (plain(server) && !server.command && !server.url) doc.deleteIn(['servers', name]);
    }
  }
  const changed = !equal(current, doc.toJS({ maxAliasCount: 0 }));
  return { text: changed ? doc.toString({ lineWidth: 0 }) : text, snapshot: { entries: next }, changed };
}

function readText(file) {
  try { return fs.readFileSync(file, 'utf8'); } catch (error) { if (error.code === 'ENOENT') return ''; throw error; }
}

function readState(options) {
  const text = readText(paths(options).stateFile);
  if (!text) return { version: 1, projections: {}, external: {} };
  const state = JSON.parse(text);
  if (state.version !== 1 || !plain(state.projections) || !plain(state.external)) throw new Error('Unsupported applied state');
  return state;
}

function retainInlineMcp(projected, inline, rendered, canonicalNames, yaml) {
  const doc = document(projected.text, yaml, 'MCP source');
  const current = doc.toJS({ maxAliasCount: 0 });
  for (const [name, server] of Object.entries(inline)) {
    if (name === 'node_repl') continue;
    if (!plain(server)) throw new Error(`Invalid inline MCP server: ${name}`);
    const route = ['servers', name];
    if (!canonicalNames.has(name)) {
      const existing = lookup(current, route);
      if (existing.present && !equal(existing.value, server)) throw new Error(`Local MCP entry collision: ${name}`);
      if (!existing.present) doc.setIn(route, server);
      continue;
    }
    if (!Object.hasOwn(rendered, name)) continue;
    const owned = entries(rendered[name]);
    for (const section of ['options', 'piOptions']) {
      if (!Object.hasOwn(server, section)) continue;
      for (const entry of entries(server[section], [section])) {
        const overlaps = owned.some(item => item.path.slice(0, Math.min(item.path.length, entry.path.length)).every((part, i) => equal(part, entry.path[i])));
        if (overlaps) continue;
        const localRoute = [...route, ...entry.path];
        const existing = lookup(current, localRoute);
        if (existing.present && !equal(existing.value, entry.value)) throw new Error(`Local MCP entry collision: ${name}`);
        if (!existing.present) doc.setIn(yamlRoute(doc, localRoute, true), entry.value);
      }
    }
  }
  return doc.toString({ lineWidth: 0 });
}

function prepare(options) {
  const p = paths(options);
  requireSupportedSkillshare(p);
  const yaml = parser(p);
  const intent = options.intent ? resolveMcpDefaults(options.intent, p) : loadIntent(p);
  const state = options.state || readState(p);
  const configBefore = readText(p.configFile);
  const mcpBefore = readText(p.mcpFile);
  const configDoc = document(configBefore, yaml, 'configuration');
  const configValue = configDoc.toJS({ maxAliasCount: 0 });
  if (!options.deferMcp) {
    if (intent.config.sources?.mcp !== p.mcpFile) throw new Error('Generated MCP source must match sources.mcp');
    if (configValue.sources?.mcp && configValue.sources.mcp !== p.mcpFile) {
      throw new Error('Existing external MCP source requires explicit migration before switching sources');
    }
  }
  const inline = lookup(configValue, ['mcp', 'servers']);
  if (inline.present && !options.deferMcp && !options.allowInlineMigration) throw new Error('Reconcile inline MCP ownership before switching sources');
  if (inline.present && !plain(inline.value)) throw new Error('Inline MCP servers must be a mapping');
  // Native legacy sources must not compete with the declared sources table.
  const retired = ['source', 'agents_source'];
  for (const key of retired) {
    if (configDoc.has(key) && (state.projections.config || !options.adoptExisting)) {
      throw new Error(`Local edit to retired owned source: ${key}`);
    }
    configDoc.delete(key);
  }
  let mcp;
  const desiredConfig = clone(intent.config);
  let previousConfig = state.projections.config;
  let frozen = [];
  if (options.deferMcp) {
    delete desiredConfig.mcp;
    if (desiredConfig.sources) {
      delete desiredConfig.sources.mcp;
      if (!Object.keys(desiredConfig.sources).length) delete desiredConfig.sources;
    }
    const isMcp = entry => entry.path[0] === 'mcp' || (entry.path[0] === 'sources' && entry.path[1] === 'mcp');
    frozen = previousConfig?.entries.filter(isMcp) || [];
    for (const entry of frozen) assertOwned(configValue, entry);
    if (previousConfig) previousConfig = { entries: previousConfig.entries.filter(entry => !isMcp(entry)) };
    const current = document(mcpBefore, yaml, 'MCP source').toJS({ maxAliasCount: 0 });
    for (const entry of state.projections.mcp?.entries || []) assertOwned(current, entry);
    mcp = { text: mcpBefore, snapshot: clone(state.projections.mcp), changed: false, omitted: [] };
  } else {
    const servers = options.servers || loadCanonicalMcp(p);
    const omitted = [];
    const rendered = Object.fromEntries(Object.entries(servers).map(([name, server]) => {
      const delivery = mcpDeliveryTargets(intent, server, p);
      omitted.push(...delivery.omitted.map(item => ({ server: name, ...item })));
      return [name, {
        targets: undefined,
        ...renderServer(server, { ...p, ...options, executables: { ...intent.executables, ...options.executables } }),
        ...(delivery.omitted.length ? { targets: delivery.targets } : {}),
      }];
    }));
    mcp = projectYaml(mcpBefore, Object.keys(rendered).length ? { servers: rendered } : {}, state.projections.mcp,
      { ...p, retireMcpServers: true });
    mcp.omitted = omitted;
    if (inline.present) {
      const canonicalNames = new Set([...(options.canonicalNames || []), ...Object.keys(servers)]);
      mcp.text = retainInlineMcp(mcp, inline.value, rendered, canonicalNames, yaml);
      mcp.changed = !equal(document(mcpBefore, yaml, 'MCP source').toJS({ maxAliasCount: 0 }), document(mcp.text, yaml, 'MCP source').toJS({ maxAliasCount: 0 }));
      configDoc.deleteIn(['mcp', 'servers']);
    }
  }
  const config = projectYaml(configDoc.toString({ lineWidth: 0 }), desiredConfig, previousConfig, p);
  config.snapshot.entries.push(...frozen, ...retired.map(key => ({ path: [key], present: false })));
  config.changed = !equal(document(configBefore, yaml, 'configuration').toJS({ maxAliasCount: 0 }), document(config.text, yaml, 'configuration').toJS({ maxAliasCount: 0 }));
  return { paths: p, intent, config, mcp, before: { config: configBefore, mcp: mcpBefore },
    state: { ...clone(state), projections: { ...clone(state.projections), config: config.snapshot, ...(!options.deferMcp ? { mcp: mcp.snapshot } : {}) } } };
}

function writeAtomic(file, text) {
  try { if (fs.lstatSync(file).isSymbolicLink()) throw new Error(`Refusing generated-file symlink: ${file}`); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temporary = `${file}.tmp-${process.pid}`;
  try {
    fs.writeFileSync(temporary, text, { mode: 0o600, flag: 'wx' });
    fs.renameSync(temporary, file);
  } finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
}

// Caller serializes preparation/publication and commits state only after success.
function applyPrepared(prepared) {
  const p = prepared.paths;
  if (readText(p.configFile) !== prepared.before.config || readText(p.mcpFile) !== prepared.before.mcp) throw new Error('Configuration changed after preparation');
  for (const file of [p.configFile, p.mcpFile]) {
    try { if (!fs.lstatSync(file).isFile()) throw new Error('Expected real configuration files'); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  if (prepared.mcp.text !== prepared.before.mcp) writeAtomic(p.mcpFile, prepared.mcp.text);
  if (prepared.config.text !== prepared.before.config) writeAtomic(p.configFile, prepared.config.text);
}

function writeState(options, state) {
  if (state.version !== 1 || !plain(state.projections) || !plain(state.external)) throw new Error('Unsupported applied state');
  writeAtomic(paths(options).stateFile, `${JSON.stringify(state, null, 2)}\n`);
}

module.exports = { ACCOUNT_OVERRIDES, MIN_VERSION, paths, parser, expand, loadIntent, nativeEnv,
  requireSupportedSkillshare, executable, assertPortable, mcpDeliveryTargets, renderServer, captureServer, loadCanonicalMcp,
  projectYaml, readState, prepare, applyPrepared, writeState, writeAtomic };
