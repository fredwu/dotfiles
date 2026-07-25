const fs = require("fs");
const path = require("path");

const mappingPath = path.resolve(__dirname, "../..", "agent-models.json");

function loadMappings() {
  return JSON.parse(fs.readFileSync(mappingPath, "utf8"));
}

function mappingFor(agentName, frontmatter) {
  const mapping = loadMappings()[agentName];
  if (!mapping) {
    throw new Error(
      `codex-agents: missing '${agentName}' in ${mappingPath}`
    );
  }

  requireFields(agentName, "claude", mapping.claude, ["model", "effort"]);
  requireFields(agentName, "codex", mapping.codex, [
    "model",
    "model_reasoning_effort",
  ]);

  for (const field of ["model", "effort"]) {
    if (frontmatter[field] !== mapping.claude[field]) {
      throw new Error(
        `codex-agents: ${agentName}.md has Claude ${field} ` +
          `'${frontmatter[field] || "<missing>"}', expected ` +
          `'${mapping.claude[field]}' from ${mappingPath}`
      );
    }
  }

  return mapping;
}

function requireFields(agentName, provider, mapping, fields) {
  if (!mapping || typeof mapping !== "object") {
    throw new Error(
      `codex-agents: ${agentName} is missing its '${provider}' mapping`
    );
  }

  for (const field of fields) {
    if (typeof mapping[field] !== "string" || !mapping[field].trim()) {
      throw new Error(
        `codex-agents: ${agentName}.${provider}.${field} must be a non-empty string`
      );
    }
  }
}

module.exports = { loadMappings, mappingFor, mappingPath };
