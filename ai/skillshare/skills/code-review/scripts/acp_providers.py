"""Provider launch settings for frozen ACP reviews."""

import json
import os
import shutil
import tomllib
from pathlib import Path

CHILD_ENVIRONMENT_KEYS = {
    "PATH",
    "HOME",
    "USER",
    "LOGNAME",
    "LANG",
    "LC_ALL",
    "LC_CTYPE",
    "TMPDIR",
    "TMP",
    "TEMP",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "NO_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "no_proxy",
    "SSL_CERT_FILE",
    "SSL_CERT_DIR",
    "NODE_EXTRA_CA_CERTS",
}

AUTH_ENVIRONMENT_KEYS = {
    "codex": {"CODEX_HOME", "CODEX_API_KEY", "OPENAI_API_KEY"},
    "claude": {
        "CLAUDE_CONFIG_DIR",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_AUTH_TOKEN",
        "CLAUDE_CODE_OAUTH_TOKEN",
    },
    "grok": {"GROK_HOME", "GROK_AUTH_PATH", "GROK_AUTH", "XAI_API_KEY"},
}


class ProviderError(ValueError):
    """Provider configuration cannot establish an isolated review session."""


def _binary(name):
    binary = shutil.which(name)
    if binary is None:
        raise ProviderError(f"Required ACP executable is missing: {name}.")
    return binary


def _codex_mcp_servers(system_config=Path("/etc/codex/config.toml")):
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
    sources = [system_config, codex_home / "config.toml"]
    if codex_home.is_dir():
        sources.extend(codex_home.glob("*.config.toml"))
    servers = set()

    def collect(value):
        if not isinstance(value, dict):
            return
        configured = value.get("mcp_servers", {})
        if not isinstance(configured, dict):
            raise ProviderError("Cannot isolate invalid Codex MCP configuration.")
        servers.update(configured)
        profiles = value.get("profiles", {})
        if not isinstance(profiles, dict):
            raise ProviderError("Cannot isolate invalid Codex profile configuration.")
        for profile in profiles.values():
            if not isinstance(profile, dict):
                raise ProviderError(
                    "Cannot isolate invalid Codex profile configuration."
                )
            collect(profile)

    for path in sources:
        if not path.exists():
            continue
        try:
            with path.open("rb") as source:
                collect(tomllib.load(source))
        except (OSError, tomllib.TOMLDecodeError):
            raise ProviderError(
                "Cannot inspect Codex configuration for ACP isolation."
            ) from None
    return {name: {"enabled": False} for name in sorted(servers)}


def provider_launch(agent, scratch):
    """Return the executable argv, child environment, and session metadata."""
    scratch = Path(scratch).resolve()
    if agent not in AUTH_ENVIRONMENT_KEYS:
        raise ProviderError(f"Unsupported ACP review provider: {agent}.")
    allowed_keys = CHILD_ENVIRONMENT_KEYS | AUTH_ENVIRONMENT_KEYS[agent]
    env = {key: value for key, value in os.environ.items() if key in allowed_keys}

    if agent == "codex":
        instruction_file = scratch / "codex-model-instructions.txt"
        instruction_file.write_text(
            "Review only the supplied frozen snapshot without tools. "
            "Return exactly the JSON result required by the prompt.\n",
            encoding="utf-8",
        )
        env["INITIAL_AGENT_MODE"] = "read-only"
        env["NO_BROWSER"] = "1"
        env["CODEX_CONFIG"] = json.dumps(
            {
                "sandbox_mode": "read-only",
                "approval_policy": "never",
                "web_search": "disabled",
                "model_instructions_file": str(instruction_file),
                "developer_instructions": "",
                "compact_prompt": "",
                "notify": [],
                "project_doc_max_bytes": 0,
                "skills": {
                    "include_instructions": False,
                    "bundled": {"enabled": False},
                },
                "mcp_servers": _codex_mcp_servers(),
                "features": {
                    name: False
                    for name in (
                        "shell_tool",
                        "unified_exec",
                        "code_mode",
                        "code_mode_host",
                        "hooks",
                        "apps",
                        "plugins",
                        "multi_agent",
                        "memories",
                        "computer_use",
                        "browser_use",
                        "image_generation",
                        "view_image",
                    )
                },
            }
        )
        return [_binary("codex-acp")], env, {}

    if agent == "claude":
        return (
            [_binary("claude-agent-acp")],
            env,
            {
                "claudeCode": {
                    "options": {
                        "tools": [],
                        "settingSources": [],
                        "settings": {"disableAllHooks": True},
                        "strictMcpConfig": True,
                        "mcpServers": {},
                        "allowDangerouslySkipPermissions": False,
                        "persistSession": False,
                    }
                },
            },
        )

    if agent == "grok":
        original_home = Path(env.get("GROK_HOME", Path.home() / ".grok")).expanduser()
        auth_path = Path(
            env.get("GROK_AUTH_PATH", original_home / "auth.json")
        ).expanduser()
        isolated_home = scratch / "grok-home"
        isolated_home.mkdir(mode=0o700)
        user_home = scratch / "home"
        user_home.mkdir(mode=0o700)
        # The native skill watcher ignores profile discovery controls.
        env["HOME"] = str(user_home)
        env["GROK_HOME"] = str(isolated_home)
        env["GROK_AUTH_PATH"] = str(auth_path.resolve())
        env["GROK_SANDBOX"] = "workspace"
        env["GROK_MEMORY"] = "0"
        env["GROK_DISABLE_AUTOUPDATER"] = "1"
        for vendor in ("CLAUDE", "CURSOR", "CODEX"):
            for surface in ("SKILLS", "RULES", "AGENTS", "MCPS", "HOOKS", "SESSIONS"):
                env[f"GROK_{vendor}_{surface}_ENABLED"] = "0"
        env["GROK_MANAGED_MCPS_ENABLED"] = "0"
        env["GROK_MANAGED_MCP_GATEWAY_TOOLS_ENABLED"] = "0"
        profile = {
            "name": "external-review",
            "description": "Review the supplied frozen snapshot without tools.",
            "injectDefaultTools": False,
            # Grok requires a nonempty curated declaration, then applies its denylist.
            "toolConfig": {"tools": [{"id": "GrokBuild:read_file"}]},
            "disallowedTools": ["read_file", "web_search", "x_search", "Agent"],
            "discoverSkills": False,
            "agentsMd": False,
            "mcpServers": [],
            "mcpInheritance": "none",
        }
        return (
            [_binary("grok"), "agent", "--no-leader", "stdio"],
            env,
            {
                "agentProfile": profile,
            },
        )
