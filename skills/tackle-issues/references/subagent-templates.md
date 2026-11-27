# Subagent Templates

Prompts for the non-reviewer subagents: implementation, fix and CI analysis, plus verify-command detection, worktree setup and the PR body.

If your agent has no subagents, follow the same prompt yourself, one step at a time. Model choice is up to you: use a strong model for implementation and fixes; a lighter one is fine for CI log parsing.

## Detecting the verify command

Prefer what the project documents. Check, in order:

1. `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CONTRIBUTING.md`, `README`: a "testing" or "development" section.
2. A project test script: `bin/test`, `script/test`, `make test` / `make check`, `just test`, a `test` or `check` script in `package.json`.
3. The CI config (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`): the lint and test steps CI runs are the ones that must pass.

Only if none of these exist, fall back to the ecosystem default:

| Marker file | Typical verify command |
|---|---|
| `package.json` | `npm run lint && npm test` (or the pnpm/yarn/bun equivalent) |
| `pyproject.toml` / `setup.py` | `ruff check . && pytest` |
| `Cargo.toml` | `cargo clippy && cargo test` |
| `go.mod` | `go vet ./... && go test ./...` |
| `Gemfile` | the project's linter plus `bundle exec rspec` or `bin/rails test` |
| `pom.xml` / `build.gradle` | `mvn verify` / `./gradlew check` |

If you still cannot tell, ask the user once rather than guess. Use its parallel form if the project has one (for example a `-n` or `--parallel` flag its docs or CI use).

**One full run per group.** Implementation and fix subagents run `FAST_CMD`, the project's lint plus affected-tests command (the one it runs before a push), and the tests they added or changed, never the full `VERIFY_CMD`. The full `VERIFY_CMD` runs once, in Phase 6, after the review loop exits, through `scripts/run-watched`. If the project has no affected-tests command, `FAST_CMD` is its linter plus the test files the change touches.

## Worktree setup

```bash
git fetch origin
REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH="issues/<group-slug>"
WT="$HOME/.worktrees/$REPO/$BRANCH"
mkdir -p "$(dirname "$WT")"

[ -d "$WT" ] && echo "worktree exists"                                  # ask: resume or recreate
git show-ref --verify --quiet "refs/heads/$BRANCH" && echo "branch exists"  # ask: resume or recreate

git worktree add "$WT" -b "$BRANCH" origin/<default-branch>
```

A fresh worktree often needs setup the main checkout already has: dependency install, generated or compiled assets, environment files, a database. Follow the project's setup docs. When several worktrees run tests at once, give each its own test database or port if the project's test setup allows it; shared test databases are a common source of phantom failures.

Run tests in the foreground, not as background jobs, so the subagent sees the result before it reports.

## Implementation subagent

One per issue, run in order within a group.

```
Implement GitHub issue #<n> in the worktree at <WT>.

Title: <title>
Labels: <labels>
Body:
<body>
<If the issue has a parent: Parent #<n> <title>: <its goal>. Sibling sub-issues are out of scope.>

Project rules (from AGENTS.md / CLAUDE.md / CONTRIBUTING.md):
<conventions summary: commit style, test standards, comment rules, design guide paths, files not to edit>

Check command: <FAST_CMD>

Steps:
1. Read the issue. If anything is unclear, run `gh issue view <n> --comments`.
2. If the change touches UI, read the project's design system or UI guide first and follow it.
3. Write a failing test first and confirm it fails for the expected reason. No production code without a failing test, or a named exception's failing check, that needs it; for a bug, the test reproduces it. Never write a bad test (one that would pass with the code deleted, mostly tests its mocks, or depends on timing). When no good test can reach the behaviour, use the closest repeatable check against the real code instead, show it failing before the change and passing after, and name the exception, why, and the check in NOTES. Only a change with no behaviour (docs, comments, formatting, plain config) skips both, and NOTES must say so.
4. Make the smallest change that fully resolves the issue.
5. Cover new behaviour and its failure paths with tests that assert observable outcomes.
6. Run the check command and the tests you added or changed, in the worktree, in the foreground. Do not run the full suite; that runs once, later. Fix what fails. Then check the real thing: run the changed command, walk the changed flow in the running app, or read back the stored value, and put what you ran and what happened in NOTES.
7. Commit in the worktree using the project's commit style, referencing #<n>.

Do NOT:
- edit files outside this issue's scope, or outside <WT>;
- add unrelated refactors, dependencies, migrations or config changes the issue does not need;
- push, open PRs, or comment on issues;
- report PASS without having run the check command and your tests.

Report:
- FILES_CHANGED
- TESTS_ADDED
- VERIFICATION: PASS or FAIL (with the command and the summary line of its output)
- COMMITS: shas
- NOTES: assumptions, open questions, anything the reviewer should look at
```

After it returns, the orchestrator checks `git status`, `git log origin/<default>..HEAD` and `git diff --stat origin/<default>...HEAD` in the worktree before accepting the report.

## Fix subagent

Used after a review round or a real CI failure. A `review-pr` NOT YET goes to `address-review` instead.

```
Fix the following findings in the worktree at <WT>.

Check command: <FAST_CMD>
Project rules: <conventions summary>

Findings (severity, file:line, problem, suggested fix):
<list>

Before fixing, check whether several findings share one root cause. If they do, fix the cause once.

Steps:
1. Read the relevant files.
2. Fix each finding minimally. If a fix needs a product or design decision, do not guess: report it.
3. Add or adjust tests so each fixed bug would be caught if it came back. Never write a bad test. When no good test can reach the behaviour, use the closest repeatable check against the real code instead, show it failing before the change and passing after, and name the exception, why, and the check in NOTES.
4. Run the check command and the tests you added or changed, in the foreground. Do not run the full suite.
5. Commit with a message that says what was fixed.

Do NOT add features, refactor unrelated code, or touch files unrelated to the findings. Do not push.

Report:
- FIXED: finding -> file:line
- NOT_FIXED: finding -> reason (decision needed, disagree, out of scope)
- VERIFICATION: PASS or FAIL
- COMMITS: shas
- NOTES: any named exception, with its check's output before and after
```

Verify the commits the same way as after implementation.

## CI analysis subagent

```
Analyse the failing CI checks on <PR URL>.

1. `gh pr checks <PR> --json name,state,link`
2. For each failed run: `gh run view <run-id> --log-failed`
3. For each failure, identify: failing test or lint rule, file:line, error message.
4. Classify each: CODE (caused by this PR), PREEXISTING (also fails on the default branch), ENVIRONMENTAL (runner, network, quota, timeout), FLAKY (passes on rerun or is order-dependent).

Report:
- FAILURES: [check] [file:line] [error] [classification] -> [suggested fix]
- ROOT_CAUSE: one sentence
- ACTIONABLE: true only if at least one failure is CODE
```

Only CODE failures go to a fix subagent. Report the rest to the user.

## PR body template

Adapt to the project's own PR template if it has one (`.github/pull_request_template.md`).

```markdown
## Summary
<one paragraph: what changes for users or developers, and why>

## Issues
- #<n>: <title>: <one line on how it is resolved>

Closes #<n>
Closes #<n>

## Changes
- <bullet per meaningful change>

## Exceptions
<from the subagents' NOTES: each behaviour proved by a check instead of a test, why, the check, its output before and after; or "none">

## Real-thing check
<from the subagents' NOTES: what was run on the real thing and what happened>

## Review
Specialist review (correctness, security, tests, simplicity<, UX><, domain>): no open P1/P2 after <k> rounds.
Minor follow-ups: <link to follow-up issue, or "none">
<Known issues, if the user chose to push with open findings>

## Test plan
- [x] <VERIFY_CMD> passes locally
- [ ] CI passes
- [ ] <manual check, if any>
```

Add whatever attribution footer your agent or the project requires.

## Resume detection

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
for wt in "$HOME/.worktrees/$REPO"/issues/*; do
  [ -d "$wt" ] || continue
  branch=$(git -C "$wt" branch --show-current)
  ahead=$(git -C "$wt" rev-list --count origin/<default-branch>..HEAD)
  pr=$(gh pr list --head "$branch" --json url --jq '.[0].url')
  echo "$wt  branch=$branch  commits=$ahead  pr=${pr:-none}"
done
```

Then run the mode's List my claims operation from `issue-tracking.md`.

## Cleanup

Worktrees are kept for inspection. After the PR merges:

```bash
git worktree remove "$HOME/.worktrees/<repo>/issues/<group-slug>"
git branch -d issues/<group-slug>
```
