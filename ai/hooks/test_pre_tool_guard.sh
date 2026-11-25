#!/usr/bin/env bash
set -euo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/pre-tool-guard.sh"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# Create synthetic repos:
# - repo_a: strict guardrails (deny, ask, allowlist, require_wrapper)
# - repo_b: unguarded git repo (no .claude/guardrails.json)
# - repo_bad_json: malformed JSON
# - repo_bad_schema: valid JSON but bad rule schema / regex / string allow_if_regex
REPO_A="$TMPDIR_BASE/repo_a"
REPO_B="$TMPDIR_BASE/repo_b"
REPO_BAD="$TMPDIR_BASE/repo_bad"
mkdir -p "$REPO_A/.git" "$REPO_A/.claude" "$REPO_B/.git" "$REPO_BAD/.git" "$REPO_BAD/.claude"

cat >"$REPO_A/.claude/guardrails.json" <<'JSON'
{
  "rules": [
    {
      "id": "no-ecto-drop",
      "decision": "deny",
      "cmd_regex": "(^|\\s)mix\\s+(do\\s+)?([^;|&]*[\\s,+])?ecto\\.(drop|reset)(\\s|$)",
      "reason": "Never drop or reset the dev database.",
      "instead": "mise exec -- mix drop_test_db"
    },
    {
      "id": "no-raw-pg-dump",
      "decision": "deny",
      "cmd_regex": "(^|\\s)(pg_dump|pg_restore)(\\s|$)",
      "allow_if_regex": ["^docker\\s+compose\\s+exec\\s+-T\\s+db\\s+pg_dump\\b"],
      "reason": "Use the backup Mix task instead of raw pg_dump/pg_restore."
    },
    {
      "id": "require-mise",
      "decision": "deny",
      "require_wrapper": {
        "wrapper": "mise",
        "commands": ["mix", "iex"]
      },
      "reason": "Run Elixir commands through mise exec --."
    },
    {
      "id": "ask-restore",
      "decision": "ask",
      "cmd_regex": "(^|\\s)mix\\s+(do\\s+)?([^;|&]*[\\s,+])?hourbun\\.restore(\\s|$)",
      "reason": "Restore replaces the dev database and requires explicit user approval."
    },
    {
      "id": "ask-fly",
      "decision": "ask",
      "cmd_regex": "(^|\\s)(fly|flyctl)\\s+([^;|&]*\\s)?(deploy|secrets|ssh|postgres|pg|proxy)(\\s|$)",
      "reason": "Fly production command requires explicit user approval."
    }
  ]
}
JSON

printf '{bad json' >"$REPO_BAD/.claude/guardrails.json"

python3 - "$HOOK" "$REPO_A" "$REPO_B" "$REPO_BAD" "$TMPDIR_BASE" <<'PY'
import json
import os
import subprocess
import sys
import time

hook, repo_a, repo_b, repo_bad, tmp_base = sys.argv[1:6]
passed = 0
failed = 0

def run_hook(payload, env_extra=None):
    # Clean ambient Claude/T3 env so tests control interactivity deterministically
    env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE_") and not k.startswith("PRE_TOOL_GUARD_")}
    if env_extra:
        env.update(env_extra)
    t0 = time.perf_counter()
    proc = subprocess.run(
        [hook],
        input=payload if isinstance(payload, str) else json.dumps(payload),
        text=True,
        capture_output=True,
        env=env,
    )
    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    out = proc.stdout.strip()
    decision = "allow"
    reason = ""
    if out:
        parsed = json.loads(out)
        hso = parsed["hookSpecificOutput"]
        decision = hso["permissionDecision"]
        reason = hso.get("permissionDecisionReason", "")
    return proc.returncode, decision, reason, elapsed_ms, proc.stderr

def check(name, expected_decision, payload, env_extra=None, reason_substr=None):
    global passed, failed
    rc, decision, reason, ms, stderr = run_hook(payload, env_extra)
    ok = rc == 0 and decision == expected_decision
    if ok and reason_substr:
        ok = reason_substr in reason
    if ok:
        passed += 1
    else:
        failed += 1
        print(f"FAIL [{name}]: expected={expected_decision!r} got={decision!r} rc={rc} reason={reason!r} stderr={stderr!r}")
    return ms

