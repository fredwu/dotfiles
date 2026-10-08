"""Checks for native provider configuration isolation."""

import contextlib
import io
import json
import os
import tempfile
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
