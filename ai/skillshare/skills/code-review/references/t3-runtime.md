# T3 Code review coordination

Use T3's app-owned delegation for reviews whenever it is available. The [external review runtime](external-runtime.md) covers the handoff, assessment, and ACP fallback.

## Launch

1. Call `orchestrator_capabilities` for live provider, model, and option IDs.
2. Select the model and effort under [Reviewer model and effort](reviewer-settings.md). Set `target.providerInstanceId`, `target.model`, and the effort in `target.options` explicitly. Do not change the main session or ambient configuration.
3. Call `delegate_task` with the brief, `role: "review"`, `interactionMode: "default"`, and normally `isolation: "shared"`. `role: "review"` labels the purpose; it does not load a configured role. A worktree starts from the parent commit without uncommitted edits, so use `isolation: "worktree"` only when the target is fully committed.
4. Use a fresh `delegate_task` for each round, with a distinct `clientRequestId` that stays the same across retries of that launch. Keep the `taskId`. Do not use top-level thread tools, and do not send review prompts to the task's `childThreadId`.

If a launch response is uncertain, retry with the same `clientRequestId` and inspect the task before you assume failure. A replacement for a confirmed failed or stopped task needs a fresh task and launch key in the same round, under the [loop recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts).

## Wait and assess

Use async completion delivery or a yielding wait on the same task. Use `task_status` only when you need a result or a liveness check. A wait timeout does not cancel the task, and a task that waits for its children is still active. Cancel only owned work, and confirm it stopped before you launch a replacement.

Answer child questions from existing authority and scope; do not add routine approval handoffs.

Read the completed `summary` of the original task, not progress output or another run. T3 completion alone does not prove the target is clean. Read-only scope is an assignment, not a filesystem sandbox; report independence and limits accurately.

## Tool transport

If T3 tools are not listed, try the capabilities tool once, loading it first where tools are deferred. If tools are hidden, use the host's supported T3 bridge when one exists. The bridge calls T3 tools; it is not an ACP review. If T3 stays unavailable, use the ACP fallback. Provider and model errors are same-round retries, not a reason for transport fallback.