INTERACTIVE_CLI = {"CLAUDE_CODE_ENTRYPOINT": "cli"}

def mk(cmd, cwd=repo_a, mode="default", extra=None):
    d = {
        "tool_name": "Bash",
        "cwd": cwd,
        "permission_mode": mode,
        "tool_input": {"command": cmd},
    }
    if extra:
        d.update(extra)
    return d

# 1. Basic deny / allow / wrapper / mix do
check("deny ecto.drop", "deny", mk("mise exec -- mix ecto.drop"), INTERACTIVE_CLI)
check("deny ecto.reset", "deny", mk("mise exec -- mix ecto.reset"), INTERACTIVE_CLI)
check("deny mix do ecto.drop", "deny", mk("mise exec -- mix do compile + ecto.drop"), INTERACTIVE_CLI)
check("deny unprefixed mix", "deny", mk("mix test"), INTERACTIVE_CLI, "require-mise")
check("deny timeout unprefixed mix", "deny", mk("timeout 60 mix test"), INTERACTIVE_CLI, "require-mise")
check("deny brace group unprefixed mix", "deny", mk("{ mix test; }"), INTERACTIVE_CLI, "require-mise")
check("allow mise wrapped mix", "allow", mk("mise exec -- mix test"), INTERACTIVE_CLI)
check("allow env var + mise", "allow", mk("PW_BROWSER=firefox mise exec -- mix test.browser"), INTERACTIVE_CLI)
check("allow mise exec bash -c mix test", "allow", mk("mise exec -- bash -c 'mix test'"), INTERACTIVE_CLI)
check("allow command -v mix", "allow", mk("command -v mix"), INTERACTIVE_CLI)
check("allow unguarded repo", "allow", mk("mix ecto.reset", cwd=repo_b), INTERACTIVE_CLI)

