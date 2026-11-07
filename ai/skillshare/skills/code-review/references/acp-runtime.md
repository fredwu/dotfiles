# ACP review fallback

Use this only when T3 orchestration is unavailable under the [runtime selection policy](external-runtime.md#select-the-runtime).

Use the harness's existing ACP client and authentication to ask the selected provider to review the actual repository or worktree. Apply and verify the provider, model, and effort under [Reviewer model and effort](reviewer-settings.md). If the harness cannot use ACP with these settings or cannot reach the actual target, report the limit. Do not build a runtime, send source in the prompt, or change the provider.

Start a fresh session for each round, keep its handle, and wait for the result. Stop and join the session before edits or a replacement.
