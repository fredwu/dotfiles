#!/usr/bin/env node
const fs = require("fs");

const [configPath, sourcePath, targetPath] = process.argv.slice(2);
if (!configPath || !sourcePath || !targetPath) {
  throw new Error("usage: configure-skillshare-extra.js CONFIG SOURCE TARGET");
}

const name = "codex-agents";
const block = [
  `  - name: ${name}`,
  `    source: ${JSON.stringify(sourcePath)}`,
  "    targets:",
  `      - path: ${JSON.stringify(targetPath)}`,
  "        mode: copy",
  `        extension: ${name}`,
];

const original = fs.readFileSync(configPath, "utf8");
const lines = original.replace(/\n$/, "").split("\n");
const extrasIndex = lines.findIndex((line) => line === "extras:");

if (extrasIndex === -1) {
  const nextSection = lines.findIndex((line) => /^(ignore|audit):/.test(line));
  const insertion = nextSection === -1 ? lines.length : nextSection;
  lines.splice(insertion, 0, "extras:", ...block);
} else {
  let sectionEnd = lines.findIndex(
    (line, index) => index > extrasIndex && /^[A-Za-z0-9_-]+:/.test(line)
  );
  if (sectionEnd === -1) sectionEnd = lines.length;

  const entryStart = lines.findIndex(
    (line, index) =>
      index > extrasIndex && index < sectionEnd && line === `  - name: ${name}`
  );

  if (entryStart === -1) {
    lines.splice(sectionEnd, 0, ...block);
  } else {
    let entryEnd = lines.findIndex(
      (line, index) =>
        index > entryStart && index < sectionEnd && /^  - name: /.test(line)
    );
    if (entryEnd === -1) entryEnd = sectionEnd;
    lines.splice(entryStart, entryEnd - entryStart, ...block);
  }
}

const updated = `${lines.join("\n")}\n`;
if (updated !== original) {
  fs.writeFileSync(configPath, updated);
  process.stdout.write("changed\n");
} else {
  process.stdout.write("unchanged\n");
}