# 2. Wrappers, continuations, nested shells, exec-capable utilities
check("deny bash -c ecto.drop", "deny", mk("bash -c 'mise exec -- mix ecto.drop'"), INTERACTIVE_CLI)
check("deny nohup unprefixed mix", "deny", mk("nohup mix setup"), INTERACTIVE_CLI)
check("deny env -S mix ecto.drop", "deny", mk("env -S 'mise exec -- mix ecto.drop'"), INTERACTIVE_CLI)
check("deny eval ecto.reset", "deny", mk("eval 'mise exec -- mix ecto.reset'"), INTERACTIVE_CLI)
check("deny backslash-newline continuation", "deny", mk("mix \\\ntest"), INTERACTIVE_CLI)
check("deny find -exec ecto.reset", "deny", mk("find . -exec mise exec -- mix ecto.reset \\;"), INTERACTIVE_CLI)
check("deny awk system()", "deny", mk("awk 'BEGIN{system(\"mise exec -- mix ecto.drop\")}'"), INTERACTIVE_CLI)
check("deny pipe into sh", "deny", mk("echo 'mise exec -- mix ecto.drop' | sh"), INTERACTIVE_CLI)
check("deny bash heredoc", "deny", mk("bash <<'EOF'\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny quoted <<EOF does not hide next line", "deny", mk("echo \"<<EOF\"\nmix test"), INTERACTIVE_CLI)
check("deny here-string <<< does not hide next line", "deny", mk("grep foo <<<bar\nmise exec -- mix ecto.drop"), INTERACTIVE_CLI)
check("deny unterminated heredoc fails closed", "deny", mk("cat <<'EOF'\nnever closed"), INTERACTIVE_CLI)
check("deny cd + bash heredoc uses active cwd", "deny", mk(f"cd {repo_a} && bash <<'EOF'\nmise exec -- mix ecto.drop\nEOF", cwd=repo_b), INTERACTIVE_CLI)
check("deny newline cd + bash -s heredoc uses active cwd", "deny", mk(f"cd {repo_a}\nbash -s <<'EOF'\nmise exec -- mix ecto.drop\nEOF", cwd=repo_b), INTERACTIVE_CLI)
check("deny brace group cd propagates out", "deny", mk(f"{{ cd {repo_a}; }}; mix test", cwd=repo_b), INTERACTIVE_CLI)
check("deny tmux send-keys sequential cd propagates", "deny", mk(f"tmux send-keys -t dev 'cd {repo_a}' Enter 'mix test' Enter", cwd=repo_b), {**INTERACTIVE_CLI, "PRE_TOOL_GUARD_TMUX_PANE_PATH": repo_b})

# 3. Shell scope, cd, pushd, popd, conditional chains, mise -C, direnv exec
check("deny cross-repo cd into repo_a", "deny", mk(f"cd {repo_a} && mise exec -- mix ecto.drop", cwd=repo_b), INTERACTIVE_CLI)
check("deny cross-repo pushd into repo_a", "deny", mk(f"pushd {repo_a} && mise exec -- mix ecto.drop", cwd=repo_b), INTERACTIVE_CLI)
check("deny dynamic cd $UNKNOWN", "deny", mk("cd \"$UNKNOWN_DIR\" && mix test", cwd=repo_b), INTERACTIVE_CLI)
check("deny popd unknown cwd", "deny", mk("popd && mix test", cwd=repo_b), INTERACTIVE_CLI)
check("deny cd - unknown cwd", "deny", mk("cd - && mix test", cwd=repo_a), INTERACTIVE_CLI)
check("deny subshell cd does not leak out", "deny", mk(f"(cd {repo_b}) ; mix test", cwd=repo_a), INTERACTIVE_CLI)
check("deny skipped conditional cd still enforces original repo", "deny", mk(f"false && cd {repo_b}; mix test", cwd=repo_a), INTERACTIVE_CLI)
check("deny mise -C repo_a exec mix ecto.drop", "deny", mk(f"mise -C {repo_a} exec -- mix ecto.drop", cwd=repo_b), INTERACTIVE_CLI)
check("deny direnv exec repo_b does not escape repo_a cwd", "deny", mk(f"direnv exec {repo_b} mix test", cwd=repo_a), INTERACTIVE_CLI)

# 4. Data commands, heredocs, comment stripping, allowlists
check("allow rg mention", "allow", mk("rg 'mix ecto.drop' docs/"), INTERACTIVE_CLI)
check("allow git commit -m", "allow", mk("git commit -m 'never run mix ecto.drop'"), INTERACTIVE_CLI)
check("allow git commit heredoc", "allow", mk("git commit -m \"$(cat <<'EOF'\nUpdate rules\n\nmix ecto.drop is blocked\nEOF\n)\""), INTERACTIVE_CLI)
check("allow cat heredoc to file", "allow", mk("cat > notes.md <<'EOF'\nmix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("allow gh pr create body mention", "allow", mk("gh pr create --title 'docs' --body 'never run mix ecto.drop'"), INTERACTIVE_CLI)
check("allow anchored allowlist pg_dump", "allow", mk("docker compose exec -T db pg_dump -U postgres hourbun_dev > /tmp/x"), INTERACTIVE_CLI)
check("deny raw pg_dump", "deny", mk("pg_dump hourbun_dev > /tmp/x"), INTERACTIVE_CLI)
check("deny comment spoofing allow_if_regex", "deny", mk("pg_dump hourbun_dev # docker compose exec -T db pg_dump"), INTERACTIVE_CLI)

# 5. tmux global options, multi-line send-keys, pane resolution
check("deny tmux send-keys into repo_a pane", "deny", mk("tmux send-keys -t dev 'mise exec -- mix ecto.drop' Enter", cwd=repo_b), {**INTERACTIVE_CLI, "PRE_TOOL_GUARD_TMUX_PANE_PATH": repo_a})
check("deny tmux -L sock send-keys with embedded Enter", "deny", mk("tmux -L alt send-keys -t dev 'echo ok' Enter 'mise exec -- mix ecto.drop' Enter", cwd=repo_b), {**INTERACTIVE_CLI, "PRE_TOOL_GUARD_TMUX_PANE_PATH": repo_a})
check("deny tmux send-keys -H hex", "deny", mk("tmux send-keys -H 6d 69 78", cwd=repo_b), {**INTERACTIVE_CLI, "PRE_TOOL_GUARD_TMUX_PANE_PATH": repo_a})
check("deny tmux send-keys unknown pane fails closed", "deny", mk("tmux send-keys -t missing 'mix test' Enter", cwd=repo_b), {**INTERACTIVE_CLI, "PRE_TOOL_GUARD_TMUX_PANE_PATH": ""})
check("allow tmux send-keys into repo_b pane", "allow", mk("tmux send-keys -t dev 'mix ecto.reset' Enter", cwd=repo_a), {**INTERACTIVE_CLI, "PRE_TOOL_GUARD_TMUX_PANE_PATH": repo_b})

# 6. Interactivity & permission_mode fail-closed matrix
for mode in ("default", "acceptEdits", "plan", "auto"):
    check(f"ask in interactive CLI {mode}", "ask", mk("mise exec -- mix hourbun.restore a.dump", mode=mode), INTERACTIVE_CLI)

check("ask in attended T3 session", "ask", mk("mise exec -- mix hourbun.restore a.dump", mode="default"), {"CLAUDE_CODE_ENTRYPOINT": "t3-code", "CLAUDE_CODE_SESSION_ATTENDED": "1"})
check("deny in unattended T3 session", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="default"), {"CLAUDE_CODE_ENTRYPOINT": "t3-code", "CLAUDE_CODE_SESSION_ATTENDED": "0"})
check("deny in T3 child session", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="default"), {"CLAUDE_CODE_ENTRYPOINT": "t3-code", "CLAUDE_CODE_CHILD_SESSION": "1"})
check("deny detached default mode with no entrypoint", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="default"), {})
check("deny in bypassPermissions", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="bypassPermissions"), INTERACTIVE_CLI)
check("deny in dontAsk", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="dontAsk"), INTERACTIVE_CLI)
check("deny with unknown mode", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="mystery"), INTERACTIVE_CLI)
check("deny with agent_id", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="default", extra={"agent_id": "sub-1"}), INTERACTIVE_CLI)
check("deny with agent_type", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="default", extra={"agent_type": "Explore"}), INTERACTIVE_CLI)
check("deny with sdk-cli entrypoint", "deny", mk("mise exec -- mix hourbun.restore a.dump", mode="default"), {"CLAUDE_CODE_ENTRYPOINT": "sdk-cli"})

