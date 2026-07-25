#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const { parseMarkdown } = require("./md-toml");
const { loadMappings, mappingFor, mappingPath } = require("./model-map");

const agentsDirectory = process.argv[2];
if (!agentsDirectory) {
  throw new Error("usage: validate.js AGENTS_DIRECTORY");
}

const files = fs.readdirSync(agentsDirectory)
  .filter((file) => file.endsWith(".md"))
  .sort();
const names = new Set();

for (const file of files) {
  process.env.SS_REL_PATH = file;
  const { frontmatter, stem } = parseMarkdown(
    fs.readFileSync(path.join(agentsDirectory, file), "utf8")
  );
  const name = (frontmatter.name || stem).trim();
  mappingFor(name, frontmatter);
  names.add(name);
}

for (const name of Object.keys(loadMappings())) {
  if (!names.has(name)) {
    throw new Error(
      `codex-agents: '${name}' in ${mappingPath} has no matching Markdown agent`
    );
  }
}
