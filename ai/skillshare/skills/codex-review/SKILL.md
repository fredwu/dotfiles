---
name: codex-review
description: Perform exactly one read-only external review with the local Codex CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $codex-review or explicitly requested by name, including from another skill; never invoke implicitly.
---

# Codex Review

Perform exactly one external Codex invocation. Do not remediate, edit files, publish comments, retry, ask Codex a follow-up, or run a second review. The calling agent remains responsible for scope and assessment.

Read `../code-review/SKILL.md` and reuse its typed target, evidence threshold,
priorities, human-summary format, and canonical
`../code-review/references/review-result.schema.json`. Explicit invocation
authorizes sending Codex only the minimum non-secret material needed for this
review. Never send credentials, unrelated user data, the whole conversation,
prior reviews, or hidden conclusions.

## Prepare a compact packet

Freeze the target exactly as `code-review` requires. Create a private temporary run directory outside the repository. Write one request containing:

- original requirements and acceptance criteria;
- frozen root, type, selector and object identities;
- included worktree classes, explicit relevant-untracked paths, and exclusions;
- `phase: single` and any user-supplied focus;
- the shared default lens: unless the effective requirements explicitly call for them, flag target-attributable legacy preservation, backward compatibility, deprecation paths or shims, dual reads/writes, migration or transition machinery, superseded paths, and tactical short-term architecture;
- the shared finding fields and a requirement to return `clean` only after inspecting the complete surface.

Tell Codex to omit `assessment` and `assessment_rationale`; the calling agent
adds them after verification. Tell it to inspect the repository directly,
preserve scope, make no changes, avoid style nits and speculation, cite
repository-relative `path:line` evidence, and expose unfinished required work.
Tell it that existing behavior alone does not establish a compatibility
requirement and to recommend removing superseded or transitional machinery and
implementing the proportional durable target state rather than layering another
workaround.
Do not paste diffs or logs that Codex can read itself.

Snapshot relevant status and diffs before invocation. Run Codex ephemerally in
its read-only sandbox, with a bounded tool timeout and no bypass or
approval-evasion flags. Pass the canonical schema to `--output-schema` and
capture the last message in an output file. A representative shape is:

```text
codex exec --ephemeral --sandbox read-only -C <root> --skip-git-repo-check \
  --output-schema <schema-file> -o <output-file> review - < <request-file>
```

Global `exec` flags must precede the `review` subcommand. Confirm syntax against
the installed CLI help. Keep untrusted request text in files or stdin, not
interpolated shell syntax. Success requires one non-empty, complete result that
validates against the canonical schema; an exit code alone is insufficient.

Snapshot the tree again afterward. If Codex mutated it, report the invocation failed and isolate only Codex's exact delta; reverse it only when safe and never blanket-restore a dirty tree. On timeout, malformed output, missing CLI/login, or incomplete inspection, do not retry or invent findings—return `verdict: incomplete` with the failure as residual risk.

## Assess and return

Independently check each supplied finding against the frozen surface and label
it `accept`, `partial`, or `decline`, with one evidence-based sentence. This
assessment is not another review round. Normalize valid reviewer content into
the shared `REVIEW_RESULT` fields without hiding or embellishing it, and add
`assessment` plus `assessment_rationale` to each finding. Note material
omissions only when directly established during assessment.

Then provide the concise shared human summary: accepted/partial findings first, declined count, inspected surface, and one-line residual risk. Do not dump tool logs or the raw transcript unless requested.

Delete only the validated current temporary run directory. If cleanup cannot be verified, preserve it and report the exact path. Make no code remediation before or after returning.
