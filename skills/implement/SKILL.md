---
name: implement
description: Implement a GitHub issue or a spec/proposal change end to end. Works in an isolated git worktree, test-first (red, green, refactor), runs the project's full local checks, then has independent security, code-quality and test-quality reviewers check the diff and loops on their findings. Opens a pull request and watches CI only after the user confirms. Use when the user asks to implement, build or ship a specific issue, ticket or change, or says "implement #N".
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
5. **Board mode.** If the repository has `.github/agent-board.json`, claim the issue on the project board before writing any code, so parallel agents do not pick it up. Use the `board` script in the tackle-issues skill (`../tackle-issues/scripts/board` from this file; its Board mode section explains the board). The agent id is `implement/<id>@$(hostname -s)`.
   ```bash
   board claim "implement/<id>@$(hostname -s)" <id>
   ```
   - The claim fails if another agent holds the issue: stop and tell the user who has it.
   - It also fails if the issue is not in Ready. Ask the user whether to approve it; on their yes, run `board approve <id>`, then claim it.
   - Later steps: `board move <agent> "In review" <id>` at Phase 3, `Verifying` after the PR is opened, and `"Ready to merge"` when CI is green. If you stop without a PR, `board release <agent> <id>`.
   - With `--resume`, re-run the same claim: claiming an issue you already hold succeeds and leaves its status alone.

## Phase 2: Implement test-first

Delegate this to one implementation subagent if your tool supports them (for example Claude Code's Task/Agent tool); this keeps the orchestrating context small. Otherwise do it yourself. Pass: the worktree path, the full requirement text, the discovered commands, and these instructions:

> Work in small cycles:
> 1. **Red:** write a failing test for the next requirement, at the right level (unit, integration or end-to-end). Run it and confirm it fails for the reason you expect, not a typo or setup error.
> 2. **Green:** write the least code that makes it pass.
> 3. **Refactor:** clean up with the tests green.
>
> Repeat until every requirement and acceptance criterion is covered. Never write production code without a failing test first; never weaken an assertion to make a test pass. If something genuinely cannot be tested first, say so explicitly.
>
> For a spec/proposal change, work through its task list in order and tick items off as they are done, committing the task list with the code.
>
> Finish by running the project's full local gate (lint, security audit, all test suites, coverage floor). Commit with a message that says what changed and why.
>
> Return: FILES_CHANGED, TESTS_ADDED (noting which were written before the code they test), VERIFICATION (PASS/FAIL with the relevant output), COMMIT_SHA.

If verification fails, show the output and ask the user whether to keep fixing or stop.

## Phase 3: Review

Get the diff: `git -C <worktree> diff origin/<default-branch>...HEAD`.

Run three reviewers in parallel (separate subagents where supported, otherwise three separate passes). Give each the diff and changed-file list, and the code, not your own conclusions, so the review is not anchored on yours. Each returns `VERDICT: PASS|FAIL` and findings as `[severity] [file:line] description`.

1. **Security:** injection, XSS, CSRF, mass assignment, authentication and authorization on every entry point, secrets in code, unsafe redirects, file upload handling, sensitive data in logs. FAIL on any CRITICAL or HIGH.
2. **Code quality:** readability, the project's conventions, duplication, single responsibility, error handling, query efficiency (N+1, missing indexes). FAIL needs a HIGH finding.
3. **Test quality:** every new public behaviour is tested on the happy path, edge cases and error paths; tests exercise real logic. Mocking the subject under test, tautological tests and assertion-free tests are automatic FAILs. Test names describe behaviour.

Consolidate:

- **Any FAIL:** show the findings, then fix the CRITICAL and HIGH ones under the same TDD rules (a regression test first where it applies), rerun the full local gate, and rerun only the reviewers that failed. Also ask how each fix could itself fail.
- **Exit rule:** stop when no reviewer fails and nothing in the diff is untrue, or after 3 rounds. Collect remaining MEDIUM/LOW findings into one follow-up note or issue rather than another round.

## Phase 4: Pull request

Pushing and opening a PR are visible to others. **Ask the user before pushing**, unless the project's instructions or the user's request already say to open the PR. Then:

```bash
git -C <worktree> push -u origin implement/<id>
gh pr create --title "<concise title>" --body "<body>"
```

The body has: a Summary (what and why), a Test plan listing the tests added, and a closing reference to the issue (for example `Closes #<n>`) or a pointer to the spec/proposal change. Follow the project's PR template if it has one.

## Phase 5: CI loop

```bash
gh pr checks <pr> --watch
```

- **Red:** read the failing job's log (`gh run view <run-id> --log-failed`), diagnose the root cause (a real failure, not something to retry away), fix test-first where it applies, push, and watch again. Stop after 3 rounds and report.
- **Green:** report the PR URL and stop. **Never merge**; that is the user's call unless the project's instructions say otherwise.

## Phase 6: Report

```
## Implementation complete
Source:   <issue or change id>
PR:       <url> (CI: green | red | not opened)
Reviews:  security PASS / quality PASS / tests PASS (rounds: n)
Tests:    <n> added, <n> written before their code
Coverage: <n>% (floor: <n>%)
Follow-ups: <remaining minor findings, or none>

Next: review and merge the PR, then archive the change if the project's workflow requires it.
Worktree: <path>
Remove after merge: git worktree remove <path>
```

## Guardrails

- Keep the change scoped to the requested outcome; prefer the simplest implementation that meets it.
- Production code is written only to make a failing test pass.
- Fix security findings above LOW before the PR is opened.
- Mock only at the system boundary; mocking internal code is a review failure.
- Never merge, force-push over requested changes, or skip hooks without the user's say-so.
- On an unrecoverable failure, report what was done, what failed, and the worktree path for manual recovery.
