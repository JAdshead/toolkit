# Issue tracking modes

GitHub issues are the way in, in both modes: work is filed as plain issues. What differs is where an issue ends up.

- **Simple:** the issue is where it finishes. Labels, assignees and open/closed are all the tracking there is.
- **Project:** the `place-issues` skill puts new issues on the repo's GitHub Project board (Status, fields, parent issue). From then on the board's Status tracks them, and larger features are parent issues with sub-issues.

This file covers what skills that pick up and work on issues need: which mode the repo is in, and how to claim, move and release an issue in each.

> Shared file: the canonical copy is `shared/issue-tracking.md` in the toolkit repo, copied into each skill's `references/`. Edit the canonical copy and run `bin/sync-shared`.

## 1. Pick the mode

1. **Declared.** Look in the project's agent instructions (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) for an `Issue tracking` section:
   ```markdown
   ## Issue tracking
   - Mode: project            # simple | project
   - Project: my-org/4        # owner/number of the GitHub Project
   - Status: Todo, In progress, In review, Done   # this board's option names, in order
   - Intake: Todo             # the Status new issues are placed in
   ```
2. **Detected.** Otherwise `gh repo view --json nameWithOwner,projectsV2`: exactly one open linked board means project mode with that board; several, ask which (or simple); none means simple mode.
3. **Say it** in one line ("Project mode: board my-org/4 is linked to this repo"). The user can override it for the run.

Never switch modes silently partway through a run. If a project command fails (usually a missing `project` scope), stop and ask: the user runs `gh auth refresh -s project`, or the run carries on in simple mode.

In project mode, read the board's Status options once (`gh project field-list <number> --owner <owner> --format json`) and map them: **Todo** is "ready to be picked up" (Ready, on a board that separates Backlog from Ready); then **In progress**, **In review** (if missing, items stay In progress), **Done**. States like "Needs decision" or "Blocked" are never picked up.

## 2. Simple mode

| Operation | How |
|---|---|
| Find work | `gh issue list --state open --search "no:assignee -label:wip" --json number,title,labels,body --limit 100` |
| Read context | `gh issue view <n> --json title,body,labels,comments` |
| List my claims | `gh issue list --state open --assignee @me --label wip --json number,title` |
| Claim | `gh issue edit <n> --add-assignee @me --add-label wip` (if `wip` doesn't exist, ask before creating it; without it, the assignee alone is the claim) |
| In review | No change; the open PR shows it |
| Done | The PR's `Closes #<n>` closes it on merge; remove `wip` |
| Release a claim | `gh issue edit <n> --remove-assignee @me --remove-label wip` |

## 3. Project mode

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

Every agent signs in as the same GitHub user, so an assignee says an issue is taken but not by which run, and a run that crashes leaves claims nothing can trace. If the board has a text field named **Agent** (seen in the `field-list` above), claim through `scripts/board` in this skill's folder instead of by assignee. Run it with no arguments for its usage. It needs `jq`. Without an Agent field the table above applies unchanged, and the script exits 2.

**Agent id.** One per run (or per PR group in `tackle-issues`): `<branch>@$(hostname -s)`, for example `issues/calendar-fixes@studio`. Use the same id for every call about that work; `--resume` finds it again with `mine`.

The script reads Status names as above: ready is Ready if the board has it, else Todo; then In progress and Done. Case doesn't matter ("In Progress" matches), and a call that would need a status the board lacks fails before changing anything. If this board names them differently, prefix calls with `BOARD_READY=<option>`, `BOARD_IN_PROGRESS=<option>` or `BOARD_DONE=<option>`.

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
