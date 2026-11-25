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
    """Join backslash-newline continuations outside single quotes and $'...' ANSI-C quotes."""
    out = []
    i = 0
    n = len(cmd)
    in_sq = False
    in_dq = False
    in_ansic = False
    while i < n:
        ch = cmd[i]
        if in_ansic:
            if ch == "\\" and i + 1 < n:
                out.append(ch)
                out.append(cmd[i + 1])
                i += 2
                continue
            if ch == "'":
                in_ansic = False
            out.append(ch)
            i += 1
            continue
        if not in_sq and not in_dq and ch == "$" and i + 1 < n and cmd[i + 1] == "'":
            in_ansic = True
            out.append("$'")
            i += 2
            continue
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


ANSIC_SIMPLE_ESCAPES = {
    "a": "\a",
    "b": "\b",
    "e": "\x1b",
    "E": "\x1b",
    "f": "\f",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "v": "\v",
    "\\": "\\",
    "'": "'",
    '"': '"',
    "?": "?",
}


def decode_ansic_escape(s, idx):
    """
    Decode one Bash ANSI-C (`$'...'`) escape sequence starting at `idx`
    (the character immediately following `\\`). Returns (decoded_str, next_idx).
    Supports simple escapes, 1-3 digit octal `\\NNN`, 1-2 digit hex `\\xHH`,
    1-4 digit `\\uHHHH`, 1-8 digit `\\UHHHHHHHH`, and `\\cX`.
    """
    n = len(s)
    if idx >= n:
        return "\\", idx
    nxt = s[idx]
    if nxt in ANSIC_SIMPLE_ESCAPES:
        return ANSIC_SIMPLE_ESCAPES[nxt], idx + 1
    if nxt in "01234567":
        j = idx
        while j < n and j - idx < 3 and s[j] in "01234567":
            j += 1
        return chr(int(s[idx:j], 8) & 0xFF), j
    if nxt == "x":
        j = idx + 1
        while j < n and j - (idx + 1) < 2 and s[j] in "0123456789abcdefABCDEF":
            j += 1
        if j > idx + 1:
            return chr(int(s[idx + 1 : j], 16)), j
        return "\\x", idx + 1
    if nxt in ("u", "U"):
        max_len = 4 if nxt == "u" else 8
        j = idx + 1
        while j < n and j - (idx + 1) < max_len and s[j] in "0123456789abcdefABCDEF":
            j += 1
        if j > idx + 1:
            codepoint = int(s[idx + 1 : j], 16)
            if 0 <= codepoint <= 0x10FFFF:
                return chr(codepoint), j
        return "\\" + nxt, idx + 1
    if nxt == "c" and idx + 1 < n:
        ctrl = ord(s[idx + 1].upper()) ^ 0x40
        return chr(ctrl & 0x7F), idx + 2
    return "\\" + nxt, idx + 1


def parse_heredoc_delimiter(line, j):
    """
    Parse a POSIX/Bash heredoc delimiter word starting at `j` with shell
    quote-removal rules (including `$'...'` ANSI-C quotes).
    Returns (delim, quoted_delim, saw_word, next_idx, error_reason).
    """
    n = len(line)
    delim_chars = []
    delim_sq = False
    delim_dq = False
    delim_ansic = False
    delim_esc = False
    quoted_delim = False
    saw_word = False
    meta = (" ", "\t", "\r", ";", "&", "|", "<", ">", "(", ")")
    while j < n:
        ch = line[j]
        if delim_ansic:
            if ch == "\\" and j + 1 < n:
                dec, j = decode_ansic_escape(line, j + 1)
                delim_chars.append(dec)
                saw_word = True
                continue
            if ch == "'":
                delim_ansic = False
                saw_word = True
                j += 1
                continue
            delim_chars.append(ch)
            saw_word = True
            j += 1
            continue
        if delim_esc:
            delim_chars.append(ch)
            delim_esc = False
            saw_word = True
            j += 1
            continue
        if delim_sq:
            if ch == "'":
                delim_sq = False
            else:
                delim_chars.append(ch)
            saw_word = True
            j += 1
            continue
        if delim_dq:
            if ch == '"':
                delim_dq = False
                saw_word = True
                j += 1
                continue
            if ch == "\\" and j + 1 < n and line[j + 1] in ('"', "\\", "$", "`"):
                delim_chars.append(line[j + 1])
                saw_word = True
                j += 2
                continue
            delim_chars.append(ch)
            saw_word = True
            j += 1
            continue
        if ch in meta:
            break
        if ch == "$" and j + 1 < n and line[j + 1] == "'":
            delim_ansic = True
            quoted_delim = True
            saw_word = True
            j += 2
            continue
        if ch == "\\":
            delim_esc = True
            quoted_delim = True
            saw_word = True
            j += 1
            continue
        if ch == "'":
            delim_sq = True
            quoted_delim = True
            saw_word = True
            j += 1
            continue
        if ch == '"':
            delim_dq = True
            quoted_delim = True
            saw_word = True
            j += 1
            continue
        delim_chars.append(ch)
        saw_word = True
        j += 1

    if delim_sq or delim_dq or delim_ansic or delim_esc:
        return None, quoted_delim, saw_word, j, "Unterminated quote in heredoc delimiter; refusing fail-closed."
    return "".join(delim_chars), quoted_delim, saw_word, j, None


