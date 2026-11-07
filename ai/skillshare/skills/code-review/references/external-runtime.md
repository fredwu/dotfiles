# External review runtime

Use this policy for every delegated review, including Codex, Claude, and Grok reviews and loops. [code-review](../SKILL.md) sets the review standard. [code-review-loop](../../code-review-loop/SKILL.md) owns assessment, repairs, rounds, and completion. These skills are instructions only: use existing tools, and do not build clients, wrappers, parsers, or validators.

## Select the runtime

Prefer [T3's orchestrator](t3-runtime.md) whenever it is available, in any host harness. Missing tools alone do not prove that it is unavailable; check as that reference describes.

If T3 orchestration is absent, unsupported, or confirmed unavailable, use the harness's [ACP client](acp-runtime.md) and state the reason. Keep the same provider, model, options, repository, and scope, and confirm that earlier work stopped before you launch a replacement. If ACP cannot keep these, report the limit. Do not substitute a provider.

Model-capacity, rate-limit, and provider API errors do not make T3 unavailable. Retry them in the same round under the [recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts). Do not change ambient configuration or transfer credentials.

For every launch, apply [Reviewer model and effort](reviewer-settings.md).

## Hand off

Send a short brief: the intended behavior and acceptance criteria, the repository and target, read-only scope, material exclusions, and a reference to the code-review instructions. Describe the target, for example "the current uncommitted changes, including relevant untracked files, in /path/to/repo". The reviewer finds the diff and reads source directly. Do not send diffs, source dumps, snapshots, manifests, or transcripts. Review the actual checkout with its dirty and untracked files; a clean worktree without the changes is not a substitute.

For loop rounds, add concise prior findings, caller responses, and open objections as claims to verify independently, without an expected verdict. Use a fresh task or session for each round.

## Run and assess

Keep the source unchanged during the review. Choose a time budget from scope and complexity, keep task handles, and wait on the same work. A tool timeout or silence alone does not prove failure; do not start duplicate work. Stop and join owned work before edits or a replacement launch.

Assess the content under the shared skills. Prose, Markdown, and structured output are all valid; missing bookkeeping does not need a retry or another model call. Keep useful partial findings and state material coverage gaps. Transport completion does not prove a clean review.

A single review returns without repairs or another review. Loops retry genuine failures under the recovery policy. After assessment, also after a failure, remove only task-owned scratch; keep provider state, deliverables, and unrelated files. Save reports or transcripts only on request.
