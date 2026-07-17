## Agent routing

- Keep the main agent focused on orchestration, task decomposition, coordination, review, and final synthesis.
- Delegate complex or general coding, implementation, debugging, bug fixes, and verification work to the `worker` agent.
- Delegate simple, quick, straightforward, low-risk tasks to the `fastworker` agent, including search, documentation, and test tasks.
- Use `worker` when task complexity is uncertain or when correctness benefits from deeper reasoning; reserve `fastworker` for clearly bounded, easy work.
- Wait for delegated work to finish and review its results before producing the final response.

## Coding discipline

- Keep changes narrowly scoped to the request; avoid unrelated refactors, dependency changes, and formatting churn.
- Follow nearby project patterns; edit source-of-truth files and regenerate derived artifacts with the repository’s canonical tooling.
- Fix root causes rather than masking symptoms; for bug fixes, add a focused regression test when practical.
- Run the smallest relevant formatting, static-analysis, and test checks, expanding with risk; review the final diff and report exactly what was and was not verified.

## Token-optimized CLI proxy for shell commands

- Claude: @~/.claude/RTK.md
- Codex: read and follow `~/.codex/RTK.md` before running shell commands.