# 7. Malformed policy / bad schema / malformed hook payload fail closed
check("deny malformed JSON policy", "deny", mk("ls", cwd=repo_bad), INTERACTIVE_CLI, "Malformed guardrails policy")
for bad_name, bad_content in [
    ("bad regex", {"rules": [{"id": "r", "decision": "deny", "cmd_regex": "(unclosed"}]}),
    ("non-dict rule", {"rules": ["oops"]}),
    ("string allow_if_regex", {"rules": [{"id": "r", "decision": "deny", "cmd_regex": "mix", "allow_if_regex": "db"}]}),
    ("typo key", {"rules": [{"id": "r", "decision": "deny", "cmd_rgx": "mix"}]}),
    ("missing rules", {"version": 1}),
    ("bad require_wrapper", {"rules": [{"id": "r", "decision": "deny", "require_wrapper": ["mix"]}]}),
]:
    bad_dir = os.path.join(tmp_base, f"bad_{bad_name.replace(' ', '_')}")
    os.makedirs(os.path.join(bad_dir, ".git"), exist_ok=True)
    os.makedirs(os.path.join(bad_dir, ".claude"), exist_ok=True)
    with open(os.path.join(bad_dir, ".claude", "guardrails.json"), "w") as f:
        json.dump(bad_content, f)
    check(f"deny schema error ({bad_name})", "deny", mk("ls", cwd=bad_dir), INTERACTIVE_CLI, "Malformed guardrails policy")

check("deny non-dict hook payload", "deny", "[1, 2, 3]", INTERACTIVE_CLI)
check("deny non-dict tool_input", "deny", json.dumps({"tool_input": "x"}), INTERACTIVE_CLI)

