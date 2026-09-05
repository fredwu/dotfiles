---
name: codex-review
description: Run one read-only external Codex CLI review and assess its findings. Use only when explicitly invoked or requested by name, including from another skill. Use codex-review-loop for iterative remediation.
---

# Codex Review

Run exactly one model-bearing top-level Codex call. Metadata preflight does not count. Do not edit, remediate, publish, retry, follow up, or invoke another review. The caller owns scope and assessment.

Read [code-review](../code-review/SKILL.md) for the frozen target, lenses, confidence threshold, priorities, and output contract. Read [runtime.md](references/runtime.md) before preparing the isolated runtime or calling Codex. Explicit invocation authorizes only the minimum non-secret transfer; exclude credentials, unrelated data, the conversation, prior reviews, and hidden conclusions.

## Prepare the request

Create a private run directory outside the repository and an empty `0700` working directory. Serialize the complete authorized snapshot into the stdin request: requirements, frozen descriptor and exclusions, current and base content, status/diff metadata, applicable instructions, and a manifest with relative path, role, size, and hash per content block. Exclude `.git`, `.codex`, credentials, symlink targets, unrelated files, host session metadata, and absolute host paths. If the complete snapshot cannot fit safely in one request, return incomplete without a model call.

Include `code-review`'s lenses, evidence threshold, priority semantics, and finding fields in the request. Require inspection of every content block, preserved scope, repository-relative `path:line` evidence, and disclosure of unfinished work. Follow applicable agent routing: workers receive relevant snapshot content, inherit the no-filesystem/no-network boundary, and finish before synthesis. Forbid nested review skills and additional top-level Codex processes.

Require one terminal JSON object conforming to [the external schema](../code-review/references/external-review-result.schema.json), without prose, fences, or caller-only assessment fields. Emit it only after complete inspection or demonstrated inability to inspect; never as progress. `clean` requires complete inspection.

## Assess and return

Apply the runtime's preflight, isolation, deadline, completion, mutation, and cleanup checks. Independently verify valid findings and normalize to [the canonical schema](../code-review/references/review-result.schema.json) with `assessment: accept | partial | decline` and `assessment_rationale`. This assessment is not another review round.

Return `REVIEW_RESULT` JSON first, then accepted and partial findings, declined count, inspected surface, and one-line residual risk. Omit raw logs unless requested. Delete only the validated run directory; otherwise preserve and report its exact path. Never commit, push, publish comments, or make remote writes without separate authorization.
