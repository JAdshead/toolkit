---
name: address-review
description: Turn a review-pr NOT YET verdict into a fix. A fresh subagent that never wrote the code either patches the confirmed findings or re-solves the PR's problem from the base branch, and the orchestrator keeps a re-solve only if it passes its checks and is smaller or simpler than the current diff. Use from review-pr Part 4 or ship-pr, when review-pr returns NOT YET.
license: MIT
metadata:
  tags: pull-request code-review fix-loop fresh-context
---

# Address Review

Solve `problem.md` so that the confirmed findings cannot arise. The current diff is one candidate, not the starting point.

The author fixing their own findings stays anchored on their design and patches around it, so you orchestrate and a fresh subagent writes the fix. Fresh means what it means in `review-pr`'s Fresh context section: no fork, nothing of your reasoning in its prompt. If you cannot start one, stop and tell the user.

## Inputs

From `review-pr` Part 4 or `ship-pr`: the PR number, your worktree on the PR branch (not `review-pr`'s detached scratch worktree), the confirmed blocking findings verbatim (this round's, and every earlier round's), the path to `problem.md`, and the round number.

## 1. Patch or re-solve

- **Patch** when the findings are few, isolated, and in code the problem needs.
- **Re-solve** when this is round 2 or later, the findings cluster in one area, or they sit in code that earlier fixes added (`git log` on those lines) or that the problem doesn't need.

A finding that can only be fixed by going beyond `problem.md` goes to the user, not to a subagent. A finding about the PR's title or description is yours: fix it with `gh pr edit` when you push. A finding about a commit message goes to the user: fixing it would rewrite history, and a squash merge would replace it.

## 2. Patch

Spawn one fresh subagent with the findings verbatim, `problem.md`, the PR's worktree, and the project's test rules (in `AGENTS.md` or `CLAUDE.md`: test first, and a test that would still pass with the fix deleted is broken; when no good test can reach the behaviour, a named exception with a repeatable check seen failing before the fix). Tell it:

> Make the smallest change that fixes these findings and still solves `problem.md`. Delete code rather than add guards where you can. Write a failing test first; for a bug, it reproduces the bug. When no good test can reach the behaviour, follow the project's test rules for an exception. Only a change with no behaviour (docs, comments, formatting, plain config) skips the test, and the commit says so. Commit with a message that says what changed.

## 3. Re-solve

Create a worktree on a new branch from the point the PR branched off, so the result replaces only the PR's own changes: `git worktree add -b <pr-branch>-resolve <scratch>/resolve-<pr> "$(git merge-base origin/<base> <pr-branch>)"`. Spawn one fresh subagent with `problem.md`, the confirmed findings from this and every earlier round, that worktree and the project's test rules. Never give it the old diff, the PR branch or the PR's worktree. Tell it:

> Solve `problem.md` from this base, test-first, with the least code that solves it. These findings were raised against an earlier attempt; your solution must not have them. Commit with a message that says what changed.

## 4. Verify

Do not trust the subagent's report. Run the project's full local checks yourself, read the diff, and check each finding, this round's and earlier ones, is gone and nothing beyond `problem.md` was added.

On a re-solve, compare `git diff --stat origin/<base>...<pr-branch>` with `git diff --stat origin/<base>...<pr-branch>-resolve`. Keep the new one only if its checks pass and it is smaller or simpler; otherwise patch instead (step 2). To keep it, make the PR branch match it in one new commit, so nothing is force-pushed:

```bash
git -C <pr-worktree> restore --source=<pr-branch>-resolve --staged --worktree :/
git -C <pr-worktree> commit -m "<what changed>"
```

If you re-solved, remove its worktree and branch (`git worktree remove --force <scratch>/resolve-<pr>`, `git branch -D <pr-branch>-resolve`).

If a patch fails the checks or leaves a finding in place, stop: show the user what failed and don't push.

Then ask the user before pushing. If you kept a re-solve, update the PR title and description to match the new diff (`gh pr edit`) when you push. Go back to `review-pr` Part 0.
