# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in any repository.

## Code Editing Defaults

- Prefer clear code over explanatory inline comments.
- Add an inline comment only when it captures intent, a constraint, or a non-obvious tradeoff that the code cannot express clearly.
- Do not add TODOs or temporary commentary unless the user explicitly asks for them.

## Rules to Follow

STRICTLY, ALWAYS follow the rules below when writing code, unless you are explicitly told to do otherwise:

- Avoid inline comments unless they explain intent the code cannot express clearly.
- Do NOT commit code to git unless you're explicitly told to.
- Always implement logic fully, do not leave TODOs or comments about unfinished code unless explicitly told to.
- Refactor only when required by the requested change or when it clearly reduces risk within the touched scope.
- Always check what and how things are implemented in the code base already to ensure you follow its convention and patterns.
- Remove unused code introduced or made obsolete by the requested change; leave unrelated cleanup alone.

In general, you should also follow these rules, unless you have good reasons not to:

- Always aim for simplicity over complexity, and ensure high maintainability and readability.
- Be thorough and grounded - especially when calling functions, etc, always check the code base and/or documentation to ensure you know exactly how things work, instead of guessing or making assumptions.
- When a task is complex, investigate thoroughly and think deeply about the problem and problem solving, break them down into manageable steps. Run the tests to ensure you haven't broken anything.
- If there is a command for a task (such as db migration), use it instead of creating the file from scratch so we have consistent filenames with correct timestamps.
- When running tests, if you need to run commands such as db migration, ensure you run it in the right environment, e.g. for Elixir Phoenix projects, `MIX_ENV=test mix ...`.
- Do not make changes you haven't been asked to, such as removing code or comments.
- For compiled languages such as Elixir, make sure the code compiles (e.g. `mix compile`), and run the tests to ensure everything works as expected (when the changes are significant, run the entire test suite).

@RTK.md
