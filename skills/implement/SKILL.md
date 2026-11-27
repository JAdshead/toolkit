---
name: implement
description: Implement a GitHub issue or a spec/proposal change end to end. Works in an isolated git worktree, test-first (red, green, refactor), runs the project's full local checks, then has independent security, code-quality and test-quality reviewers check the diff and loops on their findings. Opens a pull request only after the user confirms, then hands it to review-pr, which reads CI when it needs it. Use when the user asks to implement, build or ship a specific issue, ticket or change, or says "implement #N".
license: MIT
metadata:
  tags: implement worktree tdd review pull-request ci
---

# Implement

Take one issue or change from requirement to a reviewed, green pull request:

- an isolated git worktree, so the main checkout stays clean
- test-driven development
- independent reviews for security, code quality and test quality
- a PR and a CI fix loop, with the user deciding when to push, open and merge

A project's own instructions (AGENTS.md, CLAUDE.md, GEMINI.md, CONTRIBUTING) win wherever they differ from this skill.

## Input

`implement <id>`, where `<id>` is:

- **An issue:** `#42` or `42`. Read it with `gh issue view 42 --json title,body,labels,comments` (or the project's tracker).
- **A spec/proposal change:** if the project has a spec or proposal workflow (a `changes/`, `proposals/` or `rfcs/` folder, or a CLI for it), use that workflow's ID and follow its rules for reading, ticking off tasks and archiving.

For an issue, settle the repo's issue-tracking mode, simple or project, from `references/issue-tracking-mode.md`, and use that mode's Read context, Claim, In review and Release operations from `references/issue-tracking.md` in the phases below. If the issue is a parent with open sub-issues, list them and ask which one to implement.

With no argument, list open issues (and pending changes, if such a workflow exists) and ask the user to pick.

**Resume:** `implement <id> --resume` skips setup and continues in the existing worktree for `<id>`.

## Phase 1: Setup

1. Validate, in parallel where the tool allows:
   - the source exists and you have its full text, including acceptance criteria
   - the working tree is clean (`git status --porcelain` is empty)
   - the forge CLI is authenticated (`gh auth status`) if a PR will be opened
2. Discover the project's commands rather than assuming a stack. Read the project instructions, README, `Makefile`, `package.json` scripts, `bin/` or `script/` folders and CI workflow files to find: dependency install, test (unit and integration), lint/format, security audit, and the single "run everything" gate if one exists. Note the default branch and any coverage floor.
3. Create the worktree from the latest default branch:
   ```bash
   git fetch origin
   git worktree add <worktree-dir>/<id> -b implement/<id> origin/<default-branch>
   ```
   Use the project's worktree location if it has one; otherwise a sibling directory outside the repo. Then run the install and setup steps found above. If the project shares a resource between checkouts (a test database, a port), isolate it for this worktree.
4. If the branch or worktree already exists, stop and suggest `--resume` or the cleanup commands.
5. Claim the issue with the mode's Claim operation before writing any code. Asking for `implement <id>` is consent to claim it: don't ask, just say it in one line ("Claiming #42 as implement/42@studio"). The mode's "Before claiming" checks still apply, including its question before making an issue ready. With Agent claims, which go through `scripts/board`, the agent id is `implement/<id>@$(hostname -s)`. If someone else holds it, stop and tell the user who. With `--resume`, re-run the claim.

## Phase 2: Implement test-first

Delegate this to one implementation subagent if your tool supports them (for example Claude Code's Task/Agent tool); this keeps the orchestrating context small. Otherwise do it yourself. Pass: the worktree path, the full requirement text, the discovered commands, and these instructions:

> Work in small cycles:
> 1. **Red:** write a failing test for the next requirement, at the right level (unit, integration or end-to-end). Run it and confirm it fails for the reason you expect, not a typo or setup error.
> 2. **Green:** write the least code that makes it pass.
> 3. **Refactor:** clean up with the tests green.
>
> Repeat until every requirement and acceptance criterion is covered. Write no production code until a failing test, or a named exception's failing check, needs it; never weaken an assertion to make a test pass. For a bug, the first test reproduces it. Never write a bad test (one that would pass with the code deleted, mostly tests its mocks, or depends on timing). When no good test can reach the behaviour, use the closest repeatable check against the real code instead, show it failing before the change and passing after, and name the exception and why in EXCEPTIONS, for the PR. Only a change with no behaviour (docs, comments, formatting, plain config) skips both, and the commit says so.
>
> For a spec/proposal change, work through its task list in order and tick items off as they are done, committing the task list with the code.
>
> Finish by running the project's full local gate (lint, security audit, all test suites, coverage floor). Then check the real thing: run the changed command, walk the changed flow in the running app, or read back the stored value, and keep the output. Commit with a message that says what changed and why.
>
> Return: FILES_CHANGED, TESTS_ADDED (noting which were written before the code they test), EXCEPTIONS (each behaviour proved by a check instead of a test: why, the check, its output before and after), VERIFICATION (PASS/FAIL with the relevant output), REAL_CHECK (what you ran on the real thing and what happened), COMMIT_SHA.

If verification fails, show the output and ask the user whether to keep fixing or stop.

## Phase 3: Review

Get the diff: `git -C <worktree> diff origin/<default-branch>...HEAD`.

Run three reviewers in parallel (separate subagents where supported, otherwise three separate passes). Give each the diff and changed-file list, and the code, not your own conclusions, so the review is not anchored on yours. Also give the Test quality reviewer the subagent's EXCEPTIONS. Each returns `VERDICT: PASS|FAIL` and findings as `[severity] [file:line] description`.

1. **Security:** injection, XSS, CSRF, mass assignment, authentication and authorization on every entry point, secrets in code, unsafe redirects, file upload handling, sensitive data in logs. FAIL on any CRITICAL or HIGH.
2. **Code quality:** readability, the project's conventions, duplication, single responsibility, error handling, query efficiency (N+1, missing indexes). FAIL needs a HIGH finding.
3. **Test quality:** every new public behaviour is tested on the happy path, edge cases and error paths; tests exercise real logic. In place of a test, accept an exception named with a repeatable check and its output before and after; an exception that a good test could reach is HIGH and a FAIL. Mocking the subject under test, tautological tests and assertion-free tests are automatic FAILs. Test names describe behaviour.

Consolidate:

- **Any FAIL:** show the findings, then fix the CRITICAL and HIGH ones under the same test rules (for a bug, a reproduction first), rerun the full local gate, and rerun only the reviewers that failed. When a fix is proved by a named exception, add it to EXCEPTIONS so the rerun reviewers and the PR body see it. Also ask how each fix could itself fail.
- **Exit rule:** stop when no reviewer fails and nothing in the diff is untrue, or after 3 rounds. Don't run another round for the MEDIUM/LOW findings that remain: fix the worthwhile ones in this change, rerun the full local gate, and drop the rest. Never file them as an issue. Only a real bug a reviewer saw in code unrelated to the change becomes one: offer it to the user as an issue.

## Phase 4: Pull request

Pushing and opening a PR are visible to others. **Ask the user before pushing**, unless the project's instructions or the user's request already say to open the PR. Then:

```bash
git -C <worktree> push -u origin implement/<id>
gh pr create --title "<concise title>" --body "<body>"
```

The body has: a Summary (what and why), a Test plan listing the tests added, any exceptions with their checks and before-and-after output, and the real-thing check and its result, and a closing reference to the issue (for example `Closes #<n>`) or a pointer to the spec/proposal change. Follow the project's PR template if it has one. If the change touches UI, run the `pr-media` skill to capture it and attach the screenshots and GIFs to the PR. Then apply the mode's In review operation.

## Phase 5: Review and CI

Once the PR is open, hand off to the `review-pr` skill now, for the merge decision; it reads CI when it needs it, as `references/ci-status.md` says. Then report. **Never merge**; that is the user's call unless the project's instructions say otherwise.

- **Red CI** (unless the host handles CI failures, as that file says): read the failing job's log (`gh run view <run-id> --log-failed`), diagnose the root cause (a real failure, not something to retry away), fix test-first (a reproduction of the failure, unless the fix has no behaviour: docs, comments, formatting, plain config), push, and run `review-pr` again. Stop after 3 rounds and report.

## Phase 6: Report

```
## Implementation complete
Source:   <issue or change id>
PR:       <url> (CI: green | red | not opened)
Reviews:  security PASS / quality PASS / tests PASS (rounds: n)
Owner:    MERGE | NOT YET at <short sha> (review-pr rounds: n)
Tests:    <n> added, <n> written before their code
Coverage: <n>% (floor: <n>%)
Follow-ups: <n fixed here, n dropped; unrelated bugs offered as issues, or none>

Next: merge the PR (your call), then archive the change if the project's workflow requires it.
Worktree: <path>
Remove after merge: git worktree remove <path>
```

## Guardrails

- Keep the change scoped to the requested outcome; prefer the simplest implementation that meets it.
- Production code is written only to make a failing test, or a named exception's failing check, pass.
- Fix security findings above LOW before the PR is opened.
- Mock only at the system boundary; mocking internal code is a review failure.
- Never merge, force-push over requested changes, or skip hooks without the user's say-so.
- On an unrecoverable failure, report what was done, what failed, and the worktree path for manual recovery, and release the issue claim.