def find_heredoc_ops_on_line(line, in_sq=False, in_dq=False, in_ansic=False, arith_depth=0, arith_parens=0):
    """
    Scan a single line carrying quote/arithmetic state across lines, skipping
    single/double/ANSI-C quoted text, unquoted `#` comments, arithmetic `((...))`,
    and here-strings (`<<<`).
    Returns (ops, end_in_sq, end_in_dq, end_in_ansic, end_arith_depth, end_arith_parens, error_reason),
    where each op is (start_idx, end_idx, strip_tabs, delimiter, quoted_delim).
    """
    ops = []
    i = 0
    n = len(line)
    esc = False
    while i < n:
        ch = line[i]
        if in_ansic:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == "'":
                in_ansic = False
            i += 1
            continue
        if esc:
            esc = False
            i += 1
            continue
        if ch == "\\" and not in_sq:
            esc = True
            i += 1
            continue
        if not in_sq and not in_dq and ch == "$" and i + 1 < n and line[i + 1] == "'":
            in_ansic = True
            i += 2
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
            if ch == "#" and arith_depth == 0 and (i == 0 or line[i - 1] in (" ", "\t", ";", "(", "{")):
                break
            if ch == "$" and i + 2 < n and line[i + 1 : i + 3] == "((":
                arith_depth += 1
                i += 3
                continue
            if ch == "(" and i + 1 < n and line[i + 1] == "(" and arith_depth == 0:
                arith_depth += 1
                i += 2
                continue
            if arith_depth > 0:
                if ch == "(":
                    arith_parens += 1
                    i += 1
                    continue
                if ch == ")":
                    if arith_parens > 0:
                        arith_parens -= 1
                        i += 1
                        continue
                    if i + 1 < n and line[i + 1] == ")":
                        arith_depth -= 1
                        i += 2
                        continue
                i += 1
                continue
            if ch == "<" and i + 1 < n and line[i + 1] == "<":
                # Skip here-string `<<<`
                if i + 2 < n and line[i + 2] == "<":
                    i += 3
                    continue
                op_start = i
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
                delim, quoted_delim, saw_word, j, err = parse_heredoc_delimiter(line, j)
                if err:
                    return [], in_sq, in_dq, in_ansic, arith_depth, arith_parens, err
                if saw_word:
                    ops.append((op_start, j, strip_tabs, delim, quoted_delim))
                i = j
                continue
        i += 1
    return ops, in_sq, in_dq, in_ansic, arith_depth, arith_parens, None


def strip_heredocs(cmd, token_offset=0):
    """
    Quote- and comment-aware heredoc stripper that preserves multiline quote
    state and replaces each `<<[-]?DELIM` operator in place with a unique
    marker token (`__PRE_TOOL_GUARD_HEREDOC_<N>__`).
    Stores `{"body": body_text, "quoted": quoted_delim}` in `heredoc_map`.
    An unclosed heredoc fails closed (`error_reason`).
    """
    lines = cmd.split("\n")
    out_lines = []
    heredoc_map = {}
    i = 0
    n = len(lines)
    in_sq = False
    in_dq = False
    in_ansic = False
    arith_depth = 0
    arith_parens = 0
    next_id = token_offset
    while i < n:
        line = lines[i]
        ops, in_sq, in_dq, in_ansic, arith_depth, arith_parens, op_err = find_heredoc_ops_on_line(
            line, in_sq, in_dq, in_ansic, arith_depth, arith_parens
        )
        if op_err:
            return "", {}, op_err
        if not ops:
            out_lines.append(line)
            i += 1
            continue

        replacements = []
        for op_start, op_end, strip_tabs, delim, quoted_delim in ops:
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
            token_id = f"__PRE_TOOL_GUARD_HEREDOC_{next_id}__"
            next_id += 1
            heredoc_map[token_id] = {"body": "\n".join(body), "quoted": quoted_delim}
            replacements.append((op_start, op_end, f" {token_id} "))

        rebuilt = []
        cursor = 0
        for op_start, op_end, repl in replacements:
            rebuilt.append(line[cursor:op_start])
            rebuilt.append(repl)
            cursor = op_end
        rebuilt.append(line[cursor:])
        out_lines.append("".join(rebuilt))
        i += 1
    return "\n".join(out_lines), heredoc_map, None


