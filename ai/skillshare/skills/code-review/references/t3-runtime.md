# T3 Code review coordination

Use T3's app-owned delegation for reviews whenever available. Agents inspect the repository directly; prompts describe the target without containing its source. If orchestration is unavailable, use the [ACP fallback policy](external-runtime.md#select-the-runtime).

## Select and launch

Call `orchestrator_capabilities` for live provider/model IDs, options, and constraints. Resolve the model from the requested reviewer or configured role, then choose effort under [Reviewer model and effort](reviewer-settings.md). Explicitly pass it in `target.options` and verify the returned selection before accepting the review. Use [Subagent roles and reasoning](../../execute-plan/references/subagent-reasoning.md) without changing the main session or ambient configuration. `role: "review"` describes purpose, not a configured model role.

Use `delegate_task` with requirements, repository/target, exclusions, a reference to [code-review](../SKILL.md), `role: "review"`, the chosen target, `interactionMode: "default"`, and normally `isolation: "shared"`. The reviewer inspects Git and source directly. Do not attach source, patches, snapshots, or manifests. Worktree isolation is useful only when it preserves the actual target; it does not copy dirty edits.

Include concise prior findings, responses, and unresolved objections for loop rounds, as claims to verify independently. Use a fresh `delegate_task` per round with a distinct `clientRequestId` stable across retries of that launch. Retain its `taskId`. Do not use top-level thread tools or send another review prompt to its backing `childThreadId`.

A confirmed failed attempt is retried within the same numbered round under the [loop recovery policy](../../code-review-loop/SKILL.md#recover-failed-attempts). Reuse the launch key for an uncertain tool response; a replacement for a confirmed terminal task needs a fresh task and launch key. Preserve both round and attempt identities to avoid duplicate work.

## Wait and assess

Use async completion delivery, or a yielding wait on the same task. `task_status` is appropriate when a result or liveness check is needed mid-work. A wait timeout does not cancel the task. Keep the chosen review budget and watchdog in caller context; silence is not proof of a hang. Cancel only owned work and confirm it stopped before launching a replacement.

Resolve child questions from existing authority and scope. The caller handles real missing information; do not add routine approval handoffs. A task waiting for children is still active.

Read the original task's completed `summary`; do not substitute progress or a later unrelated run. Assess content under [code-review](../SKILL.md), retaining partial findings and coverage limits. Do not impose schema or manifest validators. T3 task completion alone does not prove the target is clean.

T3 uses normal provider/project tools and context. Read-only scope is an assignment, not an extra filesystem sandbox. Report independence and limitations accurately without turning normal context into an automatic review failure.

## Tool transport fallback

If tools are not listed, try the known capabilities tool once. When tools are hidden, use the supported T3 bridge supplied by the host if available. Do not build a replacement client.

The bridge calls T3 tools; it is not a direct ACP review. If T3 orchestration remains unavailable, use the existing ACP client under the [fallback policy](external-runtime.md#select-the-runtime). Preserve the reviewer and target, avoid duplicate active work, and report the fallback reason. Provider/model errors use same-round retries rather than triggering transport fallback.
