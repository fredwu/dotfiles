"""Deterministic protocol tests. No installed agent, login, or model is used."""

import asyncio
import contextlib
import importlib.util
import io
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "acp_review", Path(__file__).with_name("acp_review.py")
)
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)
SCHEMA = json.loads(review.SCHEMA_PATH.read_text())
CLEAN = {
    "verdict": "clean",
    "inspected_surface": "src/example.py:1-20",
    "findings": [],
    "residual_risk": "No observed defects.",
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

PEER = r"""
import json, os, pathlib, signal, subprocess, sys, time
mode, log_path, result_text = sys.argv[1:]
pathlib.Path(log_path+".pid").write_text(str(os.getpid()))
sid = "fresh-session"
def emit(value):
    print(json.dumps(value), flush=True)
def update(kind, **fields):
    emit({"jsonrpc":"2.0","method":"session/update","params":{
        "sessionId":sid,"update":{"sessionUpdate":kind,**fields}}})
def response(message, result):
    request_id=message["id"]
    if mode == "numeric_id_roundtrip" and isinstance(request_id,(int,float)):
        request_id=float(request_id)
    if mode == "wrong_string_id":
        request_id="review-999"
    emit({"jsonrpc":"2.0","id":request_id,"result":result})
def extension(name, **params):
    emit({"jsonrpc":"2.0","method":name,"params":params})
for line in sys.stdin:
    message = json.loads(line)
    with open(log_path,"a") as log:
        log.write(json.dumps(message)+"\n")
    method = message.get("method")
    if method is None:
        continue
    if method == "session/cancel":
        if mode not in {"stubborn", "stubborn_child"}:
            break
        continue
    if method == "initialize":
        if mode == "orphan_responses":
            emit({"jsonrpc":"2.0","id":"other-client","result":json.loads(result_text)})
            emit({"jsonrpc":"2.0","id":7.0,"result":{"stopReason":"end_turn"}})
        if mode == "malformed_orphan_response":
            emit({"jsonrpc":"2.0","id":"other-client","result":{},"error":{"code":-1,"message":"error"}})
            continue
        if mode == "malformed_orphan_error":
            emit({"jsonrpc":"2.0","id":"other-client","error":{"code":"invalid","message":"secret"}})
            continue
        if mode == "malformed_orphan_id":
            emit({"jsonrpc":"2.0","id":True,"result":{}})
            continue
        if mode == "nonfinite_orphan_id":
            print('{"jsonrpc":"2.0","id":1e400,"result":{}}',flush=True)
            continue
        if mode == "extensions":
            extension("_auth/status_update",authStatus="authenticated")
        if mode == "malformed_extension":
            emit({"jsonrpc":"2.0","method":"_vendor/metadata","params":"invalid"})
            continue
        if mode == "unknown_standard_notification":
            extension("unknown_standard/metadata",status="setup")
            continue
        if mode == "setup_timeout":
            time.sleep(10)
        if mode == "invalid_protocol":
            response(message,{"protocolVersion":999})
            continue
        if mode == "boolean_protocol":
            response(message,{"protocolVersion":True})
            continue
        if mode == "invalid_frame":
            print("plain CLI output",flush=True)
            continue
        if mode == "duplicate_key":
            print('{"jsonrpc":"2.0","id":1,"id":1,"result":{}}',flush=True)
            continue
        if mode == "large_frame":
            print("x"*2200000,flush=True)
            continue
        if mode == "deep_frame":
            print('{"jsonrpc":"2.0","id":1,"result":'+"["*10000+"0"+"]"*10000+'}',flush=True)
            continue
        if mode == "truncated":
            sys.stdout.write('{"jsonrpc":"2.0"}')
            sys.stdout.flush()
            break
        if mode == "protocol_error":
            emit({"jsonrpc":"2.0","id":message["id"],"error":{
                "code":-32000,"message":"secret that must not be copied","data":{"token":"secret-payload"}}})
            continue
        if mode == "wrong_id":
            response({"id":999},{"protocolVersion":1})
            continue
        response(message,{"protocolVersion":1,"agentCapabilities":{}})
        if mode == "duplicate_response":
            response(message,{"protocolVersion":1})
    elif method == "session/new":
        if mode == "surrogate_session_id":
            response(message,{"sessionId":"\ud800"})
            continue
        if mode == "session_error":
            emit({"jsonrpc":"2.0","id":message["id"],"error":{
                "code":-32000,"message":"secret login details","data":{"token":"secret-payload"}}})
            continue
        if mode == "extensions":
            extension("_x.ai/session/setup",method="session/new",phase="loading",sessionId=sid)
        if mode == "metadata_before_new_response":
            update("current_mode_update",currentModeId="read-only")
        if mode == "answer_before_prompt":
            update("agent_message_chunk",content={"type":"text","text":result_text})
        response(message,{"sessionId":sid})
        if mode == "metadata_after_new_response":
            update("current_mode_update",currentModeId="read-only")
    elif method == "session/prompt":
        if mode == "surrogate_frame_text":
            update("agent_message_chunk",content={"type":"text","text":"\ud800"})
            continue
        if mode == "surrogate_request_id":
            emit({"jsonrpc":"2.0","id":"\ud800","method":"session/request_permission",
                  "params":{"sessionId":sid,"options":[]}})
            continue
        if mode == "prompt_error":
            emit({"jsonrpc":"2.0","id":message["id"],"error":{
                "code":-32603,"message":"secret prompt details","data":{"token":"secret-payload"}}})
            continue
        if mode == "orphan_responses":
            emit({"jsonrpc":"2.0","id":"other-worker","result":json.loads(result_text)})
            emit({"jsonrpc":"2.0","id":"unrelated-error","error":{"code":-1,"message":"secret orphan diagnostic"}})
        if mode == "orphan_only":
            while True:
                emit({"jsonrpc":"2.0","id":"other-worker","result":json.loads(result_text)})
                time.sleep(.02)
        if mode in {"extensions", "extension_only"}:
            extension("_vendor/metadata",sessionId=sid,stopReason="end_turn",
                      result=result_text,toolCall={"kind":"read","path":"/outside/snapshot"})
        if mode == "extension_rpc":
            emit({"jsonrpc":"2.0","id":"extension-request","method":"_vendor/capability",
                  "params":{"sessionId":sid}})
            continue
        if mode == "answer_after_terminal":
            response(message,{"stopReason":"end_turn"})
            update("agent_message_chunk",content={"type":"text","text":result_text})
            continue
        if mode == "cwd_mutation":
            pathlib.Path("unauthorized.txt").write_text("unauthorized")
        if mode == "shutdown_mutation":
            signal.signal(signal.SIGTERM,lambda *_: pathlib.Path("unauthorized.txt").write_text("unauthorized"))
        if mode == "child":
            child=subprocess.Popen([sys.executable,"-c","import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(60)"])
            pathlib.Path(log_path+".child").write_text(str(child.pid))
            continue
        if mode == "exit":
            break
        if mode in {"idle", "stubborn", "stubborn_child"}:
            if mode in {"stubborn", "stubborn_child"}:
                signal.signal(signal.SIGTERM,signal.SIG_IGN)
            if mode == "stubborn_child":
                child=subprocess.Popen([sys.executable,"-c","import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(60)"])
                pathlib.Path(log_path+".child").write_text(str(child.pid))
            continue
        if mode == "heartbeat":
            for _ in range(7):
                update("agent_thought_chunk",content={"type":"text","text":"hidden thought"})
                time.sleep(.04)
        if mode == "total_timeout":
            while True:
                update("agent_thought_chunk",content={"type":"text","text":"thinking"})
                time.sleep(.02)
        if mode == "permission":
            emit({"jsonrpc":"2.0","id":"permission-1","method":"session/request_permission",
                  "params":{"sessionId":sid,"options":[]}})
            continue
        if mode == "file_read":
            emit({"jsonrpc":"2.0","id":"read-1","method":"fs/read_text_file",
                  "params":{"sessionId":sid,"path":"/host-secret"}})
            continue
        if mode == "tool":
            update("tool_call",toolCallId="tool-1",title="Read host data",status="completed")
            continue
        if mode == "wrong_session":
            sid="unrelated-session"
        if mode == "unsupported_content":
            update("agent_message_chunk",content={"type":"resource_link","uri":"file:///host-secret"})
            continue
        if mode == "malformed_update_type":
            update([],content={"type":"text","text":result_text})
            continue
        if mode in {"thought_only", "extension_only"}:
            update("agent_thought_chunk",content={"type":"text","text":result_text})
        elif mode == "chunks":
            for character in result_text:
                update("agent_message_chunk",content={"type":"text","text":character})
        else:
            if mode == "stderr_noise":
                sys.stderr.write("secret diagnostic noise\n"*30000)
                sys.stderr.flush()
            update("agent_message_chunk",content={"type":"text","text":result_text})
        stop = "max_tokens" if mode == "wrong_stop" else "end_turn"
        response(message,{"stopReason":stop})
        if mode == "extensions":
            extension("_vendor/finished",result=result_text,stopReason="end_turn")
        if mode == "tool_after_terminal":
            update("tool_call",toolCallId="tool-2",title="Read host data",status="completed")
        if mode == "exit_after_terminal":
            break
"""


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="acp-test-")
        self.root = Path(self.directory.name)
        self.peer = self.root / "peer.py"
        self.peer.write_text(PEER)
        self.log = self.root / "requests.jsonl"
        self.cwd = self.root / "cwd"
        self.cwd.mkdir()

    def tearDown(self):
        self.directory.cleanup()

    def run_peer(self, mode="normal", result=None, text=None, **options):
        self.log.unlink(missing_ok=True)
        command = [
            sys.executable,
            str(self.peer),
            mode,
            str(self.log),
            text
            if text is not None
            else json.dumps(result if result is not None else CLEAN),
        ]
        runner = review.AcpReview(
            command,
            cwd=self.cwd,
            timeout=2,
            idle_timeout=0.2,
            setup_timeout=0.2,
            cancel_grace=0.05,
            **options,
        )
        value = asyncio.run(runner.run("Frozen authorized snapshot", SCHEMA))
        self.assertIsNotNone(runner.process.returncode)
        return value

    def messages(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def run_cli_peer(self, result, mode="normal", expected_prompts=1):
        self.log.unlink(missing_ok=True)
        request = self.root / "request.txt"
        output = self.root / "result.json"
        output.unlink(missing_ok=True)
        request.write_text("Frozen authorized snapshot")
        command = [
            sys.executable,
            "-B",
            str(self.peer),
            mode,
            str(self.log),
            json.dumps(result),
        ]
        harness = (
            "import sys; sys.path.insert(0," + repr(str(Path(__file__).parent)) + "); "
            "import acp_review; acp_review.provider_launch=lambda agent,scratch:("
            + repr(command)
            + ",None,None); sys.exit(acp_review.main())"
        )
        process = subprocess.run(
            [
                sys.executable,
                "-B",
                "-c",
                harness,
                "--agent",
                "codex",
                "--request",
                str(request),
                "--output",
                str(output),
            ],
            capture_output=True,
            check=False,
            timeout=5,
        )
        messages = self.messages()
        self.assertEqual(
            [message["method"] for message in messages].count("session/prompt"),
            expected_prompts,
        )
        cwd = Path(
            next(
                message
                for message in messages
                if message.get("method") == "session/new"
            )["params"]["cwd"]
        )
        self.assertFalse(cwd.parent.exists())
        self.assertEqual(list(self.root.glob(".acp-result-*")), [])
        pid = int(Path(str(self.log) + ".pid").read_text())
        state = subprocess.run(
            ["ps", "-o", "stat=", "-p", str(pid)],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
        self.assertFalse(state and not state.startswith("Z"))
        self.assertEqual(process.stdout, b"")
        self.assertNotIn(b"Traceback", process.stderr)
        published = json.loads(output.read_text())
        review.validate_schema(published, SCHEMA)
        return process, published

    def test_cli_success_publishes_clean_and_findings_results(self):
        for result in (
            {**CLEAN, "inspected_surface": "src/数据.py:1 😀"},
            {**CLEAN, "verdict": "findings", "findings": [FINDING]},
        ):
            with self.subTest(verdict=result["verdict"]):
                process, published = self.run_cli_peer(result)
                self.assertEqual(process.returncode, 0)
                self.assertEqual(process.stderr, b"")
                self.assertEqual(published, result)

    def test_cli_surrogate_escapes_produce_a_normal_incomplete_result(self):
        for result in (
            {**CLEAN, "residual_risk": "\ud800"},
            {**CLEAN, "inspected_surface": "\udfff"},
            {
                **CLEAN,
                "verdict": "findings",
                "findings": [{**FINDING, "title": "\ud800"}],
            },
        ):
            with self.subTest(result=result):
                process, published = self.run_cli_peer(result)
                self.assertEqual(process.returncode, 1)
                self.assertEqual(published["verdict"], "incomplete")
                self.assertEqual(published["findings"], [])
                self.assertEqual(
                    published["inspected_surface"],
                    "A review prompt was sent; inspection did not complete.",
                )
                self.assertIn("invalid Unicode", published["residual_risk"])

    def test_frame_unicode_failures_are_not_mislabeled_as_oversized(self):
        for mode in ("surrogate_frame_text", "surrogate_request_id"):
            with self.subTest(mode=mode):
                process, published = self.run_cli_peer(CLEAN, mode=mode)
                self.assertEqual(process.returncode, 1)
                self.assertEqual(published["verdict"], "incomplete")
                self.assertIn("invalid Unicode", published["residual_risk"])
                self.assertNotIn("oversized", published["residual_risk"])
                self.assertEqual(
                    published["inspected_surface"],
                    "A review prompt was sent; inspection did not complete.",
                )
                self.assertIn(
                    "session/cancel",
                    [message.get("method") for message in self.messages()],
                )

    def test_invalid_session_id_is_pre_prompt_failure_without_async_warnings(self):
        process, published = self.run_cli_peer(
            CLEAN, mode="surrogate_session_id", expected_prompts=0
        )
        self.assertEqual(process.returncode, 1)
        self.assertEqual(published["verdict"], "incomplete")
        self.assertEqual(published["inspected_surface"], "No review prompt was sent.")
        self.assertIn("invalid Unicode", published["residual_risk"])
        self.assertNotIn(b"Future exception was never retrieved", process.stderr)

    def test_send_failure_removes_owned_pending_requests(self):
        runner = review.AcpReview([], cwd=self.cwd)

        async def failed_send(_):
            runner.fail("Peer input closed.")
            raise review.ReviewError("Peer input closed.")

        runner.send = failed_send
        with self.assertRaises(review.ReviewError):
            asyncio.run(runner.request("session/prompt", {}))
        self.assertEqual(runner.pending, {})
        self.assertEqual(runner.pending_methods, {})

    def test_cancellation_during_send_settles_owned_future(self):
        runner = review.AcpReview([], cwd=self.cwd)

        async def blocked_send(_):
            await asyncio.sleep(60)

        runner.send = blocked_send

        async def exercise():
            task = asyncio.create_task(runner.request("initialize", {}))
            await asyncio.sleep(0)
            future = next(iter(runner.pending.values()))
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
            self.assertTrue(future.cancelled())

        asyncio.run(exercise())
        self.assertEqual(runner.pending, {})
        self.assertEqual(runner.pending_methods, {})

    def test_protocol_rejection_reports_only_owned_method_and_integer_code(self):
        for mode, method, code in (
            ("protocol_error", "initialize", -32000),
            ("session_error", "session/new", -32000),
            ("prompt_error", "session/prompt", -32603),
        ):
            with self.subTest(method=method):
                result = self.run_peer(mode)
                self.assertEqual(result["verdict"], "incomplete")
                self.assertEqual(
                    result["residual_risk"],
                    f"ACP peer rejected {method} (code {code}).",
                )
                self.assertNotIn("secret", json.dumps(result))

    def test_fresh_session_and_exactly_one_prompt(self):
        self.assertEqual(self.run_peer(), CLEAN)
        messages = self.messages()
        self.assertEqual(
            [message["id"] for message in messages],
            ["review-1", "review-2", "review-3"],
        )
        self.assertEqual(
            [m["method"] for m in messages],
            ["initialize", "session/new", "session/prompt"],
        )
        capabilities = messages[0]["params"]["clientCapabilities"]
        self.assertEqual(
            capabilities,
            {"fs": {"readTextFile": False, "writeTextFile": False}, "terminal": False},
        )
        self.assertEqual(messages[1]["params"]["mcpServers"], [])
        prompt = messages[2]["params"]["prompt"]
        self.assertEqual(len(prompt), 1)
        self.assertIn("Frozen authorized snapshot", prompt[0]["text"])
        self.assertIn("Shared external result schema", prompt[0]["text"])
        self.assertEqual(list(self.cwd.iterdir()), [])

    def test_chunked_utf8_message(self):
        result = {**CLEAN, "inspected_surface": "src/数据.py:1"}
        self.assertEqual(self.run_peer("chunks", result=result), result)

    def test_string_ids_avoid_numeric_wire_representation_changes(self):
        self.assertEqual(self.run_peer("numeric_id_roundtrip"), CLEAN)
        self.assertTrue(
            all(isinstance(message["id"], str) for message in self.messages())
        )

    def test_string_response_must_match_an_outstanding_request(self):
        result = self.run_peer("wrong_string_id")
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("unexpected or duplicate response", result["residual_risk"])

    def test_valid_orphan_responses_do_not_affect_the_owned_review(self):
        self.assertEqual(self.run_peer("orphan_responses"), CLEAN)
        self.assertEqual(
            [message["id"] for message in self.messages()],
            ["review-1", "review-2", "review-3"],
        )

    def test_orphan_results_cannot_complete_or_keep_a_review_alive(self):
        result = self.run_peer("orphan_only")
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("idle deadline", result["residual_risk"])
        self.assertEqual(
            result["inspected_surface"],
            "A review prompt was sent; inspection did not complete.",
        )

    def test_malformed_orphan_responses_still_fail_closed(self):
        for mode in (
            "malformed_orphan_response",
            "malformed_orphan_error",
            "malformed_orphan_id",
            "nonfinite_orphan_id",
        ):
            with self.subTest(mode=mode):
                result = self.run_peer(mode)
                self.assertEqual(result["verdict"], "incomplete")
                self.assertEqual(
                    result["inspected_surface"], "No review prompt was sent."
                )
                self.assertNotIn("secret", result["residual_risk"])

    def test_findings(self):
        result = {**CLEAN, "verdict": "findings", "findings": [FINDING]}
        self.assertEqual(self.run_peer(result=result), result)

    def test_integral_confidence_matches_the_shared_integer_schema(self):
        for confidence in (80.0, 90.0, 100.0):
            with self.subTest(confidence=confidence):
                result = {
                    **CLEAN,
                    "verdict": "findings",
                    "findings": [{**FINDING, "confidence": confidence}],
                }
                actual = self.run_peer(result=result)
                self.assertEqual(actual, result)
                self.assertIs(type(actual["findings"][0]["confidence"]), float)

    def test_invalid_numeric_confidence_is_incomplete(self):
        for confidence in (79.0, 101.0, 90.5, True, float("inf"), float("nan")):
            with self.subTest(confidence=confidence):
                result = self.run_peer(
                    result={
                        **CLEAN,
                        "verdict": "findings",
                        "findings": [{**FINDING, "confidence": confidence}],
                    }
                )
                self.assertEqual(result["verdict"], "incomplete")
                self.assertEqual(result["findings"], [])

    def test_canonical_finding_ids_require_an_absolute_end(self):
        for findings in (
            [{**FINDING, "id": "F1\n"}],
            [FINDING, {**FINDING, "id": "F1\n"}],
            [FINDING, FINDING],
        ):
            with self.subTest(ids=[finding["id"] for finding in findings]):
                result = self.run_peer(
                    result={**CLEAN, "verdict": "findings", "findings": findings}
                )
                self.assertEqual(result["verdict"], "incomplete")
                self.assertEqual(result["findings"], [])
        result = {
            **CLEAN,
            "verdict": "findings",
            "findings": [FINDING, {**FINDING, "id": "F12"}],
        }
        self.assertEqual(self.run_peer(result=result), result)

    def test_unsupported_schema_patterns_fail_closed(self):
        with self.assertRaisesRegex(
            review.ReviewError, "unsupported validation pattern"
        ):
            review.validate_schema("F1", {"type": "string", "pattern": "F[0-9]+"})

    def test_setup_metadata_does_not_race_session_creation(self):
        for mode in ("metadata_before_new_response", "metadata_after_new_response"):
            with self.subTest(mode=mode):
                self.assertEqual(self.run_peer(mode), CLEAN)

    def test_namespaced_extension_notifications_are_metadata_only(self):
        self.assertEqual(self.run_peer("extensions"), CLEAN)
        messages = self.messages()
        self.assertEqual(
            [message["method"] for message in messages],
            ["initialize", "session/new", "session/prompt"],
        )

    def test_extension_content_never_becomes_a_terminal_answer(self):
        self.assertEqual(self.run_peer("extension_only")["verdict"], "incomplete")

    def test_extension_rpc_is_denied_and_invalidates_the_review(self):
        result = self.run_peer("extension_rpc")
        self.assertEqual(result["verdict"], "incomplete")
        response = next(
            message for message in self.messages() if "method" not in message
        )
        self.assertEqual(response["error"]["code"], -32601)

    def test_malformed_or_unknown_standard_notifications_fail_closed(self):
        for mode in ("malformed_extension", "unknown_standard_notification"):
            with self.subTest(mode=mode):
                self.assertEqual(self.run_peer(mode)["verdict"], "incomplete")

    def test_an_answer_before_the_prompt_is_not_accepted(self):
        result = self.run_peer("answer_before_prompt")
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("before the review prompt", result["residual_risk"])

    def test_tool_after_terminal_response_is_not_ignored(self):
        result = self.run_peer("tool_after_terminal")
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("outside the frozen snapshot", result["residual_risk"])

    def test_answer_after_terminal_completion_is_not_accepted(self):
        result = self.run_peer("answer_after_terminal")
        self.assertEqual(result["verdict"], "incomplete")

    def test_clean_peer_exit_after_terminal_response(self):
        self.assertEqual(self.run_peer("exit_after_terminal"), CLEAN)

    def test_valid_incomplete_is_preserved(self):
        result = {
            **CLEAN,
            "verdict": "incomplete",
            "residual_risk": "Required context is absent.",
        }
        self.assertEqual(self.run_peer(result=result), result)

    def test_thought_chunks_are_not_terminal_result(self):
        result = self.run_peer("thought_only")
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("exactly one JSON", result["residual_risk"])

    def test_protocol_failures(self):
        for mode in (
            "invalid_protocol",
            "boolean_protocol",
            "malformed_update_type",
            "invalid_frame",
            "duplicate_key",
            "large_frame",
            "deep_frame",
            "truncated",
            "protocol_error",
            "wrong_id",
            "duplicate_response",
            "exit",
            "wrong_stop",
            "wrong_session",
            "unsupported_content",
        ):
            with self.subTest(mode=mode):
                result = self.run_peer(mode)
                self.assertEqual(result["verdict"], "incomplete")
                self.assertEqual(result["findings"], [])
                self.assertNotIn("secret", result["residual_risk"])

    def test_no_prose_fences_partial_or_duplicate_json(self):
        for text in (
            "Here is the result: " + json.dumps(CLEAN),
            "```json\n" + json.dumps(CLEAN) + "\n```",
            json.dumps(CLEAN) + json.dumps(CLEAN),
            '{"verdict":"clean"',
            '{"verdict":"clean","verdict":"clean"}',
            "NaN",
            "[" * 10000 + "0" + "]" * 10000,
        ):
            with self.subTest(text=text):
                self.assertEqual(self.run_peer(text=text)["verdict"], "incomplete")

    def test_strict_shared_schema(self):
        bad_results = [
            {**CLEAN, "extra": "unsupported"},
            {**CLEAN, "verdict": "findings"},
            {**CLEAN, "findings": [FINDING]},
            {**CLEAN, "verdict": "incomplete", "findings": [FINDING]},
            {**CLEAN, "residual_risk": ""},
            {
                **CLEAN,
                "verdict": "findings",
                "findings": [{**FINDING, "confidence": 79}],
            },
            {
                **CLEAN,
                "verdict": "findings",
                "findings": [{**FINDING, "assessment": "accept"}],
            },
            {**CLEAN, "verdict": "findings", "findings": [FINDING, FINDING]},
        ]
        for result in bad_results:
            with self.subTest(result=result):
                self.assertEqual(self.run_peer(result=result)["verdict"], "incomplete")

    def test_schema_changes_fail_closed_when_not_supported(self):
        with self.assertRaises(review.ReviewError):
            review.validate_schema(CLEAN, {**SCHEMA, "unevaluatedProperties": False})

    def test_review_output_size_is_bounded(self):
        original = review.MAX_TEXT_BYTES
        review.MAX_TEXT_BYTES = 10
        try:
            self.assertEqual(self.run_peer()["verdict"], "incomplete")
        finally:
            review.MAX_TEXT_BYTES = original

    def test_permissions_and_host_capabilities_fail_closed(self):
        for mode in ("permission", "file_read", "tool"):
            with self.subTest(mode=mode):
                result = self.run_peer(mode)
                self.assertEqual(result["verdict"], "incomplete")
                self.assertIn("outside the frozen snapshot", result["residual_risk"])
                replies = [
                    message for message in self.messages() if "method" not in message
                ]
                if mode == "permission":
                    self.assertEqual(
                        replies[0]["result"]["outcome"]["outcome"], "cancelled"
                    )
                if mode == "file_read":
                    self.assertEqual(replies[0]["error"]["code"], -32601)

    def test_working_directory_mutations_invalidate_completion(self):
        for mode in ("cwd_mutation", "shutdown_mutation"):
            with self.subTest(mode=mode):
                result = self.run_peer(mode)
                self.assertEqual(result["verdict"], "incomplete")
                self.assertIn(
                    "changed the empty working directory", result["residual_risk"]
                )
                (self.cwd / "unauthorized.txt").unlink()

    def test_nonempty_working_directory_fails_before_start(self):
        (self.cwd / "ambient.txt").write_text("ambient")
        runner = review.AcpReview(["/absent/peer"], cwd=self.cwd)
        result = asyncio.run(runner.run("Snapshot", SCHEMA))
        self.assertIn("empty private working directory", result["residual_risk"])
        self.assertIsNone(runner.process)

    def test_setup_deadline(self):
        result = self.run_peer("setup_timeout")
        self.assertIn("setup deadline", result["residual_risk"])
        self.assertEqual(result["inspected_surface"], "No review prompt was sent.")
        self.assertEqual([m["method"] for m in self.messages()], ["initialize"])

    def test_idle_deadline_cancels_without_retry(self):
        result = self.run_peer("idle")
        self.assertIn("idle deadline", result["residual_risk"])
        self.assertEqual(
            result["inspected_surface"],
            "A review prompt was sent; inspection did not complete.",
        )
        methods = [m["method"] for m in self.messages()]
        self.assertEqual(methods.count("session/prompt"), 1)
        self.assertIn("session/cancel", methods)

    def test_protocol_progress_resets_idle_deadline(self):
        self.assertEqual(self.run_peer("heartbeat"), CLEAN)

    def test_total_deadline_bounds_live_notifications(self):
        command = [
            sys.executable,
            str(self.peer),
            "total_timeout",
            str(self.log),
            json.dumps(CLEAN),
        ]
        runner = review.AcpReview(
            command,
            cwd=self.cwd,
            timeout=0.2,
            idle_timeout=0.1,
            setup_timeout=0.2,
            cancel_grace=0.03,
        )
        result = asyncio.run(runner.run("Frozen snapshot", SCHEMA))
        self.assertIn("total deadline", result["residual_risk"])
        self.assertIsNotNone(runner.process.returncode)

    def test_sigkill_reaps_a_peer_that_ignores_term(self):
        started = time.monotonic()
        self.assertEqual(self.run_peer("stubborn")["verdict"], "incomplete")
        self.assertLess(time.monotonic() - started, 1.5)

    def test_child_in_peer_process_group_is_stopped(self):
        result = self.run_peer("child")
        self.assertEqual(result["verdict"], "incomplete")
        pid = int(Path(str(self.log) + ".child").read_text())
        for _ in range(20):
            state = subprocess.run(
                ["ps", "-o", "stat=", "-p", str(pid)],
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip()
            if not state or state.startswith("Z"):
                break
            time.sleep(0.025)
        else:
            self.fail("ACP peer child process survived group cleanup")

    def test_cli_sigterm_cleans_child_and_scratch_and_writes_incomplete(self):
        request = self.root / "request.txt"
        output = self.root / "result.json"
        request.write_text("Frozen authorized snapshot")
        command = [
            sys.executable,
            str(self.peer),
            "idle",
            str(self.log),
            json.dumps(CLEAN),
        ]
        harness = (
            "import sys; sys.path.insert(0," + repr(str(Path(__file__).parent)) + "); "
            "import acp_review; acp_review.provider_launch=lambda agent,scratch:("
            + repr(command)
            + ",None,None); sys.exit(acp_review.main())"
        )
        process = subprocess.Popen(
            [
                sys.executable,
                "-c",
                harness,
                "--agent",
                "codex",
                "--request",
                str(request),
                "--output",
                str(output),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            for _ in range(100):
                if self.log.exists() and "session/prompt" in self.log.read_text():
                    break
                time.sleep(0.01)
            else:
                self.fail("CLI did not start its fake review prompt")
            process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 1)
            self.assertEqual(stdout, b"")
            self.assertNotIn(b"Traceback", stderr)
            self.assertEqual(json.loads(output.read_text())["verdict"], "incomplete")
            messages = self.messages()
            cwd = Path(
                next(m for m in messages if m.get("method") == "session/new")["params"][
                    "cwd"
                ]
            )
            self.assertFalse(cwd.parent.exists())
            self.assertIn("session/cancel", [m.get("method") for m in messages])
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

    def test_signals_during_cleanup_do_not_interrupt_teardown_or_result_writing(self):
        for number in review.STOP_SIGNALS:
            with self.subTest(number=number):
                self.log.unlink(missing_ok=True)
                marker = self.root / "cleanup-started"
                marker.unlink(missing_ok=True)
                request = self.root / "request.txt"
                output = self.root / "result.json"
                output.unlink(missing_ok=True)
                request.write_text("Frozen authorized snapshot")
                command = [
                    sys.executable,
                    str(self.peer),
                    "stubborn_child",
                    str(self.log),
                    json.dumps(CLEAN),
                ]
                harness = f"""
import sys
from pathlib import Path
sys.path.insert(0, {str(Path(__file__).parent)!r})
import acp_review
class HarnessReview(acp_review.AcpReview):
    def __init__(self, *args, **kwargs):
        kwargs['cancel_grace'] = .15
        super().__init__(*args, **kwargs)
    async def cleanup(self):
        Path({str(marker)!r}).write_text('cleanup started')
        await super().cleanup()
acp_review.AcpReview = HarnessReview
acp_review.provider_launch = lambda agent, scratch: ({command!r}, None, None)
sys.exit(acp_review.main())
"""
                process = subprocess.Popen(
                    [
                        sys.executable,
                        "-B",
                        "-c",
                        harness,
                        "--agent",
                        "codex",
                        "--request",
                        str(request),
                        "--output",
                        str(output),
                        "--idle-timeout-seconds",
                        ".05",
                    ],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                try:
                    for _ in range(200):
                        if marker.exists():
                            break
                        time.sleep(0.005)
                    else:
                        self.fail("CLI did not enter cleanup")
                    process.send_signal(number)
                    time.sleep(0.01)
                    process.send_signal(signal.SIGINT)
                    process.send_signal(signal.SIGINT)
                    stdout, stderr = process.communicate(timeout=5)
                    self.assertEqual(process.returncode, 1)
                    self.assertEqual(stdout, b"")
                    self.assertNotIn(b"Traceback", stderr)
                    result = json.loads(output.read_text())
                    review.validate_schema(result, SCHEMA)
                    self.assertEqual(result["verdict"], "incomplete")
                    self.assertIn("cancelled", result["residual_risk"])
                    self.assertEqual(
                        result["inspected_surface"],
                        "A review prompt was sent; inspection did not complete.",
                    )
                    messages = self.messages()
                    cwd = Path(
                        next(
                            message
                            for message in messages
                            if message.get("method") == "session/new"
                        )["params"]["cwd"]
                    )
                    self.assertFalse(cwd.parent.exists())
                    for suffix in (".pid", ".child"):
                        pid = int(Path(str(self.log) + suffix).read_text())
                        for _ in range(20):
                            state = subprocess.run(
                                ["ps", "-o", "stat=", "-p", str(pid)],
                                capture_output=True,
                                text=True,
                                check=False,
                            ).stdout.strip()
                            if not state or state.startswith("Z"):
                                break
                            time.sleep(0.025)
                        else:
                            self.fail(
                                "ACP process survived cancellation during cleanup"
                            )
                    self.assertEqual(list(self.root.glob(".acp-result-*")), [])
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()

    def test_direct_task_cancellation_during_cleanup_is_absorbed(self):
        command = [
            sys.executable,
            str(self.peer),
            "stubborn",
            str(self.log),
            json.dumps(CLEAN),
        ]
        runner = review.AcpReview(
            command, cwd=self.cwd, idle_timeout=0.03, cancel_grace=0.04
        )

        async def exercise():
            task = asyncio.create_task(runner.run("Frozen snapshot", SCHEMA))
            while not runner.cleanup_started:
                await asyncio.sleep(0.005)
            task.cancel()
            await asyncio.sleep(0.005)
            task.cancel()
            return await task

        result = asyncio.run(exercise())
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("cancelled", result["residual_risk"])
        self.assertIsNotNone(runner.process.returncode)

    def test_cancelled_cleanup_task_does_not_spin_or_leave_peer_running(self):
        command = [
            sys.executable,
            str(self.peer),
            "idle",
            str(self.log),
            json.dumps(CLEAN),
        ]
        runner = review.AcpReview(
            command, cwd=self.cwd, idle_timeout=0.03, cancel_grace=0.05
        )

        async def interrupted_cleanup():
            asyncio.current_task().cancel()
            await asyncio.sleep(0)

        runner.cleanup = interrupted_cleanup

        async def exercise():
            return await asyncio.wait_for(runner.run("Frozen snapshot", SCHEMA), 1)

        result = asyncio.run(exercise())
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("cleanup", result["residual_risk"])
        self.assertIsNotNone(runner.process.returncode)

    def test_stderr_is_drained_without_exposing_content(self):
        self.assertEqual(self.run_peer("stderr_noise"), CLEAN)

    def test_session_metadata_is_passed_only_at_creation(self):
        metadata = {"claudeCode": {"options": {"tools": []}}}
        self.assertEqual(self.run_peer(session_meta=metadata), CLEAN)
        self.assertEqual(self.messages()[1]["params"]["_meta"], metadata)
        self.assertNotIn("_meta", self.messages()[2]["params"])

    def test_failed_launch_is_incomplete(self):
        runner = review.AcpReview(["/absent/acp-peer"], cwd=self.cwd)
        result = asyncio.run(runner.run("Frozen snapshot", SCHEMA))
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("could not start", result["residual_risk"])
        self.assertEqual(result["inspected_surface"], "No review prompt was sent.")

    def test_prompt_not_counted_when_a_failure_prevents_send(self):
        runner = review.AcpReview([], cwd=self.cwd)
        runner.failure = "Setup failed before submission."
        with self.assertRaises(review.ReviewError):
            asyncio.run(
                runner.request("session/prompt", {"sessionId": "unused", "prompt": []})
            )
        self.assertFalse(runner.prompt_started)

    def test_submitted_prompt_failure_is_reported_without_a_retry(self):
        result = self.run_peer("wrong_stop")
        self.assertEqual(
            result["inspected_surface"],
            "A review prompt was sent; inspection did not complete.",
        )
        self.assertEqual(
            [message["method"] for message in self.messages()].count("session/prompt"),
            1,
        )

    def test_atomic_output_is_private_and_never_replaces_existing_file(self):
        path = self.root / "result.json"
        with review.AtomicResult(path) as output:
            output.publish(CLEAN)
        self.assertEqual(json.loads(path.read_text()), CLEAN)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError), review.AtomicResult(path) as output:
            output.publish(review.incomplete("failure"))
        self.assertEqual(json.loads(path.read_text()), CLEAN)
        self.assertEqual(list(self.root.glob(".acp-result-*")), [])

    def test_stage_removal_survives_stream_close_failure(self):
        path = self.root / "result.json"
        with (
            self.assertRaisesRegex(OSError, "flush failed"),
            review.AtomicResult(path) as output,
        ):
            original = output.stream

            class BadClose:
                def close(self):
                    original.close()
                    raise OSError("flush failed")

            output.stream = BadClose()
        self.assertEqual(list(self.root.glob(".acp-result-*")), [])
        self.assertFalse(path.exists())

    def test_stage_close_failure_preserves_an_existing_exception(self):
        path = self.root / "result.json"
        diagnostics = io.StringIO()
        with (
            contextlib.redirect_stderr(diagnostics),
            self.assertRaisesRegex(RuntimeError, "original failure"),
            review.AtomicResult(path) as output,
        ):
            original = output.stream

            class BadClose:
                def close(self):
                    original.close()
                    raise OSError("flush failed")

            output.stream = BadClose()
            raise RuntimeError("original failure")
        self.assertIn("Result staging cleanup failed", diagnostics.getvalue())
        self.assertEqual(list(self.root.glob(".acp-result-*")), [])

    def test_publication_race_preserves_existing_output_and_removes_stage(self):
        path = self.root / "result.json"
        with self.assertRaises(FileExistsError), review.AtomicResult(path) as output:
            path.write_text("Another writer's result")
            output.publish(CLEAN)
        self.assertEqual(path.read_text(), "Another writer's result")
        self.assertEqual(list(self.root.glob(".acp-result-*")), [])

    def test_output_path_failures_prevent_provider_launch_and_remove_probes(self):
        for mode in ("missing_parent", "unwritable", "unsupported_links"):
            with self.subTest(mode=mode):
                request = self.root / "request.txt"
                marker = self.root / "provider-launched"
                output = self.root / (
                    "missing/result.json" if mode == "missing_parent" else "result.json"
                )
                request.write_text("Frozen snapshot")
                harness = f"""
import sys
from pathlib import Path
sys.path.insert(0, {str(Path(__file__).parent)!r})
import acp_review
def launch(*args):
    Path({str(marker)!r}).write_text('provider launched')
    raise AssertionError('Provider must not launch')
acp_review.provider_launch = launch
def unavailable(*args, **kwargs):
    raise PermissionError('unsupported result destination')
if {mode!r} == 'unwritable':
    acp_review.tempfile.NamedTemporaryFile = unavailable
if {mode!r} == 'unsupported_links':
    acp_review.os.link = unavailable
sys.exit(acp_review.main())
"""
                process = subprocess.run(
                    [
                        sys.executable,
                        "-B",
                        "-c",
                        harness,
                        "--agent",
                        "codex",
                        "--request",
                        str(request),
                        "--output",
                        str(output),
                    ],
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(process.returncode, 1)
                self.assertIn(b"no review prompt was sent", process.stderr)
                self.assertNotIn(b"Traceback", process.stderr)
                self.assertEqual(process.stdout, b"")
                self.assertFalse(marker.exists())
                self.assertFalse(output.exists())
                self.assertEqual(list(self.root.glob(".acp-result-*")), [])

    def test_private_result_stage_is_reserved_before_provider_launch(self):
        request = self.root / "request.txt"
        marker = self.root / "stage-observation.json"
        output = self.root / "result.json"
        request.write_text("Frozen snapshot")
        harness = f"""
import json,sys
from pathlib import Path
sys.path.insert(0, {str(Path(__file__).parent)!r})
import acp_review
def launch(*args):
    stages = list(Path({str(self.root)!r}).glob('.acp-result-*'))
    observed = {{'count': len(stages), 'mode': stages[0].stat().st_mode & 0o777,
                'output_exists': Path({str(output)!r}).exists(),
                'probes': len(list(Path({str(self.root)!r}).glob('*.probe')))}}
    Path({str(marker)!r}).write_text(json.dumps(observed))
    return ['/absent/acp-peer'],None,None
acp_review.provider_launch = launch
sys.exit(acp_review.main())
"""
        process = subprocess.run(
            [
                sys.executable,
                "-B",
                "-c",
                harness,
                "--agent",
                "codex",
                "--request",
                str(request),
                "--output",
                str(output),
            ],
            capture_output=True,
            check=False,
        )
        self.assertEqual(process.returncode, 1)
        self.assertEqual(
            json.loads(marker.read_text()),
            {"count": 1, "mode": 0o600, "output_exists": False, "probes": 0},
        )
        result = json.loads(output.read_text())
        review.validate_schema(result, SCHEMA)
        self.assertEqual(result["inspected_surface"], "No review prompt was sent.")
        self.assertEqual(list(self.root.glob(".acp-result-*")), [])

    def test_existing_cli_output_is_not_reused_and_prevents_launch(self):
        output = self.root / "existing.json"
        output.write_text(json.dumps(CLEAN))
        request = self.root / "request.txt"
        request.write_text("Frozen snapshot")
        process = subprocess.run(
            [
                sys.executable,
                str(Path(review.__file__)),
                "--agent",
                "codex",
                "--request",
                str(request),
                "--output",
                str(output),
            ],
            capture_output=True,
            check=False,
        )
        self.assertEqual(process.returncode, 1)
        self.assertEqual(json.loads(output.read_text()), CLEAN)
        self.assertNotIn(b"Traceback", process.stderr)

    def test_cli_preflight_does_not_write_bytecode_in_skill_source(self):
        skill = self.root / "copied-skill"
        scripts = skill / "scripts"
        references = skill / "references"
        scripts.mkdir(parents=True)
        references.mkdir()
        source = Path(review.__file__).parent
        for name in ("acp_review.py", "acp_providers.py"):
            shutil.copy2(source / name, scripts / name)
        shutil.copy2(review.SCHEMA_PATH, references / review.SCHEMA_PATH.name)
        before = {
            path.relative_to(skill): path.read_bytes()
            for path in skill.rglob("*")
            if path.is_file()
        }
        request = self.root / "request.txt"
        output = self.root / "result.json"
        request.write_text("Frozen authorized snapshot")
        env = os.environ.copy()
        env.pop("PYTHONDONTWRITEBYTECODE", None)
        env["PATH"] = ""
        process = subprocess.run(
            [
                sys.executable,
                str(scripts / "acp_review.py"),
                "--agent",
                "claude",
                "--request",
                str(request),
                "--output",
                str(output),
            ],
            capture_output=True,
            env=env,
            check=False,
        )
        self.assertEqual(process.returncode, 1)
        result = json.loads(output.read_text())
        review.validate_schema(result, SCHEMA)
        self.assertEqual(result["verdict"], "incomplete")
        self.assertIn("Required ACP executable is missing", result["residual_risk"])
        self.assertEqual(result["inspected_surface"], "No review prompt was sent.")
        self.assertNotIn(b"Traceback", process.stderr)
        self.assertFalse((scripts / "__pycache__").exists())
        after = {
            path.relative_to(skill): path.read_bytes()
            for path in skill.rglob("*")
            if path.is_file()
        }
        self.assertEqual(after, before)

    def test_schema_matches_canonical_assessed_contract(self):
        canonical = json.loads(
            review.SCHEMA_PATH.with_name("review-result.schema.json").read_text()
        )
        canonical_finding = canonical["properties"]["findings"]["items"]
        external_finding = SCHEMA["properties"]["findings"]["items"]
        self.assertEqual(
            {
                key: value
                for key, value in canonical_finding["properties"].items()
                if key not in {"assessment", "assessment_rationale"}
            },
            external_finding["properties"],
        )
        self.assertEqual(canonical["allOf"], SCHEMA["allOf"])


if __name__ == "__main__":
    unittest.main()