def extract_unquoted_heredoc_substs(body):
    """Extract `$(...)` and backtick command substitutions from an unquoted heredoc body."""
    substs = []
    i = 0
    n = len(body)
    while i < n:
        ch = body[i]
        if ch == "\\" and i + 1 < n:
            i += 2
            continue
        if ch == "$" and i + 1 < n and body[i + 1] == "(":
            # Skip arithmetic $((...))
            if i + 2 < n and body[i + 2] == "(":
                i += 3
                continue
            depth = 1
            j = i + 2
            sub_sq = False
            sub_dq = False
            sub_ansic = False
            sub_esc = False
            while j < n and depth > 0:
                c2 = body[j]
                if sub_ansic:
                    if sub_esc:
                        sub_esc = False
                    elif c2 == "\\":
                        sub_esc = True
                    elif c2 == "'":
                        sub_ansic = False
                elif sub_esc:
                    sub_esc = False
                elif c2 == "\\" and not sub_sq:
                    sub_esc = True
                elif not sub_sq and not sub_dq and c2 == "$" and j + 1 < n and body[j + 1] == "'":
                    sub_ansic = True
                    j += 2
                    continue
                elif c2 == "'" and not sub_dq:
                    sub_sq = not sub_sq
                elif c2 == '"' and not sub_sq:
                    sub_dq = not sub_dq
                elif not sub_sq and not sub_dq:
                    if c2 == "#" and (j == i + 2 or body[j - 1] in (" ", "\t", "\n", ";", "(", "{", "|", "&")):
                        while j < n and body[j] != "\n":
                            j += 1
                        continue
                    if c2 == "(":
                        depth += 1
                    elif c2 == ")":
                        depth -= 1
                j += 1
            inner = body[i + 2 : j - 1].strip() if depth == 0 else body[i + 2 :].strip()
            if inner:
                substs.append(inner)
            i = j
            continue
        if ch == "`":
            j = i + 1
            sub_esc = False
            while j < n:
                c2 = body[j]
                if sub_esc:
                    sub_esc = False
                elif c2 == "\\":
                    sub_esc = True
                elif c2 == "`":
                    break
                j += 1
            inner = body[i + 1 : j].strip()
            if inner:
                substs.append(inner)
            i = min(j + 1, n)
            continue
        i += 1
    return substs


def strip_unquoted_comment(segment):
    """Strip unquoted `#...` comments that start at beginning or after whitespace."""
    out = []
    in_sq = False
    in_dq = False
    in_ansic = False
    esc = False
    i = 0
    n = len(segment)
    while i < n:
        ch = segment[i]
        if in_ansic:
            if esc:
                out.append(ch)
                esc = False
            elif ch == "\\":
                out.append(ch)
                esc = True
            elif ch == "'":
                in_ansic = False
                out.append(ch)
            else:
                out.append(ch)
            i += 1
            continue
        if esc:
            out.append(ch)
            esc = False
            i += 1
            continue
        if ch == "\\" and not in_sq:
            out.append(ch)
            esc = True
            i += 1
            continue
        if not in_sq and not in_dq and ch == "$" and i + 1 < n and segment[i + 1] == "'":
            in_ansic = True
            out.append("$'")
            i += 2
            continue
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
        if not in_sq and not in_dq and ch == "#":
            if i == 0 or segment[i - 1] in (" ", "\t", ";", "(", "{"):
                break
        out.append(ch)
        i += 1
    return "".join(out).strip()


