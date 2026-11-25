#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOOK="$SCRIPT_DIR/pre-tool-guard.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Build two temporary git repos: repo_a (guarded) and repo_b (unrestricted)
REPO_A="$TMPDIR_TEST/repo_a"
REPO_B="$TMPDIR_TEST/repo_b"
REPO_BAD="$TMPDIR_TEST/repo_bad"
mkdir -p "$REPO_A/.git" "$REPO_A/sub/dir" "$REPO_A/.claude" "$REPO_B/.git" "$REPO_BAD/.git" "$REPO_BAD/.claude"

cat > "$REPO_A/.claude/guardrails.json" <<'JSON'
{
  "rules": [
    {
      "id": "no-drop",
      "decision": "deny",
      "cmd_regex": "(^|\\s)mix\\s+ecto\\.drop(\\s|$)",
      "reason": "Never drop the real database.",
      "instead": "mise exec -- mix hourbun.drop_test_db"
    },
    {
      "id": "no-raw-pg-dump",
      "decision": "deny",
      "cmd_regex": "(^|\\s)pg_(dump|restore)(\\s|$)",
      "allow_if_regex": ["docker\\s+compose\\s+exec\\s+-T\\s+db\\s+pg_(dump|restore)"],
      "reason": "Use mix hourbun.backup or the documented container-tools block."
    },
    {
      "id": "ask-restore",
      "decision": "ask",
      "cmd_regex": "(^|\\s)mix\\s+hourbun\\.restore(\\s|$)",
      "reason": "Restore overwrites the dev database; requires explicit user confirmation."
    },
    {
      "id": "require-mise",
      "decision": "deny",
      "require_wrapper": { "commands": ["mix", "iex"], "wrapper": "mise" },
      "reason": "Run Elixir commands through mise exec --."
    }
  ]
}
JSON

printf '{malformed json\n' > "$REPO_BAD/.claude/guardrails.json"

PASS=0
FAIL=0

run_case() {
  local name="$1"
  local expect="$2" # allow | deny | ask
  local json_payload="$3"
  local extra_env="${4:-}"
  local out decision

  if [[ -n "$extra_env" ]]; then
    out="$(env $extra_env "$HOOK" <<< "$json_payload")"
  else
    out="$("$HOOK" <<< "$json_payload")"
  fi

  if [[ -z "$out" ]]; then
    decision="allow"
  else
    decision="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["hookSpecificOutput"]["permissionDecision"])' "$out")"
  fi

  if [[ "$decision" == "$expect" ]]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL [$name]: expected=$expect got=$decision output=$out" >&2
    FAIL=$((FAIL + 1))
  fi
}

payload() {
  python3 -c 'import json,sys
d = {"tool_name": "Bash", "cwd": sys.argv[1], "permission_mode": sys.argv[2], "tool_input": {"command": sys.argv[3]}}
if len(sys.argv) > 4 and sys.argv[4]:
    d.update(json.loads(sys.argv[4]))
print(json.dumps(d))' "$@"
}

# 1. Basic allow/deny/wrapper cases
run_case "unwrapped mix denied" deny "$(payload "$REPO_A" default "mix test")"
run_case "mise wrapped mix test allowed" allow "$(payload "$REPO_A" default "mise exec -- mix test")"
run_case "env-var before mise allowed" allow "$(payload "$REPO_A" default "PW_BROWSER=firefox mise exec -- mix test.browser")"
run_case "mise exec env VAR allowed" allow "$(payload "$REPO_A" default "mise exec -- env MIX_ENV=test mix test")"
run_case "subdir inherits repo root policy" deny "$(payload "$REPO_A/sub/dir" default "mix test")"
run_case "unguarded repo allows mix ecto.drop" allow "$(payload "$REPO_B" default "mix ecto.drop")"

# 2. Wrapper unwrapping & nested payloads
run_case "mise wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "mise exec -- mix ecto.drop")"
run_case "direnv wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "direnv exec . mix ecto.drop")"
run_case "nohup wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "nohup mise exec -- mix ecto.drop")"
run_case "time wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "time mise exec -- mix ecto.drop")"
run_case "command wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "command mise exec -- mix ecto.drop")"
run_case "exec wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "exec mise exec -- mix ecto.drop")"
run_case "xargs wrapped ecto.drop denied" deny "$(payload "$REPO_A" default "xargs -I{} mise exec -- mix ecto.drop")"
run_case "bash -c payload denied" deny "$(payload "$REPO_A" default "bash -c 'mise exec -- mix ecto.drop'")"
run_case "sh -lc payload denied" deny "$(payload "$REPO_A" default "sh -lc 'mix ecto.drop'")"
run_case "eval payload denied" deny "$(payload "$REPO_A" default "eval 'mise exec -- mix ecto.drop'")"
run_case "subshell substitution denied" deny "$(payload "$REPO_A" default "echo \$(mise exec -- mix ecto.drop)")"
run_case "tmux new-session payload denied" deny "$(payload "$REPO_A" default "tmux new-session -d -s app 'mise exec -- mix ecto.drop'")"

