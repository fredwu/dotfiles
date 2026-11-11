---
name: ask-me
description: Find the open decisions in the current context that need the user, ask only the ambiguous, critical, or hard-to-reverse ones with recommendations, record the answers for later skills such as write-plan, and update a plan in context when the questions were about it. Use on explicit invocation.
metadata:
  origin: custom
---

# Ask Me

Align with the user before later work starts. Find the decisions in the current context that need the user, ask only those, and record the result in the conversation. Later skills, such as write-plan, read this record as conversation context. Do not start the later work. Do not change files or external state, except for the plan update below.

Use judgment for scope, number of questions, format, and follow-up. These rules set the bar for a question, not a fixed procedure.

## Find the open decisions

Use the conversation, supplied material, repository instructions, and the code. Investigate read-only only as far as necessary so that you do not ask what the context or the code already answers.

Identify the decisions that the intended work depends on. Make a decision yourself when the context, conventions, or evidence support one option, or when a wrong choice is cheap to correct later. Prefer a reasoned decision to a question.

Ask the user only when one of these conditions applies:

- The context does not resolve the decision, and a wrong choice materially changes scope, acceptance, cost, risk, or authority.
- The decision is very difficult or expensive to reverse, for example data loss, migrations, public interfaces, external commitments, or removal of behavior that people rely on. A clear recommendation does not remove the need to ask. Ask, and give the recommendation.

Do not ask about facts that you can find, routine implementation details, choices that the later work can make with better evidence, preferences with no material effect, or what the user already said.

## Ask

Use the harness's user-input tool when one is available. Otherwise, ask in the response and stop. Make each question stand alone: give the necessary context, the options when they help, your recommendation and its reason, and consequences that are not obvious.

After each set of answers, examine the decisions again. Answers can resolve other decisions or open new ones. Ask the new questions that meet the same bar, and continue until no decision meets it.

Make the status of each response clear. A response either asks the remaining questions, or says clearly that there are no more questions, for example **No more questions.** Do not end a response with questions that are only implied, and do not leave the status unclear.

## Record

When there are no more questions, including when no decision met the bar at the start, give a concise record that later skills can use:

- **Your decisions:** the meaning of each answer and the constraint it sets. An answer that changes scope is a requirement update.
- **Agent decisions:** the material decisions that you made, each with a short reason. These are proposals, not user approval, until the user adopts them. The user can override any of them.
- **Open:** decisions that the user deferred or did not answer, and the assumption that later work uses until the user decides.

Keep the record in the conversation. Write it to a file only when the user asks. Then update the plan if the next section applies, and stop. The user starts the next skill.

## Update the plan

When the context clearly identifies a plan and the questions were about that plan, update the plan when there are no more questions. Do not wait for the user to ask. If a plan seems relevant but it is not clear which plan, do not guess. Say in the record that you did not update it, and why.

Read and apply [Plan standards](../write-plan/references/plan-standards.md) and [Resolve plan requirements](../write-plan/references/requirements.md). Read the whole plan, and edit it in place. If the plan exists only in the conversation, give the updated plan in the response.

Integrate each user decision wherever it has an effect, update `## User requirements` and `## TL;DR`, and remove prose that the answers supersede. Put material agent decisions under the chosen direction or assumptions, not under user requirements. Change only what the answers affect; do not re-plan other parts. Read back the plan and its diff, and check for contradictions.

After the record, summarize the plan changes briefly.
