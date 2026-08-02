#!/usr/bin/env node
// Adapted from Skillshare's official codex-agents extension at v0.20.22.
const { block, convert } = require("./md-toml");
const { mappingFor } = require("./model-map");

convert(({ body, frontmatter, stem }) => {
  const name = (frontmatter.name || stem).trim();
  const description = (frontmatter.description || "").trim();
  const developerInstructions = body.trim();

  if (!name) {
    throw new Error("codex-agents: missing required field 'name'");
  }
  if (!description) {
    throw new Error("codex-agents: missing required frontmatter 'description'");
  }
  if (!developerInstructions) {
    throw new Error("codex-agents: missing required markdown body");
  }

  const { codex } = mappingFor(name, frontmatter);

  return {
    name,
    description,
    ...codex,
    developer_instructions: block(developerInstructions),
  };
});
