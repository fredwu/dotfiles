# MCP Connections

Skillshare keeps MCP server definitions in one source and writes each Agent's native
config file from it. It writes settings only: it never starts a server, checks
connectivity, resolves a secret or copies OAuth credentials.

## Commands

```bash
skillshare mcp --no-tui                             # Plain status (bare mcp opens the TUI)
skillshare mcp add docs --url https://example.com/mcp --target claude --sync --no-tui
skillshare mcp add local --target claude --no-tui -- npx -y @modelcontextprotocol/server-filesystem /path/to/docs
skillshare mcp edit docs --url https://updated.example/mcp --no-tui
skillshare mcp import --from claude --json           # Inspect candidates without saving
skillshare mcp import docs --from claude --target claude --sync --no-tui
skillshare sync mcp --dry-run --json                 # Preview without executing servers
skillshare sync mcp                                 # Apply native settings
skillshare mcp remove docs --sync --no-tui           # Remove unchanged managed entries
skillshare mcp remove docs --keep-files --no-tui     # Stop managing; Agent entries stay as they are
skillshare mcp restore BACKUP_ID --dry-run --json     # Preview entry-level restoration
skillshare mcp restore BACKUP_ID --no-tui            # Apply restoration; source stays unchanged
```

## Automation rules

- Pass `--no-tui` or `--json` and every required input. `edit`, `remove` and `restore`
  need a name or backup ID when noninteractive.
- Receiving clients use repeated `--target` (singular), not `--targets`. `--force` is
  unsupported and cannot bypass a conflict.
- `--target none` (YAML `targets: []`) keeps a server in Skillshare and writes it to no
  client; the next sync removes entries it had. Omitting `--target` inherits
  `mcp.targets` instead, and fails when that is empty. Not valid with `--disabled`.
- `add`, `edit`, `import` and `remove` save the source only. Add `--sync` to write the
  Agent files too. `sync --all` includes MCP along with skills, agents and extras.
- Scripted `edit` accepts `--url`, repeated `--target`, `--pi-extension`, `--direct-tools`,
  `--pi-options` or `-- command args`. Switching transport clears the fields of the other one.
- Preview with `skillshare sync mcp --dry-run --json`, then apply with
  `skillshare sync mcp --revision <revision>` to reject a stale plan.
- Noninteractive `import` without a name only lists candidates. Use `--replace` only
  when replacing is intended.
- An `update` with the message `same settings, laid out one field per line` is a
  formatting-only rewrite of a managed JSON entry that sat on one line. Values do not
  change, and entries formatted by hand are left alone.

## Source

Definitions live in `mcp.servers` of the Skillshare config, or in the YAML file named by
`sources.mcp` (top-level `servers`, path relative to the config directory). Never define
both. `mcp.targets` is the default client list; a server's own `targets` overrides it.
MCP targets are independent of skill targets.

```yaml
mcp:
  targets: [claude, codex]
  servers:
    docs:
      url: https://example.com/mcp
      headers:
        X-Api-Key: {fromEnv: DOCS_KEY}     # a reference, never the secret itself
    files:
      command: npx
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/docs"]
      targets: [claude, opencode]
```

