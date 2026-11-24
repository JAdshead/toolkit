---
name: ship-pr
description: Take one or more open pull requests from opened to merged and cleaned up. Loops review-pr and address-review until the owner review returns MERGE, with a three-review limit before asking the user, then merges only the reviewed commit, deletes the branch and worktree, and fast-forwards the default branch in the main checkout. Several PRs run in parallel, one fresh subagent each. Use when the user says ship this PR, review and merge, merge when ready, or for each PR review then merge.
license: MIT
metadata:
  tags: pull-request merge review-loop cleanup orchestration
---

# Ship PR

Get each PR to a MERGE verdict from `review-pr`, merge exactly the commit that was reviewed, and clean up after it.

You orchestrate. You do not review or fix: `review-pr` reviews and `address-review` fixes. Where this says "run the `<name>` skill" and your agent can't invoke skills by name, read `../<name>/SKILL.md`.

**The go-ahead.** Invoking `ship-pr` is the user's go-ahead to push review fixes to, and merge, the PRs they named, and no others. A project's own instructions (AGENTS.md, CLAUDE.md, GEMINI.md, CONTRIBUTING) win: if they say a human merges, stop at MERGE and report.

## One PR

1. **Review.** If 3 reviews have already run without a merge, stop and ask the user instead of starting a fourth, as `review-pr`'s own exit does: keep going, merge with the open findings listed on the PR, or stop. Keep going allows three more reviews, then ask again. Every review counts, whatever its verdict, including one rerun because the head moved in step 3. Otherwise run the `review-pr` skill on the PR. Note the `sha` its result covers.
2. **Fix and re-review.** On NOT YET, append the confirmed findings to `<scratch>/pr-<pr>-findings.md` (beside `review-pr`'s `problem.md`, so they survive a context compaction) and run the `address-review` skill with the confirmed findings from every round so far, in a worktree on the PR branch (`git worktree add <path> <branch>` if you have none), push its commit, and go back to step 1.
   - **A PR from a fork** (`gh pr view <n> --json isCrossRepository,maintainerCanModify`): if `maintainerCanModify` is false, you can't push a fix, so stop and report. Otherwise tell the user that fixing it runs the contributor's code with their local credentials, and wait for a yes. Then create the worktree with `git worktree add --detach <path>`, run `gh pr checkout <n> --branch pr-<n>` in it. Push with `git push "$(git config branch.pr-<n>.remote)" HEAD:<headRefName>`, taking `headRefName` from `gh pr view <n> --json headRefName`: this updates the fork's PR branch, never origin.
3. **Merge the reviewed commit.** On MERGE, confirm CI is green (`gh pr checks <n> --watch`; "no checks reported" means the repo has no CI and counts as green; if a check failed, stop and report) and the head is still `sha` (`gh pr view <n> --json headRefOid -q .headRefOid`). If the head moved, the new commits are unreviewed: go back to step 1. Otherwise merge: `gh pr merge <n> --<method> --match-head-commit <sha>`, where `<method>` is what the project uses, else the first the repo allows, in this order (`gh api 'repos/{owner}/{repo}' --jq '{allow_squash_merge,allow_merge_commit,allow_rebase_merge}'`): `allow_squash_merge` → `--squash`, `allow_merge_commit` → `--merge`, `allow_rebase_merge` → `--rebase`. If GitHub refuses (for example, a required approval), report why and stop.
4. **Clean up.** Once the PR is `MERGED`: remove its worktree (`git worktree remove <path>`; if it has uncommitted changes, leave it and its local branch, and say so), then delete its branch locally (`git branch -D <branch>`) and on the remote (`git push origin --delete <branch>`; already gone is fine). For a PR from a fork, delete only `pr-<n>`, and only locally. If this session is running inside that worktree, leave the worktree and its local branch, and say so. In the main checkout, if `git status --porcelain` is empty and it is on the default branch, run `git pull --ff-only`; otherwise leave it and say so.
5. **Report** one line per PR, then offer to archive the session if your agent can:
   ```
   #<n> merged at <sha>; branch and worktree removed; default branch updated
   #<n> stopped after 3 reviews: <open findings>
   ```

## Several PRs

Spawn one fresh subagent per PR, in parallel, each told to run `ship-pr` on that PR alone, to skip updating the main checkout and leave that out of its report line, and to return instead of asking when it would stop for the user. If a subagent can't start subagents of its own, which `review-pr` and `address-review` need, ship the PRs one at a time in this session instead.

Do not trust the reports. For each PR, check `gh pr view <n> --json state,mergeCommit,headRefOid` and that its branch and worktree are gone, or were left with the reason stated. Where a report and GitHub disagree, GitHub wins. Ask the user about every PR that stopped, update the main checkout once as in step 4, then report one line per PR as above.
