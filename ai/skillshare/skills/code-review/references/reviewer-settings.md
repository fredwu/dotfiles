# Reviewer model and effort

Apply this policy to every review, internal or external, including each loop round. It sets review settings only. It does not change the main session's user-selected settings or non-review assignments. If a direct review in the main session would use an effort this policy does not allow, delegate the review.

## Select

- **Model:** use the requested model. Otherwise, for Codex, Claude, and Grok, resolve a [model family](#resolve-a-model-family): in a [two-pass review](two-pass-review.md), the pass's family; in a single pass, Sol for Codex, Opus for Claude, and Grok for Grok, which has no separate families. For other providers, use the provider's configured `worker` role model, from its generated agent definition or the dotfiles `ai/skillshare/agent-models.json`. If the provider has no role mapping, choose from the live model list and state material limits.
- **Codex and Claude effort:** `medium` or `high` only. Use `medium` for a narrow, well-understood target with limited interactions. Use `high` for broad coverage, uncertain behavior, or consequential security, concurrency, data-integrity, or architectural interactions. Judge risk and uncertainty, not file count. If unsure, use `high`.
- **Grok effort:** always `xhigh`.

### Resolve a model family

The family name selects the model; do not fix version numbers. Before each launch, read the live model list (T3 `orchestrator_capabilities`, or the ACP client's model list) and select the newest available model whose ID or display name contains the family name, case-insensitive. Prefer the standard variant over mini, fast, preview, or extended-context variants when both exist. Record the resolved model ID. If no model of the family is available, the review is blocked: report it, and do not substitute another family or provider.

Record the selection and a short reason in context. A new round can reassess complexity; retries keep the round's model and effort.

## Apply and verify

- **T3:** read the live descriptors from `orchestrator_capabilities`, and set `target.model` and the effort in `target.options` explicitly. Codex and Grok use `reasoningEffort`; Claude uses `effort`. Provider defaults differ and parent effort does not carry across providers or models, so never omit the option.
- **ACP or native controls:** apply effort through supported settings and verify the effective value. A native role with a fixed effort must satisfy this policy; otherwise use another supported control.

Check the returned provider, model, and effort against the selection. Empty or mismatched options do not verify effort. Stop and join a wrongly configured task, replace it under the same-round retry rules, and do not accept its result. If a runtime cannot apply or verify the selection, report that limit. Do not accept defaults silently, substitute another effort, or change ambient configuration. Prompt wording does not set effort.
