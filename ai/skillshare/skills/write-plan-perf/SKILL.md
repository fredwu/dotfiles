---
name: write-plan-perf
description: Save a performance audit plan for project-owned code, covering runtime latency, data access, concurrency, rendering lifecycles, and test-suite value and speed. Use only on explicit invocation, for periodic audits after feature work.
metadata:
  origin: custom
---

# Write Plan Perf

Audit the app's runtime performance and the test suite's value and speed, and save a prioritized plan. Apply [write-plan](../write-plan/SKILL.md) in full and the [audit plan rules](../write-plan/references/audit-plans.md), with the rules below. The default topic is `perf-audit`. Save the plan; do not execute it.

## Measure

Base findings on measurement where you can. This skill extends `write-plan`'s read-only checks:

- Run the project's own local test and quality commands with timing or profiling options, such as `mix test --slowest 50` or per-file Jest timings, against the existing local test environment. Build outputs, test databases, and tool caches are acceptable side effects. Do not change tracked files, and do not run coverage.
- Query already-configured CI and observability tools read-only, for job and step durations, slow transactions, and query timings. Create no notes, dashboards, triggers, or reruns.
- Do not start dev or production servers, native builds, simulators, or devices. Do not deploy, make billed external calls, or change shared or remote state.

When a measurement is unavailable, unsafe, or too slow, use static evidence, label estimates, and make baseline capture an early phase outcome. Account for run-to-run variance; do not claim small differences.

## App performance

Examine the lenses that apply to the stack:

- **Data access:** N+1 and repeated queries, missing or unused indexes, over-fetching, unbounded or unpaginated reads, transaction scope, and pool sizing. For example, Ecto preloads and query shape, or client request waterfalls and duplicate fetches.
- **Hot paths:** synchronous external calls, repeated expensive work, serialization, and payload and asset size.
- **Concurrency:** blocking work on request, render, or UI threads; serial work that can run concurrently; single-process bottlenecks; queue concurrency, timeouts, and back-pressure. For example, GenServer serialization, `Task.async_stream`, and Oban queue limits, or JS-thread blocking in React Native.
- **Rendering and lifecycle:** for LiveView, work repeated across the disconnected and connected mount, `mount` versus `handle_params`, async assigns, streams versus large assigns, broken change tracking, and PubSub subscription scope. For React or React Native, unnecessary re-renders, effect dependencies and cleanup, list virtualization, and startup and bundle cost.
- **Background work:** idempotency under retries, and batched versus per-item work.

Rank findings by evidenced user-facing or resource impact and confidence, against effort and risk. Leave out speculative micro-optimizations. A cache needs an invalidation and consistency approach. A concurrency change needs a correctness argument for ordering, transactions, idempotency, and test isolation. Behavior, security boundaries, and data guarantees stay unchanged.

## Test suite

Judge the suite by the confidence it gives for changes and refactors, not by test count or coverage. It must protect behavior contracts, boundaries, regressions, security, data integrity, and concurrency.

- **Coverage:** remove coverage measurement and the rules around it: tooling and dependencies, test configuration, CI jobs, partitions, caches, and gates, artifacts and ignore entries, thresholds, and coverage rules in instructions and documentation. Do not add coverage tooling.
- **Value:** classify tests as keep, merge, move to a faster layer, or delete. Delete candidates include redundant or cross-layer duplicates, tests of framework, library, or upstream behavior, implementation-detail tests, trivial assertions, and superseded tests. Each deletion names the surviving test or contract that covers its behavior, or says why the behavior needs no test. A drastic reduction is acceptable when this holds.
- **Browser and device tests:** keep a small set for flows that need a real browser or device, such as JS hooks, browser or native APIs, and critical cross-page journeys. Move the rest to faster layers, such as LiveView, request, or component tests, or React Native Testing Library and Jest integration tests.
- **Speed:** parallelism and its isolation blockers, setup and fixture cost, sleeps and polling that deterministic synchronization can replace, timeouts, external-call stubs, compile cost, and CI partitioning, caching, and job layout.
- **Reliability:** flaky and nondeterministic tests are findings.

## Plan content

Include a baseline table with each metric, its value, method, and source, and mark estimates. Give each finding its expected effect, and write acceptance criteria that re-measure with the same method.

Remove a test that guards code the plan changes only after its replacement or the change lands. Remove coverage gates and the instructions or documentation that require them in the same phase.
