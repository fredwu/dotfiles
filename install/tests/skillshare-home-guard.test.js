'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const guard = require('./skillshare-home-guard');

test('real-home guard permits only observed concurrent runtime metadata changes', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare-guard-'));
  const file = path.join(home, '.claude.json');
  const write = value => fs.writeFileSync(file, JSON.stringify(value));
  try {
    write({ mcpServers: { shared: { command: 'node' } }, pluginUsage: { sample: 1 } });
    const before = guard.snapshot(home);
    guard.assertUnchanged(before, guard.snapshot(home));
    write({ mcpServers: { shared: { command: 'node' } }, pluginUsage: { sample: 2 } });
    assert.deepEqual(guard.assertUnchanged(before, guard.snapshot(home)), [file]);
    write({ mcpServers: { shared: { command: 'node' } }, pluginUsage: { sample: 1 }, cachedGrowthBookFeaturesAt: 123 });
    assert.deepEqual(guard.assertUnchanged(before, guard.snapshot(home)), [file]);
    write({ mcpServers: { shared: { command: 'changed' } }, pluginUsage: { sample: 3 } });
    assert.throws(() => guard.assertUnchanged(before, guard.snapshot(home)), /Real-home files changed/);
    write({ mcpServers: { shared: { command: 'node' } }, pluginUsage: { sample: 1 } });
    fs.utimesSync(file, new Date(), new Date(Date.now() + 5000));
    assert.throws(() => guard.assertUnchanged(before, guard.snapshot(home)), /Real-home files changed/);
  } finally { fs.rmSync(home, { recursive: true, force: true }); }
});

test('real-home guard rejects permission and link changes', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare-guard-'));
  const file = path.join(home, '.claude.json');
  try {
    fs.writeFileSync(file, '{}');
    const before = guard.snapshot(home);
    fs.chmodSync(file, 0o600);
    assert.throws(() => guard.assertUnchanged(before, guard.snapshot(home)), /Real-home files changed/);
    fs.chmodSync(file, before[file].mode & 0o777);
    const restored = guard.snapshot(home);
    const target = path.join(home, 'target.json');
    fs.copyFileSync(file, target);
    fs.unlinkSync(file); fs.symlinkSync(target, file);
    assert.throws(() => guard.assertUnchanged(restored, guard.snapshot(home)), /Real-home files changed/);
  } finally { fs.rmSync(home, { recursive: true, force: true }); }
});

test('real-home guard covers generated MCP source and all Claude Desktop paths', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare-guard-'));
  try {
    for (const relative of ['.config/skillshare/mcp.generated.yaml', 'Library/Application Support/Claude/claude_desktop_config.json', '.config/Claude/claude_desktop_config.json', 'AppData/Roaming/Claude/claude_desktop_config.json']) {
      const file = path.join(home, relative);
      fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, '{}');
      const before = guard.snapshot(home);
      fs.writeFileSync(file, '{"changed":true}');
      assert.throws(() => guard.assertUnchanged(before, guard.snapshot(home)), /Real-home files changed/);
    }
  } finally { fs.rmSync(home, { recursive: true, force: true }); }
});


test('real-home guard includes a custom absolute APPDATA outside the home', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'skillshare-guard-appdata-'));
  const prior = { APPDATA: process.env.APPDATA, SKILLSHARE_TEST_REAL_HOME: process.env.SKILLSHARE_TEST_REAL_HOME };
  try {
    const home = path.join(temporary, 'home');
    process.env.SKILLSHARE_TEST_REAL_HOME = home;
    process.env.APPDATA = path.join(temporary, 'outside-appdata');
    const file = path.join(process.env.APPDATA, 'Claude/claude_desktop_config.json');
    fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, '{}');
    const before = guard.snapshot();
    assert(Object.hasOwn(before, file));
    fs.writeFileSync(file, '{"changed":true}');
    assert.throws(() => guard.assertUnchanged(before, guard.snapshot()), /Real-home files changed/);
  } finally {
    for (const [key, value] of Object.entries(prior)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});
