"""Provider launch settings for frozen ACP reviews."""

import json
import os
import shutil
import sys
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


def _grok_macos_readonly_profile(grok_home, user_home, caller_home):
    # Grok's automatic socket resolver rejects Docker Desktop symlinks. Explicit
    # deny rules retain its stock candidates and resolve raw/canonical aliases.
    # Child-network restriction is already a no-op on macOS.
    # https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-sandbox/src/runtime_sockets.rs
    suffixes = ("docker.sock", "podman/podman.sock", "containerd/containerd.sock")
    paths = [f"/{root}/{suffix}" for root in ("run", "var/run") for suffix in suffixes]
    runtime_dir = f"/run/user/{os.getuid()}"
    paths.extend(f"{runtime_dir}/{suffix}" for suffix in suffixes)
    paths.extend(
        str(home / suffix)
        for home in dict.fromkeys((user_home, caller_home))
        for suffix in (".docker/desktop/docker.sock", ".docker/run/docker.sock")
    )
    denied_paths = ", ".join(
        json.dumps(path, ensure_ascii=False).replace("\x7f", "\\u007f")
        for path in paths
    )
    profile_name = "external-review-readonly"
    profile = grok_home / "sandbox.toml"
    profile.write_text(
        f"[profiles.{profile_name}]\n"
        'extends = "read-only"\n'
        "restrict_network = false\n"
        f"deny = [{denied_paths}]\n",
        encoding="utf-8",
    )
    profile.chmod(0o600)
    return profile_name


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


def provider_launch(agent, scratch, workspace=None):
    """Return the executable argv, child environment, and session metadata."""
    scratch = Path(scratch).resolve()
    if agent not in AUTH_ENVIRONMENT_KEYS:
        raise ProviderError(f"Unsupported ACP review provider: {agent}.")
    native_review = workspace is not None
    if native_review:
        workspace = Path(workspace)
        if (
            workspace.is_symlink()
            or not workspace.is_dir()
            or not workspace.resolve().is_relative_to(scratch)
        ):
            raise ProviderError("Native review requires a private prepared workspace.")
    allowed_keys = CHILD_ENVIRONMENT_KEYS | AUTH_ENVIRONMENT_KEYS[agent]
    env = {key: value for key, value in os.environ.items() if key in allowed_keys}

    if agent == "codex":
        instruction_file = scratch / "codex-model-instructions.txt"
        instruction_file.write_text(
            (
                "Review the authorized snapshot with read-only tools. "
                "Use optional workers only when useful; keep their work read-only. "
                "Inspect only the supplied workspace and request; do not read "
                "secrets, credentials, unrelated host files, or ambient instructions. "
                "Do not modify files or external state. "
                if native_review
                else "Review only the supplied frozen snapshot without tools. "
            )
            + "Return exactly the JSON result required by the prompt.\n",
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
                    name: native_review
                    and name in {"shell_tool", "unified_exec", "multi_agent"}
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
        env["CLAUDE_CODE_DISABLE_AUTO_MEMORY"] = "1"
        options = {
            "tools": [],
            "settingSources": [],
            "settings": {"disableAllHooks": True},
            "strictMcpConfig": True,
            "mcpServers": {},
            "allowDangerouslySkipPermissions": False,
            "persistSession": False,
        }
        if native_review:
            readonly_tools = ["Read", "Grep", "Glob"]
            options["tools"] = [*readonly_tools, "Agent"]
            options["allowedTools"] = readonly_tools
            options["settings"]["permissions"] = {"ask": ["Agent"]}
            options["agents"] = {
                "reviewer": {
                    "description": "Optional specialist for a bounded code review question.",
                    "prompt": (
                        "Inspect only the authorized frozen workspace and request. "
                        "Use read-only operations. Do not read credentials, secrets, "
                        "unrelated files, or ambient instructions. Report evidence "
                        "to the parent reviewer without changing files or external state."
                    ),
                    "tools": readonly_tools,
                    "model": "inherit",
                    "omitClaudeMd": True,
                }
            }
        return (
            [_binary("claude-agent-acp")],
            env,
            {"claudeCode": {"options": options}},
        )

    if agent == "grok":
        caller_home = Path(env.get("HOME", Path.home())).expanduser()
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
        env["GROK_SANDBOX"] = "read-only" if native_review else "workspace"
        if native_review and sys.platform == "darwin":
            env["GROK_SANDBOX"] = _grok_macos_readonly_profile(
                isolated_home, user_home, caller_home
            )
        env["GROK_MEMORY"] = "0"
        env["GROK_DISABLE_AUTOUPDATER"] = "1"
        for vendor in ("CLAUDE", "CURSOR", "CODEX"):
            for surface in ("SKILLS", "RULES", "AGENTS", "MCPS", "HOOKS", "SESSIONS"):
                env[f"GROK_{vendor}_{surface}_ENABLED"] = "0"
        env["GROK_MANAGED_MCPS_ENABLED"] = "0"
        env["GROK_MANAGED_MCP_GATEWAY_TOOLS_ENABLED"] = "0"
        profile = {
            "name": "external-review",
            "description": (
                "Review the authorized frozen workspace with read-only tools."
                if native_review
                else "Review the supplied frozen snapshot without tools."
            ),
            "injectDefaultTools": False,
            # Grok requires a nonempty curated declaration, then applies its denylist.
            "toolConfig": {
                "tools": [
                    {"id": f"GrokBuild:{name}"}
                    for name in (
                        ("read_file", "list_dir", "grep")
                        if native_review
                        else ("read_file",)
                    )
                ]
            },
            "disallowedTools": (
                [
                    "web_search",
                    "x_search",
                    "Agent",
                    "bash",
                    "search_replace",
                    "write_file",
                ]
                if native_review
                else ["read_file", "web_search", "x_search", "Agent"]
            ),
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
