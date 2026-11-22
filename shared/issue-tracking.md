# Issue tracking operations

How skills that pick up and work on issues claim, move and release an issue in each mode. Settle the mode first, from `issue-tracking-mode.md` beside this file; it also maps the board's Status options to the names used here.

## Simple mode

| Operation | How |
|---|---|
| Find work | `gh issue list --state open --search "no:assignee -label:wip" --json number,title,labels,body --limit 100` |
| Read context | `gh issue view <n> --json title,body,labels,comments` |
| List my claims | `gh issue list --state open --assignee @me --label wip --json number,title` |
| Claim | `gh issue edit <n> --add-assignee @me --add-label wip` (if `wip` doesn't exist, ask before creating it; without it, the assignee alone is the claim) |
| In review | No change; the open PR shows it |
| Done | The PR's `Closes #<n>` closes it on merge; remove `wip` |
| Release a claim | `gh issue edit <n> --remove-assignee @me --remove-label wip` |

## Project mode

Set a field with `gh project item-edit <number> --owner <owner> --url <issue-url> --field Status --value "<option>"`.

| Operation | How |
|---|---|
| Find work | `gh project item-list <number> --owner <owner> --format json --limit 500 --query 'repo:<owner>/<repo> status:"<Todo>" no:assignee'` (a board can span repos; quote option names). Then skip parents that still have open sub-issues, which takes `gh issue view <n> --json subIssuesSummary` per item: their sub-issues are the work |
| Read context | `gh issue view <n> --json title,body,labels,comments,parent,subIssues,subIssuesSummary,projectItems`; if it has a parent, read that too for the feature's intent and what sibling sub-issues cover |
| List my claims | `gh project item-list <number> --owner <owner> --format json --limit 500 --query 'repo:<owner>/<repo> assignee:@me status:"<In progress>","<In review>"'` |
| Claim | If the issue isn't on the board (no `projectItems` entry with this board's title), run the `place-issues` skill on it first. Then `gh issue edit <n> --add-assignee @me` and Status → In progress. No `wip` label |
| In review | Add `Part of #<parent>` (no closing keyword) to the PR body; once the PR is open, Status → In review |
| Done | The PR's `Closes #<n>` closes it on merge and the board moves it to Done. If the parent's `subIssuesSummary` shows every sub-issue closed, offer to close the parent |
| Release a claim | Remove the assignee; Status back to Todo |

Sub-issues of one parent are the natural group for a single PR. Never close an issue or a parent by hand without the user's say-so.

### Per-run claims (board with an Agent field)

Every agent signs in as the same GitHub user, so an assignee says an issue is taken but not by which run, and a run that crashes leaves claims nothing can trace. If the board has a text field named **Agent** (seen in the board's `field-list`), claim through `scripts/board` in this skill's folder instead of by assignee. Run it with no arguments for its usage. It needs `jq`. Without an Agent field the table above applies unchanged, and the script exits 2.

**Agent id.** One per run (or per PR group in `tackle-issues`): `<branch>@$(hostname -s)`, for example `issues/calendar-fixes@studio`. Use the same id for every call about that work; `--resume` finds it again with `mine`.

The script reads Status names as `issue-tracking-mode.md` maps them: ready is Ready if the board has it, else Todo; then In progress and Done. Case doesn't matter ("In Progress" matches), and a call that would need a status the board lacks fails before changing anything. If this board names them differently, prefix calls with `BOARD_READY=<option>`, `BOARD_IN_PROGRESS=<option>` or `BOARD_DONE=<option>`.

| Operation | How (`B="scripts/board <owner>/<number>"`) |
|---|---|
| Find work | `$B ready`: unclaimed, unassigned items in the ready status, with priority and area. Then skip parents with open sub-issues as above. `$B busy` lists every claim, with its Area and agent |
| List my claims | `$B mine <agent>` |
| Claim | `$B claim <agent> <n>...`: all or nothing per call; only ready issues, or ones this agent already holds (so resuming re-claims safely). Sets Agent and Status → In progress; leaves assignees alone. If it fails, someone else has the issue or it isn't ready: drop it and tell the user. If the issue isn't on the board, run `place-issues` first |
| In review | `$B move <agent> "In review" <n>...` once the PR is open. If the board has later columns (for example Verifying while CI runs, Ready to merge when it is green), move through them the same way; leave the claim in place so the board shows which run built it |
| Done | As above; merging moves it to Done |
| Release a claim | `$B release <agent> <n>...`: clears Agent, Status back to ready. `move` and `release` refuse issues another agent holds |
| Make ready | `$B approve <n>...` moves an unclaimed issue to the ready status. Only on the user's say-so: deciding what is ready is theirs |

An **Area** single-select field is optional but worth having: two runs in the same Area tend to edit the same files, so `tackle-issues` flags groups whose Area is already busy.

**What the board does not guarantee.** GitHub has no compare-and-set, so a claim is check, write, read back. Two runs claiming one issue at once are usually settled by the read-back (the loser releases everything it took in that call), but not always: if one run reads back before the other writes, both believe they hold it. A claim from this machine with no matching worktree is probably a crashed run; one from another host may still be running there. Show these to the user and release them only on their say-so.
