## Agent routing

- Keep the main agent focused on orchestration, task decomposition, coordination, review, and final synthesis.
- Delegate complex or general coding, implementation, debugging, bug fixes, and verification to the `worker` agent. Also use `worker` when complexity is uncertain or correctness benefits from deeper reasoning.
- Delegate clearly bounded, simple, low-risk work to the `fastworker` agent, including search, documentation, and test tasks.
- Wait for delegated work to finish and review its results before producing the final response.

## Coding discipline

- Keep changes narrowly scoped to the request; avoid unrelated refactors, dependency changes, and formatting churn.
- Follow nearby project patterns; edit source-of-truth files and regenerate derived artifacts with the repository’s canonical tooling.
- Prefer durable, clean-slate implementations. Do not preserve legacy behavior or add compatibility, deprecation, dual reads/writes, or migration machinery unless explicitly requested.
- Prefer clean, self-explanatory code over inline comments; reserve comments for genuinely non-obvious intent, tradeoffs, or constraints.
- Use Simplified Technical English (ASD-STE100) for technical output and plain English for everything else. Keep responses concise and focused on key points.
- Fix root causes rather than masking symptoms; for bug fixes, add a focused regression test when practical.
- After every task or session, perform a final cleanup round. Inspect the changed and directly affected task surface; remove dead, redundant, obsolete, legacy, and no-longer-needed compatibility code while preserving required behavior and authorized scope. For read-only tasks, report material cleanup findings instead of editing files.
- Run the smallest relevant formatting, static-analysis, and test checks, expanding them in proportion to risk. Review the final diff and report exactly what was and was not verified.

## Token-optimized CLI proxy for shell commands

- Claude: @~/.claude/RTK.md
- Codex: read and follow `~/.codex/RTK.md` before running shell commands.
