# Reviewer model and effort

Apply this policy to every internal and external review, including loop rounds. Preserve the main session's user-selected settings; delegate when a direct review would use a disallowed effort.

Preserve a requested model; otherwise use the configured role model from runtime settings or `ai/skillshare/agent-models.json`. If the provider has no role mapping, resolve its model through the runtime's available selection controls and disclose material limits. Choose review effort separately from role defaults:

- **Codex and Claude:** choose `medium` or `high` only. Use medium for a narrow, well-understood target with limited interactions. Use high for broad coverage, uncertain behaviour, or consequential security, concurrency, data-integrity, and architectural interactions. Judge risk and uncertainty, not file count alone. Use high when uncertain.
- **Grok:** always use `xhigh`, regardless of target size or role defaults.

Record the selection and a short reason in coordinator context. A new round can reassess complexity; retries preserve the round's selected model and effort. These review rules override role-default effort, not the main session's settings or unrelated worker assignments.

## Apply and verify

Resolve settings for every launch. With T3, read the live model descriptors and explicitly set `target.model` and `target.options`: Codex and Grok use `reasoningEffort`; Claude uses `effort`. `role: "review"` is a purpose label and does not load worker configuration. Parent effort does not carry across different providers or models.

Check the returned provider, model, and effort against the selection. Empty or mismatched options do not verify the required effort. Stop and join an incorrectly configured task before replacing it, using the same-round retry rules. Do not accept its result as a correctly configured review.

With ACP or native controls, apply the selected effort through supported settings and verify the effective configuration. A native role with fixed effort must satisfy this policy; use another supported control when it cannot. If a runtime cannot apply or verify the selection, report the limitation rather than silently accepting defaults, substituting another effort, or changing ambient configuration. Prompt wording alone does not set effort.
