'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');
const plugins = require('../lib/skillshare-plugins');
const runtime = require('../lib/skillshare-runtime');
const config = require('../lib/skillshare-config');

const repository = path.resolve(__dirname, '../..');
const roots = [];
const parentEnvironment = { ...process.env };
const commit = 'a'.repeat(40);
const selection = { name: 'demo', target: 'claude', nativeId: 'demo@team' };
const recipe = { ...selection, classification: 'portable', source: 'https://github.com/example/plugins.git', sourceRef: commit, plugin: 'demo' };
function write(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, typeof value === 'string' ? value : `${JSON.stringify(value, null, 2)}\n`);
}
function read(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }

const realHomeGuard = require('./skillshare-home-guard');
const homeGuard = realHomeGuard.snapshot;

const guard = homeGuard();
test.after(() => {
  try {
    realHomeGuard.assertUnchanged(guard, homeGuard());
    assert(isDeepStrictEqual({ ...process.env }, parentEnvironment), 'Parent environment changed');
  } finally { for (const root of roots) fs.rmSync(root, { recursive: true, force: true }); }
});

// These native client and Git doubles expose mutations. Skillshare itself is the installed binary.
const client = `#!${process.execPath}
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const home=process.env.HOME, args=process.argv.slice(2), bin=path.basename(process.argv[1]);
for(const key of ['CLAUDE_CONFIG_DIR','CODEX_HOME','OPENCODE_CONFIG_DIR','PI_CODING_AGENT_DIR','GROK_HOME','NODE_OPTIONS'])assert(process.env[key]===undefined,'Inherited routing override present');
for(const key of ['XDG_CONFIG_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','XDG_DATA_HOME','SKILLSHARE_CONFIG'])assert(process.env[key].startsWith(home+'/'));
fs.appendFileSync(path.join(home,'calls.jsonl'),JSON.stringify({bin,args})+'\\n');
const get=f=>JSON.parse(fs.readFileSync(f)), save=(f,v)=>fs.writeFileSync(f,JSON.stringify(v));
if(bin==='git'){
 if(args.includes('clone')){fs.cpSync(path.join(home,'upstream'),args.at(-1),{recursive:true});process.exit(0);}
 if(args[0]==='fetch'){assert.equal(args.at(-1),'${commit}');process.exit(0);}
 if(args.includes('checkout'))process.exit(0);
 if(args[0]==='rev-parse'){console.log('${commit}');process.exit(0);}
 process.exit(1);
}
if(args[0]==='--version'){console.log(bin+' 99.0.0');process.exit(0);}
if(args.includes('--help')){console.log('plugin install add --scope --json');process.exit(0);}
const stateFile=path.join(home,bin+'-native.json'),state=get(stateFile);
if(args.join(' ')==='plugin list --json'){console.log(JSON.stringify(bin==='codex'?{installed:state.installed}:state.installed));process.exit(0);}
if(args.join(' ')==='plugin marketplace list --json'){console.log(JSON.stringify(bin==='codex'?{marketplaces:state.marketplaces}:state.marketplaces));process.exit(0);}
if(args.slice(0,3).join(' ')==='plugin marketplace add'){
 const root=args[3],catalog=get(path.join(root,'.claude-plugin/marketplace.json'));
 state.marketplaces.push({name:catalog.name,root,installLocation:root});save(stateFile,state);process.exit(0);
}
if(args[0]==='plugin'&&(args[1]==='install'||args[1]==='add')){
 const id=args[2];state.installed.push({id,pluginId:id,scope:'user',installed:true,enabled:true,version:'1.2.3'});save(stateFile,state);process.exit(0);
}
process.exit(1);
`;

