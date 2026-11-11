# Subagent roles and reasoning

Apply this policy before each delegation and when an assignment's scope changes. The calling skill and the user's instructions decide whether to delegate; this policy selects the role and settings. It never relaxes the caller's authority, source, or context limits.

## Select the role

- Keep the main agent's user-selected model and reasoning settings. Skills do not set the main agent's effort.
- Use the configured `worker` role for complex, general, or uncertain work: implementation, investigation, review, debugging, and meaningful verification.
- Use the configured `fastworker` role for clearly bounded, simple, low-risk work with clear inputs and acceptance criteria, such as searches, documentation edits, and deterministic checks. The task label alone is not enough: a documentation investigation or a test diagnosis can need `worker`. If a `fastworker` assignment grows more complex, reassign it to `worker` with its context and evidence, without repeating completed work.
- Non-review assignments inherit the role's model and effort with no per-task override. Review assignments use [Reviewer model and effort](../../code-review/references/reviewer-settings.md) for the provider that runs the reviewer, including an external one.

## Child boundaries

A child executes its assignment and reports to its parent. It does not ask the user questions or hand work to the user. It spawns its own children only when the parent explicitly authorizes it, and passes these boundaries on. It sends questions and blockers to the parent with evidence, options, and a recommendation, and continues independent authorized work.

## Apply supported controls

- Inside T3 Code, delegate through T3 with live provider and model IDs and supported options. For reviews, set and verify model and effort under the reviewer policy; otherwise use the configured role settings. Outside T3, use the configured `worker` and `fastworker` roles, and use supported controls when review effort must differ from a fixed role default.
- `ai/skillshare/agent-models.json` in the dotfiles repository is the source of the role models and default efforts. Codex, Claude, and Grok reviews instead resolve the model families set in [Reviewer model and effort](../../code-review/references/reviewer-settings.md). Do not copy model IDs or versions into skills, and do not reload the map when the runtime roles already provide them.
- If a preferred role is unavailable, use the closest real role or supported spawn controls, and carry over the configured role settings when accessible. Do not invent role names, tools, or effort parameters. Prompt prose does not set the model or reasoning budget. Report material limits when you cannot apply or verify the required settings.
- Respect history-fork restrictions and role-fixed settings. Role selection never permits extra history or evidence; when an API needs fresh context for explicit controls, give only the permitted task context.
- Do not change the main session, ambient provider configuration, permissions, or configured role models to select a child. Keep selections in context, and report only limits that affect the outcome.

## Provider details

**Codex:** custom agent roles support `model_reasoning_effort`, which overrides spawn, default, and parent effort. Select the configured role through the active API; harness controls can differ from Codex's native agent configuration. See [Codex custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents) and the [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

**Claude:** agent definitions supply the model and `effort`. Select the configured role instead of repeating its settings on `Agent` calls. `CLAUDE_CODE_EFFORT_LEVEL` overrides session and agent-definition effort; report a material ambient override instead of changing configuration. See [Claude subagent effort](https://code.claude.com/docs/en/sub-agents#choose-an-effort-level) and [effort configuration](https://code.claude.com/docs/en/model-config#adjust-effort-level).

**Grok:** use the configured role's model and effort through supported runtime controls, without imposing a provider-wide effort. See [Grok agent definition controls](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-agent/src/config.rs#L738) and [child effort resolution](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-subagent-resolution/src/definition.rs#L209).