# 8. Real repository policy acceptance tests (when repos exist locally)
hourbun = "/Users/fredwu/Code/Wuit/hourbun"
if os.path.exists(os.path.join(hourbun, ".claude", "guardrails.json")):
    check("hourbun: deny ecto.drop", "deny", mk("mise exec -- mix ecto.drop", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny mix do ecto.reset", "deny", mk("mise exec -- mix do compile, ecto.reset", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny mix do ecto.drop, ecto.create", "deny", mk("mise exec -- mix do ecto.drop, ecto.create", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny mix do ecto.rollback, ecto.migrate", "deny", mk("mise exec -- mix do ecto.rollback, ecto.migrate", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny mix do setup, test", "deny", mk("mise exec -- mix do setup, test", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: allow documented container pg_dump", "allow", mk("docker compose exec -T db pg_dump --username postgres --format custom hourbun_dev > backups/x.partial", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny arbitrary container pg_dump", "deny", mk("docker compose exec -T db pg_dump -h otherhost otherdb", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny rollback --to", "deny", mk("mise exec -- mix ecto.rollback --to 20261008102253", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny rollback --step 1 --all", "deny", mk("mise exec -- mix ecto.rollback --step 1 --all", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny rollback --step 1 --to", "deny", mk("mise exec -- mix ecto.rollback --step 1 --to 20261008102253", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: ask exact rollback --step 1", "ask", mk("mise exec -- mix ecto.rollback --step 1", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny docker-compose down -v", "deny", mk("docker-compose down -v", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny docker compose -f down --volumes", "deny", mk("docker compose -f docker-compose.yaml down --volumes", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: deny docker volume rm hourbun_db", "deny", mk("docker volume rm hourbun_db", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: ask docker volume rm other", "ask", mk("docker volume rm old_pg15_vol", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: ask flyctl -a hourbun deploy", "ask", mk("flyctl -a hourbun deploy", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: ask fly pg connect", "ask", mk("fly pg connect", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: allow hourbun.backup", "allow", mk("mise exec -- mix hourbun.backup", cwd=hourbun), INTERACTIVE_CLI)
    check("hourbun: allow scripts/verify changed", "allow", mk("./scripts/verify changed", cwd=hourbun), INTERACTIVE_CLI)

inspiria = "/Users/fredwu/Code/Clients/Inspire/inspiria"
if os.path.exists(os.path.join(inspiria, ".claude", "guardrails.json")):
    check("inspiria: deny mix phx.gen.live", "deny", mk("mix phx.gen.live Blog Post posts title:string", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: deny mix do phx.gen.html", "deny", mk("mix do compile + phx.gen.html Accounts User users", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: deny comment spoof phx.gen.secret", "deny", mk("mix phx.gen.live A B cs # mix phx.gen.secret", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: allow mix phx.gen.secret", "allow", mk("mix phx.gen.secret", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: allow mix phx.gen.secret 32", "allow", mk("mix phx.gen.secret 32", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: allow direnv mix phx.gen.secret 32", "allow", mk("direnv exec . mix phx.gen.secret 32", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: allow mix ecto.reset", "allow", mk("mix ecto.reset", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: ask flyctl deploy", "ask", mk("flyctl deploy", cwd=inspiria), INTERACTIVE_CLI)
    check("inspiria: ask fly -a inspiria pg connect", "ask", mk("fly -a inspiria pg connect", cwd=inspiria), INTERACTIVE_CLI)

# 9. Latency budget (< 50ms average across 5 ordinary runs)
times = [check(f"latency run {i}", "allow", mk("mise exec -- mix test"), INTERACTIVE_CLI) for i in range(5)]
avg_ms = sum(times) / len(times)
if avg_ms >= 50.0:
    failed += 1
    print(f"FAIL [latency]: avg {avg_ms:.1f}ms exceeded 50ms budget")
else:
    passed += 1

print(f"pre-tool-guard tests: {passed} passed, {failed} failed (avg {avg_ms:.1f}ms)")
sys.exit(0 if failed == 0 else 1)
PY
