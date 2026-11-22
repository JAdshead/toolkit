---
name: address-review
description: Turn a review-pr NOT YET verdict into a fix. A fresh subagent that never wrote the code either patches the confirmed findings or re-solves the PR's problem from the base branch, and the orchestrator keeps whichever result is smaller and passes its checks. Use when review-pr returns NOT YET on a PR you authored, or when the user asks to address or fix confirmed review findings.
license: MIT
metadata:
  tags: pull-request code-review fix-loop fresh-context
---

# Address Review

Solve `problem.md` so that the confirmed findings cannot arise. The current diff is one candidate, not the starting point.

The author fixing their own findings stays anchored on their design and patches around it, so you orchestrate and a fresh subagent writes the fix. Fresh means what it means in `review-pr`'s Fresh context section: no fork, nothing of your reasoning in its prompt.

## Inputs

From `review-pr` Part 4: the PR number, its worktree (where the PR branch is checked out), the confirmed blocking findings verbatim, the path to `problem.md`, and the round number.

## 1. Patch or re-solve

- **Patch** when the findings are few, isolated, and in code the problem needs.
- **Re-solve** when this is round 2 or later, the findings cluster in one area, or they sit in code that earlier fixes added (`git log` on those lines) or that the problem doesn't need.

A finding that can only be fixed by going beyond `problem.md` goes to the user, not to a subagent.

## 2. Patch

Spawn one fresh subagent with the findings verbatim, `problem.md`, the PR's worktree, and the project's test rules (in `AGENTS.md` or `CLAUDE.md`: test first, and a test that would still pass with the fix deleted is broken). Tell it:

> Make the smallest change that fixes these findings and still solves `problem.md`. Delete code rather than add guards where you can. Write a failing test first where one applies. Commit with a message that says what changed.

## 3. Re-solve

Create a worktree on a new branch from the PR's current base (`git worktree add -b <pr-branch>-resolve <scratch>/resolve-<pr> origin/<base>`). Spawn one fresh subagent with `problem.md`, the findings, that worktree and the project's test rules. Never give it the old diff, the PR branch or the PR's worktree. Tell it:

> Solve `problem.md` from this base, test-first, with the least code that solves it. These findings were raised against an earlier attempt; your solution must not have them. Commit with a message that says what changed.

## 4. Verify

Do not trust the subagent's report. Run the project's full local checks yourself, read the diff, and check each finding is gone and nothing beyond `problem.md` was added.

On a re-solve, compare `git diff --stat origin/<base>...` for the old and new branches. Keep the new one only if its checks pass and it is smaller or simpler; otherwise remove its worktree and patch instead (step 2). To keep it, make the PR branch match it in one new commit, so nothing is force-pushed:

```bash
git -C <pr-worktree> restore --source=<pr-branch>-resolve --staged --worktree :/
git -C <pr-worktree> commit -m "<what changed>"
```

Then ask the user before pushing, push, and go back to `review-pr` Part 0.
