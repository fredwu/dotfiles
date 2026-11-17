# UI mockups

Before you implement a new or significant UI/UX change, draft several mockups, compare them, and implement the best direction. The agent makes the selection; the user does not review mockups unless they ask.

## When to apply

Apply this to a new screen, flow, or significant component; a change to layout, navigation, or information hierarchy; or a change to how users interact with a feature.

Do not apply it to copy changes, small style fixes, bug fixes that keep the current design, or changes that follow an existing pattern in the product. When the user or the plan specifies a design, implement that design. Explore only the decisions it leaves open.

## Draft

- Inspect the existing UI, design tokens, components, and any project design guidance first. Load a relevant design skill when one applies.
- Draft three directions that differ in a material way, such as structure, hierarchy, or interaction model. Do not draft small variants of one idea.
- Make each mockup a static HTML page that uses the project's real tokens, components, and content where practical. For a terminal or native UI, use the nearest equivalent, such as a text wireframe or a platform preview.
- Show the states that matter: typical content, empty, loading, error, and a narrow viewport where relevant.
- Independent drafts reduce anchoring. When delegation is worth its cost, draft the directions in parallel agents under [Subagent roles and reasoning](subagent-reasoning.md). Otherwise draft them in sequence. A delegated agent drafts in sequence unless its parent authorizes children, and reports the selected direction to its parent.

## Select

Render each mockup and examine a screenshot, not only its markup. Inside T3 Code, render with the preview tools; otherwise use an available browser tool. Score each direction on:

- Fit to the task and to the user's goal.
- Clarity of the visual hierarchy and of the primary action.
- Consistency with the existing product and design system.
- Coverage of the states above, accessibility, and responsiveness.
- Implementation cost and risk.

Select the best direction, or combine the strongest parts of several directions into one. Record the selected direction and a one-line reason in context.

## Implement and check

Implement the selected direction. Before the phase final-pass, render the real UI and compare it with the selected mockup. Correct material differences, or record why the implementation must differ.

Mockups are temporary files under [Temporary files](../SKILL.md#temporary-files). In the final report, give the selected direction in one line.
