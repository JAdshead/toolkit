---
name: board-setup
description: Set up a GitHub Project board for a repo so its issues are tracked in project mode. Creates the board under the repo's owner and links it, offers an Agent field for per-run claims, Backlog/Ready and In review columns and an Area field, records the board in the repo's agent instructions, then hands off to place-issues. Use when the user wants to start using a project board, move a repo from plain issues to a board, or add the Agent field to an existing board.
license: MIT
metadata:
  tags: github projects board setup issue-tracking
---

# Board setup

Give the repo a project board that the toolkit's skills can claim work on, and record it so every agent finds it.

Do each step only on the user's yes. Ask one question at a time. Project commands need the `project` scope: if one fails for lack of it, stop and ask the user to run `gh auth refresh -s project` (you can't do it for them).

## 1. The board

Read the repo and its boards: `gh repo view --json nameWithOwner,owner,projectsV2`.

- **No linked board:** offer to create one under the repo's owner and link it:
  ```bash
  gh project create --owner <owner> --title "<repo name>" --format json   # read .number
  gh project link <number> --owner <owner> --repo <owner>/<repo>
  ```
  Use the full `--repo <owner>/<repo>`: gh refuses to link a board to another owner's repo, and the full form makes a mismatch fail loudly. A new board has Status options Todo, In Progress and Done.
- **One linked board:** use it, and say so in one line.
- **Several:** ask which.

## 2. Offers

Read the board's fields: `gh project field-list <number> --owner <owner> --format json`. Skip any offer the board already has. Then offer each in turn:

1. **Agent field** (recommended). A text field the board script in `implement` and `tackle-issues` uses to claim issues per run, so parallel agents signed in as the same user never take the same issue:
   ```bash
   gh project field-create <number> --owner <owner> --name Agent --data-type TEXT
   ```
2. **Backlog and Ready.** Without them, every placed issue can be picked up at once. With them, new issues land in Backlog and only the user moves them to Ready. Rename Todo to Ready and add Backlog before it. Renaming keeps Todo's option id, so every item now in Todo becomes Ready and claimable at once: say so in the offer, and ask whether to move those items to Backlog afterwards (`gh project item-list <number> --owner <owner> --format json --limit 500 --query 'status:Ready'`, then `gh project item-edit <number> --owner <owner> --url <issue-url> --field Status --value Backlog` for each).
3. **In review.** An In review column between In Progress and Done, for issues with an open PR.
4. **Area.** A single-select field naming parts of the codebase, so `tackle-issues` can flag two runs working in the same area. Propose options from the repo's top-level folders or labels; the user edits the list.
   ```bash
   gh project field-create <number> --owner <owner> --name Area --data-type SINGLE_SELECT --single-select-options "<a>,<b>,<c>"
   ```

gh has no command for Status options (offers 2 and 3). Read the field's options with their ids, then send the whole list back, keeping each existing option's `id` so items keep their status:

```bash
gh api graphql -f query='query($id: ID!) { node(id: $id) { ... on ProjectV2SingleSelectField { options { id name color description } } } }' -f id=<status field id>
gh api graphql --input - <<'JSON'
{"query": "mutation($input: UpdateProjectV2FieldInput!) { updateProjectV2Field(input: $input) { clientMutationId } }",
 "variables": {"input": {"fieldId": "<status field id>", "singleSelectOptions": [
   {"name": "Backlog", "color": "GRAY", "description": ""},
   {"id": "<Todo's id>", "name": "Ready", "color": "<its color>", "description": "<its description>"},
   {"id": "<In Progress's id>", "name": "In Progress", "color": "<its color>", "description": "<its description>"},
   {"name": "In review", "color": "PURPLE", "description": ""},
   ...the other existing options, in order, with their ids...
 ]}}}
JSON
```

New options need a color: GRAY, BLUE, GREEN, YELLOW, ORANGE, RED, PINK or PURPLE. Read the options again afterwards and check that every existing one kept its id. If the call fails, give the user the board's URL to add the options in its Status field settings instead.

## 3. Record it

Add or update the `Issue tracking` section in the project's agent instructions (`AGENTS.md`, or `CLAUDE.md` if the repo has no `AGENTS.md`). Put it outside any `<!-- toolkit:start -->` … `<!-- toolkit:end -->` block, which `toolkit init` replaces. If the instructions already declare one (for example `Mode: simple`), replace it rather than add a second. Use the board's exact option names, read back from the board:

```markdown
## Issue tracking
- Mode: project
- Project: <owner>/<number>
- Status: ready=Ready, in progress=In Progress, in review=In review, done=Done   # role=exact option name; leave out roles the board lacks
- Intake: Backlog          # or Todo, without Backlog/Ready
```

Leave out `Claims:`: the skills read the claim style from the board's Agent field. Add `- Claims: assignee` only if the user wants assignee claims on a board that has one, and drop any other `Claims:` line from an existing section.

Show the section and the file before writing it.

## 4. Hand off

Run the `place-issues` skill on every open issue (an agent that can't invoke skills by name reads `../place-issues/SKILL.md`). Afterwards, offer to remove the `wip` labels (`gh issue edit <n> --remove-label wip`): on the board, Status and the claim replace them.

Report in a few lines: the board's URL, what was added, and where the `Issue tracking` section was written.
