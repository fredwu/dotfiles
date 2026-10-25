# External review runtime

Use this shared policy for Codex, Claude, and Grok single reviews and loops. The caller owns scope, assessment, verification, and cleanup. Remediation belongs to review loops, not single reviews.

## Select the runtime

Inside T3 Code, use [T3 delegation](t3-runtime.md) to coordinate agents. Do not switch to direct ACP because of prompt size, model settings, or a tool problem. Keep the brief small and let the agent inspect the checkout. If T3 is unavailable, report the real constraint and try its supported transport bridge; do not silently bypass it.

Outside T3 Code, use [direct ACP](acp-runtime.md) when the selected provider supports it. Preserve the requested provider and explicit model/options. Do not change ambient provider configuration or transfer credentials.

## Hand off the requirement

Send a short review brief: intended behavior and acceptance criteria, repository/target, read-only scope, and material exclusions. Refer to repository files when useful. Never send the diff, full file contents, a serialized source snapshot, or a coverage manifest. The reviewer uses normal repository and Git tools to discover and inspect the changes itself.

For T3 loop rounds, add concise prior findings, caller responses, and unresolved objections required by the host. Keep these as claims to verify. Do not send full transcripts, irrelevant history, or an expected verdict. Each reached round gets a fresh task/session.

## Run and assess

Keep review read-only and source stable while it runs. Use the actual checkout, including relevant dirty and untracked files. Do not substitute a clean worktree that omits the work under review. Choose a reasonable time budget, retain task handles, and avoid duplicate active calls.

Accept ordinary review prose, Markdown, or structured output. Do not reject useful reviews because they omit a schema, snapshot ID, confidence number, or other bookkeeping. The caller verifies findings and assesses whether required inspection is complete. Missing access or unfinished substantive inspection is a real limit; formatting is not. Retain usable findings from a partial review and disclose the gap without claiming clean completion.

Normalize findings in caller context when useful. Do not require a model call merely to reformat a response. A single review returns its findings or failure with any useful partial result; it does not start another review or edit the target. An active loop with a round available handles genuine runtime failures under the [loop recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts). Preserve honest review status, required checks, and the selected provider.

Join owned work before any loop remediation. Remove task-owned scratch after assessment, including failure or abandonment, while preserving provider state, requested deliverables, and unrelated files. Do not create reports or transcripts solely for presentation.
