# Check evidence and reuse

Apply this policy during implementation, review-loop verification, and every `final-pass` checkpoint. Required gate coverage stays the same. A checkpoint can use a passing result from an earlier checkpoint in the same task when the evidence still applies to the current state.

## Record evidence

Keep a concise record in task context for each gate:

- the exact command, options, working directory, result, and originating checkpoint or run;
- the checked source, tests, generated files, configuration, dependencies, and relevant transitive inputs, identified by content hashes or another reliable state comparison;
- the runtime and tool versions and relevant environment, services, fixtures, and input data state.

Record relevant environment identities or non-secret values only. Do not store credentials. A commit ID alone is insufficient when relevant dirty or untracked files exist. Logs and file-based evidence follow the calling skill's temporary-file rules.

## Decide whether to reuse

Reuse only a passing result whose required command and all relevant inputs remain unchanged, with a known dependency boundary. A read-only review that leaves those inputs unchanged does not invalidate test evidence. A source edit invalidates the checks that depend on it; unaffected checks can remain valid. Rerun a full gate when its dependency boundary cannot be established safely.

Rerun when evidence or input identity is missing, a relevant tool, dependency, environment, service, fixture, or data state changes, or the check depends on time or mutable state whose equivalence cannot be established. Rerun flaky or otherwise unreliable checks. Follow an explicit instruction to execute a fresh check. A required full suite still needs a full-suite passing result; targeted results cannot stand in for it.

Recheck applicability at the current checkpoint and after repairs. Treat reused evidence as passing coverage with its original run identity; report it as `reused`, never newly executed or skipped. Failed, blocked, partial, or unknown results cannot be reused as passing evidence. Preserve the reason and authorization boundary for an actual skip or blocker.

## Keep review status separate

Check evidence does not establish review coverage. Any task edit after a review invalidates that review as evidence for the resulting state, even when some passing checks remain reusable. Follow the selected loop's next-round and closing rules, and preserve capped or incomplete review status. Never use test reuse to omit a required review or to claim that an earlier review inspected a later state.
