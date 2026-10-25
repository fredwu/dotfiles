# T3 Code review coordination

Use T3's app-owned delegation for reviews and other agent work when running inside T3 Code. The agents share repository access; task prompts do not need to contain the source.

## Select and launch

Call `orchestrator_capabilities` for live provider/model IDs, options, and constraints. Respect the requested reviewer and configured role settings through supported `target.options`; do not change the main session or ambient configuration. Use [Subagent roles and reasoning](../../execute-plan/references/subagent-reasoning.md). `role: "review"` describes purpose, not a configured model role.

Use `delegate_task` with a short requirement-only brief, `role: "review"`, the chosen target, `interactionMode: "default"`, and normally `isolation: "shared"`. Let the reviewer inspect Git status, diffs, source and tests directly. Do not inline source, attach patches, serialize snapshots, or require a coverage manifest. Worktree isolation is useful only when it preserves the actual review target; it does not copy dirty edits.

Include concise prior findings, responses, and unresolved objections for loop rounds. Use a fresh `delegate_task` for every round, with a distinct `clientRequestId` stable across transport retries of that launch. Retain its `taskId`. Do not use top-level thread tools or send another review prompt to its backing `childThreadId`.

## Wait and assess

Use async completion delivery, or a yielding wait on the same task. `task_status` is appropriate when a result or liveness check is needed mid-work. A wait timeout does not cancel the task. Keep the chosen review budget and watchdog in caller context; silence is not proof of a hang. Cancel only owned work and confirm it stopped before launching a replacement.

Resolve child questions from existing authority and scope. The caller handles real missing information; do not add routine approval handoffs. A task waiting for children is still active.

Read the original task's completed `summary`; do not substitute progress or a later unrelated run. Assess the content directly. Plain prose and Markdown are valid review handoffs; do not run a schema/manifest validator or insist on exact JSON. Preserve useful partial findings and report substantive coverage limits. T3 task completion alone does not prove the code is clean.

T3 uses normal provider/project tools and context. Read-only scope is an assignment, not an extra filesystem sandbox. Report independence and limitations accurately without turning normal context into an automatic review failure.

## Tool transport fallback

If tools are not listed, try the known capabilities tool once. When tools are hidden, use the supported T3 bridge supplied by the host if available. Do not build a replacement client.

The bridge calls T3 tools; it is not a direct ACP review. If T3 still cannot run the selected task, report that constraint instead of starting a different transport or provider.
