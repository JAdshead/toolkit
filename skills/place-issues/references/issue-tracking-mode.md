# Issue tracking mode

GitHub issues are the way in, in both modes: work is filed as plain issues. What differs is where an issue ends up.

- **Simple:** the issue is where it finishes. Labels, assignees and open/closed are all the tracking there is.
- **Project:** the `place-issues` skill puts new issues on the repo's GitHub Project board (Status, fields, parent issue). From then on the board's Status tracks them, and larger features are parent issues with sub-issues.

## Pick the mode

1. **Declared.** Look in the project's agent instructions (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) for an `Issue tracking` section:
   ```markdown
   ## Issue tracking
   - Mode: project            # simple | project
   - Project: my-org/4        # owner/number of the GitHub Project
   - Claims: agent            # agent (the board has an Agent text field) | assignee
   - Status: Backlog, Ready, In progress, In review, Done   # this board's exact option names, in order
   - Intake: Backlog          # the Status new issues are placed in
   ```
2. **Detected.** Otherwise `gh repo view --json nameWithOwner,projectsV2`: exactly one open linked board means project mode with that board; several, ask which (or simple); none means simple mode. Read the claim style and Status names from the board (below).
3. **Say it** in one line ("Project mode: board my-org/4, Agent claims"). The user can override it for the run.

Never switch modes silently partway through a run. If a project command fails (usually a missing `project` scope), stop and ask: the user runs `gh auth refresh -s project` themselves (you can't), or the run carries on in simple mode where that makes sense.

The `board-setup` skill creates a board, links it and writes this section.

## Project mode: claim style and Status names

Read the board's fields once: `gh project field-list <number> --owner <owner> --format json`.

**Claim style.** `Claims: agent` when the board has a text field named **Agent**, else `assignee`. The section's value wins; without one, the field decides.

**Status names.** The operations use four roles. Take each one's exact option name from the section's `Status` line, or from the board's Status options:

- **Ready:** the column work is picked up from. On a board with Backlog and Ready, it is Ready, and only the user moves issues there (Make ready). On a board without them (Todo, In progress, Done), it is Todo, and placed issues are ready straight away.
- **In progress**, **Done.**
- **In review:** optional. On a board without it, leave it out of every query and skip every move to it; the issue stays In progress until merge.

Later columns such as Verifying or Ready to merge are optional too: use them only if the board has them. States like "Needs decision" or "Blocked" are never picked up.
