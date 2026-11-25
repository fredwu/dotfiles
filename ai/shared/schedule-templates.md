# Pre-Check-Gated Scheduled Task Templates

Draft-only templates for optional recurring T3 Code `/schedule` tasks. None are enabled automatically; activate only the ones you want, and delete any routine whose output you did not act on over the last month.

Every scheduled routine must follow three rules:
1. **Deterministic pre-check first:** compare a cheap signal (git HEAD, `mix hex.audit`, outdated deps count, CI status) against stored state; if unchanged or clean, log `no_change` and stop immediately without exploring.
2. **Draft-only stop:** unattended runs cannot answer interactive approvals; stop at a saved `.local/` report or issue draft—never push, deploy, migrate, or send external messages.
3. **Silent when nothing changed:** report only actionable changes.

## 1. Weekly Dependency & Security Audit (Hourbun / Inspiria)
- **Suggested cadence:** Weekly (e.g. `0 9 * * 1`, Monday 09:00 local).
- **Pre-check:** Run `mise exec -- mix hex.audit && npm audit --prefix assets --audit-level=moderate` (Hourbun) or `direnv exec . mix hex.audit && npm audit --prefix assets --audit-level=moderate` (Inspiria).
- **Stop rule:** If both commands exit 0 with no advisories, log `no_change` and stop immediately. Do not open source files or take a quick look around.
- **Draft output:** When advisories appear, save a short summary to `.local/YYMMDD-dep-audit-report.md` listing package, severity, and recommended action.

## 2. Weekly Hygiene & Drift Check (Hourbun / Inspiria)
- **Suggested cadence:** Weekly (e.g. `0 8 * * 5`, Friday 08:00 local).
- **Pre-check:** Compare `git rev-parse HEAD` against `.local/.last-hygiene-sha`. If unchanged, log `no_change` and stop immediately. Do not explore.
- **Draft output:** Record the new SHA, run `scripts/verify full` (read-only), and if anything fails or stale `.local/*-plan*.md` files exceed 30 days, write a ≤15-line summary of findings without editing code or deleting files.

## 3. Monthly AI Discoverability Prompt Check (Hourbun)
- **Suggested cadence:** Monthly (e.g. `0 9 1 * *`, 1st of the month).
- **Pre-check:** Read `docs/operations/discoverability.md` for the prompt-check checklist and last recorded run date; if already checked within the current calendar month, log `no_change` and stop.
- **Draft output:** Save the draft findings to `.local/YYMMDD-discoverability-check.md` for owner review; never publish or submit external directory forms automatically.