function fixture(installed = true) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare plugins '));
  roots.push(root);
  const home = path.join(root, 'home with spaces');
  const bin = path.join(home, 'bin');
  const options = { root: repository, home, timeout: 30000,
    env: { ...process.env, APPDATA: path.join(home, 'AppData/Roaming'), PATH: bin, SKILLSHARE_CODEX_CLI: path.join(bin, 'codex') } };
  // Locate the CLI before restricting PATH, including on Linux.
  const found = require('node:child_process').spawnSync('/bin/sh', ['-c', 'command -v skillshare'], { encoding: 'utf8' }).stdout.trim();
  assert(found, 'Skillshare >= 0.26.4 is required');
  options.skillshare = found;
  for (const name of ['claude', 'codex', 'git']) { const file = path.join(bin, name); write(file, client); fs.chmodSync(file, 0o700); }
  for (const key of [...runtime.ACCOUNT_OVERRIDES, 'NODE_OPTIONS']) options.env[key] = path.join(home, 'forbidden override');
  write(path.join(home, '.config/skillshare/config.yaml'), { source: path.join(home, 'skills'), targets: { claude: { path: path.join(home, '.claude/skills') }, codex: { path: path.join(home, '.codex/skills') } } });
  fs.mkdirSync(path.join(home, 'skills'));
  const upstream = path.join(home, 'upstream');
  write(path.join(upstream, '.claude-plugin/marketplace.json'), { name: 'team', plugins: [{ name: 'demo', source: './demo' }] });
  write(path.join(upstream, 'demo/.claude-plugin/plugin.json'), { name: 'demo', version: '1.2.3', description: 'Fixture plugin' });
  write(path.join(upstream, 'demo/.codex-plugin/plugin.json'), { name: 'demo', version: '1.2.3', description: 'Fixture plugin' });
  const native = { id: 'demo@team', pluginId: 'demo@team', name: 'demo', version: '1.2.3', scope: 'user', installed: true, enabled: true };
  for (const target of ['claude', 'codex']) write(path.join(home, `${target}-native.json`), {
    installed: installed && target === 'claude' ? [native] : [], marketplaces: installed && target === 'claude' ? [{ name: 'team', installLocation: upstream, root: upstream }] : [],
  });
  if (installed) {
    write(path.join(home, '.claude/plugins/installed_plugins.json'), { version: 2, plugins: { 'demo@team': [{ scope: 'user', installPath: path.join(upstream, 'demo'), version: '1.2.3', gitCommitSha: commit }] } });
    write(path.join(home, '.claude/plugins/known_marketplaces.json'), { team: { source: { source: 'github', repo: 'example/plugins' }, installLocation: upstream } });
    write(path.join(home, '.claude/settings.json'), { enabledPlugins: { 'demo@team': true }, private: 'preserve-native-private-fields' });
  }
  return options;
}

function calls(options) {
  const file = path.join(options.home, 'calls.jsonl');
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8').trim().split('\n').map(JSON.parse) : [];
}
function nativeConfig(options) {
  return config.parser({ ...options, depsDir: process.env.SKILLSHARE_TEST_DEPS || path.join(repository, '.local/skillshare-node') }).parse(fs.readFileSync(path.join(options.home, '.config/skillshare/config.yaml'), 'utf8'));
}

test('installed registry commit wins over version labels and marketplace HEAD', () => {
  const options = fixture();
  assert.deepEqual(plugins.inspectPlugin(selection, options), recipe);
  const registry = path.join(options.home, '.claude/plugins/installed_plugins.json');
  const value = read(registry);
  delete value.plugins['demo@team'][0].gitCommitSha;
  value.plugins['demo@team'][0].version = commit;
  write(registry, value);
  assert.match(plugins.inspectPlugin(selection, options).reason, /no exact commit/);
  assert.deepEqual(calls(options), []);
});