def split_top_level(cmd):
    """
    Split a shell string into a list of (kind, content, prev_op, next_op) items.
    kind is 'cmd' | 'subshell' | 'group' | 'subst'.
    prev_op / next_op is None | ';' | '&&' | '||' | '|' | '&' | '\\n'.
    """
    items = []
    substs = []
    buf = []
    i = 0
    n = len(cmd)
    in_sq = False
    in_dq = False
    in_ansic = False
    esc = False
    prev_op = None

    def flush(next_op):
        nonlocal prev_op
        s = strip_unquoted_comment("".join(buf).strip())
        buf.clear()
        if s:
            # If the immediately preceding item was a group/subshell followed by
            # trailing redirections (no separator between them), attach `next_op`
            # to that group/subshell as well so pipeline/background scope holds.
            if items and items[-1][0] in ("group", "subshell") and items[-1][3] is None:
                items[-1][3] = next_op
            items.append(["cmd", s, prev_op, next_op])
            prev_op = next_op
        else:
            # In Bash, newlines immediately after `|`, `&&`, or `||` continue
            # the pending operator rather than acting as a new list separator.
            if next_op == "\n" and prev_op in ("|", "&&", "||") and (not items or items[-1][3] is not None):
                return
            if items and items[-1][3] is None:
                items[-1][3] = next_op
            prev_op = next_op

    while i < n:
        ch = cmd[i]
        if in_ansic:
            if esc:
                buf.append(ch)
                esc = False
            elif ch == "\\":
                buf.append(ch)
                esc = True
            elif ch == "'":
                in_ansic = False
                buf.append(ch)
            else:
                buf.append(ch)
            i += 1
            continue
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
        if not in_sq and not in_dq and ch == "$" and i + 1 < n and cmd[i + 1] == "'":
            in_ansic = True
            buf.append("$'")
            i += 2
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

        # Command substitution $(...) outside single quotes (skip $((...)) arithmetic)
        if not in_sq and ch == "$" and i + 1 < n and cmd[i + 1] == "(" and not (i + 2 < n and cmd[i + 2] == "("):
            depth = 1
            j = i + 2
            sub_sq = False
            sub_dq = False
            sub_ansic = False
            sub_esc = False
            while j < n and depth > 0:
                c2 = cmd[j]
                if sub_ansic:
                    if sub_esc:
                        sub_esc = False
                    elif c2 == "\\":
                        sub_esc = True
                    elif c2 == "'":
                        sub_ansic = False
                elif sub_esc:
                    sub_esc = False
                elif c2 == "\\" and not sub_sq:
                    sub_esc = True
                elif not sub_sq and not sub_dq and c2 == "$" and j + 1 < n and cmd[j + 1] == "'":
                    sub_ansic = True
                    j += 2
                    continue
                elif c2 == "'" and not sub_dq:
                    sub_sq = not sub_sq
                elif c2 == '"' and not sub_sq:
                    sub_dq = not sub_dq
                elif not sub_sq and not sub_dq:
                    if c2 == "#" and (j == i + 2 or cmd[j - 1] in (" ", "\t", "\n", ";", "(", "{", "|", "&")):
                        while j < n and cmd[j] != "\n":
                            j += 1
                        continue
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
            prefix_str = "".join(buf).strip()
            coproc_prefix = bool(re.match(r"^coproc(?:\s+[A-Za-z_][A-Za-z0-9_]*)?$", prefix_str))
            compound_prefix_ok = (not prefix_str) or coproc_prefix or (prefix_str in SHELL_RESERVED_PREFIXES)

            # Top-level subshell (...) (also handles `coproc [NAME] (...)` and `! (...)`)
            if ch == "(" and compound_prefix_ok and not (i + 1 < n and cmd[i + 1] == "("):
                depth = 1
                j = i + 1
                sub_sq = False
                sub_dq = False
                sub_ansic = False
                sub_esc = False
                while j < n and depth > 0:
                    c2 = cmd[j]
                    if sub_ansic:
                        if sub_esc:
                            sub_esc = False
                        elif c2 == "\\":
                            sub_esc = True
                        elif c2 == "'":
                            sub_ansic = False
                    elif sub_esc:
                        sub_esc = False
                    elif c2 == "\\" and not sub_sq:
                        sub_esc = True
                    elif not sub_sq and not sub_dq and c2 == "$" and j + 1 < n and cmd[j + 1] == "'":
                        sub_ansic = True
                        j += 2
                        continue
                    elif c2 == "'" and not sub_dq:
                        sub_sq = not sub_sq
                    elif c2 == '"' and not sub_sq:
                        sub_dq = not sub_dq
                    elif not sub_sq and not sub_dq:
                        if c2 == "#" and (j == i + 1 or cmd[j - 1] in (" ", "\t", "\n", ";", "(", "{", "|", "&")):
                            while j < n and cmd[j] != "\n":
                                j += 1
                            continue
                        if c2 == "(":
                            depth += 1
                        elif c2 == ")":
                            depth -= 1
                    j += 1
                if depth == 0:
                    inner = cmd[i + 1 : j - 1].strip()
                    buf.clear()
                    if inner:
                        items.append(["subshell", inner, prev_op, None])
                    i = j
                    continue

            # Top-level brace group { ...; } (also handles `coproc [NAME] { ...; }` and `! { ...; }`)
            if ch == "{" and compound_prefix_ok and (i + 1 < n and cmd[i + 1] in (" ", "\t", "\n")):
                depth = 1
                j = i + 1
                sub_sq = False
                sub_dq = False
                sub_ansic = False
                sub_esc = False
                while j < n and depth > 0:
                    c2 = cmd[j]
                    if sub_ansic:
                        if sub_esc:
                            sub_esc = False
                        elif c2 == "\\":
                            sub_esc = True
                        elif c2 == "'":
                            sub_ansic = False
                    elif sub_esc:
                        sub_esc = False
                    elif c2 == "\\" and not sub_sq:
                        sub_esc = True
                    elif not sub_sq and not sub_dq and c2 == "$" and j + 1 < n and cmd[j + 1] == "'":
                        sub_ansic = True
                        j += 2
                        continue
                    elif c2 == "'" and not sub_dq:
                        sub_sq = not sub_sq
                    elif c2 == '"' and not sub_sq:
                        sub_dq = not sub_dq
                    elif not sub_sq and not sub_dq:
                        if c2 == "#" and (j == i + 1 or cmd[j - 1] in (" ", "\t", "\n", ";", "(", "{", "|", "&")):
                            while j < n and cmd[j] != "\n":
                                j += 1
                            continue
                        if c2 == "{":
                            depth += 1
                        elif c2 == "}":
                            depth -= 1
                    j += 1
                if depth == 0:
                    inner = cmd[i + 1 : j - 1].strip()
                    buf.clear()
                    if inner:
                        kind_out = "subshell" if coproc_prefix else "group"
                        items.append([kind_out, inner, prev_op, None])
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
        items.append(["subst", sc, None, None])
    return [tuple(it) for it in items]


