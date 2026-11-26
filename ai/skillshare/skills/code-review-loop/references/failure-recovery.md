# Recover failed attempts

Failure-recovery and retry policy for [code-review-loop](../SKILL.md) and delegated review runtimes.

## Normalize format without retrying

Assess content, not format. Normalize prose, Markdown, or missing bookkeeping yourself without another model call, and keep useful partial findings without inventing missing inspection.

## Retry budget and per-reviewer tracking

For a model-capacity, rate-limit, API, launch, transport, timeout, authentication, workspace failure, or incomplete required coverage in an otherwise successful response:

- Record the cause and retain any useful partial findings.
- Retry the same round against the unchanged target with the same scope, provider, model, options, and broad/focused purpose. A failed broad review stays a broad review on retry.
- Use up to **three attempts per round** unless the user says otherwise.
- In a multi-reviewer panel, track attempts and failures per reviewer independently: retry only failed reviewer(s) against the unchanged target without discarding or re-running other reviewers' completed inspections from that round.
- For transient failures, follow retry-after guidance or use increasing delays within the budget. For configuration or access failures, fix the cause before retrying; mark that reviewer `blocked` if required input or access is unavailable.
- A user cancellation stops work. Do not duplicate active calls or switch providers silently.
- If attempts or time budget run out for a reviewer, mark it `blocked` for the rest of this loop stage and record its cause and any useful partial findings.

## Round-count accounting

Once every reviewer assigned to a round has either completed its inspection or become `blocked`:

- Assess all completed findings together with any retained useful partial findings before deciding whether to repair, schedule another round, or close (never counting a failed or partial inspection toward completed coverage or round count).
- If at least one reviewer completed an inspection, charge **one shared round**.
- If every reviewer assigned to that round became `blocked` (zero completed inspections), do **not** advance or charge the round: after assessing retained partial findings, recompute eligibility among remaining non-blocked reviewers at that same round number (for example, scheduling remaining non-blocked reviewers that still lack broad coverage).
- If no non-blocked reviewer remains anywhere in the stage (including a single-reviewer loop whose reviewer is blocked), stop the stage as `incomplete` without advancing past an uncompleted round or claiming the round cap was reached.

## Transport coordination

Track round and attempt separately. T3 launch keys and task replacement follow [T3 Code review coordination](../../code-review/references/t3-runtime.md); with ACP, use a fresh session after a confirmed failure. A permitted transport fallback stays in the same round and attempt budget.
