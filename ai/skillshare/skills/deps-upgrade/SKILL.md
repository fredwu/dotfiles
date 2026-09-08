---
name: deps-upgrade
description: Upgrade project dependencies across Mix/Hex, npm workspaces, and Tailwind, and repair resulting source, configuration, and test breakage.
---

# Dependency Upgrade

Upgrade every discovered dependency within compatibility constraints. Preserve unrelated work; do not commit, push, or open a pull request unless requested.

## Inventory

Read repository instructions and inspect status/diffs. Find manifests, locks, workspaces, umbrella apps, Phoenix assets, and extension packages, including nested locations. Identify outdated direct/transitive dependencies, coupled packages, constraints, and applicable checks. Check Tailwind's npm package, Hex wrapper, and configured standalone binary independently.

Delegate independent applications/ecosystems when useful. Keep shared locks, generated outputs, and coupled packages under one owner. Reconcile worker changes and verification before integration.

## Upgrade

- **Mix/Hex:** inspect `mix.exs` and `mix.lock`; run `mix hex.outdated --all`. Read migration notes for breaking/coupled changes, adjust constraints, update with canonical Mix commands, and repair APIs/configuration. An available Elixir/Phoenix dependency updater can perform this work. Update Git dependencies to their intended newer revision; classify path/umbrella dependencies separately. Update and exercise the Tailwind wrapper and standalone binary through project tasks.
- **npm/workspaces:** run `npm outdated --all` or the package-manager equivalent. Upgrade direct dependencies, Tailwind, and plugins to current compatible versions; honor engine and peer requirements. Refresh the transitive tree through canonical tooling, never hand-edit locks. Apply required source, CSS, build, extension-manifest, and test migrations.

Distinguish outdated-results exit codes from command failures. Track packages held back by constraints, overrides, engines, peers, or upstream availability. Keep notes and inventories in context unless an agent needs files; treat such files as temporary.

## Integrate and verify

Review combined diffs and remove confirmed code, tests, configuration, or documentation made obsolete by the upgrades. Preserve required behavior and explicit supported-version compatibility.

Run repository-required quality gates on the integrated result, plus relevant dependency/security audits, builds, and Tailwind checks not already covered. Fix upgrade-caused failures and verify repairs; reuse passing results for unchanged relevant code and environment. Respect authorization boundaries for checks with cost or external effects.

Rerun outdated inventories and inspect final diffs for coverage and canonical locks. Report upgrades, required migrations, held-back packages, and material check results or gaps in short, plain prose. Skip stock headings and repeated summaries; save a user report only if requested. An unavailable required check is not a pass.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
