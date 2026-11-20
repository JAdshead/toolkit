---
name: tackle-issues
description: Work through a batch of open GitHub issues end to end. Selects and filters issues, groups related ones into coherent pull requests, implements each group in its own git worktree, runs parallel specialist code reviews with a finite fix loop, verifies every subagent's output, and asks before pushing or merging anything. Use when the user asks to "tackle issues", "work through issues", "process GitHub issues", "batch implement issues", or "clear the backlog". Accepts an optional focus filter such as "calendar bugs", "P1 enhancements" or "tech-debt", and --resume to continue interrupted work.
license: MIT
metadata:
  tags: github issues pull-requests worktrees code-review automation
---

# Tackle Issues

Take a set of open GitHub issues from "open" to "pull request ready for a human", one coherent PR per group of related issues, with each group isolated in its own git worktree and reviewed by specialist reviewers before anything leaves the machine.

## Principles

- **The orchestrator stays lean.** It selects, groups, delegates, verifies and asks. Heavy work (implementing, reviewing, fixing) goes to subagents when the agent supports them.
- **Sequential within a group, isolated across groups.** Issues in one PR are implemented one after another on the same branch. Each group has its own worktree, so separate runs (or separate terminals) never touch the same files.
- **Claim before you build.** Issues are claimed as soon as the user confirms the grouping, so a second run does not pick them up.
- **Follow the repo's issue-tracking mode.** Simple (plain issues and labels) or project (a GitHub Project board). Find work, Claim, In review, Done and Release are the mode's operations from `references/issue-tracking.md`; settle the mode in Phase 0.
- **Trust, but verify.** Every subagent report is checked against `git log` and `git diff` before it counts as done.
- **Reviews end.** The review loop has a fixed exit rule, not "until nobody has anything to say".
- **Nothing is pushed, opened, merged or closed without the user's go-ahead.**

## Portability

This skill works in any coding agent that can run shell commands and `gh` (Claude Code, Codex CLI, Gemini CLI and others).

- **Subagents:** where it says "spawn a subagent", use your agent's parallel subagent or task tool if it has one (for example the `Agent`/`Task` tool in Claude Code). If your agent does not support subagents, do the same work yourself, sequentially, following the same prompt.
- **Worktrees:** if your agent supports working in separate git worktrees, use one per PR group. If it cannot change directory between worktrees, process groups one at a time on separate branches in the main checkout instead.
- **Asking the user:** use your agent's question tool if it has one; otherwise ask in plain text and wait.

## Prerequisites

- `gh` installed and authenticated (`gh auth status`).
- A clean working tree (`git status --porcelain` prints nothing).

## Arguments

- `tackle issues` with no filter: all open, unassigned, implementable issues.
- `tackle issues <focus>`: filter by label or text, e.g. `calendar bugs`, `P1 enhancements`, `tech-debt test quality`.
- `tackle issues --resume`: continue interrupted work (see Resume).

## Phase 0: Learn the project

Before touching any issue, read how this project wants work done. Look at, in order: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CONTRIBUTING.md`, `README`, and the CI config (`.github/workflows/`, `.gitlab-ci.yml`, etc.).

Record:
- **Verify command**: the lint and test commands the project or CI actually runs. See `references/subagent-templates.md` for detection when nothing is documented.
- **Conventions**: commit message style, branch naming, test standards, comment rules, design system or UI guide, files never to edit.
- **Domain reviewers**: any area the project's docs treat as high-risk (payments, auth, data migrations, privacy, legal copy). These become extra reviewers in Phase 5.

Pass these to every subagent. Project rules override the defaults in this skill.

## Phase 1: Discover and filter issues

Run in parallel:

```bash
git status --porcelain
gh auth status
```

and the mode's Find work operation.

Stop with a clear message if the tree is dirty, `gh` is not authenticated, or nothing matches.

With a focus filter:
1. **Label match**: any argument that matches a label name (case-insensitive) becomes `gh issue list --label "<label>"`.
2. **Text search**: remaining arguments become `gh issue list --search "<term>"`.
3. **Union** the results, deduplicated by number.

Exclude:
- issues with any assignee (claimed);
- issues already claimed or in progress under the mode's rules;
- tracking issues (titles starting `Epic:`, labelled `epic`/`tracking`, or parents with open sub-issues, whose sub-issues are the work);
- issues that need a decision rather than code (questions, open design discussions). List these separately so the user can see why they were skipped.

## Phase 2: Group into pull requests

**Group together** issues that share a feature area or module, touch the same files, or are small related fixes that read well as one change.

**Keep apart** issues that are unrelated, carry different risk (a risky migration next to a safe copy fix), are large on their own (roughly 500+ changed lines), or need different reviewers.

Sub-issues of one parent usually make one group; don't mix sub-issues of different parents in one PR.

Order groups so independent, low-risk ones come first. Present the plan and wait for confirmation:

```
## Proposed PR grouping

### PR 1: <theme>
- #<n>: <title>
- #<n>: <title>
Why together: same module / related fix

### PR 2: <theme>
- #<n>: <title>
Why alone: higher risk, touches the data model

Skipped: #<n> (needs a product decision), #<n> (epic)