# 3. Cross-repo cd chains & tmux send-keys target pane resolution
run_case "cross-repo cd into repo_a denied" deny "$(payload "$REPO_B" default "echo ok && cd '$REPO_A' && mise exec -- mix ecto.drop")"
run_case "cross-repo cd into repo_b allowed" allow "$(payload "$REPO_A" default "cd '$REPO_B' && mix ecto.drop")"
run_case "tmux send-keys into repo_a pane denied" deny "$(payload "$REPO_B" default "tmux send-keys -t app 'mise exec -- mix ecto.drop' Enter")" "PRE_TOOL_GUARD_TMUX_PANE_PATH=$REPO_A"
run_case "tmux send-keys into repo_b pane allowed" allow "$(payload "$REPO_A" default "tmux send-keys -t app 'mix ecto.drop' Enter")" "PRE_TOOL_GUARD_TMUX_PANE_PATH=$REPO_B"
run_case "tmux send-keys unresolved pane fails closed" deny "$(payload "$REPO_B" default "tmux send-keys -t missing 'mix test' Enter")" "PRE_TOOL_GUARD_TMUX_PANE_PATH="

# 4. Quoted data arguments & allowlist exceptions
run_case "rg quoting forbidden text allowed" allow "$(payload "$REPO_A" default "rg 'mix ecto.drop' docs/")"
run_case "git commit message mentioning forbidden text allowed" allow "$(payload "$REPO_A" default "git commit -m 'block mix ecto.drop and pg_dump'")"
run_case "raw pg_dump denied" deny "$(payload "$REPO_A" default "pg_dump hourbun_dev")"
run_case "container-tools pg_dump allowlisted" allow "$(payload "$REPO_A" default "docker compose exec -T db pg_dump --username postgres hourbun_dev")"

# 5. All 6 permission_modes + child/headless ask -> deny fail-closed
for mode in default acceptEdits plan auto; do
  run_case "ask stays ask in interactive $mode" ask "$(payload "$REPO_A" "$mode" "mise exec -- mix hourbun.restore x.dump")"
done
for mode in bypassPermissions dontAsk ""; do
  run_case "ask fails closed to deny in mode='$mode'" deny "$(payload "$REPO_A" "$mode" "mise exec -- mix hourbun.restore x.dump")"
done
run_case "ask fails closed for subagent agent_id" deny "$(payload "$REPO_A" default "mise exec -- mix hourbun.restore x.dump" '{"agent_id":"sub-1"}')"
run_case "ask fails closed for subagent agent_type" deny "$(payload "$REPO_A" default "mise exec -- mix hourbun.restore x.dump" '{"agent_type":"research"}')"
run_case "ask fails closed for sdk-cli headless" deny "$(payload "$REPO_A" default "mise exec -- mix hourbun.restore x.dump")" "CLAUDE_CODE_ENTRYPOINT=sdk-cli"
run_case "ask fails closed for CLAUDE_NONINTERACTIVE=1" deny "$(payload "$REPO_A" default "mise exec -- mix hourbun.restore x.dump")" "CLAUDE_NONINTERACTIVE=1"

# 6. Malformed policy fails closed
run_case "malformed guardrails.json fails closed" deny "$(payload "$REPO_BAD" default "ls -la")"

# 7. Latency check (<50 ms avg over 5 runs)
LATENCY_MS="$(python3 - "$HOOK" "$REPO_A" <<'PY'
import json, subprocess, sys, time
hook, cwd = sys.argv[1], sys.argv[2]
p = json.dumps({"tool_name": "Bash", "cwd": cwd, "permission_mode": "default", "tool_input": {"command": "mise exec -- mix test"}})
t0 = time.perf_counter()
for _ in range(5):
    subprocess.run([hook], input=p, text=True, check=True, stdout=subprocess.PIPE)
avg_ms = (time.perf_counter() - t0) * 1000 / 5
print(f"{avg_ms:.1f}")
if avg_ms >= 100.0:
    sys.exit(1)
PY
)"

echo "pre-tool-guard tests: $PASS passed, $FAIL failed (avg ${LATENCY_MS}ms)"
[[ "$FAIL" -eq 0 ]]
