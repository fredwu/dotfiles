# Local `cua-driver` preferences

The `cua-driver` updater owns the linked vendor skill pack (`~/.cua-driver/skills/cua-driver`), so local delivery and interaction preferences live here outside the vendor skill directory.

## Preflight

- Check `cua-driver --version`, the running daemon version (`health_report`), and `describe <tool>` before using unfamiliar options.

## Background-first capture and input

- Prefer exact-window background capture and input; set `delivery_mode:"background"` where supported.
- Preserve the user's frontmost app, keyboard focus, pointer position, and workspace/Space whenever background operation can complete the task.
- Use `launch_app` for background launches and file opening.
- Prefer exact-window accessibility actions with fresh `element_token` values; use screenshot coordinates only from a valid capture of that window.
- Keep one controller per shared desktop.

## Action execution

- For known actions, prefer `run_steps` with `delivery_mode:"background"`, `foreground_fallback:false`, and `observe:{}`. Request `observe:{include_screenshot:true}` when visual proof is needed.
- Use `run_script` for flows that need branches or loops; it has no top-level `delivery_mode` option, so keep its actions on background routes.
- Use `since:"latest"` for repeat window reads and the new snapshot's tokens.

## Refusals and foreground fallback

- If background input is unavailable or ineffective, read the refusal's `hint` and `next_call`, verify current state, and try another supported background route when possible. Do not replay partial or unknown actions.
- Standing user authorization for visible foreground fallback during a **requested** desktop UI task lives in `AGENTS.md`. When using foreground fallback, keep it brief and restore the prior frontmost app, focus, pointer position, and workspace/Space where supported.
- Reserve `bring_to_front` for required persistent foreground state; do not use shell activation or input workarounds.
- For unasked self-verification checks (such as `final-pass` visual checks), stay background-only; record a verification limit instead of taking foreground focus if background capture is unavailable.
