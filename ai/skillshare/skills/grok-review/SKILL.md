---
name: grok-review
description: Run one read-only external Grok CLI review and assess its findings. Use only when explicitly invoked or requested by name, including from another skill. Use grok-review-loop for iterative remediation.
---

# Grok Review

Run exactly one model-bearing top-level Grok call. Metadata and authentication preflight do not count. Do not edit, remediate, publish, retry, follow up, or invoke another review. The caller owns scope and assessment.

Read [code-review](../code-review/SKILL.md) for the frozen target, lenses, confidence threshold, priorities, and output contract. Read [runtime.md](references/runtime.md) before preparing the isolated runtime or calling Grok. Explicit invocation authorizes only the minimum non-secret transfer; exclude credentials, unrelated data, the conversation, prior reviews, and hidden conclusions.

## Prepare the request

Create a private non-secret run directory outside the target. Include requirements, frozen descriptor and exclusions, `phase: single`, user focus, and `code-review`'s lenses, evidence threshold, priority semantics, and finding fields. Require complete-surface tool inspection before terminal output, preserved files and scope, repository-relative `path:line` evidence, and disclosure of unfinished work. Omit caller-only assessment fields.

Map applicable repository `worker` and `fastworker` roles to Grok's built-in `general-purpose` task. Workers inherit scope and finish before synthesis; do not otherwise restrict delegation. Forbid nested review skills and additional top-level Grok processes.

Require terminal `StructuredOutput` exactly once, conforming to [the external schema](../code-review/references/external-review-result.schema.json). Emit it only after complete inspection or an attempted inspection that proved impossible; never as progress. `clean` requires complete inspection.

## Assess and return

Apply the runtime's preflight, isolation, deadline, completion, mutation, and cleanup checks. Independently verify valid findings and normalize to [the canonical schema](../code-review/references/review-result.schema.json) with `assessment: accept | partial | decline` and `assessment_rationale`. This assessment is not another review round.

Return `REVIEW_RESULT` JSON first, then accepted and partial findings, declined count, inspected surface, and one-line residual risk. Omit raw logs unless requested. Never commit, push, publish comments, or make remote writes without separate authorization.
