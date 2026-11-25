# Working rules

Generic defaults for every project. A project's own instructions win where they differ.

## Tests

- **Test first.** Write the failing test first, run it, and confirm it fails for the reason you expect. Then write the least code that makes it pass, then refactor.
- **Every bug fix starts with a reproduction.** See it fail before touching the code.
- **A bad test is worse than none.** It costs upkeep, breaks on harmless refactors, and gives false confidence. A test is bad when it would still pass with the implementation deleted, mostly tests its mocks, depends on timing or shared state, or needs setup out of proportion to the change. Assert observable state or return values; mock only at the system boundary (third-party APIs, network, email, filesystem).
- **When no good test can reach the behaviour, prove it another way.** Use the closest repeatable check against the real code: a script, a repro command, browser automation, an assertion on output or logs. Show it failing before the change and passing after, and name the exception, why no good test fits, and the check in the PR. "Hard to test" is not a reason when a unit or integration test could reach it.
- **Only changes with no behaviour skip both** (docs, comments, formatting, plain config). Name the exception in the commit or PR; never skip silently.
- **No `sleep` in tests.** Wait on a condition (a waiting matcher, a poll with a deadline), never on a fixed delay. Freeze the clock around any assertion about time.

## Done

- **Check the real thing before calling it done.** Passing tests are not enough. Run the changed command, walk the changed flow in the running app, or read back the stored value, and show what happened. A self-report, cached output, or "it compiles" does not count. Script the check when you can, so a reviewer can rerun it.

## Fixes

- **Adversarially review your own fix.** Before calling it done, ask how the fix itself fails: which inputs, states, or callers it now gets wrong. Look for an existing green test that encodes the bug. A fix's failure modes are often worse than the bug it replaces.
- **Attack the premise.** When two fixes that share an assumption both fail the same check, write the assumption down and test it before writing another fix on it.
- **Fix the root cause.** Trace a symptom back to where things first went wrong and fix it there. A guard is a fix only when the state it handles is legitimate.

## Review loops

- **Every review loop needs a finite exit.** Stop when a round finds no serious defects and nothing untrue. Collect the remaining minor findings into one follow-up instead of another round.

## Pull request review

- **After opening or updating a pull request, and before merging it, review it with the `review-pr` skill (https://github.com/JAdshead/toolkit), or, without it, a fresh-context reviewer held to the owner's bar.** Don't report a PR as ready until it passes. It passes only if a fresh-context reviewer, acting as the repo's owner, would merge it as it stands.
- **A behaviour change with no proof that fails without it is not ready to merge.** The proof is a test, or a named exception with a repeatable check seen failing before the change (see Tests).

## Finishing

- **When a session's last pull request merges, clean up before reporting done:** delete the session's merged branches (local and remote) and their worktrees, except the worktree you are running in and its local branch: keep those, and say so; fast-forward the main checkout if it is clean and on the default branch; then offer to archive the session if your tool supports it.

## UI

- **Never call UI work done without seeing it.** Use the `ui-design` skill to screenshot every UI change, and to critique all but small changes inside an existing look (setting a new look's direction first).
- **A UI pull request shows what changed.** Attach its screenshots, and a GIF of each changed interaction, with the `pr-media` skill, and merge it only after the owner's visual sign-off.

## Terminology

- **When a domain term in a prompt is vague, overloaded, or used differently from the project's glossary, and its meaning would change what you do, use the `glossary` skill** to settle it with the user rather than guessing what they meant.

## Communication

- **Show plans and decisions, don't write them.** Whenever you present a plan, compare options, or need the user to decide or approve, use the `visual-plan` skill: shape first, one decision at a time, clickable choices, and a quick quiz before approving a plan.
