#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const [configPath, sourcePath, claudeTarget, codexTarget, nativeAgentsSource] = process.argv.slice(2);
if (!configPath || !sourcePath || !claudeTarget || !codexTarget || !nativeAgentsSource) {
  throw new Error(
    "usage: configure-skillshare-extra.js CONFIG SOURCE CLAUDE_TARGET CODEX_TARGET NATIVE_AGENTS_SOURCE"
  );
}

const block = [
  "  - name: dotfiles-agents",
  `    source: ${JSON.stringify(sourcePath)}`,
  "    targets:",
  `      - path: ${JSON.stringify(claudeTarget)}`,
  "        mode: copy",
  "        extension: dotfiles-claude-agents",
  `      - path: ${JSON.stringify(codexTarget)}`,
  "        mode: copy",
  "        extension: dotfiles-codex-agents",
];

const original = fs.readFileSync(configPath, "utf8");
assertCanonicalConfig(original);
const lines = original.replace(/\n$/, "").split("\n");

assertNoExtraTargetConflicts(lines);
setNativeAgentsSource(lines);
removeCollidingNativeAgentsTarget(lines, "claude", claudeTarget);
removeCollidingNativeAgentsTarget(lines, "codex", codexTarget);
replaceAgentsExtra(lines);

const updated = `${lines.join("\n")}\n`;
if (updated !== original) {
  const temporary = `${configPath}.dotfiles-${process.pid}.tmp`;
  try {
    fs.writeFileSync(temporary, updated, { mode: fs.statSync(configPath).mode });
    fs.renameSync(temporary, configPath);
  } finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
  process.stdout.write("changed\n");
} else {
  process.stdout.write("unchanged\n");
}

function assertCanonicalConfig(content) {
  if (content.includes("\r")) unsupported("CRLF line endings");
  if (content.includes("\t")) unsupported("tab indentation");

  const configLines = content.replace(/\n$/, "").split("\n");
  if (configLines.some((line) => /^ +(?:sources|extras):/.test(line) || /^  targets:/.test(line))) {
    unsupported("leading-indented relevant top-level section");
  }
  for (const key of ["sources", "targets", "extras"]) {
    const canonical = `${key}:`;
    const candidates = configLines.filter((line) =>
      new RegExp(`^[\"']?${key}[\"']?\\s*:`).test(line)
    );
    if (candidates.length > 1) unsupported(`duplicate '${key}' sections`);
    if (candidates.length === 1 && candidates[0] !== canonical) {
      unsupported(`noncanonical '${key}' section`);
    }
  }

  assertCanonicalSources(configLines);
  assertCanonicalTargets(configLines);
  assertCanonicalExtras(configLines);
}

