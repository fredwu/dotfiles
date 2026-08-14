---
name: grok-review
description: Perform exactly one read-only external review with the local Grok CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $grok-review or explicitly requested by name, including from another skill; never invoke implicitly. Use grok-review-loop for iterative remediation.
---

# Grok Review

Perform exactly one external Grok invocation. Do not edit, remediate, publish, retry, follow up, or run a second review. The caller owns scope and assessment.

Read `../code-review/SKILL.md`; reuse its typed target, evidence threshold, priorities, summary format, strict external schema at `../code-review/references/external-review-result.schema.json`, and final schema at `../code-review/references/review-result.schema.json`. Send only the minimum non-secret review material authorized by explicit invocation—never credentials, unrelated user data, the whole conversation, prior reviews, or hidden conclusions.

## Prepare one direct review

Freeze the target per `code-review`. Create one private temporary run directory outside the repository for request, stdout, and stderr. Include:

- original requirements and acceptance criteria;
- frozen root, type, selector and object identities;
- included worktree classes, explicit relevant-untracked paths, and exclusions;
- `phase: single` and any user-supplied focus;
- the shared default lens: unless the effective requirements explicitly call for them, flag target-attributable legacy preservation, backward compatibility, deprecation paths or shims, dual reads/writes, migration or transition machinery, superseded paths, and tactical short-term architecture;
- the shared finding fields and a requirement to return `clean` only after inspecting the complete surface.

Require direct frozen-repository inspection, preserved scope, no file changes, repository-relative `path:line` evidence, no style nits or speculation, and disclosure of unfinished required work. Tell Grok to omit `assessment` and `assessment_rationale`; the caller adds them after verification. State that existing behavior alone is not a compatibility requirement and prefer removal of superseded or transitional machinery and a proportional durable target state over another workaround. Do not paste diffs or logs Grok can read itself.

Snapshot relevant status and diffs immediately before invocation. Set `--cwd` to the frozen root; use `dontAsk`, read-only sandbox, bounded turns and execution timeout, no memory/subagents/MCP/web/update check, and only `read_file`, `grep`, `list_dir`, and `run_terminal_cmd`. Limit the shell tool to documented auto-approved read-only target inspection, including Git status, diff, history, search, and view commands. `dontAsk` must deny approval-requiring commands. Add no broad Bash allow rules, mutating commands, `--always-approve`, or bypass flags. Set an outer deadline of at least 30 minutes; this is not a Grok CLI flag. Poll the same yielded session/process handle until exit or the real deadline; yield, silence, or an empty poll is not a timeout. Never cancel a healthy process or replace it.

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

Confirm current flags and envelope names with installed CLI help/docs. Keep untrusted text in the prompt file, not interpolated shell syntax. Success requires a successful exit, exactly one stdout JSON object, the documented normal end-of-turn marker (`stopReason: end_turn` currently), and object-valued `structuredOutput` under the strict external schema. Inspect stderr and only directly check top-level fields and verdict/findings coherence. Exit code or freeform `text` alone is insufficient.

Snapshot again afterward. If Grok changed the tree, fail the invocation, isolate only its exact delta, reverse it only when safe, and never blanket-restore a dirty tree. On timeout, malformed output, missing CLI/login, sandbox failure, or incomplete inspection, return `verdict: incomplete` with the failure as residual risk; never retry or invent findings.

## Assess and return

Independently verify each finding against the frozen surface and label it `accept`, `partial`, or `decline` with one evidence-based sentence. Normalize valid content without hiding or embellishing it, add `assessment` and `assessment_rationale`, conform to canonical `REVIEW_RESULT`, and note only directly established omissions. This is not another review round.

Provide the shared concise summary: accepted/partial findings first, declined count, inspected surface, and one-line residual risk. Omit logs and raw transcript unless requested.

Delete only the validated current run directory; if cleanup cannot be verified, preserve and report its exact path. Make no remediation before or after returning.
