#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const { loadMappings, mappingFor, mappingPath, readDocument } = require("./transform");

const agentsDirectory = process.argv[2];
if (!agentsDirectory) throw new Error("usage: validate.js AGENTS_DIRECTORY");

const names = new Set();
for (const file of fs.readdirSync(agentsDirectory).filter((name) => name.endsWith(".md")).sort()) {
  const document = readDocument(fs.readFileSync(path.join(agentsDirectory, file), "utf8"), file);
  mappingFor(document.name, "claude");
  mappingFor(document.name, "codex");
  names.add(document.name);
}

for (const name of Object.keys(loadMappings())) {
  if (!names.has(name)) throw new Error(`agents: '${name}' in ${mappingPath} has no Markdown source`);
}
