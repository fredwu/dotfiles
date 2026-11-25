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

# 4b. Round 3 heredoc & child-shell brace group regressions
check("deny shell heredoc with trailing comment", "deny", mk("bash <<'EOF' # comment\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny shell heredoc followed by cd on same line", "deny", mk("bash <<'EOF'; cd /tmp\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny leading heredoc redirection before bash and cd", "deny", mk("<<'EOF' bash; cd /tmp\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("allow heredoc inside brace group", "allow", mk("{\n  cat <<'EOF'\nhello\nEOF\n}"), INTERACTIVE_CLI)
check("deny shell heredoc inside subshell after cd", "deny", mk(f"( cd {repo_a} && bash <<'EOF'\nmix test\nEOF\n)", cwd="/tmp"), INTERACTIVE_CLI)
check("allow harmless shell heredoc inside brace group after cd", "allow", mk("cd /tmp && { bash <<'EOF'\necho ok\nEOF\n}"), INTERACTIVE_CLI)
check("deny after piped brace group cd (left of pipe)", "deny", mk("{ cd /tmp; } | cat; mix test"), INTERACTIVE_CLI)
check("deny after piped brace group cd (right of pipe)", "deny", mk("echo hi | { cd /tmp; }; mix test"), INTERACTIVE_CLI)
check("deny after redirected piped brace group cd", "deny", mk("{ cd /tmp; } 2>/dev/null | cat; mix test"), INTERACTIVE_CLI)
check("deny after backgrounded brace group cd", "deny", mk("{ cd /tmp; } & mix test"), INTERACTIVE_CLI)
check("deny after backgrounded list cd", "deny", mk("cd /tmp && echo ok & mix test"), INTERACTIVE_CLI)
check("allow dotted heredoc delimiter", "allow", mk("cat <<END.1\nhello\nEND.1"), INTERACTIVE_CLI)
check("allow mixed-quote dotted heredoc delimiter", "allow", mk("cat <<E'N'D.1\nhello\nEND.1"), INTERACTIVE_CLI)
check("allow << inside multiline double-quoted string", "allow", mk('echo "line 1\nnot a <<EOF heredoc\nline 3"'), INTERACTIVE_CLI)
check("allow << inside multiline single-quoted string", "allow", mk("echo 'line 1\nnot a <<EOF heredoc\nline 3'"), INTERACTIVE_CLI)

# 4c. Round 4 regressions (reserved words, ANSI-C quoting, unquoted heredoc subst, arithmetic, continuations, delimiters, bash -c stdin)
check("deny shell heredoc under if/then", "deny", mk("if true; then bash <<EOF\nmise exec -- mix ecto.drop\nEOF\nfi"), INTERACTIVE_CLI)
check("deny shell heredoc under for/do", "deny", mk("for i in 1; do bash <<EOF\nmise exec -- mix ecto.drop\nEOF\ndone"), INTERACTIVE_CLI)
check("deny shell heredoc under case pattern", "deny", mk("case x in x) bash <<EOF\nmise exec -- mix ecto.drop\nEOF\n;; esac"), INTERACTIVE_CLI)
check("deny shell heredoc under negation !", "deny", mk("! bash <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny shell heredoc under sudo", "deny", mk("sudo bash <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny unwrapped mix test under if/then", "deny", mk("if true; then mix test; fi"), INTERACTIVE_CLI)
check("deny command after ANSI-C quote with escaped apostrophe", "deny", mk("echo $'it\\'s'; mise exec -- mix ecto.drop"), INTERACTIVE_CLI)
check("deny heredoc on line after ANSI-C quote", "deny", mk("echo $'a\\'b'\nbash <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny command substitution inside unquoted heredoc", "deny", mk("cat <<EOF\n$(mise exec -- mix ecto.drop)\nEOF"), INTERACTIVE_CLI)
check("allow command substitution text inside quoted heredoc", "allow", mk("cat <<'EOF'\n$(mise exec -- mix ecto.drop)\nEOF"), INTERACTIVE_CLI)
check("allow arithmetic bitshift $((1<<2))", "allow", mk("echo $((1<<2))"), INTERACTIVE_CLI)
check("allow arithmetic command ((1 << 3))", "allow", mk("x=$((1 << 3))"), INTERACTIVE_CLI)
check("deny after pipe-newline-continued brace group cd", "deny", mk("printf hi |\n{ cd /tmp; }; mix test"), INTERACTIVE_CLI)
check("deny after &&-newline-continued background list cd", "deny", mk("cd /tmp &&\ntrue & wait; mix test"), INTERACTIVE_CLI)
check("allow double-quoted heredoc delimiter with escaped $", "allow", mk('cat <<"END\\$X"\nhello\nEND$X'), INTERACTIVE_CLI)
check("allow empty quoted heredoc delimiter", "allow", mk("cat <<''\nmise exec -- mix ecto.drop\n"), INTERACTIVE_CLI)
check("allow bash -c with non-code heredoc containing <<MISSING", "allow", mk("bash -c true <<'EOF'\n<<MISSING\nEOF"), INTERACTIVE_CLI)

# 4d. Round 5 regressions (bash -c nested stdin, shell option operands, ANSI-C escapes/delims, comments in subst, compact case, coproc, sudo -s)
check("deny bash -c nested shell reading heredoc", "deny", mk("bash -c 'bash' <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny bash -c exec bash -s reading heredoc", "deny", mk("bash -c 'exec bash -s' <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny bash -c $(cat) reading heredoc", "deny", mk("bash -c 'eval \"$(cat)\"' <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny bash -o pipefail reading heredoc", "deny", mk("bash -o pipefail <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny bash -o nounset reading heredoc", "deny", mk("bash -o nounset <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny bash +o history reading heredoc", "deny", mk("bash +o history <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny bash --rcfile /dev/null reading heredoc", "deny", mk("bash --rcfile /dev/null <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny piped bash -o pipefail", "deny", mk("printf 'mix ecto.drop\n' | bash -o pipefail"), INTERACTIVE_CLI)
check("deny octal ANSI-C encoded mix command", "deny", mk("$'\\155'ix test"), INTERACTIVE_CLI)
check("deny unicode ANSI-C encoded mix command", "deny", mk("$'\\u006d'ix test"), INTERACTIVE_CLI)
check("deny octal ANSI-C encoded ecto.drop arg", "deny", mk("mise exec -- mix $'\\145'cto.drop"), INTERACTIVE_CLI)
check("allow ANSI-C quoted heredoc delimiter", "allow", mk("cat <<$'END'\nhello\nEND"), INTERACTIVE_CLI)
check("deny command after comment-paren inside unquoted heredoc subst", "deny", mk("cat <<EOF\n$(true # )\nmise exec -- mix ecto.drop\n)\nEOF"), INTERACTIVE_CLI)
check("deny compact case arm without space after )", "deny", mk("case x in x)mix test;; esac"), INTERACTIVE_CLI)
check("deny coproc named brace group", "deny", mk("coproc NAME { mix test; }"), INTERACTIVE_CLI)
check("deny coproc unnamed brace group", "deny", mk("coproc { mix test; }"), INTERACTIVE_CLI)
check("deny sudo -s reading heredoc", "deny", mk("sudo -s <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)
check("deny sudo -i reading heredoc", "deny", mk("sudo -i <<EOF\nmise exec -- mix ecto.drop\nEOF"), INTERACTIVE_CLI)

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

def require_policy(repo_path, label):
    global passed, failed
    policy_path = os.path.join(repo_path, ".claude", "guardrails.json")
    if not os.path.exists(policy_path):
        failed += 1
        print(f"FAIL [{label}]: missing required guardrails policy at {policy_path}")
        return False
    passed += 1
    return True

keeper = "/Users/fredwu/Code/Wuit/keeper"
if require_policy(keeper, "keeper policy exists"):
    check("keeper: ask rm Godot userdata", "ask", mk('rm -rf "$HOME/Library/Application Support/Godot/app_userdata/Keeper"', cwd=keeper), INTERACTIVE_CLI, "[ask-delete-godot-userdata]")
    check("keeper: ask godot --export-release", "ask", mk("godot --headless --export-release macOS build/keeper.dmg", cwd=keeper), INTERACTIVE_CLI, "[ask-godot-export]")
    check("keeper: ask macOS Godot.app --export-release", "ask", mk("/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release macOS build/keeper.dmg", cwd=keeper), INTERACTIVE_CLI, "[ask-godot-export]")
    check("keeper: allow documented Android --export-debug", "allow", mk("python3 tools/gate/run_checked.py --timeout 540 godot --headless --path . --export-debug Android .local/audit-package/keeper-debug.apk", cwd=keeper), INTERACTIVE_CLI)
    check("keeper: allow documented Android --export-pack", "allow", mk("python3 tools/gate/run_checked.py --timeout 540 godot --headless --path . --export-pack Android .local/audit-package/keeper.pck", cwd=keeper), INTERACTIVE_CLI)
    check("keeper: allow tools/run_gate.sh headless", "allow", mk("bash tools/run_gate.sh headless", cwd=keeper), INTERACTIVE_CLI)

feedbun = "/Users/fredwu/Code/Wuit/feedbun"
if require_policy(feedbun, "feedbun policy exists"):
    check("feedbun: deny mix phx.gen.live", "deny", mk("mix phx.gen.live Blog Post posts title:string", cwd=feedbun), INTERACTIVE_CLI, "[no-phx-gen]")
    check("feedbun: allow mix phx.gen.secret 32", "allow", mk("mix phx.gen.secret 32", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: deny wrong app db hourbun_dev", "deny", mk("psql -d hourbun_dev -c 'select 1'", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: deny inline PGDATABASE=hourbun_dev psql", "deny", mk("PGDATABASE=hourbun_dev psql", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: deny env PGDATABASE=rizzfarm_dev psql", "deny", mk("env PGDATABASE=rizzfarm_dev psql", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: allow overridden PGDATABASE to feedbun_dev", "allow", mk("PGDATABASE=hourbun_dev env PGDATABASE=feedbun_dev psql", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow unset PGDATABASE", "allow", mk("PGDATABASE=hourbun_dev env -u PGDATABASE psql", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow attached -uPGDATABASE and --unset PGDATABASE", "allow", mk("PGDATABASE=hourbun_dev env -uPGDATABASE psql && PGDATABASE=hourbun_dev env --unset PGDATABASE psql", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: deny self-reassigned PGDATABASE in nested shell", "deny", mk("PGDATABASE=hourbun_dev bash -c 'PGDATABASE=$PGDATABASE true'", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: deny unresolved expansion retaining PGDATABASE", "deny", mk("PGDATABASE=hourbun_dev bash -c 'PGDATABASE=${UNKNOWN:-$PGDATABASE} psql'", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: deny conninfo DATABASE_URL with wrong db", "deny", mk("DATABASE_URL='host=localhost dbname=hourbun_dev' psql", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: allow NOTE='mix ecto.reset' true", "allow", mk("NOTE='mix ecto.reset' true", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow PGOPTIONS with command text", "allow", mk("PGOPTIONS='-c application_name=mix ecto.reset' true", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow PGDATABASE with non-db command words", "allow", mk("PGDATABASE='mix ecto.reset' true", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow expansion using caller scope not temporary cmd assign", "allow", mk('DB_NAME=feedbun_dev; DB_NAME=hourbun_dev env PGDATABASE="$DB_NAME" psql --version', cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow left-to-right shell prefix assignment override", "allow", mk("DB_NAME=hourbun_dev zsh -c 'DB_NAME=feedbun_dev PGDATABASE=$DB_NAME printenv PGDATABASE'", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: deny caller-scope expansion into env inside nested shell", "deny", mk("PGDATABASE=hourbun_dev bash -c 'PGDATABASE=feedbun_dev env PGDATABASE=$PGDATABASE psql'", cwd=feedbun), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("feedbun: ask mix ecto.drop", "ask", mk("mix ecto.drop", cwd=feedbun), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("feedbun: ask mix ecto.reset", "ask", mk("mix ecto.reset", cwd=feedbun), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("feedbun: ask mix ecto.setup", "ask", mk("mix ecto.setup", cwd=feedbun), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("feedbun: ask mix setup", "ask", mk("mix setup", cwd=feedbun), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("feedbun: ask mix seed", "ask", mk("mix seed", cwd=feedbun), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("feedbun: allow mix do deps.get, assets.setup", "allow", mk("mix do deps.get, assets.setup", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask mix run priv/repo/seeds.exs", "ask", mk("mix run priv/repo/seeds.exs", cwd=feedbun), INTERACTIVE_CLI, "[ask-direct-seeds-script]")
    check("feedbun: ask PetalPro.Seeds.Development", "ask", mk("mix run -e 'PetalPro.Seeds.Development.run()'", cwd=feedbun), INTERACTIVE_CLI, "[ask-direct-seeds-script]")
    check("feedbun: ask feedbun.reset_item_data confirm", "ask", mk("mix feedbun.reset_item_data --confirm yes", cwd=feedbun), INTERACTIVE_CLI, "[ask-reset-item-data]")
    check("feedbun: ask feedbun.reset_item_data preview+confirm", "ask", mk("mix feedbun.reset_item_data --preview --confirm yes", cwd=feedbun), INTERACTIVE_CLI, "[ask-reset-item-data]")
    check("feedbun: allow feedbun.reset_item_data --preview", "allow", mk("mix feedbun.reset_item_data --preview", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask bare mix feedbun.llm_smoke", "ask", mk("mix feedbun.llm_smoke", cwd=feedbun), INTERACTIVE_CLI, "[ask-paid-llm-tasks]")
    check("feedbun: ask mix feedbun.llm_smoke --dry-run --no-dry-run", "ask", mk("mix feedbun.llm_smoke --dry-run --no-dry-run", cwd=feedbun), INTERACTIVE_CLI, "[ask-paid-llm-tasks]")
    check("feedbun: ask mix feedbun.llm_rank --mode dev", "ask", mk("mix feedbun.llm_rank --mode dev", cwd=feedbun), INTERACTIVE_CLI, "[ask-paid-llm-tasks]")
    check("feedbun: allow mix feedbun.llm_rank --dry-run --mode live", "allow", mk("mix feedbun.llm_rank --dry-run --mode live", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow mix feedbun.llm_smoke --dry-run --mode live", "allow", mk("mix feedbun.llm_smoke --dry-run --mode live", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow mix feedbun.llm_smoke --help", "allow", mk("mix feedbun.llm_smoke --help", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow mix feedbun.workflow_smoke -h", "allow", mk("mix feedbun.workflow_smoke -h", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask mix feedbun.workflow_smoke", "ask", mk("mix feedbun.workflow_smoke --base-url http://127.0.0.1:4002", cwd=feedbun), INTERACTIVE_CLI, "[ask-paid-llm-tasks]")
    check("feedbun: ask mix feedbun.ingredient_research_smoke", "ask", mk("mix feedbun.ingredient_research_smoke --ingredient-id 123", cwd=feedbun), INTERACTIVE_CLI, "[ask-paid-llm-tasks]")
    check("feedbun: ask mix feedbun.embedding_eval --execute", "ask", mk("mix feedbun.embedding_eval --execute", cwd=feedbun), INTERACTIVE_CLI, "[ask-embedding-eval-execute]")
    check("feedbun: allow provisional mix feedbun.embedding_eval", "allow", mk("mix feedbun.embedding_eval", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask mix feedbun.launch_smoke --queue-extractions", "ask", mk("mix feedbun.launch_smoke --base-url https://feedbun.com --queue-extractions", cwd=feedbun), INTERACTIVE_CLI, "[ask-launch-smoke-queue]")
    check("feedbun: allow read-only mix feedbun.launch_smoke", "allow", mk("mix feedbun.launch_smoke --base-url https://feedbun.com", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask mix feedbun.rebuild_knowledge_embeddings --execute", "ask", mk("mix feedbun.rebuild_knowledge_embeddings --scope ingredients --execute", cwd=feedbun), INTERACTIVE_CLI, "[ask-rebuild-embeddings-execute]")
    check("feedbun: ask mix feedbun.rebuild_knowledge_embeddings --resume", "ask", mk("mix feedbun.rebuild_knowledge_embeddings --resume 42", cwd=feedbun), INTERACTIVE_CLI, "[ask-rebuild-embeddings-execute]")
    check("feedbun: allow preview mix feedbun.rebuild_knowledge_embeddings", "allow", mk("mix feedbun.rebuild_knowledge_embeddings --scope ingredients", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask extension smoke:api with inherited env", "ask", mk("export FEEDBUN_SMOKE_SUBMIT_EXTRACTION=true && npm run smoke:api --prefix browser_extension", cwd=feedbun), INTERACTIVE_CLI, "[ask-extension-api-smoke]")
    check("feedbun: ask extension smoke:api --submit-extraction", "ask", mk("npm run smoke:api --prefix browser_extension -- --require-token --submit-extraction", cwd=feedbun), INTERACTIVE_CLI, "[ask-extension-api-smoke]")
    check("feedbun: ask extension run-script smoke:api", "ask", mk("npm --prefix browser_extension run-script smoke:api", cwd=feedbun), INTERACTIVE_CLI, "[ask-extension-api-smoke]")
    check("feedbun: ask extension smoke:api even with --help token", "ask", mk("npm run smoke:api --prefix browser_extension -- --base-url --help", cwd=feedbun), INTERACTIVE_CLI, "[ask-extension-api-smoke]")
    check("feedbun: ask fly deploy", "ask", mk("fly deploy", cwd=feedbun), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("feedbun: ask fly --app=feedbun deploy", "ask", mk("fly --app=feedbun deploy", cwd=feedbun), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("feedbun: ask fly machine --app=feedbun destroy", "ask", mk("fly machine --app=feedbun destroy abc", cwd=feedbun), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("feedbun: ask fly m destroy", "ask", mk("fly m destroy abc", cwd=feedbun), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("feedbun: ask fly secrets set", "ask", mk("fly secrets set FOO=bar", cwd=feedbun), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("feedbun: ask docker compose down -v", "ask", mk("docker compose down -v", cwd=feedbun), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("feedbun: ask docker --context default compose down -v", "ask", mk("docker --context default compose down -v", cwd=feedbun), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("feedbun: ask docker -H=unix socket compose down -v", "ask", mk("docker -H=unix:///var/run/docker.sock compose down -v", cwd=feedbun), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("feedbun: ask docker -Hunix attached compose down -v", "ask", mk("docker -Hunix:///var/run/docker.sock compose down -v", cwd=feedbun), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("feedbun: ask docker compose -f path with space down -v", "ask", mk('docker compose -f "my file.yml" down -v', cwd=feedbun), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("feedbun: allow docker -Hunix compose exec grep --regexp=down -v", "allow", mk("docker -Hunix:///var/run/docker.sock compose exec db grep --regexp=down -v /etc/hosts", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: ask docker volume prune", "ask", mk("docker volume prune -f", cwd=feedbun), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("feedbun: allow docker compose down without -v", "allow", mk("docker compose down", cwd=feedbun), INTERACTIVE_CLI)
    check("feedbun: allow ./scripts/verify changed", "allow", mk("./scripts/verify changed", cwd=feedbun), INTERACTIVE_CLI)

feedbun_mobile = "/Users/fredwu/Code/Wuit/feedbun-mobile"
if require_policy(feedbun_mobile, "feedbun-mobile policy exists"):
    check("feedbun-mobile: deny npm audit fix --force", "deny", mk("npm audit fix --force", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-npm-audit-force]")
    check("feedbun-mobile: deny npm audit fix -f", "deny", mk("npm audit fix -f", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-npm-audit-force]")
    check("feedbun-mobile: deny open Insta360 Link Controller", "deny", mk('open -a "Insta360 Link Controller"', cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-insta360-controller]")
    check("feedbun-mobile: allow Finder reveal open -R Insta360", "allow", mk('open -R "/Applications/Insta360 Link Controller.app"', cwd=feedbun_mobile), INTERACTIVE_CLI)
    check("feedbun-mobile: deny rm -rf patches", "deny", mk("rm -rf patches", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf patches/", "deny", mk("rm -rf patches/", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf patches//", "deny", mk("rm -rf patches//", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf patches/*", "deny", mk("rm -rf patches/*", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf patches/*.patch", "deny", mk("rm -rf patches/*.patch", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf ./patches/*", "deny", mk("rm -rf ./patches/*", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -fr patches", "deny", mk("rm -fr patches", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -Rf ./patches/", "deny", mk("rm -Rf ./patches/", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -r -f abs patches", "deny", mk("rm -r -f /Users/fredwu/Code/Wuit/feedbun-mobile/patches/", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf project root", "deny", mk("rm -rf .", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf *", "deny", mk("rm -rf *", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf ../feedbun-mobile", "deny", mk("rm -rf ../feedbun-mobile", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf ~/Code/Wuit/feedbun-mobile", "deny", mk("rm -rf ~/Code/Wuit/feedbun-mobile", cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: deny rm -rf $PWD", "deny", mk('rm -rf "$PWD"', cwd=feedbun_mobile), INTERACTIVE_CLI, "[no-rm-patches-or-root]")
    check("feedbun-mobile: allow rm single patch file", "allow", mk("rm patches/expo+58.0.0.patch", cwd=feedbun_mobile), INTERACTIVE_CLI)
    check("feedbun-mobile: ask expo prebuild --clean", "ask", mk("npx expo prebuild --clean", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-expo-prebuild-clean]")
    check("feedbun-mobile: ask eas build", "ask", mk("eas build --platform ios", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-eas-release]")
    check("feedbun-mobile: ask npx eas-cli build", "ask", mk("npx eas-cli build -p ios", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-eas-release]")
    check("feedbun-mobile: ask npx eas-cli@latest build", "ask", mk("npx eas-cli@latest build -p ios", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-eas-release]")
    check("feedbun-mobile: ask npx -y eas-cli@16.0.0 submit", "ask", mk("npx -y eas-cli@16.0.0 submit", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-eas-release]")
    check("feedbun-mobile: ask eas submit", "ask", mk("eas submit --platform ios", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-eas-release]")
    check("feedbun-mobile: ask eas update", "ask", mk("eas update --branch preview", cwd=feedbun_mobile), INTERACTIVE_CLI, "[ask-eas-release]")
    check("feedbun-mobile: allow npm run quality.check", "allow", mk("npm run quality.check", cwd=feedbun_mobile), INTERACTIVE_CLI)

rizzfarm = "/Users/fredwu/Code/Wuit/rizzfarm"
if require_policy(rizzfarm, "rizzfarm policy exists"):
    check("rizzfarm: deny wrong app db hourbun_dev", "deny", mk("psql -d hourbun_dev", cwd=rizzfarm), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("rizzfarm: deny inline PGDATABASE=persumi_dev psql", "deny", mk("PGDATABASE=persumi_dev psql", cwd=rizzfarm), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("rizzfarm: ask mix ecto.drop", "ask", mk("mix ecto.drop", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("rizzfarm: ask mix ecto.reset", "ask", mk("mix ecto.reset", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("rizzfarm: ask mix ecto.setup", "ask", mk("mix ecto.setup", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("rizzfarm: ask mix setup", "ask", mk("mix setup", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("rizzfarm: ask mix seed", "ask", mk("mix seed", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("rizzfarm: allow mix do deps.get, assets.setup", "allow", mk("mix do deps.get, assets.setup", cwd=rizzfarm), INTERACTIVE_CLI)
    check("rizzfarm: ask mix run priv/repo/seeds.exs", "ask", mk("mix run priv/repo/seeds.exs", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-direct-seeds-script]")
    check("rizzfarm: ask fly deploy", "ask", mk("fly deploy", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("rizzfarm: ask fly --app=rizzfarm deploy", "ask", mk("fly --app=rizzfarm deploy", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("rizzfarm: ask fly machine --app rizzfarm destroy", "ask", mk("fly machine --app rizzfarm destroy abc", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("rizzfarm: ask docker --context default compose down -v", "ask", mk("docker --context default compose down -v", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("rizzfarm: ask docker -H=unix compose down -v", "ask", mk("docker -H=unix:///var/run/docker.sock compose down -v", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("rizzfarm: ask docker -Hunix compose down -v", "ask", mk("docker -Hunix:///var/run/docker.sock compose down -v", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("rizzfarm: ask docker volume rm", "ask", mk("docker volume rm db_pg17", cwd=rizzfarm), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("rizzfarm: allow mix phx.gen.context", "allow", mk("mix phx.gen.context Analytics Event events type:string", cwd=rizzfarm), INTERACTIVE_CLI)

persumi = "/Users/fredwu/Code/Wuit/persumi"
if require_policy(persumi, "persumi policy exists"):
    check("persumi: deny wrong app db rizzfarm_dev", "deny", mk("psql -d rizzfarm_dev", cwd=persumi), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("persumi: deny inline PGDATABASE=rizzfarm_dev psql", "deny", mk("PGDATABASE=rizzfarm_dev psql", cwd=persumi), INTERACTIVE_CLI, "[no-wrong-app-db]")
    check("persumi: ask mix ecto.drop", "ask", mk("mix ecto.drop", cwd=persumi), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("persumi: ask mix ecto.reset", "ask", mk("mix ecto.reset", cwd=persumi), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("persumi: ask mix ecto.setup", "ask", mk("mix ecto.setup", cwd=persumi), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("persumi: ask mix setup", "ask", mk("mix setup", cwd=persumi), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("persumi: ask mix seed", "ask", mk("mix seed", cwd=persumi), INTERACTIVE_CLI, "[ask-db-reset-and-seeds]")
    check("persumi: allow mix do deps.get, assets.setup", "allow", mk("mix do deps.get, assets.setup", cwd=persumi), INTERACTIVE_CLI)
    check("persumi: ask mix run priv/repo/seeds.exs", "ask", mk("mix run priv/repo/seeds.exs", cwd=persumi), INTERACTIVE_CLI, "[ask-direct-seeds-script]")
    check("persumi: ask fly deploy", "ask", mk("fly deploy", cwd=persumi), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("persumi: ask fly --app=persumi deploy", "ask", mk("fly --app=persumi deploy", cwd=persumi), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("persumi: ask fly machine destroy", "ask", mk("fly machine destroy 123 --app persumi --force", cwd=persumi), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("persumi: ask fly machine --app=persumi destroy", "ask", mk("fly machine --app=persumi destroy 123", cwd=persumi), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("persumi: ask fly m destroy", "ask", mk("fly m destroy 123", cwd=persumi), INTERACTIVE_CLI, "[ask-fly-prod]")
    check("persumi: ask docker --context default compose down -v", "ask", mk("docker --context default compose down -v", cwd=persumi), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("persumi: ask docker -H=unix compose down -v", "ask", mk("docker -H=unix:///var/run/docker.sock compose down -v", cwd=persumi), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("persumi: ask docker -Hunix compose down -v", "ask", mk("docker -Hunix:///var/run/docker.sock compose down -v", cwd=persumi), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("persumi: ask docker system prune --volumes", "ask", mk("docker system prune --volumes -f", cwd=persumi), INTERACTIVE_CLI, "[ask-docker-volume-destruction]")
    check("persumi: allow mix test --exclude ci_skip", "allow", mk("mix test --exclude ci_skip", cwd=persumi), INTERACTIVE_CLI)

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
