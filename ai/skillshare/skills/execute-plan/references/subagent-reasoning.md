# Subagent roles and reasoning

Apply this policy before each delegation and when an assignment's scope changes. The calling skill and the user's instructions decide whether to delegate; this policy selects the agent and settings. It never relaxes the caller's authority, source, or context limits.

## Select the agent and effort

- Keep the main agent's user-selected model and reasoning settings. Skills do not set the main agent's effort.
- For complex, general, or uncertain work (implementation, investigation, debugging, and meaningful verification), let delegated agents inherit the current session's model and reasoning settings.
- For clearly bounded, simple, low-risk work with clear inputs and acceptance criteria (such as quick lookups, documentation edits, and deterministic checks), you may use a lighter built-in subagent or model tier when the active runtime provides one. The task label alone is not enough: a documentation investigation or a test diagnosis can need full reasoning. If a lightweight assignment grows more complex, escalate it back to the parent or a full-strength agent with its context and evidence, without repeating completed work.
- Non-review assignments use the active runtime's native defaults without fixed model pins. Review assignments use Reviewer model and effort (`code-review/references/reviewer-settings.md`) for the provider that runs the reviewer, including an external one.

## Child boundaries

A child executes its assignment and reports to its parent. It does not ask the user questions or hand work to the user. It spawns its own children only when the parent explicitly authorizes it, and passes these boundaries on. It sends questions and blockers to the parent with evidence, options, and a recommendation, and continues independent authorized work.

## Apply supported controls

- Inside T3 Code, use the harness's native subagent controls for same-provider assignments—including internal reviews—when the current session's active model and effort already satisfy the applicable policy (for reviews, `code-review/references/reviewer-settings.md`) and no extra model/effort overrides, separate worktree, or background task are needed. Use T3 `delegate_task` with live provider and model IDs and supported options for external reviews, internal reviews whose model or effort must differ from or be explicitly verified against the session, cross-provider assignments, explicit model or effort overrides, worktree isolation, or background tasks. Outside T3 Code, use the harness's native subagent controls, and use supported controls (or ACP fallback for cross-provider reviews) when review effort must differ from the session default.
- Do not copy hardcoded model IDs or versions into skills. Codex, Claude, Grok, and Gemini reviews resolve live model families under Reviewer model and effort (`code-review/references/reviewer-settings.md`).
- Do not invent role names, tools, or effort parameters. Prompt prose does not set the model or reasoning budget. Report material limits when you cannot apply or verify required settings.
- Respect history-fork restrictions. Selection never permits extra history or evidence; when an API needs fresh context for explicit controls, give only the permitted task context.
- Do not change the main session, ambient provider configuration, or permissions to select a child. Keep selections in context, and report only limits that affect the outcome.

## Provider details

**Codex:** native subagents inherit session settings unless overridden through supported spawn controls. See [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents) and the [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

**Claude:** native `Agent` calls inherit the session model and effort unless overridden by a built-in subagent or explicit call parameters. `CLAUDE_CODE_EFFORT_LEVEL` overrides session effort; report a material ambient override instead of changing configuration. See [Claude subagents](https://code.claude.com/docs/en/sub-agents) and [effort configuration](https://code.claude.com/docs/en/model-config#adjust-effort-level).

**Grok:** apply child model and effort only through supported runtime controls, without imposing a provider-wide effort. See [Grok agent definition controls](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-agent/src/config.rs) and [child effort resolution](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-subagent-resolution/src/definition.rs).

**Gemini (Antigravity):** inside T3 Code, target the enabled provider that exposes the Gemini model and supports `thought_level` (such as `antigravity`), and set `thought_level` explicitly in `target.options` when explicit effort is required. Outside T3 Code, or for native Antigravity subagents (`invoke_subagent`), use the supported model tiers (`inherit`, `pro`, `flash`, `flash_lite`) and report if a required effort control cannot be applied or verified.
