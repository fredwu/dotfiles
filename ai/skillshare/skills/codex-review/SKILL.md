---
name: codex-review
description: Perform exactly one read-only external review with the local Codex CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $codex-review or explicitly requested by name, including from another skill; never invoke implicitly. Use codex-review-loop for iterative remediation.
---

# Codex Review

Perform exactly one external Codex invocation. Do not remediate, edit files, publish comments, retry, ask Codex a follow-up, or run a second review. The calling agent remains responsible for scope and assessment.

Read `../code-review/SKILL.md` and reuse its typed target, evidence threshold, priorities, human-summary format, strict external schema at `../code-review/references/external-review-result.schema.json`, and final canonical schema at `../code-review/references/review-result.schema.json`. Explicit invocation authorizes sending Codex only the minimum non-secret material needed for this review. Never send credentials, unrelated user data, the whole conversation, prior reviews, or hidden conclusions.

## Prepare one direct review

Freeze the target exactly as `code-review` requires. Create a private temporary run directory outside the repository. Begin the request with this exact output contract, using the external schema's fields:

```text
Your entire final message must be a single JSON object and nothing else. No markdown, prose, or fences.

Required JSON shape example:
{
  "verdict": "findings",
  "inspected_surface": "Complete frozen review surface",
  "findings": [
    {
      "id": "F1",
      "priority": "P2",
      "confidence": 90,
      "title": "Use an imperative, specific title",
      "location": "relative/path.ex:42",
      "evidence": "Reachable scenario and supporting repository evidence",
      "impact": "Demonstrated consequence",
      "remediation": "Smallest defensible correction"
    }
  ],
  "residual_risk": "none"
}
```

- Use only `findings`, `clean`, or `incomplete` for `verdict`, and only `P0`, `P1`, `P2`, or `P3` for `priority`.
- Report only findings with integer confidence from 80 through 100.
- For `clean`, use an empty `findings` array only after complete inspection.
- For `incomplete`, use an empty `findings` array and state the inspection failure in `residual_risk`; never claim clean.

Then include:

- original requirements and acceptance criteria;
- frozen root, type, selector and object identities;
- included worktree classes, explicit relevant-untracked paths, and exclusions;
- `phase: single` and any user-supplied focus;
- the shared default lens: unless the effective requirements explicitly call for them, flag target-attributable legacy preservation, backward compatibility, deprecation paths or shims, dual reads/writes, migration or transition machinery, superseded paths, and tactical short-term architecture;
- the shared finding fields and a requirement to return `clean` only after inspecting the complete surface.

Tell Codex to omit `assessment` and `assessment_rationale`; the calling agent adds them after verification. Tell it to inspect the repository directly, preserve scope, make no changes, avoid style nits and speculation, cite repository-relative `path:line` evidence, and expose unfinished required work. Tell it that existing behavior alone does not establish a compatibility requirement and to recommend removing superseded or transitional machinery and implementing the proportional durable target state rather than layering another workaround. Do not paste diffs or logs that Codex can read itself. End the request with: `Return exactly one JSON object matching the required shape. Output nothing else.`

Before consuming the sole invocation, verify from the outer runtime's documented permissions that the Codex CLI can read its existing authentication and write its normal state under the existing Codex home (`CODEX_HOME` when configured, otherwise the CLI default). If the host sandbox blocks that access, obtain or request the narrow authority needed for the one exact `codex exec` process before starting it. This outer process authority is distinct from the reviewer sandbox and must not weaken the inner `--sandbox read-only`. If the required authority is unavailable, return `verdict: incomplete` without invoking Codex.

Do not launch Codex as an access probe and then retry it. Do not relocate or repoint `CODEX_HOME`, copy or symlink credentials, use broad bypass flags, or weaken the reviewer sandbox to work around host restrictions.

Snapshot relevant status and diffs before invocation. Run Codex ephemerally in its read-only sandbox with user configuration ignored and no bypass or approval-evasion flags. Pass the strict external schema to `--output-schema` and capture the last message in an output file.

Use prompt-bearing `review -` for every typed target. Put the exact frozen type, selector, full object identities, included worktree classes, and exclusions in the request so Codex inspects that surface directly in the repository. Do not combine `--uncommitted`, `--base`, or `--commit` with the required custom prompt: Codex's selection modes and prompt mode are mutually exclusive.

A representative shape is:

```text
codex exec --ignore-user-config --ephemeral --sandbox read-only -C <root> \
  --skip-git-repo-check --output-schema <external-schema-file> \
  -o <output-file> review - < <request-file>
```

Global `exec` flags must precede the `review` subcommand. Confirm syntax against the installed CLI help. Keep untrusted request text in files or stdin, not interpolated shell syntax. Do not add a wrapper or a Python, jq, or other validator. Prefer one non-empty, complete JSON result conforming to the strict external schema. Directly inspect its top-level fields and verdict/findings coherence. An exit code alone is insufficient.

Give the outer execution call a timeout/deadline of at least 30 minutes. If the tool yields a running session or process handle, poll that same handle until the process exits or the real deadline expires. A yield, silence, or an empty poll is not a timeout. Never cancel a healthy yielded process or start a replacement; this skill permits exactly one Codex invocation.

Snapshot the tree again afterward. If Codex mutated it, report the invocation failed and isolate only Codex's exact delta; reverse it only when safe and never blanket-restore a dirty tree. On timeout, empty output, missing CLI/login, or incomplete inspection, do not retry or invent findings—return `verdict: incomplete` with the failure as residual risk.

If a successful invocation returns schema-invalid prose, inspect that same last message once; never invoke Codex again. Recover content only when the message is non-empty and complete, the tree is unchanged, and no timeout, CLI, login, or inspection failure occurred:

- Recover `clean` only when the prose explicitly says the complete frozen surface was inspected and no finding met the 80% confidence threshold.
- Recover a finding only when it supplies a priority, an in-scope `path:line`, concrete defect evidence, impact, and remediation direction. Independently verify it against the frozen surface and retain it only at confidence 80 or above.
- Preserve the reviewer's meaning. Assign stable IDs in source order, convert an absolute location to repository-relative only when it is under the frozen root, and use the independently verified confidence rather than inventing the reviewer's omitted score.
- State `schema-invalid prose recovered` and any coverage limitation in `residual_risk`. If findings are usable but complete inspection is not explicit, use the findings but do not let the result establish clean or an early stop.

Treat vague praise, truncated text, out-of-scope evidence, or prose missing a required finding element as unusable. If neither strict JSON nor usable prose remains, return `verdict: incomplete`. This recovery consumes the original invocation; it is not a retry or another review round.

## Assess and return

Independently check each supplied finding against the frozen surface and label it `accept`, `partial`, or `decline`, with one evidence-based sentence. This assessment is not another review round. Normalize valid reviewer content into the final canonical `REVIEW_RESULT` fields without hiding or embellishing it, and add `assessment` plus `assessment_rationale` to each finding. Ensure the normalized object conforms to the final canonical schema. Note material omissions only when directly established during assessment.

Then provide the concise shared human summary: accepted/partial findings first, declined count, inspected surface, and one-line residual risk. Do not dump tool logs or the raw transcript unless requested.

Delete only the validated current temporary run directory. If cleanup cannot be verified, preserve it and report the exact path. Make no code remediation before or after returning.