def tokenize(segment):
    """POSIX + Bash ANSI-C ($'...') aware shell word tokenizer."""
    tokens = []
    buf = []
    has_token = False
    i = 0
    n = len(segment)
    in_sq = False
    in_dq = False
    in_ansic = False

    while i < n:
        ch = segment[i]
        if in_ansic:
            if ch == "\\" and i + 1 < n:
                dec, i = decode_ansic_escape(segment, i + 1)
                buf.append(dec)
                continue
            if ch == "'":
                in_ansic = False
                i += 1
                continue
            buf.append(ch)
            i += 1
            continue
        if in_sq:
            if ch == "'":
                in_sq = False
            else:
                buf.append(ch)
            i += 1
            continue
        if in_dq:
            if ch == '"':
                in_dq = False
                i += 1
                continue
            if ch == "\\" and i + 1 < n and segment[i + 1] in ('"', "\\", "$", "`"):
                buf.append(segment[i + 1])
                i += 2
                continue
            buf.append(ch)
            i += 1
            continue
        if ch in (" ", "\t", "\r", "\n"):
            if has_token:
                tokens.append("".join(buf))
                buf = []
                has_token = False
            i += 1
            continue
        if ch == "$" and i + 1 < n and segment[i + 1] == "'":
            in_ansic = True
            has_token = True
            i += 2
            continue
        if ch == "'":
            in_sq = True
            has_token = True
            i += 1
            continue
        if ch == '"':
            in_dq = True
            has_token = True
            i += 1
            continue
        if ch == "\\" and i + 1 < n:
            buf.append(segment[i + 1])
            has_token = True
            i += 2
            continue
        buf.append(ch)
        has_token = True
        i += 1

    if has_token:
        tokens.append("".join(buf))
    return tokens


SHELL_RESERVED_PREFIXES = {"!", "if", "then", "elif", "else", "do", "while", "until", "coproc"}


def strip_shell_prefixes(tokens):
    """Strip leading shell reserved words, `time`, and `case ... in pat)` prefixes."""
    toks = list(tokens)
    while toks:
        head = toks[0]
        if head in SHELL_RESERVED_PREFIXES:
            toks = toks[1:]
            continue
        if head == "time":
            toks = toks[1:]
            while toks and toks[0] in ("-p", "--"):
                toks = toks[1:]
            continue
        if head == "case":
            if "in" in toks[1:]:
                in_idx = toks.index("in", 1)
                rest = toks[in_idx + 1 :]
                found_arm = False
                for k, tok in enumerate(rest):
                    if ")" in tok:
                        after = tok.split(")", 1)[1]
                        toks = ([after] if after else []) + rest[k + 1 :]
                        found_arm = True
                        break
                if found_arm:
                    continue
            break
        if ")" in head and not head.startswith(("(", "$(")) and not head.endswith("()"):
            after = head.split(")", 1)[1]
            toks = ([after] if after else []) + toks[1:]
            continue
        if len(toks) >= 2 and toks[1] == ")":
            toks = toks[2:]
            continue
        break
    return toks


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


