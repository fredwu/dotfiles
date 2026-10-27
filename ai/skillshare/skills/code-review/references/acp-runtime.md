# ACP review fallback

When T3 orchestration is unavailable, use the harness's existing ACP client to ask the selected provider to review the actual repository or worktree. Prefer [T3 delegation](t3-runtime.md) whenever available, regardless of the host harness.

Apply the [shared handoff and assessment policy](external-runtime.md). These skills supply Markdown instructions only; do not create custom clients, wrappers, parsers, or validation scripts to run a review.

Use normal provider tools and controls with existing authentication. Apply and verify the selected provider, model, and effort under [Reviewer model and effort](reviewer-settings.md). If the harness cannot use ACP with those settings or access the actual target, report that limit rather than building a runtime, sending source in the prompt, or substituting another provider.

Start a fresh session for each review round, retain its handle, and wait for the result. Stop and join the session before edits or replacement calls.
