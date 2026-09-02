---
name: deps-upgrade
description: Upgrade all project dependencies across Mix/Hex, npm applications including Phoenix assets and browser extensions, and Tailwind. Use when asked to update, upgrade, or modernize every dependency and repair resulting code, configuration, or test breakage.
---

# Dependency Upgrade

Upgrade every discovered dependency while preserving unrelated work. Do not commit, push, or open pull requests unless explicitly asked.

## Inventory

1. Read repository instructions; snapshot `git status --short` and relevant diffs. Preserve unrelated staged, unstaged, and untracked work.
2. Find every manifest, lockfile, workspace, umbrella app, Phoenix assets directory, and browser-extension package, including nested `mix.exs`, `package.json`, and npm workspaces. Do not assume conventional paths.
3. Inventory outdated Mix and npm dependencies, coupled packages, constraints, generated files, and app-specific checks.
4. Check Tailwind independently in all forms: npm package, Phoenix `tailwind` Hex wrapper, and configured standalone binary.

After the repository and status preflight, prefer available subagents for parallel inventories of independent ecosystems or applications. Reconcile the inventories before assigning parallel upgrades, and do so only for scopes that do not share manifests, lockfiles, generated outputs, source files, or services. Assign exact path ownership and require migration, repair, and affected-check evidence. Keep coupled packages, shared workspaces, final integration and cleanup, outdated reinventory, and canonical full-suite reruns coordinated and serial; the primary agent owns every residual.

After all assigned upgrades, wait for every upgrade worker to finish. Before final integration, cleanup, outdated reinventory, or the canonical full suite, the primary agent must inspect and reconcile each worker's diff, evidence, and residuals.

## Upgrade Mix and Hex

Prefer the installed Elixir/Phoenix updater: invoke `$elixir-phoenix:phx-deps-update` in Codex or `/phx:deps-update` in Claude/Grok. Use its inventory, update, breaking-fix, and verification phases. Run or select scopes as needed until every outdated group, including coupled groups, is covered. Skip its commit/PR actions unless explicitly requested, leaving reviewed working-tree changes only.

If that updater is unavailable, perform a concise best-effort fallback:

1. Inspect every `mix.exs` and `mix.lock` for Hex, Git, and path dependencies. Run `mix hex.outdated --all`; treat its outdated exit status as inventory, not failure.
2. Read release and migration notes before major or coupled upgrades. Adjust constraints and use canonical Mix commands.
3. Inspect the `mix.lock` diff, repair breaking API or configuration changes, and keep source, manifest, and lockfile edits together.

After either path, canonically update each inventoried Git dependency to its intended newer revision and report blockers. Classify path dependencies, including umbrella-internal apps, separately from registry-versioned dependencies. Update the Phoenix `tailwind` wrapper and standalone version when newer compatible/current versions exist; reinstall or exercise the binary through project Mix tasks.

## Upgrade npm and Tailwind

For every npm app or workspace, including Phoenix assets and browser extensions:

1. Run `npm outdated --all` or the package-manager equivalent for direct and transitive inventory. Treat an outdated-results exit status as inventory, not failure; do not ignore command errors. Read migration notes for breaking upgrades.
2. Upgrade direct dependencies, Tailwind, and its plugins to appropriate current versions. Respect compatibility and engine constraints; report blockers.
3. Refresh the complete transitive tree with canonical package-manager commands; never hand-edit generated lockfiles. Report packages held back by constraints, overrides, engine or peer requirements, or upstream availability.
4. Apply required source, build, CSS, extension-manifest, and test repairs. Follow applicable Tailwind migrations, not only version changes.

## Verify and report

Discover the complete canonical quality and test suite from repository instructions, CI, and task runners. After all upgrades, run it in full, plus affected-app formatting, compile/static analysis, dependency/security audits, tests, builds, and Tailwind exercises. Fix upgrade-caused failures, then rerun the canonical suite from the beginning until it passes. Resolve failed or unavailable checks, or report a genuine blocker and incomplete result.

Before final reporting, deliberately inspect the upgrade-changed and directly affected task surface for confirmed legacy, redundant, duplicate, dead or unused, obsolete, superseded, and no-longer-needed compatibility code. Remove only in-scope code, tests, configuration, or documentation made unnecessary by the upgraded versions when safe and authorized. Preserve required behavior, explicitly required supported-version compatibility, unrelated work, and scope. A clean result is acceptable; do not invent work.

Rerun every outdated inventory. Review final status and diff for canonical lockfiles, complete ecosystem coverage, and preserved unrelated work. Report upgrades, blockers, migrations, check outcomes, and anything unverified.
