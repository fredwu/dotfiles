# Check evidence and reuse

Apply this policy to implementation checks, review-loop verification, and every final-pass checkpoint. It never reduces the required gates. A later checkpoint in the same task can reuse a passing result when that result still applies to the current state.

## Record

For each gate, keep a short record in context: the exact command, options, and working directory; the result; the checkpoint or run that produced it; and the state it checked. Identify the state so that later changes are detectable, for example the commit plus the dirty and untracked files, or content hashes. A commit ID alone is not enough when relevant files are dirty or untracked. Note relevant runtime, tool, service, fixture, or data versions when they can change. Record only non-secret values, never credentials. Logs follow the calling skill's temporary-file rules.

## Reuse or rerun

Reuse a passing result only when its command and every relevant input are unchanged and you know what the check depends on. A read-only review does not invalidate check evidence. A source edit invalidates the checks that depend on it; unaffected checks stay valid.

Rerun when:

- the evidence or input identity is missing, or the dependency boundary is unclear;
- a relevant tool, dependency, environment, service, fixture, or data state changed;
- the check depends on time or mutable state that you cannot show to be equivalent;
- the check is flaky or otherwise unreliable;
- the user asks for a fresh run.

Targeted results never stand in for a required full suite. Failed, blocked, partial, or unknown results are never reusable passes. Recheck applicability at each checkpoint and after repairs. Report reused evidence as `reused` with its original run, never as newly executed or skipped, and keep the reason and authorization boundary of any real skip or blocker.

## Review status is separate

Check evidence never proves review coverage. A task edit after a review means that review does not cover the resulting state, even when checks stay reusable. Follow the loop's next-round and closing rules, and keep capped or incomplete review status. Never use check reuse to skip a required review or to claim that an earlier review saw a later state.