test('vendor, unsupported, ambiguous, automatic and external-source plugins remain local', () => {
  const options = fixture();
  for (const marketplace of ['openai-bundled', 'openai-curated', 'openai-curated-remote', 'openai-primary-runtime']) {
    assert.match(plugins.inspectPlugin({ ...selection, nativeId: `demo@${marketplace}` }, options).reason, /Vendor/);
  }
  assert.match(plugins.inspectPlugin({ ...selection, target: 'pi' }, options).reason, /not qualified/);
  const file = path.join(options.home, '.claude/plugins/installed_plugins.json');
  const value = read(file);
  value.plugins['demo@team'].push({ ...value.plugins['demo@team'][0] });
  write(file, value);
  assert.match(plugins.inspectPlugin(selection, options).reason, /Exactly one/);
  value.plugins['demo@team'].pop(); value.plugins['demo@team'][0].auto = true; write(file, value);
  assert.match(plugins.inspectPlugin(selection, options).reason, /automatic/);
  delete value.plugins['demo@team'][0].auto; write(file, value);
  write(path.join(options.home, 'upstream/.claude-plugin/marketplace.json'), { plugins: [{ name: 'demo', source: { source: 'url', url: 'https://example.com/other.git' } }] });
  assert.match(plugins.inspectPlugin(selection, options).reason, /in-repository/);
});

test('Codex marketplace revision is not substituted for missing installed provenance', () => {
  const options = fixture();
  write(path.join(options.home, '.codex/.tmp/marketplaces/team/.codex-marketplace-install.json'), { source_type: 'git', source: recipe.source, revision: commit });
  assert.equal(plugins.inspectPlugin({ ...selection, target: 'codex' }, options).classification, 'local');
  assert.deepEqual(calls(options), []);
});

test('disabled and unknown native enablement stay local without install or enablement changes', () => {
  const options = fixture();
  const file = path.join(options.home, '.claude/settings.json');
  write(file, { enabledPlugins: { 'demo@team': false } });
  const before = runtime.inventory(options.home);
  assert.match(plugins.adoptPlugin(selection, options).recipe.reason, /disabled/);
  assert.deepEqual(runtime.inventory(options.home), before);
  assert.deepEqual(calls(options), []);
  write(file, { enabledPlugins: {} });
  assert.match(plugins.inspectPlugin(selection, options).reason, /unknown/);
});

test('adoption uses actual native import and preserves content, enablement and private fields', () => {
  const options = fixture();
  const files = ['.claude/plugins', '.claude/settings.json', 'claude-native.json', 'upstream'].map(file => path.join(options.home, file));
  const before = files.map(runtime.inventory);
  assert.equal(plugins.adoptPlugin(selection, options).action, 'adopt');
  assert.deepEqual(files.map(runtime.inventory), before);
  const binding = nativeConfig(options).plugins.packages.demo.bindings.claude;
  assert.deepEqual(binding, { id: 'demo@team', version: '1.2.3' });
  assert(calls(options).length > 0);
  assert(calls(options).every(call => call.args[0] === '--version' || call.args.includes('list')));
  // Native import must preserve an existing deselection and its local version metadata too.
  const file = path.join(options.home, '.config/skillshare/config.yaml');
  const value = nativeConfig(options); value.plugins.packages.demo.bindings.claude.sync = false; write(file, value);
  plugins.adoptPlugin(recipe, options);
  assert.equal(nativeConfig(options).plugins.packages.demo.bindings.claude.sync, false);
  assert.deepEqual(files.map(runtime.inventory), before);
});

for (const target of ['claude', 'codex']) test(`clean ${target} home adds the exact pin through actual Skillshare and ordinary sync does not upgrade`, () => {
  const options = fixture(false);
  const pinned = { ...recipe, target };
  assert.equal(plugins.rebuildPlugin(pinned, options).action, 'add');
  const binding = nativeConfig(options).plugins.packages.demo.bindings[target];
  assert.equal(binding.source, recipe.source);
  assert.equal(binding.source_ref, commit);
  assert.equal(binding.commit, commit);
  const before = calls(options).length;
  runtime.runNative(['sync', 'plugins', 'demo', '--json', '-g'], options);
  const later = calls(options).slice(before);
  assert(later.every(call => call.bin !== 'git' && (call.args[0] === '--version' || call.args.includes('list'))));
  const downloads = calls(options).filter(call => call.bin === 'git' && call.args[0] === 'fetch');
  assert(downloads.length >= 1);
  assert(downloads.every(call => call.args.at(-1) === commit));
  assert(calls(options).some(call => call.bin === target && ['install', 'add'].includes(call.args[1]) && call.args[2].startsWith('demo@skillshare-')));
});

