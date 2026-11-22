---
name: place-issues
description: Place GitHub issues on the repo's GitHub Project board. Adds unplaced issues to the board, sets their Status and Priority/Size fields, and groups related issues under parent issues as sub-issues, after the user confirms the plan. Also offers to close parents whose sub-issues are all closed. Use after issues are filed in a repo that tracks work on a project board, or when the user asks to triage, place, organize or board issues.
license: MIT
metadata:
  tags: github issues projects triage sub-issues
---

# Place Issues

GitHub issues are the way in. Filing skills (and people) create plain issues; in a repo that tracks work on a GitHub Project board, this skill takes those issues and puts each in its place: on the board, in the intake column, with its fields set, under its parent issue.

In a repo without a board (simple mode) there is nothing to do: the issue is where it belongs.

## Input

- `place-issues #52 #53 #55`: place these issues (typically the ones a filing skill just created).
- `place-issues`: place every open issue in the repo that is not on the board yet.

## 1. Find the board

1. Settle the mode and the board with `references/issue-tracking-mode.md`. It also covers a missing `project` scope.
2. In simple mode, say so in one line and stop. If the user wants a board, run the `board-setup` skill instead (an agent that can't invoke skills by name reads `../board-setup/SKILL.md`).

## 2. Learn the board

```bash
gh project view <number> --owner <owner> --format json
gh project field-list <number> --owner <owner> --format json
```

Note the board's title, its Status options, and any Priority or Size fields with their options. The **intake** status is where new issues land: Todo on a simple board, Backlog on a board that separates Backlog from Ready. If the `Issue tracking` section doesn't say and it isn't obvious, ask once and offer to record the answer there. Use only options that exist; never add fields or options without asking.

## 3. Work out each issue's place

Get the issues: `gh issue view <n> --json number,title,labels,body,url,assignees,parent,projectItems` for each number given, or for all open ones:

```bash
gh issue list --state open --limit 500 --json number,title,labels,body,url,assignees,parent,projectItems,subIssuesSummary
```

If the list hits the limit, say so and work in batches.

An issue is unplaced when no entry in its `projectItems` has this board's title. Skip issues already on the board. For each unplaced issue:

- **Status:** the intake status. An issue that is already assigned and labelled `wip` goes to In progress instead, except with Agent claims: there it goes to intake like the rest, and the plan names it, since an In progress issue with no Agent is invisible to the board script's `busy` list.
- **Fields:** the board's Priority from the priority label or the body's `Priority:` or `Severity:` line; Size from a `Size:` line. Map by rank when the scales differ (HIGH/MEDIUM/LOW onto P1/P2/P3). Leave a field empty rather than guess.
- **Parent:** an existing open parent when the issue says `Part of #<n>`, is listed in another issue's checklist (`- [ ] #<n>`), or plainly belongs to it. Propose a **new** parent only for two or more issues that form one feature (for example several bodies saying `Part of: <feature>`). One task on its own is just an issue; never invent a parent to group unrelated work.

When placing every open issue (no numbers given), also list open parents that have sub-issues, all of them closed (`subIssuesSummary`). The plan offers to close them.

## 4. Confirm

Show the plan and wait for a yes:

```
Placing 6 issues on <board title>:
- New parent "Export to CSV" ← #52, #53, #55
- Existing #31 "Onboarding revamp" ← #57
- Standalone: #54, #56
Status: Backlog (all). Priority: 2 × P1, 4 × P2 from labels.
Close finished parents: #40 "Search revamp" (3/3 sub-issues closed)
```

The user can move issues between parents, rename or drop a proposed parent, change fields, skip issues, or keep a finished parent open.

## 5. Apply

Create new parents first (what and why, and the feature's overall acceptance criteria; native sub-issues list the tasks). Then, for every unplaced issue and every new parent, but never an issue already on the board:

```bash
gh project item-add <number> --owner <owner> --url <issue-url>
gh project item-edit <number> --owner <owner> --url <issue-url> --field Status --value "<intake>"
gh project item-edit <number> --owner <owner> --url <issue-url> --field Priority --value "<option>"   # one field per call
gh issue edit <child> --parent <parent>
```

Attaching to an existing parent only sets `--parent` on the child; leave the parent's own Status and fields alone. Don't edit issue bodies or labels while placing. If `gh issue edit` doesn't know `--parent`, the installed `gh` is too old: ask the user to upgrade it. Close each finished parent the user agreed to with `gh issue close <n>`. If a command fails, carry on with the rest and list the failures at the end.

## 6. Report

```
Placed 6 issues on <board title> (<board url>):
- #60 Export to CSV (new parent)
  - #52, #53, #55
- #31 Onboarding revamp
  - #57
- #54, #56
Skipped: #58 (already on the board)
Closed: #40 Search revamp (all sub-issues closed)
```

