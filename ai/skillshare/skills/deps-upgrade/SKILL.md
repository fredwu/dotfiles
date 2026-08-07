---
name: deps-upgrade
description: Upgrade all project dependencies across Mix/Hex, npm applications including Phoenix assets and browser extensions, and Tailwind. Use when asked to update, upgrade, or modernize every dependency and repair resulting code, configuration, or test breakage.
---

# Dependency Upgrade

Upgrade every discovered dependency while preserving unrelated work. Do not commit, push, or open pull requests unless explicitly asked.

## Inventory and protect scope

1. Read repository instructions and snapshot `git status --short` plus relevant diffs. Preserve all unrelated staged, unstaged, and untracked changes.
2. Find every manifest, lockfile, workspace, umbrella app, Phoenix assets directory, and browser-extension package. Include nested `mix.exs`, `package.json`, npm workspaces, and lockfiles; do not assume conventional paths.
3. Inventory outdated Mix and npm dependencies. Identify coupled packages, constraints, generated files, and app-specific checks.
4. Locate Tailwind in every form: an npm dependency, the Phoenix `tailwind` Hex wrapper, and any configured standalone binary version. Check each independently against a newer compatible or current release.

## Upgrade Mix and Hex

Prefer the installed Elixir/Phoenix updater: invoke `$elixir-phoenix:phx-deps-update` in Codex or `/phx:deps-update` in Claude/Grok. Use its inventory, update, breaking-fix, and verification phases. Run or select scopes as needed until every outdated group, including coupled groups, is covered. Skip its commit/PR actions unless explicitly requested, leaving reviewed working-tree changes only.

If that updater is unavailable, perform a concise best-effort fallback:

1. Inspect every `mix.exs` and `mix.lock` to inventory Hex, Git, and path dependencies. Run `mix hex.outdated --all`, treating its outdated exit status as inventory rather than failure.
2. Read release and migration notes before major or coupled upgrades. Edit constraints when needed, then use canonical Mix commands.
3. Inspect the actual `mix.lock` diff, fix breaking API/configuration changes, and keep source, manifest, and lockfile edits together in the working tree.

After either path, canonically update every inventoried Git dependency with a newer intended revision. Report blocked Git dependencies, and classify path dependencies, including umbrella-internal apps, separately without treating them as registry-versioned dependencies. Update the Phoenix `tailwind` Hex wrapper and configured standalone version when newer compatible/current versions exist. Reinstall or exercise the binary through the project's Mix tasks.

## Upgrade npm and Tailwind

For every npm app or workspace, including Phoenix assets and browser extensions:

1. Inventory direct and transitive outdated packages with `npm outdated --all` or the package-manager equivalent. Treat an outdated-results exit status, including its package-manager equivalent where applicable, as inventory rather than failure; do not ignore actual command errors. Inspect release or migration notes for breaking upgrades.
2. Upgrade direct dependencies to appropriate current versions, including Tailwind and its plugins. Respect compatibility and engine constraints; report blocked upgrades.
3. Refresh the complete transitive lock tree with the repository's canonical package-manager command. Never hand-edit a generated lockfile. Explicitly report transitive packages held back by constraints, overrides, engine or peer requirements, or upstream availability.
4. Apply required source, build configuration, CSS, extension manifest, and test changes. Follow the applicable Tailwind migration steps rather than merely changing its version.

## Verify and report

Discover the repository or project's complete canonical quality and test suite from its instructions, CI configuration, and task runners. After all upgrades, run that suite in full. Run affected-app formatting, compile/static analysis, tests, builds, and Tailwind exercises as supplemental checks. Fix upgrade-caused failures within scope, then rerun the complete canonical suite from the beginning until it passes. Do not silently skip failed or unavailable checks; resolve them or report a genuine blocker and an incomplete result.

Re-run all outdated inventories at the end. Review the final status and diff to confirm lockfiles are canonical, requested ecosystems were covered, and unrelated changes remain intact. Report upgraded and blocked dependencies, migrations performed, checks passed or failed, and anything not verified.