test('managed plugin preparation recognizes the native alias created by clean-home add', () => {
  const options = config.paths({ ...fixture(false), depsDir: process.env.SKILLSHARE_TEST_DEPS || path.join(repository, '.local/skillshare-node') });
  options.pluginsFile = path.join(options.home, 'portable-plugins.json');
  write(options.pluginsFile, { version: 1, plugins: [recipe] });
  const sync = require('../lib/skillshare-sync');
  assert.equal(sync.preparePlugins({ ...options, bootstrap: true })[0].action, 'add');
  const before = calls(options).length;
  assert.equal(sync.preparePlugins(options)[0].action, 'managed');
  assert.equal(sync.preparePlugins({ ...options, bootstrap: true })[0].action, 'managed');
  assert(calls(options).slice(before).every(call => call.bin !== 'git' && (call.args[0] === '--version' || call.args.includes('list'))));
});

test('rebuild refuses native import substitution, dry-run is pure, and local adoption never runs a CLI', () => {
  const options = fixture();
  const before = runtime.inventory(options.home);
  assert.equal(plugins.adoptPlugin(selection, { ...options, dryRun: true }).action, 'adopt');
  assert.equal(plugins.rebuildPlugin(recipe, { ...options, dryRun: true }).action, 'add');
  assert.deepEqual(runtime.inventory(options.home), before);
  assert.throws(() => plugins.rebuildPlugin(recipe, options), /adopt existing/);
  assert(calls(options).every(call => call.bin === 'git' || call.args[0] === '--version' || call.args.includes('list')));
  const count = calls(options).length;
  assert.equal(plugins.adoptPlugin({ ...selection, nativeId: 'demo@openai-bundled' }, options).action, 'local');
  assert.equal(calls(options).length, count);
});

test('manifest requires exact pins, credential-free sources, unique selections and explicit local reasons', () => {
  const options = fixture();
  const file = path.join(options.home, 'plugins.json');
  write(file, { version: 1, plugins: [recipe, { ...selection, target: 'codex', classification: 'local', reason: 'No installed ref' }] });
  assert.equal(plugins.loadPlugins(file).plugins.length, 2);
  for (const source of ['https://user:private@example.com/repo.git', 'https://example.com/repo.git?token=private', '/machine/repo', 'owner/repo']) {
    write(file, { version: 1, plugins: [{ ...recipe, source }] });
    assert.throws(() => plugins.loadPlugins(file), /exact portable/);
  }
  write(file, { version: 1, plugins: [{ ...recipe, sourceRef: 'main' }] });
  assert.throws(() => plugins.loadPlugins(file), /exact portable/);
  write(file, { version: 1, plugins: [recipe, recipe] });
  assert.throws(() => plugins.loadPlugins(file), /Duplicate/);
  write(file, { version: 1, plugins: [{ ...selection, classification: 'local' }] });
  assert.throws(() => plugins.loadPlugins(file), /Explicit local/);
});

test('obsolete Skillshare stops adoption before any native write', () => {
  const options = fixture();
  const executable = path.join(options.home, 'old-skillshare');
  write(executable, `#!${process.execPath}\nconsole.log('skillshare v0.26.3');\n`);
  fs.chmodSync(executable, 0o700);
  const before = runtime.inventory(options.home);
  assert.throws(() => plugins.adoptPlugin(selection, { ...options, skillshare: executable }), /0.26.4/);
  assert.deepEqual(runtime.inventory(options.home), before);
});

test('tracked recipes keep native bindings and machine paths out of portable intent', () => {
  const file = path.join(repository, 'ai/skillshare/plugins.json');
  const manifest = plugins.loadPlugins(file);
  assert(manifest.plugins.some(recipe => recipe.classification === 'portable'));
  for (const recipe of manifest.plugins) {
    assert(!Object.hasOwn(recipe, 'bindings'));
    assert(!JSON.stringify(recipe).includes(process.env.SKILLSHARE_TEST_REAL_HOME || os.homedir()));
    if (recipe.nativeId.includes('@openai-')) assert.equal(recipe.classification, 'local');
  }
});
