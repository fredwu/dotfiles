# External review runtime

Use this policy for Codex, Claude, and Grok reviews and loops. [code-review](../SKILL.md) defines the review standard; [code-review-loop](../../code-review-loop/SKILL.md) owns assessment, remediation, rounds, and completion.

## Select the runtime

Inside T3 Code, use [T3 delegation](t3-runtime.md). If tools are unavailable, try the supported T3 bridge before reporting the constraint. Do not bypass T3 with direct ACP.

Outside T3, use [direct ACP](acp-runtime.md) when supported. Preserve the requested provider and explicit model/options. Do not silently substitute providers or transports, change ambient configuration, or transfer credentials.

## Hand off the requirement

Send a short brief: intended behavior and acceptance criteria, repository/target, read-only scope, material exclusions, and a reference to the shared review instructions. The reviewer reads Git and source directly. Do not send diffs, source dumps, snapshots, coverage manifests, or full transcripts. Use the actual checkout, including relevant dirty and untracked files; a clean worktree that omits the changes is not a substitute.

For T3 loop rounds, add concise prior findings, caller responses, and unresolved objections. Present these as claims to verify independently, without an expected verdict. Each round uses a fresh task/session.

## Run and assess

Keep source stable during read-only review. Choose a scope-based time budget, retain task handles, and wait on the same active work. A tool timeout or silence alone does not prove failure. Join owned work before edits or replacement calls.

Assess content directly under the shared skills. Prose, Markdown, and structured output are valid; missing bookkeeping does not require a retry or model call. Retain useful partial findings and disclose substantive inspection gaps. Transport completion does not establish a clean review.

A single review returns without repairs or another review invocation. Loops use the [recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts) for genuine failures. Remove only task-owned scratch after assessment, including on failure; preserve provider state, deliverables, and unrelated files. Save reports or transcripts only when requested.
