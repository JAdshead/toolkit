# Working rules

Generic defaults for every project. A project's own instructions win where they differ.

## Tests

- **TDD by default.** Write the failing test first, run it, and confirm it fails for the reason you expect. Then write the least code that makes it pass, then refactor. If you can't test first, say so in the commit or PR rather than skipping it silently.
- **No `sleep` in tests.** Wait on a condition (a waiting matcher, a poll with a deadline), never on a fixed delay. Freeze the clock around any assertion about time.
- **A test that would still pass with the implementation deleted is broken.** Assert observable state or return values; mock only at the system boundary (third-party APIs, network, email, filesystem).

## Fixes

- **Adversarially review your own fix.** Before calling it done, ask how the fix itself fails: which inputs, states, or callers it now gets wrong. Look for an existing green test that encodes the bug. A fix's failure modes are often worse than the bug it replaces.

## Review loops

- **Every review loop needs a finite exit.** Stop when a round finds no serious defects and nothing untrue. Collect the remaining minor findings into one follow-up instead of another round.

## Pull request review

- **Before merging a pull request, review it with the `review-pr` skill.** It passes only if a fresh-context reviewer, acting as the repo's owner, would merge it as it stands.

## Terminology

- **When a domain term in a prompt is vague, overloaded, or used differently from the project's glossary, and its meaning would change what you do, use the `glossary` skill** to settle it with the user rather than guessing what they meant.
