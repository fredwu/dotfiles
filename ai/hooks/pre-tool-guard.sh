#!/usr/bin/env python3
import json
import os
import re
import shlex
import subprocess
import sys

INTERACTIVE_MODES = {"default", "acceptEdits", "plan", "auto"}

ALWAYS_DATA_COMMANDS = {
    "rg", "grep", "egrep", "fgrep", "ag", "ack",
    "echo", "printf", "cat", "head", "tail", "wc", "ls",
    "cut", "sort", "uniq", "tr", "tee", "bat",
}
GIT_DATA_SUBCOMMANDS = {
    "commit", "log", "diff", "status", "show", "grep", "check-ignore",
    "tag", "branch", "notes", "describe", "rev-parse", "ls-files",
}
GH_DATA_SUBCOMMANDS = {"pr", "issue", "release", "gist"}
SIMPLE_WRAPPERS = {"nohup", "time", "command", "exec", "xargs"}
SHELL_BINARIES = {"sh", "bash", "zsh"}
ENV_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
HEREDOC_OP_RE = re.compile(r"<<(-)?\s*(?:'([^']+)'|\"([^\"]+)\"|\\?([A-Za-z_][A-Za-z0-9_-]*))")
ALLOWED_POLICY_KEYS = {"version", "rules"}
ALLOWED_RULE_KEYS = {
    "id", "decision", "cmd_regex", "allow_if_regex",
    "require_wrapper", "reason", "instead", "match_data_commands",
}
ALLOWED_WRAPPER_KEYS = {"wrapper", "commands"}


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
    if not path:
        return None
    cur = os.path.abspath(path)
    while True:
        if os.path.exists(os.path.join(cur, ".git")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent


def compile_regex_list(items, label):
    if not isinstance(items, list) or not all(isinstance(x, str) and x for x in items):
        raise ValueError(f"{label} must be a list of non-empty regex strings")
    return [re.compile(x) for x in items]


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
            raise ValueError("root must be a JSON object")
        unknown_top = set(data.keys()) - ALLOWED_POLICY_KEYS
        if unknown_top:
            raise ValueError(f"unknown top-level keys: {sorted(unknown_top)}")
        if "rules" not in data or not isinstance(data["rules"], list):
            raise ValueError("'rules' must be a list")

        compiled_rules = []
        for idx, rule in enumerate(data["rules"]):
            if not isinstance(rule, dict):
                raise ValueError(f"rule[{idx}] must be an object")
            unknown_keys = set(rule.keys()) - ALLOWED_RULE_KEYS
            if unknown_keys:
                raise ValueError(f"rule[{idx}] has unknown keys: {sorted(unknown_keys)}")

            decision = rule.get("decision")
            if decision not in ("deny", "ask"):
                raise ValueError(f"rule[{idx}].decision must be 'deny' or 'ask'")

            rid = rule.get("id", f"rule-{idx}")
            reason = rule.get("reason", "Blocked by repository guardrails.")
            instead = rule.get("instead")
            if not isinstance(rid, str) or not isinstance(reason, str):
                raise ValueError(f"rule[{idx}] id/reason must be strings")
            if instead is not None and not isinstance(instead, str):
                raise ValueError(f"rule[{idx}].instead must be a string")

            allow_res = []
            if "allow_if_regex" in rule:
                allow_res = compile_regex_list(rule["allow_if_regex"], f"rule[{idx}].allow_if_regex")

            has_cmd = "cmd_regex" in rule
            has_req = "require_wrapper" in rule
            if has_cmd == has_req:
                raise ValueError(f"rule[{idx}] must define exactly one of 'cmd_regex' or 'require_wrapper'")

            compiled_cmd = None
            req_cfg = None
            if has_cmd:
                pat = rule["cmd_regex"]
                if not isinstance(pat, str) or not pat:
                    raise ValueError(f"rule[{idx}].cmd_regex must be a non-empty string")
                compiled_cmd = re.compile(pat)
            else:
                req = rule["require_wrapper"]
                if not isinstance(req, dict):
                    raise ValueError(f"rule[{idx}].require_wrapper must be an object")
                unknown_req = set(req.keys()) - ALLOWED_WRAPPER_KEYS
                if unknown_req:
                    raise ValueError(f"rule[{idx}].require_wrapper unknown keys: {sorted(unknown_req)}")
                wrapper = req.get("wrapper")
                commands = req.get("commands")
                if not isinstance(wrapper, str) or not wrapper:
                    raise ValueError(f"rule[{idx}].require_wrapper.wrapper must be a non-empty string")
                if not isinstance(commands, list) or not commands or not all(isinstance(c, str) and c for c in commands):
                    raise ValueError(f"rule[{idx}].require_wrapper.commands must be a non-empty list of strings")
                req_cfg = {"wrapper": wrapper, "commands": set(commands)}

            match_data = rule.get("match_data_commands", False)
            if not isinstance(match_data, bool):
                raise ValueError(f"rule[{idx}].match_data_commands must be a boolean")

            compiled_rules.append({
                "id": rid,
                "decision": decision,
                "reason": reason,
                "instead": instead,
                "allow_res": allow_res,
                "cmd_re": compiled_cmd,
                "require_wrapper": req_cfg,
                "match_data_commands": match_data,
            })

        policy = {"rules": compiled_rules}
        cache[repo_root] = policy
        return policy
    except Exception as exc:
        emit("deny", f"Malformed guardrails policy at {policy_path}: {exc}")


def normalize_continuations(cmd):
    """Join backslash-newline continuations outside single quotes."""
    out = []
    i = 0
    n = len(cmd)
    in_sq = False
    in_dq = False
    while i < n:
        ch = cmd[i]
        if ch == "'" and not in_dq:
            in_sq = not in_sq
            out.append(ch)
            i += 1
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            out.append(ch)
            i += 1
            continue
        if ch == "\\" and not in_sq and i + 1 < n:
            if cmd[i + 1] == "\n":
                i += 2
                continue
            if cmd[i + 1] == "\r" and i + 2 < n and cmd[i + 2] == "\n":
                i += 3
                continue
            out.append(ch)
            out.append(cmd[i + 1])
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def find_heredoc_ops_on_line(line):
    """
    Scan a single line outside single/double quotes and unquoted `#` comments for
    heredoc operators (`<<` / `<<-`), explicitly skipping here-strings (`<<<`).
    Returns list of (strip_tabs, delimiter) tuples.
    """
    ops = []
    i = 0
    n = len(line)
    in_sq = False
    in_dq = False
    esc = False
    while i < n:
        ch = line[i]
        if esc:
            esc = False
            i += 1
            continue
        if ch == "\\" and not in_sq:
            esc = True
            i += 1
            continue
        if ch == "'" and not in_dq:
            in_sq = not in_sq
            i += 1
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            i += 1
            continue
        if not in_sq and not in_dq:
            if ch == "#" and (i == 0 or line[i - 1] in (" ", "\t", ";", "(", "{")):
                break
            if ch == "<" and i + 1 < n and line[i + 1] == "<":
                # Skip here-string `<<<`
                if i + 2 < n and line[i + 2] == "<":
                    i += 3
                    continue
                j = i + 2
                strip_tabs = False
                if j < n and line[j] == "-":
                    strip_tabs = True
                    j += 1
                while j < n and line[j] in (" ", "\t"):
                    j += 1
                if j >= n:
                    i = j
                    continue
                # Parse delimiter token (quoted or unquoted word)
                if line[j] in ("'", '"'):
                    q = line[j]
                    j += 1
                    start = j
                    while j < n and line[j] != q:
                        j += 1
                    delim = line[start:j]
                    if j < n:
                        j += 1
                else:
                    if line[j] == "\\":
                        j += 1
                    start = j
                    while j < n and (line[j].isalnum() or line[j] in ("_", "-")):
                        j += 1
                    delim = line[start:j]
                if delim:
                    ops.append((strip_tabs, delim))
                i = j
                continue
        i += 1
    return ops


def strip_heredocs(cmd):
    """
    Quote- and comment-aware heredoc stripper.
    Returns (cleaned_cmd, heredoc_map, error_reason).
    - Non-shell heredoc bodies (e.g. `git commit -m "$(cat <<'EOF'...EOF)"`) are stripped.
    - Shell-fed heredoc bodies (`sh`/`bash`/`zsh <<EOF`) are stored in `heredoc_map`
      and replaced inline with a placeholder so they are evaluated at the command's
      exact active `cwd`.
    - An unclosed heredoc fails closed (`error_reason`).
    """
    lines = cmd.split("\n")
    out_lines = []
    heredoc_map = {}
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        ops = find_heredoc_ops_on_line(line)
        if not ops:
            out_lines.append(line)
            i += 1
            continue

        feeds_shell = bool(re.search(r"(?:^|[;&|(\s])(?:sh|bash|zsh)\b[^#]*<<", line))
        captured_bodies = []
        for strip_tabs, delim in ops:
            body = []
            found_end = False
            i += 1
            while i < n:
                candidate = lines[i].lstrip("\t") if strip_tabs else lines[i]
                if candidate == delim:
                    found_end = True
                    break
                body.append(lines[i])
                i += 1
            if not found_end:
                return "", {}, f"Unterminated heredoc (missing delimiter `{delim}`); refusing fail-closed."
            if feeds_shell and body:
                captured_bodies.append("\n".join(body))

        if feeds_shell and captured_bodies:
            token_id = f"__PRE_TOOL_GUARD_HEREDOC_{len(heredoc_map)}__"
            heredoc_map[token_id] = "\n".join(captured_bodies)
            # Keep any leading `cd ... &&` on the same line, and attach the placeholder command
            out_lines.append(f"{line} ; {token_id}")
        else:
            out_lines.append(line)
        i += 1
    return "\n".join(out_lines), heredoc_map, None


def strip_unquoted_comment(segment):
    """Strip unquoted `#...` comments that start at beginning or after whitespace."""
    out = []
    in_sq = False
    in_dq = False
    esc = False
    for idx, ch in enumerate(segment):
        if esc:
            out.append(ch)
            esc = False
            continue
        if ch == "\\" and not in_sq:
            out.append(ch)
            esc = True
            continue
        if ch == "'" and not in_dq:
            in_sq = not in_sq
            out.append(ch)
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            out.append(ch)
            continue
        if not in_sq and not in_dq and ch == "#":
            if idx == 0 or segment[idx - 1] in (" ", "\t", ";", "(", "{"):
                break
        out.append(ch)
    return "".join(out).strip()


def split_top_level(cmd):
    """
    Split a shell string into a list of (kind, content, prev_op) items.
    kind is 'cmd' | 'subshell' | 'group' | 'subst'.
    prev_op is None | ';' | '&&' | '||' | '|' | '&' | '\\n'.
    """
    items = []
    substs = []
    buf = []
    i = 0
    n = len(cmd)
    in_sq = False
    in_dq = False
    esc = False
    prev_op = None

    def flush(next_op):
        nonlocal prev_op
        s = strip_unquoted_comment("".join(buf).strip())
        buf.clear()
        if s:
            items.append(("cmd", s, prev_op))
        prev_op = next_op

    while i < n:
        ch = cmd[i]
        if esc:
            buf.append(ch)
            esc = False
            i += 1
            continue
        if ch == "\\" and not in_sq:
            buf.append(ch)
            esc = True
            i += 1
            continue
        if ch == "'" and not in_dq:
            in_sq = not in_sq
            buf.append(ch)
            i += 1
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            buf.append(ch)
            i += 1
            continue

        # Comment to end of line outside quotes
        if not in_sq and not in_dq and ch == "#" and (not buf or buf[-1] in (" ", "\t")):
            while i < n and cmd[i] != "\n":
                i += 1
            continue

        # Command substitution $(...) outside single quotes
        if not in_sq and ch == "$" and i + 1 < n and cmd[i + 1] == "(":
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
                substs.append(inner)
            buf.append(cmd[i:j])
            i = j
            continue

        # Backtick substitution outside single quotes
        if not in_sq and ch == "`":
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
                substs.append(inner)
            buf.append(cmd[i : min(j + 1, n)])
            i = min(j + 1, n)
            continue

        if not in_sq and not in_dq:
            # Top-level subshell (...)
            if ch == "(" and not "".join(buf).strip():
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
                    buf.clear()
                    if inner:
                        items.append(("subshell", inner, prev_op))
                    i = j
                    continue

            # Top-level brace group { ...; }
            if ch == "{" and not "".join(buf).strip() and (i + 1 < n and cmd[i + 1] in (" ", "\t", "\n")):
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
                        if c2 == "{":
                            depth += 1
                        elif c2 == "}":
                            depth -= 1
                    j += 1
                if depth == 0:
                    inner = cmd[i + 1 : j - 1].strip()
                    buf.clear()
                    if inner:
                        items.append(("group", inner, prev_op))
                    i = j
                    continue

            if ch in (";", "\n"):
                flush(ch)
                i += 1
                continue
            if ch == "&":
                if i + 1 < n and cmd[i + 1] == "&":
                    flush("&&")
                    i += 2
                    continue
                prev_c = cmd[i - 1] if i > 0 else ""
                next_c = cmd[i + 1] if i + 1 < n else ""
                if prev_c in (">", "<") or next_c == ">":
                    buf.append(ch)
                    i += 1
                    continue
                flush("&")
                i += 1
                continue
            if ch == "|":
                if i + 1 < n and cmd[i + 1] == "|":
                    flush("||")
                    i += 2
                else:
                    flush("|")
                    i += 1
                continue

        buf.append(ch)
        i += 1

    flush(None)
    for sc in substs:
        items.append(("subst", sc, None))
    return items


def tokenize(segment):
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return segment.split()


def resolve_dir_arg(base_cwd, target):
    """Resolve a cd/pushd target path or return None if dynamic/unresolvable."""
    if target is None:
        return os.path.expanduser("~")
    if target == "-":
        return None
    expanded = os.path.expanduser(os.path.expandvars(target))
    if "$" in expanded or "`" in expanded:
        return None
    return os.path.abspath(os.path.join(base_cwd, expanded))


def resolve_tmux_pane_cwd(target, server_opts):
    override = os.environ.get("PRE_TOOL_GUARD_TMUX_PANE_PATH")
    if override is not None:
        return override if override.strip() else None
    cmd = ["tmux"] + list(server_opts) + ["display-message", "-p"]
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


def unwrap_tokens(tokens, cwd, inherited_wrappers=None):
    """Unwrap env assignments and exec wrappers. Returns (tokens, wrappers_seen, effective_cwd, err)."""
    wrappers = set(inherited_wrappers or ())
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
                if t in ("-u", "-C"):
                    if t == "-C" and idx + 1 < n:
                        resolved = resolve_dir_arg(eff_cwd, tokens[idx + 1])
                        if not resolved:
                            return [], wrappers, eff_cwd, "Cannot determine execution directory for `env -C`."
                        eff_cwd = resolved
                    idx += 2
                    continue
                if t == "-S" and idx + 1 < n:
                    # Splice split string tokens back into token stream
                    spliced = tokenize(tokens[idx + 1])
                    tokens = tokens[:idx] + spliced + tokens[idx + 2 :]
                    n = len(tokens)
                    break
                if t.startswith("-") or ENV_ASSIGN_RE.match(t):
                    idx += 1
                    continue
                break
            continue

        if base == "command":
            # `command -v` / `command -V` inspects PATH only, does not execute
            look = idx + 1
            is_query = False
            while look < n and tokens[look].startswith("-") and tokens[look] != "--":
                if "v" in tokens[look][1:] or "V" in tokens[look][1:]:
                    is_query = True
                    break
                look += 1
            if is_query:
                break
            wrappers.add("command")
            idx += 1
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "timeout":
            wrappers.add("timeout")
            idx += 1
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t in ("-k", "-s", "--kill-after", "--signal"):
                    idx += 2
                    continue
                if t.startswith("-"):
                    idx += 1
                    continue
                # First positional argument to timeout is duration
                idx += 1
                break
            continue

        if base == "nice":
            wrappers.add("nice")
            idx += 1
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t in ("-n", "--adjustment"):
                    idx += 2
                    continue
                if t.startswith("-"):
                    idx += 1
                    continue
                break
            continue

        if base == "caffeinate":
            wrappers.add("caffeinate")
            idx += 1
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t in ("-t", "-w"):
                    idx += 2
                    continue
                if t.startswith("-"):
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

        if base == "mise":
            # Support global flags before exec/x, e.g. `mise -C /path exec -- mix test`
            j = idx + 1
            mise_cwd = eff_cwd
            while j < n:
                t = tokens[j]
                if t in ("-C", "--cd") and j + 1 < n:
                    resolved = resolve_dir_arg(mise_cwd, tokens[j + 1])
                    if not resolved:
                        return [], wrappers, eff_cwd, "Cannot determine execution directory for `mise -C`."
                    mise_cwd = resolved
                    j += 2
                    continue
                if t.startswith("-C="):
                    resolved = resolve_dir_arg(mise_cwd, t[3:])
                    if not resolved:
                        return [], wrappers, eff_cwd, "Cannot determine execution directory for `mise -C`."
                    mise_cwd = resolved
                    j += 1
                    continue
                if t.startswith("--cd="):
                    resolved = resolve_dir_arg(mise_cwd, t[5:])
                    if not resolved:
                        return [], wrappers, eff_cwd, "Cannot determine execution directory for `mise --cd`."
                    mise_cwd = resolved
                    j += 1
                    continue
                if t in ("-E", "--env", "--profile") and j + 1 < n:
                    j += 2
                    continue
                if t.startswith("-"):
                    j += 1
                    continue
                break
            if j < n and tokens[j] in ("exec", "x"):
                wrappers.add("mise")
                eff_cwd = mise_cwd
                idx = j + 1
                while idx < n:
                    t = tokens[idx]
                    if t == "--":
                        idx += 1
                        break
                    if t in ("-C", "--cd") and idx + 1 < n:
                        resolved = resolve_dir_arg(eff_cwd, tokens[idx + 1])
                        if not resolved:
                            return [], wrappers, eff_cwd, "Cannot determine execution directory for `mise exec -C`."
                        eff_cwd = resolved
                        idx += 2
                        continue
                    if t.startswith("-"):
                        idx += 1
                        continue
                    if "@" in t and "--" in tokens[idx:]:
                        idx += 1
                        continue
                    break
                continue

        if base == "direnv" and idx + 2 < n and tokens[idx + 1] == "exec":
            # direnv exec <dir> <cmd> loads env from <dir> but executes <cmd> in caller's cwd!
            wrappers.add("direnv")
            idx += 3
            continue

        break

    return tokens[idx:], wrappers, eff_cwd, None


def is_data_command(tokens):
    if not tokens:
        return True
    base = os.path.basename(tokens[0])
    if base in ALWAYS_DATA_COMMANDS:
        return True
    if base == "command":
        # Reaches here only for `command -v` / `command -V`
        return True
    if base == "find":
        return not any(t in ("-exec", "-execdir", "-ok", "-okdir") for t in tokens[1:])
    if base == "awk":
        joined = " ".join(tokens[1:])
        return "system(" not in joined and "|" not in joined
    if base == "sed":
        return not any(re.search(r"(^|[^a-zA-Z])e($|\s|;)", t) for t in tokens[1:] if not t.startswith("-"))
    if base == "git":
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
    if base == "gh" and len(tokens) > 1:
        return tokens[1] in GH_DATA_SUBCOMMANDS
    return False


def parse_tmux_subcommand(tokens):
    """Parse global tmux options before subcommand. Returns (sub, rest_tokens, server_opts)."""
    server_opts = []
    i = 1
    n = len(tokens)
    while i < n:
        t = tokens[i]
        if t in ("-L", "-S") and i + 1 < n:
            server_opts.extend([t, tokens[i + 1]])
            i += 2
            continue
        if t in ("-f", "-c", "-T") and i + 1 < n:
            i += 2
            continue
        if t.startswith("-"):
            i += 1
            continue
        return t, tokens[i + 1 :], server_opts
    return None, [], server_opts


def split_tmux_send_keys(args):
    """
    Parse `tmux send-keys` arguments.
    Returns (target, commands_list, error_reason).
    Splits on embedded or trailing Enter/C-m/KPEnter/C-j/newline into separate submitted commands.
    """
    target = None
    keys = []
    i = 0
    n = len(args)
    while i < n:
        t = args[i]
        if t == "--":
            keys.extend(args[i + 1 :])
            break
        if t == "-H":
            return target, [], "Refusing `tmux send-keys -H` (hex key bytes cannot be verified by guardrails)."
        if t in ("-t", "-N") and i + 1 < n:
            if t == "-t":
                target = args[i + 1]
            i += 2
            continue
        if t.startswith("-"):
            i += 1
            continue
        keys.append(t)
        i += 1

    # Split key stream into submitted command lines on Enter tokens or embedded newlines
    lines = []
    cur = []
    enter_tokens = {"Enter", "C-m", "KPEnter", "C-j", "KP_Enter"}
    for k in keys:
        if k in enter_tokens:
            if cur:
                lines.append(" ".join(cur))
                cur = []
        elif "\n" in k or "\r" in k:
            parts = re.split(r"[\r\n]+", k)
            for idx_p, part in enumerate(parts):
                if part:
                    cur.append(part)
                if idx_p < len(parts) - 1 and cur:
                    lines.append(" ".join(cur))
                    cur = []
        else:
            cur.append(k)
    if cur:
        lines.append(" ".join(cur))
    return target, lines, None


def extract_subpayloads(tokens, cwd, prev_op, wrappers):
    """Extract list of (payload_cmd, payload_cwd, inherited_wrappers, error_reason)."""
    if not tokens:
        return []
    base = os.path.basename(tokens[0])
    results = []

    if base in SHELL_BINARIES:
        i = 1
        found_c = False
        has_script_file = False
        while i < len(tokens):
            t = tokens[i]
            if t == "--":
                if i + 1 < len(tokens):
                    has_script_file = True
                break
            if t == "-c" or (t.startswith("-") and not t.startswith("--") and "c" in t[1:]):
                found_c = True
                if i + 1 < len(tokens):
                    results.append((tokens[i + 1], cwd, wrappers, None))
                break
            if not t.startswith("-"):
                has_script_file = True
                break
            i += 1
        if not found_c and not has_script_file and prev_op == "|":
            # Piped input into sh/bash/zsh cannot be safely inspected in a guarded repo
            if load_policy(find_git_root(cwd), {}):
                results.append((None, None, None, f"Piping commands into `{base}` is blocked in guarded repositories."))
        return results

    if base == "eval" and len(tokens) > 1:
        results.append((" ".join(tokens[1:]), cwd, wrappers, None))
        return results

    if base == "find":
        i = 1
        while i < len(tokens):
            if tokens[i] in ("-exec", "-execdir", "-ok", "-okdir"):
                sub = []
                j = i + 1
                while j < len(tokens) and tokens[j] not in (";", "+"):
                    sub.append(tokens[j])
                    j += 1
                if sub:
                    results.append((" ".join(sub), cwd, wrappers, None))
                i = j + 1
                continue
            i += 1
        return results

    if base == "awk":
        joined = " ".join(tokens[1:])
        if "system(" in joined:
            if load_policy(find_git_root(cwd), {}):
                results.append((None, None, None, "`awk` calling `system(...)` is blocked in guarded repositories."))
        return results

    if base == "tmux" and len(tokens) > 1:
        sub, rest, server_opts = parse_tmux_subcommand(tokens)
        if sub in ("new-session", "new"):
            i = 0
            pos = []
            sess_cwd = cwd
            while i < len(rest):
                t = rest[i]
                if t in ("-s", "-n", "-t", "-c", "-x", "-y", "-e", "-F") and i + 1 < len(rest):
                    if t == "-c":
                        resolved = resolve_dir_arg(sess_cwd, rest[i + 1])
                        if not resolved:
                            results.append((None, None, None, "Cannot resolve `-c` directory for `tmux new-session`."))
                            return results
                        sess_cwd = resolved
                    i += 2
                    continue
                if t.startswith("-"):
                    i += 1
                    continue
                pos.append(t)
                i += 1
            if pos:
                results.append((" ".join(pos), sess_cwd, wrappers, None))
        elif sub == "send-keys":
            target, lines, err = split_tmux_send_keys(rest)
            if err:
                results.append((None, None, None, err))
                return results
            if lines:
                pane_cwd = resolve_tmux_pane_cwd(target, server_opts)
                if not pane_cwd:
                    results.append((
                        None,
                        None,
                        None,
                        f"Cannot resolve target tmux pane working directory for `tmux send-keys` (target={target or 'current'}); refusing fail-closed.",
                    ))
                else:
                    # Join submitted lines with `\n` so sequential `cd` / `pushd`
                    # commands across tmux submissions propagate cwd forward.
                    results.append(("\n".join(lines), pane_cwd, set(), None))
    return results


def evaluate_policy(tokens, wrappers, raw_segment, policy):
    """Returns (decision, reason) or None."""
    if not policy or not tokens:
        return None

    unwrapped_str = " ".join(tokens)
    clean_raw = strip_unquoted_comment(raw_segment)
    data_cmd = is_data_command(tokens)
    best = None

    def record(decision, reason):
        nonlocal best
        if decision == "deny":
            best = ("deny", reason)
        elif decision == "ask" and best is None:
            best = ("ask", reason)

    for rule in policy["rules"]:
        allow_res = rule["allow_res"]
        if any(rx.search(unwrapped_str) or rx.search(clean_raw) for rx in allow_res):
            continue

        matched = False
        req = rule["require_wrapper"]
        if req:
            if os.path.basename(tokens[0]) in req["commands"] and req["wrapper"] not in wrappers:
                matched = True
        else:
            if data_cmd and not rule["match_data_commands"]:
                continue
            if rule["cmd_re"].search(unwrapped_str):
                matched = True

        if matched:
            msg = f"[{rule['id']}] {rule['reason']}"
            if rule["instead"]:
                msg += f" Use instead: {rule['instead']}"
            record(rule["decision"], msg)
            if best and best[0] == "deny":
                return best

    return best


def merge_decisions(worst, res):
    if not res:
        return worst
    if res[0] == "deny":
        return res
    if res[0] == "ask" and worst is None:
        return res
    return worst


def eval_command(cmd, start_cwds, policy_cache, depth=0, inherited_wrappers=None, heredoc_map=None):
    """Evaluate `cmd` and return `(worst_decision_or_None, final_active_cwds)`."""
    if depth > 6:
        return ("deny", "Command nesting depth exceeded guardrail inspection limit."), set(start_cwds)

    if isinstance(start_cwds, str):
        active_cwds = {start_cwds}
    else:
        active_cwds = set(start_cwds)

    fallback_cwds = set()
    in_conditional = False
    worst = None

    norm = normalize_continuations(cmd)
    cleaned, local_heredocs, hd_err = strip_heredocs(norm)
    if hd_err:
        return ("deny", hd_err), active_cwds

    merged_heredocs = dict(heredoc_map or {})
    merged_heredocs.update(local_heredocs)

    for kind, content, prev_op in split_top_level(cleaned):
        if prev_op in ("&&", "||"):
            if not in_conditional:
                fallback_cwds = set(active_cwds)
                in_conditional = True
            elif prev_op == "||":
                active_cwds = active_cwds | fallback_cwds
        elif prev_op in (";", "\n", "&"):
            if in_conditional:
                active_cwds = active_cwds | fallback_cwds
                fallback_cwds = set()
                in_conditional = False

        if kind in ("subshell", "subst"):
            # Subshell / command substitution keeps its cwd strictly local
            res, _sub_cwds = eval_command(content, active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs)
            worst = merge_decisions(worst, res)
            if worst and worst[0] == "deny":
                return worst, active_cwds
            continue

        if kind == "group":
            # Brace group runs in parent shell: carry its final cwds forward!
            res, group_cwds = eval_command(content, active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs)
            worst = merge_decisions(worst, res)
            active_cwds = group_cwds
            if worst and worst[0] == "deny":
                return worst, active_cwds
            continue

        # Inline shell heredoc body evaluated at this exact active_cwds!
        if content in merged_heredocs:
            res, _hd_cwds = eval_command(
                merged_heredocs[content], active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs
            )
            worst = merge_decisions(worst, res)
            if worst and worst[0] == "deny":
                return worst, active_cwds
            continue

        tokens = tokenize(content)
        if not tokens:
            continue

        first_base = os.path.basename(tokens[0])
        if first_base in ("cd", "pushd"):
            target = None
            for arg in tokens[1:]:
                if arg in ("-L", "-P", "--", "-n"):
                    continue
                target = arg
                break
            next_cwds = set()
            for c in active_cwds:
                resolved = resolve_dir_arg(c, target)
                if not resolved:
                    return (
                        "deny",
                        f"Cannot determine target directory for `{first_base} {target or ''}`. Use an explicit path so repository guardrails can be verified.",
                    ), active_cwds
                next_cwds.add(resolved)
            active_cwds = next_cwds
            continue

        if first_base == "popd":
            return (
                "deny",
                "Cannot determine target directory for `popd`; use an explicit `cd <path>` so repository guardrails can be verified.",
            ), active_cwds

        for c in sorted(active_cwds):
            unwrapped, wrappers, seg_cwd, unwrap_err = unwrap_tokens(tokens, c, inherited_wrappers)
            if unwrap_err:
                return ("deny", unwrap_err), active_cwds
            if not unwrapped:
                continue

            subpayloads = extract_subpayloads(unwrapped, seg_cwd, prev_op, wrappers)
            if subpayloads:
                for p_cmd, p_cwd, p_wrappers, p_err in subpayloads:
                    if p_err:
                        return ("deny", p_err), active_cwds
                    if p_cmd:
                        res, _p_cwds = eval_command(p_cmd, p_cwd, policy_cache, depth + 1, p_wrappers, merged_heredocs)
                        worst = merge_decisions(worst, res)
                        if worst and worst[0] == "deny":
                            return worst, active_cwds
                continue

            repo_root = find_git_root(seg_cwd)
            policy = load_policy(repo_root, policy_cache)
            worst = merge_decisions(worst, evaluate_policy(unwrapped, wrappers, content, policy))
            if worst and worst[0] == "deny":
                return worst, active_cwds

    if in_conditional:
        active_cwds = active_cwds | fallback_cwds
    return worst, active_cwds


def check_command(cmd, start_cwds, policy_cache, depth=0, inherited_wrappers=None):
    res, _cwds = eval_command(cmd, start_cwds, policy_cache, depth, inherited_wrappers)
    return res


def can_prompt_interactively(payload):
    mode = payload.get("permission_mode")
    if mode not in INTERACTIVE_MODES:
        return False
    if payload.get("agent_id") or payload.get("agent_type"):
        return False
    if payload.get("non_interactive") is True:
        return False
    if os.environ.get("CLAUDE_NONINTERACTIVE") in ("1", "true", "TRUE", "yes"):
        return False
    if os.environ.get("CLAUDE_CODE_CHILD_SESSION") == "1":
        return False
    if os.environ.get("CLAUDE_CODE_SESSION_ATTENDED") == "0":
        return False

    # Require positive evidence that an interactive human session can receive the prompt.
    entrypoint = os.environ.get("CLAUDE_CODE_ENTRYPOINT", "")
    if entrypoint == "cli":
        return True
    if entrypoint == "t3-code" and os.environ.get("CLAUDE_CODE_SESSION_ATTENDED") == "1":
        return True
    return False


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        sys.exit(0)
    try:
        payload = json.loads(raw)
    except Exception as exc:
        emit("deny", f"pre-tool-guard received malformed hook input JSON: {exc}")

    if not isinstance(payload, dict):
        emit("deny", "pre-tool-guard expected a JSON object hook payload.")

    tool_input = payload.get("tool_input")
    if tool_input is None:
        sys.exit(0)
    if not isinstance(tool_input, dict):
        emit("deny", "pre-tool-guard expected 'tool_input' to be a JSON object.")

    cmd = tool_input.get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        sys.exit(0)

    cwd = payload.get("cwd") or os.getcwd()
    if not isinstance(cwd, str) or not cwd.strip():
        emit("deny", "pre-tool-guard received invalid 'cwd' in hook payload.")

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
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        emit("deny", f"pre-tool-guard internal error (fail closed): {exc}")
