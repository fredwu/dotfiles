# Subagent roles and reasoning

Apply this policy before each delegated assignment and when its scope changes. Use the executing provider, including for an external reviewer. The calling skill and repository instructions decide whether to delegate and retain all authority, source, and context restrictions.

| Provider | Main agent default | Child settings |
| --- | --- | --- |
| Codex or Claude | `xhigh` | Select the configured `worker` or `fastworker` role; inherit its model and reasoning settings without overrides. |
| Grok | `xhigh` | `xhigh` for every child, regardless of role or task. |

Choose `worker` for complex, general, or uncertain work, including implementation, investigation, review, debugging, and meaningful verification. Choose `fastworker` for clearly bounded, simple, low-risk work, such as searches, documentation edits, and deterministic checks with clear inputs and acceptance criteria. The task label alone is insufficient: a documentation investigation or test diagnosis can need `worker`. If a `fastworker` assignment grows in complexity, return or reassign it to `worker` with its context and existing evidence; do not repeat completed work unnecessarily.

## Apply supported controls

- Prefer the runtime's configured `worker` and `fastworker` roles. Select the role without explicit model or effort fields so later role changes take effect automatically. Shared role generation uses `ai/skillshare/agent-models.json` as its sole source for model and effort values; skills must not duplicate those values or reload the map when runtime roles already provide them.
- If a preferred role is unavailable, use the closest actual available role or supported spawn controls suited to the task, carrying over the configured role settings when accessible. Do not invent role names, tools, or effort parameters. Prompt prose does not set the model or reasoning budget. Report material limits when the required settings cannot be applied or verified.
- Respect history-fork constraints and role-fixed settings. Fresh-review and source exclusions still apply; role selection does not permit extra history or evidence. When the active API requires fresh context for explicit controls, supply only the permitted task context.
- Preserve Grok's `xhigh` requirement through its configured roles or supported effort controls, including for simple tasks. Do not change the main session, ambient provider configuration, permissions, or configured role model to select a child. Keep selections and limits in coordinator context; report only limits that affect the outcome.

## Provider details

**Codex:** Custom agent role configuration supports `model_reasoning_effort`; its value overrides spawn, default, and parent effort. Select the configured role through the active API; harness controls can differ from Codex's native agent configuration. See [Codex custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents) and [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

**Claude:** Agent definitions supply model and `effort` settings. Select the configured role rather than repeating its settings on `Agent` calls. `CLAUDE_CODE_EFFORT_LEVEL` overrides session and child-definition effort; report a material ambient override instead of changing configuration. See [Claude subagent effort](https://code.claude.com/docs/en/sub-agents#choose-an-effort-level) and [effort configuration](https://code.claude.com/docs/en/model-config#adjust-effort-level).

**Grok:** Agent definitions support `effort: xhigh`; ensure a role or persona does not resolve a lower level before that fallback. Retain `xhigh` through these definitions or other supported controls. A restriction that disables children remains in force; in particular, the external ACP review runtime prohibits Grok children until restriction inheritance is verified. See [Grok agent definition controls](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-agent/src/config.rs#L738) and [child effort resolution](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-subagent-resolution/src/definition.rs#L209).
