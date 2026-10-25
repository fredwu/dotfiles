# Direct ACP review outside T3

Outside T3 Code, use the harness's existing ACP client to ask the selected provider to review the actual repository or worktree. Inside T3, use [T3 delegation](t3-runtime.md).

Send a short brief with the requirements, repository/target, read-only scope, and important exclusions. The reviewer discovers changes with Git and reads the source itself. Do not send diffs, source dumps, snapshots, or manifests. These skills supply Markdown instructions only; do not create custom clients, wrappers, parsers, or validation scripts to run a review.

Use normal provider tools and controls. Keep the target unchanged while review runs, preserve existing authentication, and follow the requested provider/model settings. If the harness cannot use ACP with that provider, report the limitation rather than building a runtime or silently changing transports.

Keep the session handle and wait for its result. Choose a budget appropriate to the work; a tool wait timeout or silence alone does not mean the review failed. Avoid duplicate active requests.

Read the returned findings directly. Prose, Markdown, and structured output are valid. Assess actionable claims against the checkout, retain useful partial findings, and report real inspection gaps. Missing schema fields or formatting do not fail a review.

The caller owns assessment and repairs. Stop and join owned work before edits, then remove only task-owned scratch. Preserve provider state, deliverables, and unrelated files.