Proceed with this grouping?
```

## Phase 3: Claim issues and create worktrees

Right after the user confirms, claim every issue in every selected group with the mode's Claim operation.

Then one worktree per group, branched from an up-to-date default branch:

```bash
git fetch origin
REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH="issues/<group-slug>"
WT="$HOME/.worktrees/$REPO/$BRANCH"
mkdir -p "$(dirname "$WT")"
git worktree add "$WT" -b "$BRANCH" origin/<default-branch>
```

If the worktree or branch already exists, ask: resume or recreate. Use the project's branch naming if it has one. Some projects need per-worktree setup (install dependencies, build assets, a separate test database so parallel runs do not collide); follow the project's docs. Details in `references/subagent-templates.md`.

## Phase 4: Implement (per group)

For each issue in the group, in order, spawn an **implementation subagent** (template in `references/subagent-templates.md`). It works only inside the group's worktree, writes a failing test first where practical, implements, runs the verify command, and commits.

**After every subagent returns, verify its work yourself:**

```bash
git -C "$WT" status --porcelain                 # anything left uncommitted?
git -C "$WT" log --oneline origin/<default>..HEAD   # the commits you expect, no extras
git -C "$WT" diff --stat origin/<default>...HEAD    # only files in scope
```

Watch for: files outside the issue's scope, extra migrations or config changes, unrelated refactors, a claimed "PASS" with no test run, uncommitted changes, or no commit at all. If the report and the repository disagree, the repository wins: fix it or send the subagent back with the specific problem.

On failure, ask the user whether to skip the issue (unclaim it) or stop the group.

## Phase 5: Review loop (per group, before pushing)

Spawn the specialist reviewers in parallel (prompts in `references/review-prompts.md`):

| Reviewer | Focus | When |
|---|---|---|
| Correctness | logic bugs, edge cases, does it actually fix the issue | always |
| Security | injection, authz, secrets, unsafe input handling | always |
| Tests | coverage of new behaviour and failure paths; tests prove behaviour, not mocks | always |
| Simplicity and maintainability | duplication, needless abstraction, naming, project conventions | always |
| UX and accessibility | feedback, errors, a11y, design system | only if UI files changed |
| Domain reviewers | rules from the project's own docs (Phase 0) | when the diff touches that area |

Each finding carries a severity: **P1** (wrong, unsafe or data-losing), **P2** (a real problem that should be fixed before merge), **P3** (minor, polish, nice to have). Reviewers also flag anything **untrue**: a comment, doc, UI string or PR text that misdescribes the behaviour.

**Exit rule.** The loop ends when a round returns no P1, no P2 and nothing untrue. Then:
- collect every outstanding P3 from all rounds into **one** follow-up issue (draft it, show the user, create it only on confirmation);
- do not keep iterating on P3s.

**Fix rounds.** If any P1/P2 or untrue finding remains: show the findings grouped by reviewer, spawn a **fix subagent** with only those findings, verify its commits as in Phase 4, then re-run only the reviewers that raised them. Before each fix round, check for a shared root cause: if several findings come from one mistake, fix the cause, not each symptom.

**Cap.** After 3 fix rounds with P1/P2 findings still open, stop and ask the user: keep going, push with the known issues listed in the PR, or abandon the group. Escalate immediately on any critical security finding.

## Phase 6: Push and open the PR (with confirmation)

1. Run the full verify command in the worktree. If it fails, report and ask.
2. Show the user: branch, commits, diff stat, test result, review summary, and the drafted PR title and body (template in `references/subagent-templates.md`). **Ask before pushing.**
3. On a yes: `git push -u origin "$BRANCH"`, then `gh pr create` with `Closes #<n>` lines for each issue, and apply the mode's In review operation.
4. Optionally run the **holistic PR reviewer** on the final diff and description. Same exit rule; at most 2 rounds. Any further push needs the user's go-ahead again.

## Phase 7: CI

```bash
gh pr checks <pr> --watch
```

On failure, spawn a **CI analysis subagent** to read `gh run view <id> --log-failed` and separate real failures from environmental or flaky ones. Real failures: ask the user, then fix, verify, push (with confirmation). Environmental: report, do not "fix" code for them. Stop after 3 attempts and leave the PR open with a summary.

**Never merge** unless the user explicitly asks you to, for that PR.

## Phase 8: Clean up and report

- Apply the mode's Done operation to claimed issues (the PR closes them on merge), and Release any issue that was skipped or abandoned.
- Report:

```
## Tackle issues: done

| PR | Issues | Review | CI | URL |
|----|--------|--------|----|-----|
| <title> | #<n>, #<n> | clean after 2 rounds | passing | <url> |

Follow-up issue: <url> (P3s)
Skipped: #<n> (reason)
Worktrees kept at: ~/.worktrees/<repo>/issues/...  (remove with `git worktree remove <path>` after merge)
```

## Resume

`tackle issues --resume`:
1. List worktrees under `~/.worktrees/<repo>/issues/` and their commits ahead of the default branch.
2. Match them to issues you still have claimed under the mode's rules.
3. Resume at Phase 4 (no commits yet), Phase 5 (commits but no PR) or Phase 7 (PR open).

## Errors

- **Worktree or branch exists:** ask, resume or recreate.
- **Subagent went off-scope:** revert the out-of-scope changes, note it, retry with a tighter "do not" list.
- **Anything else fails:** report what finished, what did not, worktree paths and issue numbers, and release the claim on issues you are no longer working on.

## References

- `references/subagent-templates.md`: verify-command detection, worktree setup, implementation, fix and CI-analysis prompts, PR body template.
- `references/issue-tracking.md`: simple and project modes and their issue operations.
- `references/review-prompts.md`: reviewer prompts, severity scale, selection rules, consolidation and large-diff handling.
