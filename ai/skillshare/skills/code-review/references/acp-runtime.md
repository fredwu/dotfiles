# Direct ACP review outside T3

Outside T3 Code, use the harness's existing ACP client to ask the selected provider to review the actual repository or worktree. Inside T3, use [T3 delegation](t3-runtime.md).

Apply the [shared handoff and assessment policy](external-runtime.md). These skills supply Markdown instructions only; do not create custom clients, wrappers, parsers, or validation scripts to run a review.

Use normal provider tools and controls with existing authentication. If the harness cannot use ACP with the requested provider, report that limit rather than building a runtime or changing transports.

Start a fresh session for each review round, retain its handle, and wait for the result. Stop and join the session before edits or replacement calls.
