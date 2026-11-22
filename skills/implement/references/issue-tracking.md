# Issue tracking operations

How skills that pick up and work on issues claim, move and release an issue in each mode. Settle the mode first, from `issue-tracking-mode.md` beside this file. In project mode it also gives the claim style (Agent or assignee) and the board's names for Ready, In progress, In review and Done, which the operations below use.

**Running another skill.** "Run the `<name>` skill" means invoke it by name. An agent that can't invoke skills by name (Codex, Gemini CLI) reads `../<name>/SKILL.md` beside this skill's folder and follows it.

## Simple mode

| Operation | How |
|---|---|
| Find work | `gh issue list --state open --search "no:assignee -label:wip" --json number,title,labels,body --limit 100` |
| Read context | `gh issue view <n> --json title,body,labels,comments` |
| List my claims | `gh issue list --state open --assignee @me --json number,title,labels`: `wip` marks work in progress; the rest have an open PR |
| Claim | `gh issue edit <n> --add-assignee @me --add-label wip` (if `wip` doesn't exist, ask before creating it; without it, the assignee alone is the claim) |
| In review | Once the PR is open, `gh issue edit <n> --remove-label wip`. The assignee and the open PR still show the claim |
| Done | The PR's `Closes #<n>` closes it on merge |
| Release a claim | `gh issue edit <n> --remove-assignee @me --remove-label wip` |

## Project mode

One table, two claim styles. Use the column for this board's claim style.

**Agent claims** go through `scripts/board` in this skill's folder. Below, `$B` stands for `BOARD_READY="<Ready>" BOARD_IN_PROGRESS="<In progress>" BOARD_DONE="<Done>" scripts/board <owner>/<number>`; write it out in full on every call. Run the script with no arguments for its usage; it needs `jq`. It matches names case-insensitively, and a call that needs a status the board lacks fails before changing anything. An **agent id** names one run (or one PR group in `tackle-issues`): `<branch>@$(hostname -s)`, for example `issues/calendar-fixes@studio`. Use the same id for every call about that work; `--resume` finds it again with `mine`.

**Assignee claims** set Status with `gh project item-edit <number> --owner <owner> --url <issue-url> --field Status --value "<option>"`, and list with `gh project item-list <number> --owner <owner> --format json --limit 500 --query '<query>'` (a board can span repos, so queries start `repo:<owner>/<repo>`; quote option names).

| Operation | Agent claims | Assignee claims |
|---|---|---|
| Find work | `$B ready`: unclaimed, unassigned items in Ready, with priority and area. `$B busy` lists every claim, with its Area and agent | Query `repo:<owner>/<repo> status:"<Ready>" no:assignee` |
| | Both: skip parents that still have open sub-issues (`gh issue view <n> --json subIssuesSummary` per item); their sub-issues are the work | |
| Read context | `gh issue view <n> --json title,body,labels,comments,parent,subIssues,subIssuesSummary,projectItems`; if it has a parent, read that too for the feature's intent and what sibling sub-issues cover | Same |
| List my claims | `$B mine <agent>` | Query `repo:<owner>/<repo> assignee:@me status:"<In progress>","<In review>"` |
| Claim | `$B claim <agent> <n>...`: all or nothing per call; only Ready issues, or ones this agent already holds (so resuming re-claims safely). Sets Agent and Status → In progress; leaves assignees alone. If it fails, someone else has the issue or it isn't ready: drop it and tell the user | Only a Ready issue with no assignee: `gh issue edit <n> --add-assignee @me`, then Status → In progress. No `wip` label |
| | Both: if the issue isn't on the board (no `projectItems` entry with this board's title), run the `place-issues` skill on it first. If it isn't in Ready, ask the user; on a yes, Make ready, then claim | |
| In review | Add `Part of #<parent>` (no closing keyword) to the PR body. Once the PR is open, `$B move <agent> "<In review>" <n>...`. Move through later columns (Verifying, Ready to merge) the same way if the board has them. Leave the claim in place so the board shows which run built it | Add `Part of #<parent>` (no closing keyword) to the PR body. Once the PR is open, Status → In review. Later columns the same way, if the board has them |
| Done | The PR's `Closes #<n>` closes it on merge and the board moves it to Done | Same |
| Release a claim | `$B release <agent> <n>...`: clears Agent, Status back to Ready. `move` and `release` refuse issues another agent holds | `gh issue edit <n> --remove-assignee @me`, then Status → Ready |
| Make ready | `$B approve <n>...` | Status → Ready |
| | Both: only on the user's say-so, since deciding what is ready is theirs. On a board where Ready is Todo, placed issues are already ready | |

Sub-issues of one parent are the natural group for a single PR. Never close an issue or a parent by hand without the user's say-so.

**Why the Agent field.** Every agent signs in as the same GitHub user, so an assignee says an issue is taken but not by which run, and a run that crashes leaves claims nothing can trace. The `board-setup` skill offers to add the field.

An **Area** single-select field is optional but worth having: two runs in the same Area tend to edit the same files, so `tackle-issues` flags groups whose Area is already busy.

**What the board does not guarantee.** GitHub has no compare-and-set, so an Agent claim is check, write, read back. Two runs claiming one issue at once are usually settled by the read-back (the loser releases everything it took in that call), but not always: if one run reads back before the other writes, both believe they hold it. A claim from this machine with no matching worktree is probably a crashed run; one from another host may still be running there. Show these to the user and release them only on their say-so.
