# External review runtime

Use this policy for delegated reviews, including Codex, Claude, and Grok reviews and loops. [code-review](../SKILL.md) defines the review standard; [code-review-loop](../../code-review-loop/SKILL.md) owns assessment, remediation, rounds, and completion.

For every launch, apply [Reviewer model and effort](reviewer-settings.md). The coordinator chooses Codex/Claude effort from medium or high by complexity; Grok always uses xhigh. Apply and verify actual runtime settings rather than relying on role labels or provider defaults.

## Select the runtime

Prefer [T3's orchestrator](t3-runtime.md) whenever available. Missing tools alone do not prove it is unavailable: try the known capabilities tool and any supported host bridge as described in that reference.

When T3 orchestration is absent, unsupported, or confirmed unavailable after those checks, fall back to the harness's existing [ACP client](acp-runtime.md). State the fallback and its reason. Keep the same provider, model/options, repository, and review scope; confirm prior work stopped before launching a replacement. If ACP cannot preserve those requirements, report the limit instead of substituting a provider or building a runtime.

Model-capacity, rate-limit, or provider API failures do not by themselves make T3 unavailable. Retry them within the same round under the [recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts). Do not change ambient configuration or transfer credentials.

## Hand off the requirement

Send a short brief: intended behavior and acceptance criteria, repository/target, read-only scope, material exclusions, and a reference to the shared review instructions. Describe the target, for example “the current uncommitted changes in /path/to/repo”; the reviewer discovers the diff and reads source directly. Do not send diffs, source dumps, snapshots, coverage manifests, or full transcripts. Use the actual checkout, including relevant dirty and untracked files; a clean worktree that omits the changes is not a substitute.

For T3 loop rounds, add concise prior findings, caller responses, and unresolved objections. Present these as claims to verify independently, without an expected verdict. Each round uses a fresh task/session.

## Run and assess

Keep source stable during read-only review. Choose a scope-based time budget, retain task handles, and wait on the same active work. A tool timeout or silence alone does not prove failure. Join owned work before edits or replacement calls.

Assess content directly under the shared skills. Prose, Markdown, and structured output are valid; missing bookkeeping does not require a retry or model call. Retain useful partial findings and disclose substantive inspection gaps. Transport completion does not establish a clean review.

A single review returns without repairs or another review invocation. Loops use the [recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts) for genuine failures. Remove only task-owned scratch after assessment, including on failure; preserve provider state, deliverables, and unrelated files. Save reports or transcripts only when requested.
