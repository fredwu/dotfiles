#!/usr/bin/env python3
import json
import os
import re
import shlex
import subprocess
import sys

INTERACTIVE_MODES = {"default", "acceptEdits", "plan", "auto"}
NON_INTERACTIVE_MODES = {"bypassPermissions", "dontAsk"}

DATA_COMMANDS = {
    "rg", "grep", "egrep", "fgrep", "ag", "ack",
    "echo", "printf", "cat", "head", "tail", "wc", "ls", "find",
    "sed", "awk", "cut", "sort", "uniq", "tr", "tee", "bat",
}
GIT_DATA_SUBCOMMANDS = {
    "commit", "log", "diff", "status", "show", "grep", "check-ignore",
    "tag", "branch", "notes", "describe", "rev-parse", "ls-files",
}
SIMPLE_WRAPPERS = {"nohup", "time", "command", "exec", "xargs"}
SHELL_BINARIES = {"sh", "bash", "zsh"}
ENV_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def emit(decision, reason):
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }
    sys.stdout.write(json.dumps(out) + "\n")
    sys.exit(0)


def find_git_root(path):
    cur = os.path.abspath(path)
    while True:
        if os.path.exists(os.path.join(cur, ".git")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent


def load_policy(repo_root, cache):
    if not repo_root:
        return None
    if repo_root in cache:
        return cache[repo_root]
    policy_path = os.path.join(repo_root, ".claude", "guardrails.json")
    if not os.path.exists(policy_path):
        cache[repo_root] = None
        return None
    try:
        with open(policy_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError("guardrails.json root must be a JSON object")
        rules = data.get("rules", [])
        if not isinstance(rules, list):
            raise ValueError("guardrails.json 'rules' must be a list")
        cache[repo_root] = data
        return data
    except Exception as exc:
        emit("deny", f"Malformed guardrails policy at {policy_path}: {exc}")


def split_segments(cmd):
    """Split a shell command into top-level segments on &&, ||, ;, |, &, newline, and extract $(...) / `...`."""
    segments = []
    nested = []
    buf = []
    i = 0
    n = len(cmd)
    in_squote = False
    in_dquote = False
    escaped = False

    def flush():
        s = "".join(buf).strip()
        buf.clear()
        if s:
            segments.append(s)

    while i < n:
        ch = cmd[i]
        if escaped:
            buf.append(ch)
            escaped = False
            i += 1
            continue
        if ch == "\\" and not in_squote:
            buf.append(ch)
            escaped = True
            i += 1
            continue
        if ch == "'" and not in_dquote:
            in_squote = not in_squote
            buf.append(ch)
            i += 1
            continue
        if ch == '"' and not in_squote:
            in_dquote = not in_dquote
            buf.append(ch)
            i += 1
            continue

        # Extract $(...) outside single quotes
        if not in_squote and ch == "$" and i + 1 < n and cmd[i + 1] == "(":
            depth = 1
            j = i + 2
            sub_sq = False
            sub_dq = False
            sub_esc = False
            while j < n and depth > 0:
                c2 = cmd[j]
                if sub_esc:
                    sub_esc = False
                elif c2 == "\\" and not sub_sq:
                    sub_esc = True
                elif c2 == "'" and not sub_dq:
                    sub_sq = not sub_sq
                elif c2 == '"' and not sub_sq:
                    sub_dq = not sub_dq
                elif not sub_sq and not sub_dq:
                    if c2 == "(":
                        depth += 1
                    elif c2 == ")":
                        depth -= 1
                j += 1
            inner = cmd[i + 2 : j - 1].strip() if depth == 0 else cmd[i + 2 :].strip()
            if inner:
                nested.append(inner)
            buf.append(cmd[i:j])
            i = j
            continue

        # Extract backtick substitution outside single quotes
        if not in_squote and ch == "`":
            j = i + 1
            sub_esc = False
            while j < n:
                c2 = cmd[j]
                if sub_esc:
                    sub_esc = False
                elif c2 == "\\":
                    sub_esc = True
                elif c2 == "`":
                    break
                j += 1
            inner = cmd[i + 1 : j].strip()
            if inner:
                nested.append(inner)
            buf.append(cmd[i : min(j + 1, n)])
            i = min(j + 1, n)
            continue

        if not in_squote and not in_dquote:
            if ch in (";", "\n"):
                flush()
                i += 1
                continue
            if ch == "&":
                if i + 1 < n and cmd[i + 1] == "&":
                    flush()
                    i += 2
                    continue
                # Avoid splitting redirections like 2>&1 or >&2 or &>file
                prev = cmd[i - 1] if i > 0 else ""
                nxt = cmd[i + 1] if i + 1 < n else ""
                if prev in (">", "<") or nxt == ">":
                    buf.append(ch)
                    i += 1
                    continue
                flush()
                i += 1
                continue
            if ch == "|":
                flush()
                i += 2 if (i + 1 < n and cmd[i + 1] == "|") else 1
                continue
            if ch == "(" and not buf:
                # Leading subshell group: strip outer parens if matched
                depth = 1
                j = i + 1
                sub_sq = False
                sub_dq = False
                sub_esc = False
                while j < n and depth > 0:
                    c2 = cmd[j]
                    if sub_esc:
                        sub_esc = False
                    elif c2 == "\\" and not sub_sq:
                        sub_esc = True
                    elif c2 == "'" and not sub_dq:
                        sub_sq = not sub_sq
                    elif c2 == '"' and not sub_sq:
                        sub_dq = not sub_dq
                    elif not sub_sq and not sub_dq:
                        if c2 == "(":
                            depth += 1
                        elif c2 == ")":
                            depth -= 1
                    j += 1
                if depth == 0:
                    inner = cmd[i + 1 : j - 1].strip()
                    if inner:
                        segments.extend(split_segments(inner))
                    i = j
                    continue

        buf.append(ch)
        i += 1

    flush()
    for ncmd in nested:
        segments.extend(split_segments(ncmd))
    return segments


def tokenize(segment):
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return segment.split()


def resolve_tmux_pane_cwd(target):
    override = os.environ.get("PRE_TOOL_GUARD_TMUX_PANE_PATH")
    if override is not None:
        return override if override.strip() else None
    cmd = ["tmux", "display-message", "-p"]
    if target:
        cmd.extend(["-t", target])
    cmd.append("#{pane_current_path}")
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=1.0)
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    return None


def unwrap_tokens(tokens, cwd):
    """Unwrap env assignments and exec wrappers. Returns (tokens, wrappers_seen, effective_cwd)."""
    wrappers = set()
    eff_cwd = cwd
    idx = 0
    n = len(tokens)

    while idx < n:
        tok = tokens[idx]
        if ENV_ASSIGN_RE.match(tok):
            idx += 1
            continue

        base = os.path.basename(tok)

        if base == "env":
            wrappers.add("env")
            idx += 1
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t in ("-u", "-C", "-S"):
                    if t == "-C" and idx + 1 < n:
                        eff_cwd = os.path.abspath(os.path.join(eff_cwd, os.path.expanduser(tokens[idx + 1])))
                    idx += 2
                    continue
                if t.startswith("-") or ENV_ASSIGN_RE.match(t):
                    idx += 1
                    continue
                break
            continue

        if base in SIMPLE_WRAPPERS:
            wrappers.add(base)
            idx += 1
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if base == "exec" and t == "-a":
                    idx += 2
                    continue
                if base == "xargs" and t in ("-I", "-n", "-P", "-L", "-d", "-E", "-s", "-J", "-R"):
                    idx += 2
                    continue
                if t.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "mise" and idx + 1 < n and tokens[idx + 1] in ("exec", "x"):
            wrappers.add("mise")
            idx += 2
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t in ("-C", "--cd") and idx + 1 < n:
                    eff_cwd = os.path.abspath(os.path.join(eff_cwd, os.path.expanduser(tokens[idx + 1])))
                    idx += 2
                    continue
                if t.startswith("-"):
                    idx += 1
                    continue
                # Tool spec like elixir@1.18 before --
                if "@" in t and "--" in tokens[idx:]:
                    idx += 1
                    continue
                break
            continue

        if base == "direnv" and idx + 2 < n and tokens[idx + 1] == "exec":
            wrappers.add("direnv")
            target_dir = tokens[idx + 2]
            if target_dir != ".":
                eff_cwd = os.path.abspath(os.path.join(eff_cwd, os.path.expanduser(target_dir)))
            idx += 3
            continue

        break

    return tokens[idx:], wrappers, eff_cwd


def is_data_command(tokens):
    if not tokens:
        return True
    base = os.path.basename(tokens[0])
    if base in DATA_COMMANDS:
        return True
    if base == "git":
        # Find git subcommand skipping global flags like -C <dir>, -c k=v
        i = 1
        while i < len(tokens):
            t = tokens[i]
            if t in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
                i += 2
                continue
            if t.startswith("-"):
                i += 1
                continue
            return t in GIT_DATA_SUBCOMMANDS
    return False


def extract_subpayloads(tokens, cwd):
    """Extract (payload_cmd, payload_cwd, error_reason) for sh -c / bash -c / eval / tmux."""
    if not tokens:
        return []
    base = os.path.basename(tokens[0])
    results = []

    if base in SHELL_BINARIES:
        i = 1
        while i < len(tokens):
            t = tokens[i]
            if t == "--":
                break
            if t == "-c" or (t.startswith("-") and not t.startswith("--") and "c" in t[1:]):
                if i + 1 < len(tokens):
                    results.append((tokens[i + 1], cwd, None))
                break
            if not t.startswith("-"):
                break
            i += 1
        return results

    if base == "eval" and len(tokens) > 1:
        results.append((" ".join(tokens[1:]), cwd, None))
        return results

    if base == "tmux" and len(tokens) > 1:
        sub = tokens[1]
        if sub in ("new-session", "new"):
            # Command string is the last positional argument after flags
            i = 2
            pos = []
            while i < len(tokens):
                t = tokens[i]
                if t in ("-s", "-n", "-t", "-c", "-x", "-y", "-e", "-F"):
                    if t == "-c" and i + 1 < len(tokens):
                        cwd = os.path.abspath(os.path.join(cwd, os.path.expanduser(tokens[i + 1])))
                    i += 2
                    continue
                if t.startswith("-"):
                    i += 1
                    continue
                pos.append(t)
                i += 1
            if pos:
                results.append((" ".join(pos), cwd, None))
        elif sub == "send-keys":
            target = None
            i = 2
            keys = []
            while i < len(tokens):
                t = tokens[i]
                if t in ("-t", "-N"):
                    if t == "-t" and i + 1 < len(tokens):
                        target = tokens[i + 1]
                    i += 2
                    continue
                if t.startswith("-"):
                    i += 1
                    continue
                keys.append(t)
                i += 1
            # Strip trailing Enter / C-m / KPEnter key names
            while keys and keys[-1] in ("Enter", "C-m", "KPEnter", "C-j"):
                keys.pop()
            if keys:
                pane_cwd = resolve_tmux_pane_cwd(target)
                if not pane_cwd:
                    results.append((
                        None,
                        None,
                        f"Cannot resolve target tmux pane working directory for `tmux send-keys` (target={target or 'current'}); refusing fail-closed.",
                    ))
                else:
                    results.append((" ".join(keys), pane_cwd, None))
    return results


def evaluate_policy(tokens, wrappers, raw_segment, policy):
    """Returns (decision, reason) or None."""
    if not policy or not tokens:
        return None

    unwrapped_str = " ".join(tokens)
    data_cmd = is_data_command(tokens)
    best = None  # ("ask" | "deny", reason)

    def record(decision, reason):
        nonlocal best
        if decision == "deny":
            best = ("deny", reason)
        elif decision == "ask" and best is None:
            best = ("ask", reason)

    for rule in policy.get("rules", []):
        decision = rule.get("decision", "deny")
        if decision not in ("deny", "ask"):
            emit("deny", f"Invalid rule decision {decision!r} in guardrails.json")

        allow_patterns = rule.get("allow_if_regex", [])
        if any(re.search(pat, unwrapped_str) or re.search(pat, raw_segment) for pat in allow_patterns):
            continue

        matched = False
        req = rule.get("require_wrapper")
        if req:
            cmds = set(req.get("commands", []))
            needed = req.get("wrapper")
            if os.path.basename(tokens[0]) in cmds and needed not in wrappers:
                matched = True
        else:
            pat = rule.get("cmd_regex")
            if pat:
                if data_cmd and not rule.get("match_data_commands", False):
                    continue
                if re.search(pat, unwrapped_str):
                    matched = True

        if matched:
            rid = rule.get("id", "guardrail")
            reason = rule.get("reason", "Blocked by repository guardrails.")
            instead = rule.get("instead")
            msg = f"[{rid}] {reason}"
            if instead:
                msg += f" Use instead: {instead}"
            record(decision, msg)
            if best and best[0] == "deny":
                return best

    return best


def check_command(cmd, start_cwd, policy_cache, depth=0):
    if depth > 6:
        return ("deny", "Command nesting depth exceeded guardrail inspection limit.")

    eff_cwd = start_cwd
    worst = None

    def merge(res):
        nonlocal worst
        if not res:
            return
        if res[0] == "deny":
            worst = res
        elif res[0] == "ask" and worst is None:
            worst = res

    for seg in split_segments(cmd):
        tokens = tokenize(seg)
        if not tokens:
            continue

        unwrapped, wrappers, seg_cwd = unwrap_tokens(tokens, eff_cwd)
        if not unwrapped:
            continue

        # Track cd across subsequent segments
        if unwrapped[0] == "cd":
            target = None
            for arg in unwrapped[1:]:
                if arg in ("-L", "-P", "--"):
                    continue
                target = arg
                break
            if target is None:
                eff_cwd = os.path.expanduser("~")
            elif target == "-":
                pass
            elif "$" in target:
                # Dynamic cd target: keep current cwd
                pass
            else:
                eff_cwd = os.path.abspath(os.path.join(eff_cwd, os.path.expanduser(target)))
            continue

        # Inspect nested shell / eval / tmux payloads in their resolved execution cwd
        subpayloads = extract_subpayloads(unwrapped, seg_cwd)
        if subpayloads:
            for p_cmd, p_cwd, p_err in subpayloads:
                if p_err:
                    merge(("deny", p_err))
                    if worst and worst[0] == "deny":
                        return worst
                elif p_cmd:
                    merge(check_command(p_cmd, p_cwd, policy_cache, depth + 1))
                    if worst and worst[0] == "deny":
                        return worst
            continue

        repo_root = find_git_root(seg_cwd)
        policy = load_policy(repo_root, policy_cache)
        merge(evaluate_policy(unwrapped, wrappers, seg, policy))
        if worst and worst[0] == "deny":
            return worst

    return worst


def can_prompt_interactively(payload):
    mode = payload.get("permission_mode")
    if mode not in INTERACTIVE_MODES:
        return False
    # Delegated subagents cannot show an interactive human prompt
    if payload.get("agent_id") or payload.get("agent_type"):
        return False
    # Explicit non-interactive / headless indicators
    if os.environ.get("CLAUDE_NONINTERACTIVE") in ("1", "true", "TRUE", "yes"):
        return False
    # Claude Code headless (`claude -p`) sets CLAUDE_CODE_ENTRYPOINT=sdk-cli or non-TTY stdout/stderr
    entrypoint = os.environ.get("CLAUDE_CODE_ENTRYPOINT", "")
    if entrypoint in ("sdk-cli", "sdk-ts", "sdk-py", "cli-print"):
        return False
    # If neither /dev/tty nor interactive terminal indicator is available?
    # Note: PreToolUse hook processes themselves run with piped stdin/stdout, so check /dev/tty or env!
    if payload.get("non_interactive") is True:
        return False
    return True


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        sys.exit(0)
    try:
        payload = json.loads(raw)
    except Exception as exc:
        emit("deny", f"pre-tool-guard received malformed hook input JSON: {exc}")

    tool_input = payload.get("tool_input") or {}
    cmd = tool_input.get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        sys.exit(0)

    cwd = payload.get("cwd") or os.getcwd()
    policy_cache = {}
    res = check_command(cmd, cwd, policy_cache)
    if not res:
        sys.exit(0)

    decision, reason = res
    if decision == "ask" and not can_prompt_interactively(payload):
        emit(
            "deny",
            f"{reason} (Cannot prompt interactively in current mode/session; ask the user to run this command directly.)",
        )
    emit(decision, reason)


if __name__ == "__main__":
    main()