| Field | Meaning |
|---|---|
| `command`, `args`, `env` | Local stdio server. `env` values are strings or `{fromEnv: VARIABLE}` |
| `url`, `headers`, `bearerToken` | Streamable HTTP server. `bearerToken` is `{fromEnv: VARIABLE}` and cannot coexist with an Authorization header |
| `transport` | Optional `stdio` or `streamable-http`; inferred when omitted. Legacy SSE is not supported |
| `targets` | Receiving clients for this server. `[]` keeps it in Skillshare only |
| `piExtension`, `directTools`, `piOptions` | Pi only. See [Pi](#pi) |
| `disabled` | `true` only, no connection fields, and a project must be in scope: project mode, or a root under `mcp.projects`. See [Turn off a global server in one project](#turn-off-a-global-server-in-one-project) |

Client IDs: `claude`, `codex`, `cursor`, `vscode`, `opencode`, `kilocode`, `grok`,
`antigravity`, `amp`, `claude-desktop`, `cline`, `copilot`, `factory`, `gemini`, `goose`,
`junie`, `kiro`, `lmstudio`, `warp`, `windsurf`, `pi`. Scope and transport support vary by
client; the website's MCP command reference lists every native destination and limit.
Names such as `company-docs` (letters, digits, hyphens) work across all clients.

## Ownership and conflicts

- Skillshare only changes entries it wrote. A native entry that already matches the
  source is reported unchanged and stays unmanaged until imported.
- A differing unmanaged entry is a conflict. Resolve it with `mcp import --replace` or
  an explicit per-entry replacement. Inspect conflicts with `skillshare mcp --json`.
- Only the fields Skillshare writes are compared. Agent-only fields in an entry, such
  as timeouts or tool filters, are kept across syncs.
- Turning a managed server off by hand in the Agent's file (`enabled: false`,
  `disabled: true`) is reported as a conflict.
- Every write is backed up per Agent file. `mcp restore` restores entries, not the
  source.

## Agent notes

Read the matching note before writing for one of these Agents. They are where MCP
setups usually go wrong.

### Claude Code

| Scope | File |
|---|---|
| Global | `~/.claude.json` (honors `CLAUDE_CONFIG_DIR`) |
| Project | `.mcp.json` |

- Another account: a target with `agent:` and `config_dir: <dir>` is an MCP target by its own
  name, and `mcp import --from <name>` reads that file. `claude` (`CLAUDE_CONFIG_DIR`) writes
  `<dir>/.claude.json`, `codex` (`CODEX_HOME`) writes `<dir>/config.toml`, `pi`
  (`PI_CODING_AGENT_DIR`) writes `<dir>/mcp.json` and needs `piExtension: pi-mcp-adapter`,
  because `pi-mcp-extension` always reads `~/.pi/agent/mcp.json`. Global scope only; a project
  uses the Agent's own name, and a project's off switch goes to every account that has the
  server.
- Reserved names: a server called `workspace`, `claude-in-chrome` or `computer-use` is
  skipped by Claude Code. Skillshare refuses them for `claude`.
- Claude Code never sends its own credentials to a remote server.
  `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `AWS_BEARER_TOKEN_BEDROCK`, `HTTPS_PROXY`
  and `NPM_TOKEN` read as empty in `url` and `headers`, so Skillshare refuses them there.
  Copy the credential into a variable with another name and reference that.
- Local scope hides entries. A server added with `claude mcp add` and no `--scope` is
  stored per project in `~/.claude.json` and wins, whole, over the same name in
  `.mcp.json` or the user scope. Project mode reports it beside the entry it hides
  without blocking. Remove it with `claude mcp remove NAME -s local` in that folder.
- Claude Code rewrites `~/.claude.json` constantly. A preview stays valid unless the
  file's MCP entries themselves changed.
- In project mode, `claude` and `copilot` cannot be selected together, and an existing
  `.mcp.json` blocks Copilot CLI sync, because Copilot reads `.mcp.json` first. Use
  global mode for one of them.
- Claude Desktop (`claude-desktop`) is a separate client: global only, stdio only.

### Codex

| Scope | File |
|---|---|
| Global | `~/.codex/config.toml` (honors `CODEX_HOME`) |
| Project | `.codex/config.toml` |

- One `config.toml` is shared by the Codex CLI, the Codex IDE extension and the ChatGPT
  desktop app. A server synced to `codex` appears in all three.
- Codex loads `.codex/config.toml` only in a project it trusts. In an untrusted project
  the synced servers do not load, and Codex shows no error. Check trust first when a
  user reports "synced but missing".
- Only `[mcp_servers.NAME]` tables and their subtables can be edited. Inline or dotted
  definitions are rejected without touching the file; convert them to tables first.
- `cwd`, `http_headers_helper`, tool lists, approval modes, timeouts
  (`startup_timeout_sec`) and the `oauth` table have no portable form. Import leaves
  them out with a warning, and sync keeps them in the existing entry.
- Servers bundled by a Codex plugin live under `plugins.<plugin>.mcp_servers` and are
  not managed here.
- `--disabled` is not supported: a lone `enabled = false` breaks Codex's whole config
  where the global server is missing.

### OpenCode

| Scope | File |
|---|---|
| Global | `~/.config/opencode/opencode.json` (honors `XDG_CONFIG_HOME`) |
| Project | `opencode.json` in the project root |

- Entries are written in OpenCode's own shape: `local` / `remote` types under `mcp`,
  and `{env:VARIABLE}` for `fromEnv`. Write the portable form in the source; Skillshare
  converts it.
- An existing `opencode.jsonc` is used instead of creating `opencode.json`. A project
  file kept in `.opencode/` is reused too; a new one goes in the project root. If more
  than one exists, sync stops; the user consolidates them first. Comments and unrelated
  settings are preserved.
- `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, inline config and ancestor-directory files
  are not managed and may override what Skillshare wrote.
- `--disabled` writes `{"enabled": false}` for the named server in the project file.
- Kilo Code (`kilocode`) uses the same format in `kilo.jsonc`. It treats project config
  as untrusted and drops the whole file if it contains an `{env:VARIABLE}` reference,
  so a server using `fromEnv` or `bearerToken` is refused for Kilo in project mode.
  Define it in global mode.

### Pi

Pi has no built-in MCP. It needs one third-party extension, which the user installs:
`pi install npm:pi-mcp-adapter` or `pi install npm:pi-mcp-extension`. Syncing config
does not install it.

| Scope | File |
|---|---|
| Global | `~/.pi/agent/mcp.json` |
| Project | `.pi/mcp.json` |

- Every Pi server needs `piExtension`. Scripts pass `--target pi --pi-extension
  pi-mcp-adapter` (or `pi-mcp-extension`) to `add`, `edit` and `import`. All Pi servers
  in one source must use the same extension.
- `pi-mcp-adapter` supports `fromEnv` in `env` and `headers`, connects on demand, and
  its global path honors `PI_CODING_AGENT_DIR`. After a sync the user restarts Pi and
  checks the connection with `/mcp`.
- `pi-mcp-extension` does not interpolate references. HTTP references are rejected. A
  stdio variable that keeps its own name (`TOKEN: {fromEnv: TOKEN}`) is inherited from
  Pi's process instead. Global sync rejects `PI_CODING_AGENT_DIR`. New servers need
  `/mcp:start <server>` after a restart; existing lifecycle settings survive sync.

`directTools` (adapter only) registers a server's tools as individual Pi tools instead
of reaching them through the adapter's proxy tool:

```bash
skillshare mcp add context7 --target pi --pi-extension pi-mcp-adapter --direct-tools true --no-tui -- npx -y @upstash/context7-mcp
skillshare mcp edit context7 --direct-tools resolve-library-id,get-library-docs --no-tui
```

| `--direct-tools` / `directTools` | Effect |
|---|---|
| `true` | Every tool of the server |
| names, comma-separated (a YAML list in the source) | Only those tools, by their original MCP names |
| `search` | Registered inactive; a search activates matches |
| `false` | Proxy only, written explicitly |
| omitted | Field left alone, including a value the user added to Pi's file by hand |

- Removing `directTools` from the source does not remove it from Pi's file. Write
  `false` to turn it off.
- `directTools` directly under `mcp` is a default for every `pi-mcp-adapter` server
  without its own value. It is written into each server's entry; the adapter's own
  `settings.directTools` is not managed. No flag edits it: set it in `config.yaml`, or
  under **Defaults** on the dashboard's MCP page.
- It cannot be combined with `disabled`, and it is an error without
  `piExtension: pi-mcp-adapter`.
- `import --from pi` keeps an entry's `directTools` and selects `pi-mcp-adapter` for it.

`piOptions` (adapter only) holds adapter fields Skillshare has no setting for, such as
`excludeTools` or `approveTools`. They are written into Pi's entry as given.

```bash
skillshare mcp edit github --pi-options '{"excludeTools":["*emulator*"]}' --no-tui
```

- The flag takes a JSON object and replaces the whole of `piOptions`; `{}` clears it.
- Field names and values are not checked. Fields Skillshare writes itself (`command`,
  `args`, `env`, `url`, `headers`, `transport`, `enabled`, `disabled`, `directTools`)
  are an error.
- Values are literal: no `fromEnv`, so keep credentials out.
- A field removed from `piOptions` stays in Pi's file, and import does not read these
  fields back.

## Turn off a global server in one project

Needs a project in scope: `-p`, a folder with `.skillshare/config.yaml`, or a root under
`mcp.projects` in the global config. It writes just the switch, so the Agent keeps its
global command or URL. NAME must be the name in the Agent's own global config;
Skillshare does not check that it exists there.

| Target | Supported | Written |
|---|---|---|
| `claude` | Yes | name added to this project's `disabledMcpServers` in `~/.claude.json` (per machine) |
| `opencode`, `kilocode` | Yes | `{"enabled": false}` |
| `pi` + `--pi-extension pi-mcp-adapter` | Yes | `{"disabled": true}` |
| `codex` | No | see [Codex](#codex) |
| `pi` + `pi-mcp-extension`, all other targets | No | Error, nothing written |

```bash
skillshare mcp add NAME --disabled --target opencode -p --no-tui
skillshare mcp add NAME --disabled --target pi --pi-extension pi-mcp-adapter -p --no-tui
skillshare sync mcp -p
```

- `--disabled` cannot be combined with `--url` or `-- command`. Without `--target` the
  entry follows the project's targets: each sync sends it to the clients that have a
  switch (under `mcp.projects`, also only those the global server of that name goes to).
  With `--target`, an unsupported client is an error.
- `piExtension` is only read for Pi, so one entry can cover `[opencode, kilocode, pi]`.
- Claude's off list is per machine and keyed by the project's absolute path. Each
  teammate syncs once in their own checkout, and a moved project needs a new sync. A
  name the user turned off in `/mcp` themselves is never claimed or removed.
- To turn the server back on, `skillshare mcp remove NAME -p --sync`.
- For a server Skillshare itself defines, unselect the Agent on that server instead.

## Several projects from the global config

`mcp.projects` in the global config writes project files for many folders in one sync,
without a `.skillshare/config.yaml` in each. Keys are absolute paths or start with `~`.
Each project takes `targets`, `servers` and `directTools`; missing `targets` and
`directTools` inherit the global ones.

```yaml
# ~/.config/skillshare/config.yaml
mcp:
  targets: [opencode, pi]
  servers:
    context7:
      command: npx
      args: ["-y", "@upstash/context7-mcp"]
      piExtension: pi-mcp-adapter
  projects:
    ~/work/project01:
      servers:
        context7:                  # off in this project only
          disabled: true
          piExtension: pi-mcp-adapter
    ~/work/project02:
      servers:
        internal-docs:             # exists in this project only
          url: https://example.com/mcp
          targets: [opencode]
```

- A project lists only what differs. Global servers already load in every project,
  because the Agent reads its global and project files together; do not repeat them. A
  `disabled` entry only switches one off in that folder.
- No command edits `mcp.projects`; `mcp add` leaves it as written. Edit `config.yaml`, or
  use the dashboard: the MCP page's **Projects** tab adds and removes projects, turns
  global servers off per project and edits project servers.
- `disabled` under `mcp.projects` cannot target `claude`. Use project mode in that
  folder instead.
- It is refused inside a project config. A folder whose own `.skillshare/config.yaml`
  manages the same entry produces a conflict, not an overwrite.
- Removing a project from the list removes the entries Skillshare wrote there.
- To share one definition between projects, use a YAML anchor kept inside
  `mcp.projects`.
- The preview names the file when one server appears in several places.

## Interactive use

For a person at a terminal: `skillshare mcp` opens the manager (`/` search, Enter
details, `a` add, `i` import, `e` edit, `x` remove, `s` sync, `b` backups). `mcp add`
guides URL or JSON setup, `mcp edit` opens a server picker and editor, `mcp import
--from claude` offers batch selection with one preview, and `mcp restore` browses
backups. Review screens scroll before confirmation, and Esc cancels without saving. The
TUI offers "Save only" or "Save and sync" instead of `--sync`. An agent running
commands for the user should stay on `--no-tui` or `--json`.
