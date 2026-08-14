---
name: codex-review
description: Perform exactly one read-only external review with the local Codex CLI, then return its evidence-backed findings in the shared agent contract plus a concise human assessment. Use only when explicitly invoked as $codex-review or explicitly requested by name, including from another skill; never invoke implicitly. Use codex-review-loop for iterative remediation.
---

# Codex Review

Perform exactly one external Codex invocation. Do not edit, remediate, publish, retry, follow up, or run a second review. The caller owns scope and assessment.

Read `../code-review/SKILL.md`; reuse its typed target, evidence threshold, priorities, summary format, strict external schema at `../code-review/references/external-review-result.schema.json`, and final schema at `../code-review/references/review-result.schema.json`. Send only the minimum non-secret review material authorized by explicit invocation—never credentials, unrelated user data, the whole conversation, prior reviews, or hidden conclusions.

## Prepare one direct review

Freeze the target per `code-review` and create a private temporary run directory outside the repository. Begin the request with this exact output contract:

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

Require direct repository inspection, preserved scope, no file changes, repository-relative `path:line` evidence, no style nits or speculation, and disclosure of unfinished required work. Tell Codex to omit `assessment` and `assessment_rationale`; the caller adds them after verification. State that existing behavior alone is not a compatibility requirement and prefer removal of superseded or transitional machinery and a proportional durable target state over another workaround. Do not paste diffs or logs Codex can read itself. End with: `Return exactly one JSON object matching the required shape. Output nothing else.`

Before the sole invocation, verify from documented outer-runtime permissions that Codex can read its existing authentication and write normal state under the existing Codex home (`CODEX_HOME` when configured, otherwise the CLI default). If blocked, obtain narrow authority for the exact `codex exec` process before starting it; keep the inner `--sandbox read-only`. If unavailable, return `verdict: incomplete` without invoking.

Never use Codex as an access probe, relocate/repoint `CODEX_HOME`, copy/symlink credentials, use bypass flags, or weaken the reviewer sandbox.

Snapshot relevant status and diffs. Run Codex ephemerally, read-only, with user configuration ignored and no bypass/approval-evasion flags. Pass the strict external schema to `--output-schema`; capture the last message in an output file.

Use prompt-bearing `review -` for every typed target. Put the exact frozen type, selector, full object identities, included worktree classes, and exclusions in the request. Never combine the custom prompt with mutually exclusive `--uncommitted`, `--base`, or `--commit` selection modes.

A representative shape is:

```text
codex exec --ignore-user-config --ephemeral --sandbox read-only -C <root> \
  --skip-git-repo-check --output-schema <external-schema-file> \
  -o <output-file> review - < <request-file>
```

Keep global `exec` flags before `review`; confirm syntax with installed CLI help. Keep untrusted text in files/stdin, not interpolated shell syntax. Add no wrapper or Python, jq, or other validator. Require one non-empty, complete schema-conforming JSON result; directly check top-level fields and verdict/findings coherence. An exit code alone is insufficient.

Set an outer deadline of at least 30 minutes. Poll the same yielded session/process handle until exit or the real deadline; yield, silence, or an empty poll is not a timeout. Never cancel a healthy process or replace it.

Snapshot again afterward. If Codex changed the tree, fail the invocation, isolate only its exact delta, reverse it only when safe, and never blanket-restore a dirty tree. On timeout, empty output, missing CLI/login, or incomplete inspection, return `verdict: incomplete` with the failure as residual risk; never retry or invent findings.

If a successful invocation returns schema-invalid prose, inspect that last message once without another invocation. Recover only when it is non-empty and complete, the tree is unchanged, and no timeout, CLI, login, or inspection failure occurred:

- Recover `clean` only when the prose explicitly says the complete frozen surface was inspected and no finding met the 80% confidence threshold.
- Recover a finding only with priority, in-scope `path:line`, concrete evidence, impact, and remediation; independently verify it and retain it only at confidence 80 or above.
- Preserve meaning; assign stable source-order IDs, relativize absolute locations only under the frozen root, and use independently verified confidence rather than inventing an omitted score.
- Put `schema-invalid prose recovered` and any coverage limit in `residual_risk`. Findings without explicit complete inspection cannot establish clean or an early stop.

Reject vague praise, truncation, out-of-scope evidence, or incomplete findings. If neither strict JSON nor usable prose remains, return `verdict: incomplete`. Recovery consumes the original invocation; it is not a retry or round.

## Assess and return

Independently verify each finding against the frozen surface and label it `accept`, `partial`, or `decline` with one evidence-based sentence. Normalize valid content without hiding or embellishing it, add `assessment` and `assessment_rationale`, conform to canonical `REVIEW_RESULT`, and note only directly established omissions. This is not another review round.

Provide the shared concise summary: accepted/partial findings first, declined count, inspected surface, and one-line residual risk. Omit logs and raw transcript unless requested.

Delete only the validated current run directory; if cleanup cannot be verified, preserve and report its exact path. Make no remediation before or after returning.
