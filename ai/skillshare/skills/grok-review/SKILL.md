---
name: grok-review
description: Perform exactly one read-only external review with the local Grok CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $grok-review or explicitly requested by name, including from another skill; never invoke implicitly. Use grok-review-loop for iterative remediation.
---

# Grok Review

Perform exactly one external Grok invocation. Do not remediate, edit files, publish comments, retry, ask Grok a follow-up, or run a second review. The calling agent remains responsible for scope and assessment.

Read `../code-review/SKILL.md` and reuse its typed target, evidence threshold, priorities, human-summary format, strict external schema at `../code-review/references/external-review-result.schema.json`, and final canonical schema at `../code-review/references/review-result.schema.json`. Explicit invocation authorizes sending Grok only the minimum non-secret material needed for this review. Never send credentials, unrelated user data, the whole conversation, prior reviews, or hidden conclusions.

## Prepare one direct review

Freeze the target exactly as `code-review` requires. Create one private temporary run directory outside the repository for the request, stdout, and stderr. Write one request containing:

- original requirements and acceptance criteria;
- frozen root, type, selector and object identities;
- included worktree classes, explicit relevant-untracked paths, and exclusions;
- `phase: single` and any user-supplied focus;
- the shared default lens: unless the effective requirements explicitly call for them, flag target-attributable legacy preservation, backward compatibility, deprecation paths or shims, dual reads/writes, migration or transition machinery, superseded paths, and tactical short-term architecture;
- the shared finding fields and a requirement to return `clean` only after inspecting the complete surface.

Tell Grok to omit `assessment` and `assessment_rationale`; the calling agent adds them after verification. Tell it to inspect the frozen repository directly, preserve scope, make no changes, avoid style nits and speculation, cite repository-relative `path:line` evidence, and expose unfinished required work. Tell it that existing behavior alone does not establish a compatibility requirement and to recommend removing superseded or transitional machinery and implementing the proportional durable target state rather than layering another workaround. Do not paste diffs or logs that Grok can read itself.

Snapshot relevant status and diffs immediately before invocation. Run Grok with `--cwd` set to the frozen repository root, `dontAsk` permissions, the read-only sandbox, bounded turns and execution timeout, and no memory, subagents, MCP, web access, or update check. Allow only `read_file`, `grep`, `list_dir`, and `run_terminal_cmd`. Use the shell tool only for the installed CLI's documented auto-approved read-only inspection commands relevant to the frozen target, including read-only Git status, diff, history, search, and view commands. In `dontAsk` mode, commands that require approval are denied rather than prompting. Do not add broad Bash allow rules or run mutating commands. Never use `--always-approve` or another bypass flag. Give the outer execution call a timeout/deadline of at least 30 minutes; this is a caller setting, not an additional Grok CLI flag. If the call yields a running session or process handle, poll that same handle until the process exits or the real deadline expires. A yield, silence, or empty poll is not a timeout. Never cancel a healthy yielded process or start a replacement; this skill permits exactly one Grok invocation.

Pass the strict external schema's JSON content directly as one `--json-schema` argument; do not pass a schema path or build a Python, jq, or other validator. Capture stdout as the complete JSON envelope and stderr separately. A representative shape is:

```text
grok --cwd <frozen-root> --prompt-file <run-directory>/request.md --verbatim \
  --permission-mode dontAsk \
  --tools "read_file,grep,list_dir,run_terminal_cmd" \
  --disallowed-tools Agent --deny MCPTool --sandbox read-only \
  --max-turns 30 --no-memory --no-auto-update --disable-web-search \
  --output-format json --json-schema <schema-content> \
  > <run-directory>/stdout.json 2> <run-directory>/stderr.log
```

Use the installed CLI's help and documentation to confirm current flag and envelope names. Keep untrusted request text in the prompt file, not interpolated shell syntax. Success requires a successful exit, exactly one JSON object on stdout, the installed CLI's documented normal end-of-turn marker (`stopReason: end_turn` is the current example), and an object-valued `structuredOutput` produced under the strict external schema. Inspect stderr and perform only direct top-level-field and verdict/findings coherence checks; the CLI's schema-constrained result is the review payload. An exit code or freeform `text` alone is insufficient.

Snapshot the tree again afterward. If Grok mutated it, report the invocation failed and isolate only Grok's exact delta; reverse it only when safe and never blanket-restore a dirty tree. On timeout, malformed output, missing CLI/login, sandbox failure, or incomplete inspection, do not retry or invent findings—return `verdict: incomplete` with the failure as residual risk.

## Assess and return

Independently check each supplied finding against the frozen surface and label it `accept`, `partial`, or `decline`, with one evidence-based sentence. This assessment is not another review round. Normalize valid reviewer content into the final canonical `REVIEW_RESULT` fields without hiding or embellishing it, and add `assessment` plus `assessment_rationale` to each finding. Ensure the normalized object conforms to the final canonical schema. Note material omissions only when directly established during assessment.

Then provide the concise shared human summary: accepted/partial findings first, declined count, inspected surface, and one-line residual risk. Do not dump tool logs or the raw transcript unless requested.

Delete only the validated current temporary run directory. If cleanup cannot be verified, preserve it and report the exact path. Make no code remediation before or after returning.
