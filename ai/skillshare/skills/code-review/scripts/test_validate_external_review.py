"""Offline checks for the shared external review validation command."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("validate_external_review.py")
spec = importlib.util.spec_from_file_location(
    "acp_review", SCRIPT.with_name("acp_review.py")
)
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)
SCHEMA = json.loads(review.SCHEMA_PATH.read_text(encoding="utf-8"))
CLEAN = {
    "verdict": "clean",
    "inspected_surface": "src/example.py:1-20",
    "findings": [],
    "residual_risk": "Private review result text must not appear in diagnostics.",
}
FINDING = {
    "id": "F1",
    "priority": "P2",
    "confidence": 90,
    "title": "Handle missing values",
    "location": "src/example.py:5",
    "evidence": "A missing value reaches the conversion.",
    "impact": "The operation fails.",
    "remediation": "Validate the value.",
}


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.input = self.root / "private-input-path.json"

    def run_command(self, content=None, *, path=None):
        if content is not None:
            self.input.write_bytes(
                content.encode("utf-8") if isinstance(content, str) else content
            )
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(path or self.input)],
            cwd=self.root,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        diagnostics = completed.stdout + completed.stderr
        self.assertNotIn(str(path or self.input), diagnostics)
        self.assertNotIn(CLEAN["residual_risk"], diagnostics)
        self.assertNotIn(FINDING["evidence"], diagnostics)
        self.assertNotIn("Traceback", diagnostics)
        return completed

    def test_completed_and_incomplete_exit_codes_without_file_changes(self):
        for result, expected in (
            (CLEAN, 0),
            ({**CLEAN, "verdict": "findings", "findings": [FINDING]}, 0),
            ({**CLEAN, "verdict": "incomplete"}, 1),
        ):
            with self.subTest(verdict=result["verdict"]):
                content = " \n" + json.dumps(result) + "\n"
                completed = self.run_command(content)
                self.assertEqual(completed.returncode, expected)
                self.assertEqual(self.input.read_text(encoding="utf-8"), content)
                self.assertEqual(list(self.root.iterdir()), [self.input])

    def test_rejects_nonterminal_and_malformed_json(self):
        valid = json.dumps(CLEAN)
        for content in (
            "",
            "Review result: " + valid,
            "```json\n" + valid + "\n```",
            valid + valid,
            valid + "\nAdditional prose",
            '{"verdict": "clean"',
            valid.replace('"verdict": "clean"', '"verdict":"clean","verdict":"clean"'),
            json.dumps({"result": CLEAN}),
            json.dumps({"terminal_summary": valid}),
            "null",
            "[]",
            "NaN",
            "Infinity",
            "-Infinity",
            "[" * 10000 + "0" + "]" * 10000,
        ):
            with self.subTest(content=content[:80]):
                self.assertEqual(self.run_command(content).returncode, 2)

    def test_shared_schema_and_finding_identifiers_fail_closed(self):
        malformed = (
            {**CLEAN, "unexpected": "value"},
            {key: value for key, value in CLEAN.items() if key != "inspected_surface"},
            {**CLEAN, "verdict": "findings"},
            {**CLEAN, "findings": [FINDING]},
            {**CLEAN, "verdict": "incomplete", "findings": [FINDING]},
            {**CLEAN, "residual_risk": ""},
            {**CLEAN, "inspected_surface": "\ud800"},
            {**CLEAN, "verdict": "findings", "findings": [FINDING, FINDING]},
        )
        malformed += tuple(
            {**CLEAN, "verdict": "findings", "findings": [{**FINDING, **fields}]}
            for fields in (
                {"id": "F1\n"},
                {"id": "F0"},
                {"confidence": 79},
                {"confidence": 101},
                {"confidence": 90.5},
                {"confidence": True},
                {"confidence": float("inf")},
                {"confidence": float("nan")},
                {"evidence": "\udfff"},
                {"assessment": "accept"},
            )
        )
        for result in malformed:
            with self.subTest(result=repr(result)):
                with self.assertRaises(review.ReviewError):
                    review.validate_review_result(result, SCHEMA)
                self.assertEqual(self.run_command(json.dumps(result)).returncode, 2)

    def test_integral_confidence_and_unique_ids_match_acp_contract(self):
        for confidence in (80, 90.0, 100.0):
            with self.subTest(confidence=confidence):
                result = {
                    **CLEAN,
                    "verdict": "findings",
                    "findings": [
                        {**FINDING, "confidence": confidence},
                        {**FINDING, "id": "F12"},
                    ],
                }
                review.validate_review_result(result, SCHEMA)
                self.assertEqual(self.run_command(json.dumps(result)).returncode, 0)

    def test_nested_duplicate_keys_and_numeric_overflow_are_rejected(self):
        valid = json.dumps({**CLEAN, "verdict": "findings", "findings": [FINDING]})
        for content in (
            valid.replace('"id": "F1"', '"id":"F1","id":"F2"'),
            valid.replace('"confidence": 90', '"confidence": 1e400'),
        ):
            with self.subTest(content=content):
                self.assertEqual(self.run_command(content).returncode, 2)

    def test_input_must_be_bounded_regular_utf8_file_without_symlinks(self):
        self.assertEqual(self.run_command().returncode, 2)
        self.assertEqual(self.run_command(path=self.root).returncode, 2)
        self.assertEqual(self.run_command(b"\xff").returncode, 2)
        link = self.root / "input-link"
        link.symlink_to(self.input)
        self.assertEqual(self.run_command(path=link).returncode, 2)
        self.input.unlink()
        self.assertEqual(self.run_command(path=link).returncode, 2)
        fifo = self.root / "input-fifo"
        os.mkfifo(fifo)
        self.assertEqual(self.run_command(path=fifo).returncode, 2)
        with self.input.open("wb") as stream:
            stream.truncate(review.MAX_TEXT_BYTES + 1)
        self.assertEqual(self.run_command().returncode, 2)

    def test_imports_do_not_load_provider_or_start_runtime(self):
        with (
            patch.dict(sys.modules, {"acp_providers": None}),
            patch("asyncio.create_subprocess_exec", side_effect=AssertionError),
            patch("subprocess.Popen", side_effect=AssertionError),
            patch("tempfile.TemporaryDirectory", side_effect=AssertionError),
        ):
            for path in (SCRIPT, SCRIPT.with_name("acp_review.py")):
                with self.subTest(path=path.name):
                    spec = importlib.util.spec_from_file_location("review_import", path)
                    spec.loader.exec_module(importlib.util.module_from_spec(spec))


if __name__ == "__main__":
    unittest.main()
