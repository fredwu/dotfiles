## Agent routing

- Keep the main agent focused on orchestration, task decomposition, coordination, review, and final synthesis.
- Keep Codex and Claude main agents at the user's `high` default. Select configured child roles separately and inherit their model and reasoning settings without overrides. For Grok, use `xhigh` for the main agent and every child, regardless of task.
- Delegate complex or general coding, implementation, investigation, review, debugging, bug fixes, and meaningful verification to the configured `worker` agent. Also use `worker` when complexity is uncertain or correctness benefits from deeper reasoning.
- Delegate clearly bounded, simple, low-risk work to the configured `fastworker` agent, including search, documentation, and deterministic checks. If complexity increases, return or reassign the task to `worker` with its context and evidence. Grok children retain `xhigh` under either role.
- Respect the active runtime's role-fixed settings, supported controls, and history-fork restrictions. If a preferred role is unavailable, use the closest available role or supported spawn controls, carrying over the configured role settings when accessible. Do not invent roles or controls; report material limits.
- Wait for delegated work to finish and review its results before producing the final response.
- Never treat silence from delegated or background work as progress. While such work is pending, keep a watchdog that wakes the main agent at least every 20 minutes; on each wake, verify real activity (live processes, recent file changes, new output). If there is none, or an agent reports that it waits on sub-agents, intervene at once (resume it with the missing input, or reassign the work) and tell the user how long the work was stalled.

## Tool routing

- Use the cua-driver skill by default for native desktop app and window tasks. Respect explicitly requested tools. Use browser-specific tools for web pages and agent-device for mobile or TV devices.
- For cua-driver, prefer exact-window background capture and input; set `delivery_mode:"background"` where supported. Preserve the user's frontmost app, keyboard focus, pointer position, and workspace/Space when background operation can complete the task.
- If background capture or input is unavailable or ineffective, verify the current state, then use the necessary foreground or desktop interaction without asking for confirmation. This is standing user authorization for visible control during the requested UI task, including when cua-driver skill guidance requires authorization. Keep foreground use brief and restore the prior frontmost app, focus, pointer position, and workspace/Space where supported.

## Coding discipline

- Keep changes narrowly scoped to the request; avoid unrelated refactors, dependency changes, and formatting churn.
- Follow nearby project patterns; edit source-of-truth files and regenerate derived artifacts with the repository’s canonical tooling.
- Prefer durable, clean-slate implementations. Do not preserve legacy behavior or add compatibility, deprecation, dual reads/writes, or migration machinery unless explicitly requested.
- Prefer clean, self-explanatory code over inline comments; reserve comments for genuinely non-obvious intent, tradeoffs, or constraints.
- Use Simplified Technical English (ASD-STE100) for technical output and plain English for everything else. Keep responses concise and focused on key points.
- Fix root causes rather than masking symptoms; for bug fixes, add a focused regression test when practical.
- After every coding task or session, perform one deliberate cleanup round over the changed and directly affected task surface. Remove confirmed legacy, redundant, duplicate, dead or unused, obsolete, superseded, and no-longer-needed compatibility code, including directly related tests, configuration, and documentation, when safe and authorized. Preserve required behavior, explicitly required compatibility, unrelated work, and authorized scope. For planning or other read-only tasks, report or plan only material cleanup findings; do not edit implementation. A clean result is acceptable; do not invent work.
- Run the smallest relevant formatting, static-analysis, and test checks, expanding them in proportion to risk. Review the final diff and report exactly what was and was not verified.
