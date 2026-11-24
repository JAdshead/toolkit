# Working rules

Generic defaults for every project. A project's own instructions win where they differ.

## Tests

- **TDD, always.** Write the failing test first, run it, and confirm it fails for the reason you expect. Then write the least code that makes it pass, then refactor. No production code without a failing test that needs it.
- **Every bug fix starts with a test that reproduces it.** See it fail before touching the code.
- **Only changes with no behaviour skip the test** (docs, comments, formatting, plain config). Name the exception in the commit or PR; never skip silently.
- **No `sleep` in tests.** Wait on a condition (a waiting matcher, a poll with a deadline), never on a fixed delay. Freeze the clock around any assertion about time.
- **A test that would still pass with the implementation deleted is broken.** Assert observable state or return values; mock only at the system boundary (third-party APIs, network, email, filesystem).

## Fixes

- **Adversarially review your own fix.** Before calling it done, ask how the fix itself fails: which inputs, states, or callers it now gets wrong. Look for an existing green test that encodes the bug. A fix's failure modes are often worse than the bug it replaces.

## Review loops

- **Every review loop needs a finite exit.** Stop when a round finds no serious defects and nothing untrue. Collect the remaining minor findings into one follow-up instead of another round.

## Pull request review

- **After opening or updating a pull request, and before merging it, review it with the `review-pr` skill.** Don't report a PR as ready until it passes. It passes only if a fresh-context reviewer, acting as the repo's owner, would merge it as it stands.
- **A behaviour change with no test that fails without it is not ready to merge.**

## Finishing

- **When a session's last pull request merges, clean up before reporting done:** delete its branch (local and remote) and its worktree, fast-forward `main` in the main checkout if it is clean, then offer to archive the session.

## UI

- **Never call UI work done without seeing it.** Use the `ui-design` skill to build, screenshot and critique UI changes.

## Terminology

- **When a domain term in a prompt is vague, overloaded, or used differently from the project's glossary, and its meaning would change what you do, use the `glossary` skill** to settle it with the user rather than guessing what they meant.
