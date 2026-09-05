---
name: deps-upgrade
description: Upgrade all project dependencies across Mix/Hex, npm applications and workspaces, and Tailwind. Repair resulting source, configuration, and test breakage.
---

# Dependency Upgrade

Upgrade every discovered dependency within compatibility constraints and preserve unrelated work. Do not commit, push, or open a pull request unless explicitly requested.

## Inventory and ownership

Read repository instructions and inspect status/diffs. Find every manifest, lockfile, workspace, umbrella app, Phoenix assets directory, and browser-extension package, including nested locations. Inventory outdated direct/transitive dependencies, coupled packages, constraints, generated files, and app checks. Check Tailwind's npm package, Phoenix Hex wrapper, and configured standalone binary independently.

Prefer parallel inventories for independent applications/ecosystems. Reconcile coverage before parallel upgrades; assign exact path ownership only where manifests, locks, generated outputs, source files, and services do not overlap. Keep coupled packages and shared workspaces serial. Require migration, repair, and affected-check evidence.

Wait for every upgrade worker and inspect its diff, evidence, and residuals before final integration, cleanup, outdated reinventory, or the canonical full suite. The coordinator owns every residual.

## Mix and Hex

Use an available Elixir/Phoenix dependency updater for inventory, upgrades, breaking-change repairs, and verification. Cover every outdated and coupled group; omit its commit/PR actions unless requested. If unavailable:

1. Inspect all `mix.exs` and `mix.lock` files for Hex, Git, and path dependencies. Run `mix hex.outdated --all`; an outdated-results exit status is inventory, while command errors require investigation.
2. Read release/migration notes for major or coupled upgrades, adjust constraints, and update with canonical Mix commands.
3. Inspect lockfile changes and repair affected APIs/configuration together with manifest/source changes.

With either approach, update each inventoried Git dependency to its intended newer revision and classify path/umbrella dependencies separately. Update the Tailwind wrapper and standalone version when newer compatible versions exist; reinstall or exercise the binary through project Mix tasks.

## npm and Tailwind

For every app/workspace:

1. Run `npm outdated --all` or the package-manager equivalent. Distinguish outdated results from command errors; read migration notes for breaking upgrades.
2. Upgrade direct dependencies, Tailwind, and plugins to current compatible versions. Honor engine and peer requirements.
3. Refresh the full transitive tree using canonical package-manager commands; never hand-edit generated locks. Record packages held back by constraints, overrides, engines, peers, or upstream availability.
4. Repair source, builds, CSS, extension manifests, and tests, including applicable Tailwind migrations.

## Integrate and verify

After joining workers, reconcile the combined result. Remove only confirmed obsolete, duplicate, dead, or unnecessary compatibility code and related tests/configuration/docs made unnecessary by the upgrades. Preserve required behavior, explicit supported-version compatibility, unrelated work, and scope; do not invent cleanup.

Discover the canonical full quality suite from repository instructions, CI, and task runners. Run it on the integrated result, plus affected-app checks, dependency/security audits, builds, and Tailwind exercises not already covered. Fix upgrade-caused failures and rerun the full suite after repairs; reuse passing results only for unchanged relevant code and environment. Respect authorization boundaries for checks with cost or external side effects.

Rerun all outdated inventories and review final status/diffs for ecosystem coverage and canonical locks. Report upgrades, migrations, held-back packages/blockers, exact check results, and anything unverified. An unavailable required check is an incomplete result, not a pass.
