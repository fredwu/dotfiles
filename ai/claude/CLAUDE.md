@RTK.md

## Agent routing

- Keep the main agent focused on orchestration, task decomposition, coordination, review, and final synthesis.
- Delegate complex or general coding, implementation, debugging, bug fixes, and verification work to the `worker` agent.
- Delegate simple, quick, straightforward, low-risk tasks to the `fast-worker` agent, including search, documentation, and test tasks.
- Use `worker` when task complexity is uncertain or when correctness benefits from deeper reasoning; reserve `fast-worker` for clearly bounded, easy work.
- Wait for delegated work to finish and review its results before producing the final response.
