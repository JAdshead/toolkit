---
name: ship-pr
description: Take one or more open pull requests from opened to merged and cleaned up. Loops review-pr and address-review until the owner review returns MERGE, with a three-round limit before asking the user, then merges only the reviewed commit, deletes the branch and worktree, and updates the local main checkout. Several PRs run in parallel, one fresh subagent each. Use when the user says ship this PR, review and merge, merge when ready, or for each PR review then merge.
license: MIT
metadata:
  tags: pull-request merge review-loop cleanup orchestration
---

# Ship PR

Get each PR to a MERGE verdict from `review-pr`, merge exactly the commit that was reviewed, and clean up after it.

You orchestrate. You do not review or fix: `review-pr` reviews and `address-review` fixes. Where this says "run the `<name>` skill" and your agent can't invoke skills by name, read `../<name>/SKILL.md`.

**The go-ahead.** Invoking `ship-pr` is the user's go-ahead to push review fixes to, and merge, the PRs they named, and no others. A project's own instructions (AGENTS.md, CLAUDE.md, GEMINI.md, CONTRIBUTING) win: if they say a human merges, stop at MERGE and report.

## One PR

1. **Review.** Run the `review-pr` skill on the PR. Note the `sha` its result covers.
2. **Fix and re-review.** On NOT YET, run the `address-review` skill with the confirmed findings, push its commit, and go back to step 1. After 3 rounds without MERGE, stop and ask the user, as `review-pr`'s own exit does: keep going, merge with the open findings listed on the PR, or stop.
3. **Merge the reviewed commit.** On MERGE, confirm CI is green (`gh pr checks <n>`) and the head is still `sha` (`gh pr view <n> --json headRefOid -q .headRefOid`). If the head moved, the new commits are unreviewed: go back to step 1. Otherwise, with the merge method the project uses or the repo allows (`gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,autoMergeAllowed`):
   - if `autoMergeAllowed`: `gh pr merge <n> --auto --<method> --match-head-commit <sha>`, then wait until `gh pr view <n> --json state -q .state` is `MERGED`
   - otherwise: `gh pr merge <n> --<method> --match-head-commit <sha>`
4. **Clean up.** Once the PR is `MERGED`: remove its worktree (`git worktree remove <path>`), then delete its branch locally (`git branch -D <branch>`) and on the remote (`git push origin --delete <branch>`; already gone is fine). If this session is running inside that worktree, leave the worktree and its local branch, and say so. In the main checkout, if `git status --porcelain` is empty and it is on the default branch, run `git pull --ff-only`; otherwise leave it and say so.
5. **Report** one line per PR, then offer to archive the session if your agent can:
   ```
   #<n> merged at <sha>; branch and worktree removed; main updated
   #<n> stopped after 3 rounds: <open findings>
   ```

## Several PRs

Spawn one fresh subagent per PR, in parallel, each told to run `ship-pr` on that PR alone and to return instead of asking when it would stop for the user. If a subagent can't start subagents of its own, which `review-pr` and `address-review` need, ship the PRs one at a time in this session instead.

Do not trust the reports. For each PR, check `gh pr view <n> --json state,mergeCommit,headRefOid` and that its branch and worktree are gone. Where a report and GitHub disagree, GitHub wins. Ask the user about every PR that stopped, then report one line per PR as above.
