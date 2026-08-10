const fs = require("fs");
const path = require("path");

const mappingPath = path.resolve(__dirname, "../..", "agent-models.json");

function loadMappings() {
  return JSON.parse(fs.readFileSync(mappingPath, "utf8"));
}

function parseMarkdown(input, relPath = process.env.SS_REL_PATH || "input.md") {
  const match = input.match(/^---\r?\n([\s\S]*?)\r?\n---[ \t]*\r?\n?/);
  const frontmatter = {};
  const text = match ? match[1] : "";

  for (const line of text.split(/\r?\n/)) {
    const field = line.match(/^\s*([A-Za-z0-9_-]+)\s*:\s*(.*?)\s*$/);
    if (field) frontmatter[field[1]] = stripQuotes(field[2]);
  }

  return {
    body: match ? input.slice(match[0].length) : input,
    frontmatter,
    stem: path.basename(relPath, path.extname(relPath)),
  };
}

function stripQuotes(value) {
  if (value.length < 2) return value;
  const first = value[0];
  const last = value[value.length - 1];
  return (first === `"` && last === `"`) || (first === `'` && last === `'`)
    ? value.slice(1, -1)
    : value;
}

function readDocument(input, relPath) {
  const parsed = parseMarkdown(input, relPath);
  const name = (parsed.frontmatter.name || parsed.stem).trim();
  const description = (parsed.frontmatter.description || "").trim();
  const body = parsed.body.trim();

  for (const field of ["model", "effort", "model_reasoning_effort", "service_tier"]) {
    if (field in parsed.frontmatter) {
      throw new Error(`agents: provider field '${field}' must be defined in ${mappingPath}`);
    }
  }
  if (!name || !description || !body) {
    throw new Error("agents: name, description, and Markdown body are required");
  }

  return { name, description, body };
}

function mappingFor(name, provider) {
  const mapping = loadMappings()[name]?.[provider];
  const required = provider === "claude"
    ? ["model", "effort"]
    : ["model", "model_reasoning_effort"];

  if (!mapping || typeof mapping !== "object") {
    throw new Error(`agents: missing '${name}.${provider}' in ${mappingPath}`);
  }
  for (const field of required) {
    if (typeof mapping[field] !== "string" || !mapping[field].trim()) {
      throw new Error(`agents: ${name}.${provider}.${field} must be a non-empty string`);
    }
  }
  return mapping;
}

function renderClaude(document) {
  const mapping = mappingFor(document.name, "claude");
  const fields = { name: document.name, description: document.description, ...mapping };
  const frontmatter = Object.entries(fields)
    .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
    .join("\n");
  return `---\n${frontmatter}\n---\n\n${document.body}\n`;
}

function renderCodex(document) {
  const mapping = mappingFor(document.name, "codex");
  const fields = { name: document.name, description: document.description, ...mapping };
  const lines = Object.entries(fields).map(([key, value]) => `${key} = ${JSON.stringify(value)}`);
  lines.push(`developer_instructions = ${tomlBlock(document.body)}`);
  return `${lines.join("\n")}\n`;
}

function tomlBlock(value) {
  if (!value.includes(`"""`)) return `"""\n${value}\n"""`;
  if (!value.includes(`'''`)) return `'''\n${value}\n'''`;
  return `"""\n${value.replace(/"""/g, `\\"""`)}\n"""`;
}

function convert(provider) {
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", () => {
    try {
      const document = readDocument(input);
      process.stdout.write(provider === "claude" ? renderClaude(document) : renderCodex(document));
    } catch (error) {
      process.stderr.write(`${error.message || error}\n`);
      process.exitCode = 1;
    }
  });
}

module.exports = { convert, loadMappings, mappingFor, mappingPath, parseMarkdown, readDocument };
