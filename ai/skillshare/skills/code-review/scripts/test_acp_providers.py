"""Checks for native provider configuration isolation."""

import contextlib
import io
import json
import os
import socket
import tempfile
import tomllib
import unittest
from pathlib import Path
from unittest.mock import patch

import acp_providers


class ProviderLaunchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.codex_config = self.root / "codex"
        self.codex_config.mkdir()
        self.system_config = self.root / "system.toml"
        self.environment = {
            "PATH": "/test/bin",
            "HOME": str(self.root),
            "CODEX_HOME": str(self.codex_config),
            "GROK_HOME": str(self.root / "existing-grok"),
            "NODE_OPTIONS": "--require /untrusted/plugin.js",
            "GROK_CONFIG": "untrusted override",
            "CLAUDE_CODE_EXECUTABLE": "/untrusted/claude",
            "MODEL_PROVIDER": "untrusted provider",
            "DEFAULT_AUTH_REQUEST": "secret-custom-route",
            "UNRELATED_SECRET": "never-inherit",
        }
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, self.environment, clear=True).start()
        patch.object(
            acp_providers.shutil, "which", side_effect=lambda name: "/test/bin/" + name
        ).start()

    def test_codex_disables_servers_from_all_config_sources(self):
        self.system_config.write_text('[mcp_servers.system]\ncommand="system-agent"\n')
        (self.codex_config / "config.toml").write_text(
            '[mcp_servers.user]\ncommand="agent"\n'
            '[profiles.review.mcp_servers.profile]\ncommand="profile-agent"\n'
        )
        (self.codex_config / "team.config.toml").write_text(
            '[mcp_servers.named_profile]\ncommand="team-agent"\n'
        )
        self.assertEqual(
            acp_providers._codex_mcp_servers(self.system_config),
            {
                "system": {"enabled": False},
                "user": {"enabled": False},
                "profile": {"enabled": False},
                "named_profile": {"enabled": False},
            },
        )

    def test_codex_rejects_invalid_config_shapes(self):
        for text in (
            'profiles="invalid"',
            'profiles={review="invalid"}',
            'mcp_servers="invalid"',
            "broken=[toml",
        ):
            with self.subTest(text=text):
                (self.codex_config / "config.toml").write_text(text)
                with self.assertRaises(ValueError):
                    acp_providers._codex_mcp_servers(self.system_config)

    def test_config_error_does_not_disclose_contents(self):
        (self.codex_config / "config.toml").write_text(
            'private_key="secret-token"\nbroken=['
        )
        output = io.StringIO()
        with (
            contextlib.redirect_stdout(output),
            contextlib.redirect_stderr(output),
            self.assertRaises(ValueError) as result,
        ):
            acp_providers._codex_mcp_servers(self.system_config)
        self.assertNotIn("secret-token", str(result.exception) + output.getvalue())

    def test_codex_limits_tools_and_host_instructions(self):
        with patch.object(
            acp_providers,
            "_codex_mcp_servers",
            return_value={"ambient": {"enabled": False}},
        ):
            command, env, metadata = acp_providers.provider_launch("codex", self.root)
        config = json.loads(env["CODEX_CONFIG"])
        self.assertEqual(command, ["/test/bin/codex-acp"])
        self.assertEqual(env["INITIAL_AGENT_MODE"], "read-only")
        self.assertEqual(config["sandbox_mode"], "read-only")
        self.assertEqual(config["approval_policy"], "never")
        self.assertEqual(config["project_doc_max_bytes"], 0)
        self.assertFalse(config["skills"]["include_instructions"])
        self.assertFalse(config["features"]["hooks"])
        self.assertEqual(config["developer_instructions"], "")
        self.assertEqual(config["notify"], [])
        instruction_file = Path(config["model_instructions_file"])
        self.assertEqual(instruction_file.parent, self.root.resolve())
        self.assertTrue(instruction_file.read_text(encoding="utf-8").strip())
        self.assertEqual(metadata, {})

    def test_claude_disables_builtin_tools_settings_and_hooks(self):
        command, env, metadata = acp_providers.provider_launch("claude", self.root)
        options = metadata["claudeCode"]["options"]
        self.assertEqual(command, ["/test/bin/claude-agent-acp"])
        self.assertEqual(options["tools"], [])
        self.assertEqual(options["settingSources"], [])
        self.assertTrue(options["strictMcpConfig"])
        self.assertTrue(options["settings"]["disableAllHooks"])
        self.assertNotIn("CLAUDE_CODE_EXECUTABLE", env)

    def test_claude_disables_auto_memory_only_in_child_environment(self):
        workspace = self.root / "cwd"
        workspace.mkdir()
        flag = "CLAUDE_CODE_DISABLE_AUTO_MEMORY"
        auth = {
            key: f"test-{key}" for key in acp_providers.AUTH_ENVIRONMENT_KEYS["claude"]
        }
        for prepared_workspace in (None, workspace):
            _, _, original_metadata = acp_providers.provider_launch(
                "claude", self.root, workspace=prepared_workspace
            )
            for inherited_value in (None, "0", "false"):
                with (
                    self.subTest(
                        native_review=prepared_workspace is not None,
                        inherited_value=inherited_value,
                    ),
                    patch.dict(os.environ, auth),
                ):
                    if inherited_value is None:
                        os.environ.pop(flag, None)
                    else:
                        os.environ[flag] = inherited_value
                    parent_environment = dict(os.environ)
                    command, env, metadata = acp_providers.provider_launch(
                        "claude", self.root, workspace=prepared_workspace
                    )
                    self.assertEqual(env[flag], "1")
                    self.assertEqual(dict(os.environ), parent_environment)
                    self.assertEqual(env["HOME"], parent_environment["HOME"])
                    for key, value in auth.items():
                        self.assertEqual(env[key], value)
                    self.assertEqual(command, ["/test/bin/claude-agent-acp"])
                    self.assertEqual(metadata, original_metadata)

    def test_native_codex_preserves_readonly_sandbox_with_tools_and_workers(self):
        workspace = self.root / "cwd"
        workspace.mkdir()
        with patch.object(acp_providers, "_codex_mcp_servers", return_value={}):
            _, env, metadata = acp_providers.provider_launch(
                "codex", self.root, workspace=workspace
            )
        config = json.loads(env["CODEX_CONFIG"])
        self.assertEqual(config["sandbox_mode"], "read-only")
        self.assertEqual(env["INITIAL_AGENT_MODE"], "read-only")
        self.assertEqual(config["approval_policy"], "never")
        self.assertEqual(config["web_search"], "disabled")
        self.assertEqual(
            {name for name, enabled in config["features"].items() if enabled},
            {"shell_tool", "unified_exec", "multi_agent"},
        )
        self.assertEqual(config["mcp_servers"], {})
        self.assertEqual(metadata, {})
        instructions = Path(config["model_instructions_file"]).read_text()
        self.assertIn("read-only tools", instructions)
        self.assertIn("Do not modify files or external state", instructions)

    def test_native_claude_exposes_only_readonly_tools_and_bounded_workers(self):
        workspace = self.root / "cwd"
        workspace.mkdir()
        _, env, metadata = acp_providers.provider_launch(
            "claude", self.root, workspace=workspace
        )
        options = metadata["claudeCode"]["options"]
        self.assertEqual(set(options["tools"]), {"Read", "Grep", "Glob", "Agent"})
        self.assertEqual(set(options["allowedTools"]), {"Read", "Grep", "Glob"})
        self.assertEqual(options["settings"]["permissions"], {"ask": ["Agent"]})
        self.assertEqual(set(options["agents"]), {"reviewer"})
        self.assertEqual(
            set(options["agents"]["reviewer"]["tools"]), {"Read", "Grep", "Glob"}
        )
        self.assertEqual(options["agents"]["reviewer"]["model"], "inherit")
        self.assertTrue(options["agents"]["reviewer"]["omitClaudeMd"])
        self.assertNotIn("CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH", env)
        self.assertNotIn("CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS", env)
        self.assertEqual(options["settingSources"], [])
        self.assertEqual(options["mcpServers"], {})
        self.assertTrue(options["settings"]["disableAllHooks"])
        self.assertFalse(options["allowDangerouslySkipPermissions"])
        self.assertFalse(options["persistSession"])

    def test_native_grok_keeps_write_shell_web_and_unverified_workers_unavailable(self):
        workspace = self.root / "cwd"
        workspace.mkdir()
        with patch.object(acp_providers.sys, "platform", "linux"):
            _, env, metadata = acp_providers.provider_launch(
                "grok", self.root, workspace=workspace
            )
        profile = metadata["agentProfile"]
        self.assertEqual(env["GROK_SANDBOX"], "read-only")
        self.assertFalse((Path(env["GROK_HOME"]) / "sandbox.toml").exists())
        self.assertEqual(
            {tool["id"] for tool in profile["toolConfig"]["tools"]},
            {"GrokBuild:read_file", "GrokBuild:list_dir", "GrokBuild:grep"},
        )
        self.assertTrue(
            {
                "Agent",
                "bash",
                "search_replace",
                "write_file",
                "web_search",
                "x_search",
            }.issubset(profile["disallowedTools"])
        )
        self.assertFalse(profile["injectDefaultTools"])
        self.assertFalse(profile["discoverSkills"])
        self.assertEqual(profile["mcpServers"], [])
        self.assertEqual(profile["mcpInheritance"], "none")

    def test_native_macos_grok_preserves_readonly_and_stock_socket_denials(self):
        workspace = self.root / "cwd"
        workspace.mkdir()
        with (
            patch.object(acp_providers.sys, "platform", "darwin"),
            patch.object(acp_providers.os, "getuid", return_value=602) as getuid,
        ):
            _, env, metadata = acp_providers.provider_launch(
                "grok", self.root, workspace=workspace
            )
        getuid.assert_called_once_with()
        profile_path = Path(env["GROK_HOME"]) / "sandbox.toml"
        config = tomllib.loads(profile_path.read_text(encoding="utf-8"))
        home = Path(env["HOME"])
        expected_denials = {
            "/run/docker.sock",
            "/var/run/docker.sock",
            "/run/podman/podman.sock",
            "/var/run/podman/podman.sock",
            "/run/containerd/containerd.sock",
            "/var/run/containerd/containerd.sock",
            "/run/user/602/docker.sock",
            "/run/user/602/podman/podman.sock",
            "/run/user/602/containerd/containerd.sock",
            str(home / ".docker/desktop/docker.sock"),
            str(home / ".docker/run/docker.sock"),
            str(self.root / ".docker/desktop/docker.sock"),
            str(self.root / ".docker/run/docker.sock"),
        }
        profile = config["profiles"]["external-review-readonly"]
        self.assertEqual(env["GROK_SANDBOX"], "external-review-readonly")
        self.assertEqual(set(profile["deny"]), expected_denials)
        self.assertEqual(len(profile["deny"]), 13)
        self.assertEqual(
            config,
            {
                "profiles": {
                    "external-review-readonly": {
                        "extends": "read-only",
                        "restrict_network": False,
                        "deny": profile["deny"],
                    }
                }
            },
        )
        self.assertEqual(profile_path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(profile_path.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(home.stat().st_mode & 0o777, 0o700)
        self.assertFalse((home / ".docker").exists())
        self.assertEqual(
            {tool["id"] for tool in metadata["agentProfile"]["toolConfig"]["tools"]},
            {"GrokBuild:read_file", "GrokBuild:list_dir", "GrokBuild:grep"},
        )
        self.assertIn("Agent", metadata["agentProfile"]["disallowedTools"])
        self.assertEqual(metadata["agentProfile"]["mcpInheritance"], "none")

    def test_macos_grok_profile_escapes_unusual_private_home_paths(self):
        scratch = self.root / 'unicode-🔎-"-\\-\n-\t-\x7f'
        scratch.mkdir()
        caller_home = self.root / 'caller-🔎-"-\\-\n-\t-\x7f'
        workspace = scratch / "cwd"
        workspace.mkdir()
        with (
            patch.object(acp_providers.sys, "platform", "darwin"),
            patch.object(acp_providers.os, "getuid", return_value=602),
            patch.dict(os.environ, {"HOME": str(caller_home)}),
        ):
            _, env, _ = acp_providers.provider_launch(
                "grok", scratch, workspace=workspace
            )
        config = tomllib.loads(
            (Path(env["GROK_HOME"]) / "sandbox.toml").read_text(encoding="utf-8")
        )
        denied = config["profiles"]["external-review-readonly"]["deny"]
        self.assertEqual(len(denied), 13)
        self.assertIn(str(Path(env["HOME"]) / ".docker/run/docker.sock"), denied)
        self.assertIn(str(Path(env["HOME"]) / ".docker/desktop/docker.sock"), denied)
        self.assertIn(str(caller_home / ".docker/run/docker.sock"), denied)
        self.assertIn(str(caller_home / ".docker/desktop/docker.sock"), denied)
        self.assertTrue(all(isinstance(path, str) and path for path in denied))

    def test_macos_grok_denies_caller_docker_sockets_without_system_aliases(self):
        caller_home = self.root / "caller"
        sockets = [
            caller_home / ".docker/run/docker.sock",
            caller_home / ".docker/desktop/docker.sock",
        ]
        workspace = self.root / "cwd"
        workspace.mkdir()
        with contextlib.ExitStack() as stack:
            for path in sockets:
                path.parent.mkdir(parents=True)
                listener = stack.enter_context(socket.socket(socket.AF_UNIX))
                listener.bind(str(path))
                self.assertFalse(path.is_symlink())
            stack.enter_context(patch.dict(os.environ, {"HOME": str(caller_home)}))
            stack.enter_context(patch.object(acp_providers.sys, "platform", "darwin"))
            stack.enter_context(
                patch.object(acp_providers.os, "getuid", return_value=602)
            )
            _, env, _ = acp_providers.provider_launch(
                "grok", self.root, workspace=workspace
            )
        profile_path = Path(env["GROK_HOME"]) / "sandbox.toml"
        denied = tomllib.loads(profile_path.read_text(encoding="utf-8"))["profiles"][
            "external-review-readonly"
        ]["deny"]
        self.assertEqual(len(denied), 13)
        self.assertTrue(set(map(str, sockets)).issubset(denied))
        self.assertNotEqual(env["HOME"], str(caller_home))

    def test_prompt_only_grok_does_not_create_a_custom_sandbox_on_any_platform(self):
        for platform in ("darwin", "linux", "win32"):
            with (
                self.subTest(platform=platform),
                tempfile.TemporaryDirectory(dir=self.root) as scratch,
                patch.object(acp_providers.sys, "platform", platform),
                patch.object(
                    acp_providers.os,
                    "getuid",
                    side_effect=AssertionError(
                        "Text-only mode does not resolve sockets"
                    ),
                ),
            ):
                _, env, metadata = acp_providers.provider_launch("grok", scratch)
                self.assertEqual(env["GROK_SANDBOX"], "workspace")
                self.assertFalse((Path(env["GROK_HOME"]) / "sandbox.toml").exists())
                self.assertIn("read_file", metadata["agentProfile"]["disallowedTools"])

    def test_native_review_requires_an_existing_private_workspace(self):
        outside = self.root.parent
        regular_file = self.root / "source.txt"
        regular_file.write_text("source")
        workspace = self.root / "cwd"
        workspace.mkdir()
        link = self.root / "linked-cwd"
        link.symlink_to(workspace)
        for path in (outside, regular_file, self.root / "missing", link):
            with (
                self.subTest(path=path),
                self.assertRaisesRegex(
                    acp_providers.ProviderError, "private prepared workspace"
                ),
            ):
                acp_providers.provider_launch("claude", self.root, workspace=path)

    def test_prompt_only_profiles_do_not_enable_native_review_tools_or_workers(self):
        with patch.object(acp_providers, "_codex_mcp_servers", return_value={}):
            _, env, _ = acp_providers.provider_launch("codex", self.root)
        features = json.loads(env["CODEX_CONFIG"])["features"]
        self.assertFalse(any(features.values()))
        _, env, metadata = acp_providers.provider_launch("claude", self.root)
        self.assertEqual(metadata["claudeCode"]["options"]["tools"], [])
        self.assertNotIn("agents", metadata["claudeCode"]["options"])
        self.assertNotIn("CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS", env)

    def test_grok_keeps_auth_path_and_isolates_user_configuration(self):
        command, env, metadata = acp_providers.provider_launch("grok", self.root)
        self.assertEqual(command, ["/test/bin/grok", "agent", "--no-leader", "stdio"])
        private_home = self.root / "home"
        self.assertEqual(env["HOME"], str(private_home.resolve()))
        self.assertEqual(private_home.stat().st_mode & 0o777, 0o700)
        self.assertEqual(os.environ["HOME"], self.environment["HOME"])
        for vendor in (".agents", ".claude", ".cursor", ".codex"):
            self.assertFalse((private_home / vendor).exists())
        self.assertEqual(
            env["GROK_AUTH_PATH"],
            str((self.root / "existing-grok" / "auth.json").resolve()),
        )
        self.assertEqual(env["GROK_HOME"], str((self.root / "grok-home").resolve()))
        self.assertEqual(env["GROK_SANDBOX"], "workspace")
        self.assertNotIn("GROK_CONFIG", env)
        self.assertEqual(env["GROK_CLAUDE_MCPS_ENABLED"], "0")
        profile = metadata["agentProfile"]
        self.assertFalse(profile["injectDefaultTools"])
        self.assertFalse(profile["discoverSkills"])
        self.assertFalse(profile["agentsMd"])
        declared = {
            tool["id"].rsplit(":", 1)[-1] for tool in profile["toolConfig"]["tools"]
        }
        self.assertTrue(declared.issubset(profile["disallowedTools"]))
        self.assertTrue(
            {"web_search", "x_search", "Agent"}.issubset(profile["disallowedTools"])
        )

    def test_child_environment_retains_only_required_auth_and_host_keys(self):
        for agent, auth_key in (
            ("codex", "OPENAI_API_KEY"),
            ("claude", "ANTHROPIC_API_KEY"),
            ("grok", "XAI_API_KEY"),
        ):
            with (
                self.subTest(agent=agent),
                tempfile.TemporaryDirectory(dir=self.root) as scratch,
            ):
                with (
                    patch.dict(os.environ, {auth_key: "secret-auth"}),
                    patch.object(acp_providers, "_codex_mcp_servers", return_value={}),
                ):
                    _, env, _ = acp_providers.provider_launch(agent, scratch)
                self.assertEqual(env[auth_key], "secret-auth")
                if agent == "grok":
                    self.assertEqual(env["HOME"], str(Path(scratch).resolve() / "home"))
                else:
                    self.assertEqual(env["HOME"], self.environment["HOME"])
                for key in (
                    "NODE_OPTIONS",
                    "MODEL_PROVIDER",
                    "DEFAULT_AUTH_REQUEST",
                    "UNRELATED_SECRET",
                ):
                    self.assertNotIn(key, env)

    def test_grok_preserves_custom_auth_location_without_copy(self):
        auth_path = self.root / "custom-auth.json"
        auth_path.write_text("private-authentication")
        with (
            patch.dict(os.environ, {"GROK_AUTH_PATH": str(auth_path)}),
            patch.object(Path, "open", side_effect=AssertionError("No auth file IO")),
        ):
            _, env, _ = acp_providers.provider_launch("grok", self.root)
        self.assertEqual(env["GROK_AUTH_PATH"], str(auth_path.resolve()))
        self.assertEqual(auth_path.read_text(), "private-authentication")
        self.assertFalse((Path(env["GROK_HOME"]) / "auth.json").exists())

    def test_missing_executable_has_actionable_error(self):
        with (
            patch.object(acp_providers.shutil, "which", return_value=None),
            self.assertRaisesRegex(ValueError, "claude-agent-acp"),
        ):
            acp_providers.provider_launch("claude", self.root)


if __name__ == "__main__":
    unittest.main()