DB_SELECTOR_ENV_VARS = {"PGDATABASE", "DATABASE_URL", "PGSERVICE"}
SIMPLE_VAR_REF_RE = re.compile(r"^\$(?:([A-Za-z_][A-Za-z0-9_]*)|\{([A-Za-z_][A-Za-z0-9_]*)\})$")


def _record_env_assign(env_map, token, expansion_env):
    if "=" not in token:
        return
    key, val = token.split("=", 1)
    m = SIMPLE_VAR_REF_RE.match(val)
    if m:
        ref = m.group(1) or m.group(2)
        if ref in expansion_env:
            env_map[key] = set(expansion_env[ref])
            return
        # Unresolved reference: retain any prior known candidate values
        env_map[key] = set(env_map.get(key, ())) | {val}
        return
    if "$" in val or "`" in val:
        # Unresolved shell expansion: keep prior candidates so known targets are never erased
        env_map[key] = set(env_map.get(key, ())) | {val}
        return
    env_map[key] = {val}


def unwrap_tokens(tokens, cwd, inherited_wrappers=None, inherited_env=None):
    """Unwrap env assignments and exec wrappers. Returns (tokens, wrappers_seen, env_map, effective_cwd, err)."""
    wrappers = set(inherited_wrappers or ())
    expansion_env = {k: set(v) for k, v in (inherited_env or {}).items()}
    env_map = {k: set(v) for k, v in expansion_env.items()}
    eff_cwd = cwd
    idx = 0
    n = len(tokens)

    while idx < n:
        tok = tokens[idx]
        if ENV_ASSIGN_RE.match(tok):
            # Shell prefix assignments evaluate left-to-right against prior prefix assignments.
            _record_env_assign(env_map, tok, env_map)
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
                if t in ("-i", "--ignore-environment", "-"):
                    env_map.clear()
                    idx += 1
                    continue
                if t in ("-u", "--unset") and idx + 1 < n:
                    env_map.pop(tokens[idx + 1], None)
                    idx += 2
                    continue
                if t.startswith("-u") and len(t) > 2:
                    env_map.pop(t[2:], None)
                    idx += 1
                    continue
                if t.startswith("--unset="):
                    env_map.pop(t.split("=", 1)[1], None)
                    idx += 1
                    continue
                if t == "-C" and idx + 1 < n:
                    resolved = resolve_dir_arg(eff_cwd, tokens[idx + 1])
                    if not resolved:
                        return [], wrappers, env_map, eff_cwd, "Cannot determine execution directory for `env -C`."
                    eff_cwd = resolved
                    idx += 2
                    continue
                if t == "-S" and idx + 1 < n:
                    # Splice split string tokens back into token stream
                    spliced = tokenize(tokens[idx + 1])
                    tokens = tokens[:idx] + spliced + tokens[idx + 2 :]
                    n = len(tokens)
                    break
                if ENV_ASSIGN_RE.match(t):
                    _record_env_assign(env_map, t, expansion_env)
                    idx += 1
                    continue
                if t.startswith("-"):
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

        if base in ("sudo", "doas"):
            wrappers.add(base)
            idx += 1
            sudo_shell = False
            arg_flags = ("-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-T", "-U") if base == "sudo" else ("-u", "-C")
            while idx < n:
                t = tokens[idx]
                if t == "--":
                    idx += 1
                    break
                if t in arg_flags:
                    idx += 2
                    continue
                if base == "sudo" and (
                    t in ("-s", "-i", "--shell", "--login")
                    or (t.startswith("-") and not t.startswith("--") and ("s" in t[1:] or "i" in t[1:]))
                ):
                    sudo_shell = True
                    idx += 1
                    continue
                if ENV_ASSIGN_RE.match(t):
                    _record_env_assign(env_map, t, expansion_env)
                    idx += 1
                    continue
                if t.startswith("-"):
                    idx += 1
                    continue
                break
            if sudo_shell and idx >= n:
                return ["sh"], wrappers, env_map, eff_cwd, None
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
                        return [], wrappers, env_map, eff_cwd, "Cannot determine execution directory for `mise -C`."
                    mise_cwd = resolved
                    j += 2
                    continue
                if t.startswith("-C="):
                    resolved = resolve_dir_arg(mise_cwd, t[3:])
                    if not resolved:
                        return [], wrappers, env_map, eff_cwd, "Cannot determine execution directory for `mise -C`."
                    mise_cwd = resolved
                    j += 1
                    continue
                if t.startswith("--cd="):
                    resolved = resolve_dir_arg(mise_cwd, t[5:])
                    if not resolved:
                        return [], wrappers, env_map, eff_cwd, "Cannot determine execution directory for `mise --cd`."
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
                            return [], wrappers, env_map, eff_cwd, "Cannot determine execution directory for `mise exec -C`."
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

    return tokens[idx:], wrappers, env_map, eff_cwd, None


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