function assertCanonicalSources(configLines) {
  const start = configLines.indexOf("sources:");
  if (start === -1) return;
  const end = sectionEnd(configLines, start);
  for (let index = start + 1; index < end; index++) {
    const line = configLines[index];
    if (/^  ["']agents["']\s*:/.test(line) || /^  agents:\s*[\[{]/.test(line)) {
      unsupported("noncanonical 'sources.agents'");
    }
  }
}

function assertCanonicalTargets(configLines) {
  const start = configLines.indexOf("targets:");
  if (start === -1) return;
  const end = sectionEnd(configLines, start);
  for (let index = start + 1; index < end; index++) {
    const line = configLines[index];
    if (/^  ["'](?:claude|codex)["']\s*:/.test(line) ||
      /^  (?:claude|codex):\s*[\[{]/.test(line) ||
      /^    ["']agents["']\s*:/.test(line) ||
      /^    agents:\s*[\[{]/.test(line)) {
      unsupported("noncanonical managed target configuration");
    }
  }
}

function assertCanonicalExtras(configLines) {
  const start = configLines.indexOf("extras:");
  if (start === -1) return;
  const end = sectionEnd(configLines, start);
  for (let index = start + 1; index < end; index++) {
    const line = configLines[index];
    if (/^  - ["']name["']\s*:/.test(line) || /^  - name:\s*[\[{]/.test(line)) {
      unsupported("noncanonical extras entry");
    }
    if (/^    ["'](?:source|targets)["']\s*:/.test(line) ||
      /^    targets:\s*[\[{]/.test(line) ||
      /^      - ["']path["']\s*:/.test(line)) {
      unsupported("noncanonical extras target");
    }
  }
}

function unsupported(reason) {
  throw new Error(
    `unsupported Skillshare config (${reason}); expected Skillshare-serialized block YAML`
  );
}

function setNativeAgentsSource(configLines) {
  const sourcesStart = configLines.indexOf("sources:");
  const agentsLine = `  agents: ${JSON.stringify(nativeAgentsSource)}`;
  if (sourcesStart === -1) {
    const next = configLines.findIndex((line) => /^(mode|target_naming|targets|extras|ignore|audit):/.test(line));
    const insertion = next === -1 ? configLines.length : next;
    configLines.splice(insertion, 0, "sources:", agentsLine);
    return;
  }

  const sourcesEnd = sectionEnd(configLines, sourcesStart);
  const currentAgents = configLines.findIndex(
    (line, index) => index > sourcesStart && index < sourcesEnd && line.startsWith("  agents:")
  );
  if (currentAgents === -1) {
    configLines.splice(sourcesEnd, 0, agentsLine);
  } else {
    configLines[currentAgents] = agentsLine;
  }
}

function removeCollidingNativeAgentsTarget(configLines, targetName, managedTarget) {
  const targetsStart = configLines.indexOf("targets:");
  if (targetsStart === -1) return;
  const targetsEnd = sectionEnd(configLines, targetsStart);
  const targetStart = configLines.findIndex(
    (line, index) => index > targetsStart && index < targetsEnd && line === `  ${targetName}:`
  );
  if (targetStart === -1) return;
  const targetEnd = nextMatchingLine(configLines, targetStart, targetsEnd, /^  [A-Za-z0-9_-]+:/);
  const agentsStart = configLines.findIndex(
    (line, index) => index > targetStart && index < targetEnd && line === "    agents:"
  );
  if (agentsStart === -1) return;
  const agentsEnd = nextMatchingLine(configLines, agentsStart, targetEnd, /^    [A-Za-z0-9_-]+:/);
  const pathLines = configLines.slice(agentsStart + 1, agentsEnd)
    .filter((line) => line.startsWith("      path:"));
  if (pathLines.length > 1) unsupported(`multiple '${targetName}.agents.path' values`);
  if (pathLines.length === 1) {
    const configuredPath = parseScalar(pathLines[0].slice("      path:".length), `${targetName}.agents.path`);
    if (!pathsEqual(configuredPath, managedTarget)) return;
  }
  configLines.splice(agentsStart, agentsEnd - agentsStart);
}

function assertNoExtraTargetConflicts(configLines) {
  for (const entry of extraEntries(configLines)) {
    if (entry.name === "dotfiles-agents" || isManagedLegacyExtra(entry)) continue;
    for (const target of entry.targets) {
      if (pathsEqual(target, claudeTarget) || pathsEqual(target, codexTarget)) {
        throw new Error(
          `extra '${entry.name}' already targets managed agent path ${target}; refusing conflicting ownership`
        );
      }
    }
  }
}

function replaceAgentsExtra(configLines) {
  let extrasStart = configLines.indexOf("extras:");
  if (extrasStart === -1) {
    const next = configLines.findIndex((line) => /^(ignore|audit):/.test(line));
    const insertion = next === -1 ? configLines.length : next;
    configLines.splice(insertion, 0, "extras:", ...block);
    return;
  }

  const removable = extraEntries(configLines)
    .filter((entry) => entry.name === "dotfiles-agents" || isManagedLegacyExtra(entry))
    .sort((left, right) => right.start - left.start);
  for (const entry of removable) configLines.splice(entry.start, entry.end - entry.start);

  extrasStart = configLines.indexOf("extras:");
  configLines.splice(sectionEnd(configLines, extrasStart), 0, ...block);
}

function isManagedLegacyExtra(entry) {
  return entry.name === "codex-agents" &&
    entry.source !== null && pathsEqual(entry.source, sourcePath) &&
    entry.targets.length === 1 && pathsEqual(entry.targets[0], codexTarget) &&
    entry.extensions.length === 1 && entry.extensions[0] === "codex-agents";
}

function extraEntries(configLines) {
  const extrasStart = configLines.indexOf("extras:");
  if (extrasStart === -1) return [];
  const extrasEnd = sectionEnd(configLines, extrasStart);
  const starts = [];
  for (let index = extrasStart + 1; index < extrasEnd; index++) {
    if (/^  - name:/.test(configLines[index])) starts.push(index);
  }

  return starts.map((start, position) => {
    const end = starts[position + 1] ?? extrasEnd;
    const name = parseScalar(configLines[start].slice("  - name:".length), "extra.name");
    let source = null;
    const targets = [];
    const extensions = [];
    for (let index = start + 1; index < end; index++) {
      const line = configLines[index];
      if (line.startsWith("    source:")) {
        source = parseScalar(line.slice("    source:".length), `${name}.source`);
      } else if (line.startsWith("      - path:")) {
        targets.push(parseScalar(line.slice("      - path:".length), `${name}.target.path`));
      } else if (line.startsWith("        extension:")) {
        extensions.push(parseScalar(line.slice("        extension:".length), `${name}.target.extension`));
      }
    }
    return { start, end, name, source, targets, extensions };
  });
}

function parseScalar(raw, label) {
  const value = raw.trim();
  if (!value || /^[\[{]/.test(value)) unsupported(`noncanonical '${label}'`);
  if (value.startsWith('"')) {
    try {
      const parsed = JSON.parse(value);
      if (typeof parsed !== "string") throw new Error();
      return parsed;
    } catch {
      unsupported(`invalid quoted '${label}'`);
    }
  }
  if (value.startsWith("'")) {
    if (!value.endsWith("'")) unsupported(`invalid quoted '${label}'`);
    return value.slice(1, -1).replace(/''/g, "'");
  }
  if (/\s+#/.test(value)) unsupported(`commented '${label}'`);
  return value;
}

function pathsEqual(left, right) {
  return path.resolve(expandHome(left)) === path.resolve(expandHome(right));
}

function expandHome(value) {
  if (value === "~") return process.env.HOME;
  return value.startsWith("~/") ? path.join(process.env.HOME, value.slice(2)) : value;
}

function nextMatchingLine(configLines, start, limit, pattern) {
  const next = configLines.findIndex(
    (line, index) => index > start && index < limit && pattern.test(line)
  );
  return next === -1 ? limit : next;
}

function sectionEnd(configLines, start) {
  const end = configLines.findIndex(
    (line, index) => index > start && /^[A-Za-z0-9_-]+:/.test(line)
  );
  return end === -1 ? configLines.length : end;
}
