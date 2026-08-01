---
name: grok-review
description: Perform exactly one read-only external review with the local Grok CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $grok-review or explicitly requested by name, including from another skill; never invoke implicitly. Use grok-review-loop for iterative remediation.
---

# Grok Review

Perform exactly one external Grok invocation. Do not remediate, edit files, publish comments, retry, ask Grok a follow-up, or run a second review. The calling agent remains responsible for scope and assessment.

Read `../code-review/SKILL.md` and reuse its typed target, evidence threshold,
priorities, human-summary format, and canonical
`../code-review/references/review-result.schema.json`. Explicit invocation
authorizes sending Grok only the minimum non-secret material needed for this
review. Never send credentials, unrelated user data, the whole conversation,
prior reviews, or hidden conclusions.

## Prepare a compact packet

Freeze the target exactly as `code-review` requires. Create a private temporary run directory outside the repository. Write one request containing:

- original requirements and acceptance criteria;
- frozen root, type, selector and object identities;
- included worktree classes, explicit relevant-untracked paths, and exclusions;
- `phase: single` and any user-supplied focus;
- the shared finding fields and a requirement to return `clean` only after inspecting the complete surface.

Tell Grok to omit `assessment` and `assessment_rationale`; the calling agent
adds them after verification. Tell it to inspect the repository directly,
preserve scope, make no changes, avoid style nits and speculation, cite
repository-relative `path:line` evidence, and expose unfinished required work.
Do not paste diffs or logs that Grok can read itself.

Snapshot relevant status and diffs before invocation. Run Grok with plan
permissions, bounded turns and timeout, no memory, and web search disabled
unless the frozen target explicitly requires external verification. Never use
`--always-approve` or another bypass flag. Pass the canonical schema content to
`--json-schema` and capture the complete JSON envelope. A representative shape
is:

```text
grok --cwd <root> --prompt-file <request-file> --verbatim \
  --permission-mode plan --max-turns 8 --no-memory --disable-web-search \
  --json-schema <schema>
```

Use the installed CLI's help to place supported flags correctly. Keep untrusted
request text in the prompt file, not interpolated shell syntax. Require the
outer result's `stopReason` to be `EndTurn`, require non-empty `text`, and parse
that text against the canonical schema. An exit code alone is insufficient.

Snapshot the tree again afterward. If Grok mutated it, report the invocation failed and isolate only Grok's exact delta; reverse it only when safe and never blanket-restore a dirty tree. On timeout, malformed output, missing CLI/login, or incomplete inspection, do not retry or invent findings—return `verdict: incomplete` with the failure as residual risk.

## Assess and return

Independently check each supplied finding against the frozen surface and label
it `accept`, `partial`, or `decline`, with one evidence-based sentence. This
assessment is not another review round. Normalize valid reviewer content into
the shared `REVIEW_RESULT` fields without hiding or embellishing it, and add
`assessment` plus `assessment_rationale` to each finding. Note material
omissions only when directly established during assessment.

Then provide the concise shared human summary: accepted/partial findings first, declined count, inspected surface, and one-line residual risk. Do not dump tool logs or the raw transcript unless requested.

Delete only the validated current temporary run directory. If cleanup cannot be verified, preserve it and report the exact path. Make no code remediation before or after returning.