def extract_subpayloads(tokens, cwd, prev_op, wrappers, attached_heredocs=None, heredoc_map=None, stdin_heredocs=None):
    """Extract list of (payload_cmd, payload_cwd, inherited_wrappers, error_reason, child_stdin_heredocs)."""
    if not tokens:
        return []
    base = os.path.basename(tokens[0])
    results = []
    effective_stdin = list(attached_heredocs or []) or list(stdin_heredocs or [])

    if base in SHELL_BINARIES:
        i = 1
        found_c = False
        has_script_file = False
        reads_stdin_flag = False
        shell_arg_opts = ("-o", "+o", "-O", "+O", "--rcfile", "--init-file")
        while i < len(tokens):
            t = tokens[i]
            if t == "--":
                if not reads_stdin_flag and i + 1 < len(tokens):
                    has_script_file = True
                break
            if t in shell_arg_opts:
                i += 2
                continue
            if t == "-c" or (t.startswith("-") and not t.startswith("--") and "c" in t[1:]):
                found_c = True
                if i + 1 < len(tokens):
                    results.append((tokens[i + 1], cwd, wrappers, None, effective_stdin))
                break
            if t == "-s" or (t.startswith("-") and not t.startswith("--") and "s" in t[1:]):
                reads_stdin_flag = True
                i += 1
                continue
            if t.startswith("-") or t.startswith("+"):
                i += 1
                continue
            if not reads_stdin_flag:
                has_script_file = True
            break
        if not found_c and not has_script_file and effective_stdin and heredoc_map:
            for tok in effective_stdin:
                entry = heredoc_map.get(tok)
                body = entry["body"] if isinstance(entry, dict) else (entry or "")
                if body.strip():
                    results.append((body, cwd, wrappers, None, None))
        if not found_c and not has_script_file and not effective_stdin and prev_op == "|":
            # Piped input into sh/bash/zsh cannot be safely inspected in a guarded repo
            if load_policy(find_git_root(cwd), {}):
                results.append(
                    (None, None, None, f"Piping commands into `{base}` is blocked in guarded repositories.", None)
                )
        return results

    if base == "eval" and len(tokens) > 1:
        results.append((" ".join(tokens[1:]), cwd, wrappers, None, effective_stdin))
        return results

    if base in ("source", ".") and effective_stdin and heredoc_map:
        if any("/dev/stdin" in t or "/dev/fd/0" in t for t in tokens[1:]):
            for tok in effective_stdin:
                entry = heredoc_map.get(tok)
                body = entry["body"] if isinstance(entry, dict) else (entry or "")
                if body.strip():
                    results.append((body, cwd, wrappers, None, None))
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


def evaluate_policy(tokens, wrappers, raw_segment, policy, env_map=None):
    """Returns (decision, reason) or None."""
    if not policy or not tokens:
        return None

    unwrapped_str = " ".join(tokens)
    db_env_tokens = []
    for k, vals in (env_map or {}).items():
        if k in DB_SELECTOR_ENV_VARS:
            for v in vals:
                if v:
                    db_env_tokens.extend(v.split())
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
            if rule["cmd_re"].search(unwrapped_str) or any(rule["cmd_re"].search(tok) for tok in db_env_tokens):
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


