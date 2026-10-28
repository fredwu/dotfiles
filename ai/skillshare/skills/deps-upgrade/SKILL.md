---
name: deps-upgrade
description: Upgrade project dependencies and runtimes, including Elixir/OTP, Mix/Hex, npm workspaces, and Tailwind; align local, CI, Docker, and deployment versions and repair resulting breakage.
---

# Dependency Upgrade

Upgrade every discovered dependency and the project runtime/toolchain to current stable, mutually compatible releases within explicit support constraints. Existing version pins are upgrade candidates, not automatic holdbacks. Preserve unrelated work; do not commit, push, deploy, or open a pull request unless requested.

## Inventory

Read repository instructions and inspect status/diffs. Find manifests, locks, workspaces, umbrella apps, Phoenix assets, and extension packages, including nested locations. Identify outdated direct/transitive dependencies, coupled packages, constraints, and applicable checks. Check Tailwind's npm package, Hex wrapper, and configured standalone binary independently. Use canonical tooling for each discovered ecosystem; report any ecosystem that cannot be handled.

Trace version declarations and effective versions across local version-manager files (`mise.toml`, `.tool-versions`, `.node-version`, and equivalents), manifest engine/runtime requirements, package-manager pins, CI workflows and matrices, Dockerfiles and Compose, devcontainers, deployment/buildpack configuration, scripts, and setup documentation where present. Follow variables, shared actions, build arguments, and image tags/digests to their source. Record current and target versions with their consumers in context; distinguish exact pins, minimum requirements, and intentional compatibility matrices.

Check current official release and migration documentation for target versions, support status, runtime compatibility, and available platform images. Resolve the runtime, dependency, and image constraints together before edits; do not assume independently newest versions form a working stack.

Delegate independent applications/ecosystems when useful. Before delegating, apply [Subagent roles and reasoning](../execute-plan/references/subagent-reasoning.md) to select a configured child role without repeating its model or effort settings, or changing scope or context restrictions. Keep shared locks, generated outputs, and coupled packages under one owner. Reconcile worker changes and verification before integration.

## Upgrade

- **Runtime/toolchain:** upgrade the environment as part of the task. For Elixir projects, update both Elixir and Erlang/OTP to a supported pair, including the OTP variant of precompiled Elixir builds. Update other discovered project runtimes and package managers, such as Node.js and npm/pnpm/Yarn, within their engine and peer requirements. Install and select the targets with the project's version manager or isolated environment, then verify the actual runtime and tool versions before regenerating locks or running checks. Keep selection project-scoped; do not change machine-wide defaults or live environments. If installation is blocked, report that gap and distinguish configuration edits from execution under the target versions.
- **Mix/Hex:** inspect `mix.exs` and `mix.lock`; run `mix hex.outdated --all`. Read migration notes for breaking/coupled changes, adjust constraints, update with canonical Mix commands, and repair APIs/configuration. An available Elixir/Phoenix dependency updater can perform this work. Update Git dependencies to their intended newer revision; classify path/umbrella dependencies separately. Update and exercise the Tailwind wrapper and standalone binary through project tasks.
- **npm/workspaces:** run `npm outdated --all` or the package-manager equivalent. Upgrade direct dependencies, Tailwind, and plugins to current compatible versions; honor engine and peer requirements. Refresh the transitive tree through canonical tooling, never hand-edit locks. Apply required source, CSS, build, extension-manifest, and test migrations.

Update all discovered consumers of the selected versions in the same change. For CI, align setup actions, matrices, job/service images, and version-dependent caches; upgrade related actions or tooling when required. For Docker, check every build stage, runtime image, build argument, and pinned digest. Ensure Elixir release builder and runner OS, architecture, and native library compatibility; account for OTP/NIF and Node native-addon rebuilds. Update relevant service images and deployment configuration within project support constraints. Verify image/tag availability; do not guess tags or retain a digest for an old image.

Keep local, CI, container, and deployment targets consistent where they serve the same role. Preserve explicit supported-version matrix entries and valid differences between build and runtime images; document their reasons. Adjust manifest minimum requirements only when required by the upgraded code or dependencies. Update setup documentation and examples to match the resulting configuration.

Distinguish outdated-results exit codes from command failures. Track packages held back by constraints, overrides, engines, peers, or upstream availability. Keep notes and inventories in context unless an agent needs files; treat such files as temporary.

## Integrate and verify

Review combined diffs and remove confirmed code, tests, configuration, or documentation made obsolete by the upgrades. Preserve required behavior and explicit supported-version compatibility.

Run repository-required quality gates on the integrated result under the selected runtimes, plus relevant dependency/security audits, builds, and Tailwind checks not already covered. Verify reproducible installs from the updated locks. Where present, build affected container targets and smoke-test the final image/release startup; validate CI configuration and test supported matrix combinations where feasible. Fix upgrade-caused failures and verify repairs; reuse passing results only for unchanged relevant code and environment. Respect authorization boundaries for checks with cost or external effects.

Rerun outdated inventories and recheck version declarations and effective versions against the targets to catch stale pins. Inspect final diffs for coverage and canonical locks.

Before the final report, run [final-pass](../final-pass/SKILL.md) on the complete integrated upgrade, including runtime and environment configuration. Follow its cleanup, full testing and quality checks, evidence-reuse, repair, and stop rules. A failed or blocked required check keeps the upgrade incomplete.

Report package and runtime upgrades, environment consistency, intentional differences, required migrations, held-back items with reasons, and material check results or gaps in short, plain prose. Distinguish local execution, container checks, and hosted CI/deployment evidence. Skip stock headings and repeated summaries; save a user report only if requested. An unavailable required check is not a pass.

## Temporary files

Keep scratch in context unless files serve a concrete agent need; never create them solely for user presentation. Track task-owned paths; remove them after use, including failure or abandonment, and verify cleanup before returning. Retain files only for active agent continuation with a cleanup owner and removal point; report retained paths or cleanup failures. Preserve requested deliverables (including `.local/` plans), pre-existing files, and unrelated work; never delete shared directories wholesale.