def eval_command(
    cmd,
    start_cwds,
    policy_cache,
    depth=0,
    inherited_wrappers=None,
    heredoc_map=None,
    stdin_heredocs=None,
    inherited_env=None,
):
    """Evaluate `cmd` and return `(worst_decision_or_None, final_active_cwds)`."""
    if depth > 6:
        return ("deny", "Command nesting depth exceeded guardrail inspection limit."), set(start_cwds)

    if isinstance(start_cwds, str):
        active_cwds = {start_cwds}
    else:
        active_cwds = set(start_cwds)

    fallback_cwds = set()
    in_conditional = False
    list_start_cwds = set(active_cwds)
    worst = None

    norm = normalize_continuations(cmd)
    existing_heredocs = dict(heredoc_map or {})
    cleaned, local_heredocs, hd_err = strip_heredocs(norm, token_offset=len(existing_heredocs))
    if hd_err:
        return ("deny", hd_err), active_cwds

    merged_heredocs = existing_heredocs
    merged_heredocs.update(local_heredocs)

    for kind, content, prev_op, next_op in split_top_level(cleaned):
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
            list_start_cwds = set(active_cwds)

        runs_in_child_shell = prev_op == "|" or next_op in ("|", "&")

        if kind in ("subshell", "subst"):
            # Subshell / command substitution keeps its cwd strictly local
            if kind == "subst" and stdin_heredocs and re.search(r"\bcat\b", content):
                for tok in stdin_heredocs:
                    entry = merged_heredocs.get(tok)
                    body = entry["body"] if isinstance(entry, dict) else (entry or "")
                    if body.strip():
                        res, _sc = eval_command(
                            body, active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs, None, inherited_env
                        )
                        worst = merge_decisions(worst, res)
                        if worst and worst[0] == "deny":
                            return worst, active_cwds
            res, _sub_cwds = eval_command(
                content, active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs, stdin_heredocs, inherited_env
            )
            worst = merge_decisions(worst, res)
            if worst and worst[0] == "deny":
                return worst, active_cwds
            if next_op == "&":
                active_cwds = set(list_start_cwds)
                fallback_cwds = set()
                in_conditional = False
            continue

        if kind == "group":
            # Brace group runs in parent shell unless piped or backgrounded.
            res, group_cwds = eval_command(
                content, active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs, stdin_heredocs, inherited_env
            )
            worst = merge_decisions(worst, res)
            if not runs_in_child_shell:
                active_cwds = group_cwds
            if worst and worst[0] == "deny":
                return worst, active_cwds
            if next_op == "&":
                active_cwds = set(list_start_cwds)
                fallback_cwds = set()
                in_conditional = False
            continue

        tokens = tokenize(content)
        if not tokens:
            if next_op == "&":
                active_cwds = set(list_start_cwds)
                fallback_cwds = set()
                in_conditional = False
            continue

        attached_heredocs = [t for t in tokens if t in merged_heredocs]
        tokens = strip_shell_prefixes([t for t in tokens if t not in merged_heredocs])
        # Unquoted heredoc bodies still expand `$(...)` and backticks in Bash
        # even when attached to non-shell commands (e.g. `cat <<EOF`).
        if attached_heredocs:
            for tok in attached_heredocs:
                entry = merged_heredocs.get(tok)
                if isinstance(entry, dict) and not entry.get("quoted", True):
                    for subst_cmd in extract_unquoted_heredoc_substs(entry.get("body", "")):
                        res, _sc = eval_command(
                            subst_cmd, active_cwds, policy_cache, depth + 1, inherited_wrappers, merged_heredocs, None, inherited_env
                        )
                        worst = merge_decisions(worst, res)
                        if worst and worst[0] == "deny":
                            return worst, active_cwds
        if not tokens:
            if next_op == "&":
                active_cwds = set(list_start_cwds)
                fallback_cwds = set()
                in_conditional = False
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
            if not runs_in_child_shell:
                active_cwds = next_cwds
            if next_op == "&":
                active_cwds = set(list_start_cwds)
                fallback_cwds = set()
                in_conditional = False
            continue

        if first_base == "popd":
            return (
                "deny",
                "Cannot determine target directory for `popd`; use an explicit `cd <path>` so repository guardrails can be verified.",
            ), active_cwds

        for c in sorted(active_cwds):
            unwrapped, wrappers, env_assigns, seg_cwd, unwrap_err = unwrap_tokens(
                tokens, c, inherited_wrappers, inherited_env
            )
            if unwrap_err:
                return ("deny", unwrap_err), active_cwds
            if not unwrapped:
                continue

            subpayloads = extract_subpayloads(
                unwrapped, seg_cwd, prev_op, wrappers, attached_heredocs, merged_heredocs, stdin_heredocs
            )
            if subpayloads:
                for entry in subpayloads:
                    if len(entry) == 5:
                        p_cmd, p_cwd, p_wrappers, p_err, p_stdin = entry
                    else:
                        p_cmd, p_cwd, p_wrappers, p_err = entry
                        p_stdin = None
                    if p_err:
                        return ("deny", p_err), active_cwds
                    if p_cmd:
                        res, _p_cwds = eval_command(
                            p_cmd, p_cwd, policy_cache, depth + 1, p_wrappers, merged_heredocs, p_stdin, env_assigns
                        )
                        worst = merge_decisions(worst, res)
                        if worst and worst[0] == "deny":
                            return worst, active_cwds
                continue

            repo_root = find_git_root(seg_cwd)
            policy = load_policy(repo_root, policy_cache)
            worst = merge_decisions(worst, evaluate_policy(unwrapped, wrappers, content, policy, env_assigns))
            if worst and worst[0] == "deny":
                return worst, active_cwds

        if next_op == "&":
            active_cwds = set(list_start_cwds)
            fallback_cwds = set()
            in_conditional = False

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
