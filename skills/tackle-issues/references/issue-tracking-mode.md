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
   - Status: Todo, In progress, In review, Done   # this board's option names, in order
   - Intake: Todo             # the Status new issues are placed in
   ```
2. **Detected.** Otherwise `gh repo view --json nameWithOwner,projectsV2`: exactly one open linked board means project mode with that board; several, ask which (or simple); none means simple mode.
3. **Say it** in one line ("Project mode: board my-org/4 is linked to this repo"). The user can override it for the run.

Never switch modes silently partway through a run. If a project command fails (usually a missing `project` scope), stop and ask: the user runs `gh auth refresh -s project`, or the run carries on in simple mode.

In project mode, read the board's Status options once (`gh project field-list <number> --owner <owner> --format json`) and map them: **Todo** is "ready to be picked up" (Ready, on a board that separates Backlog from Ready); then **In progress**, **In review** (if missing, items stay In progress), **Done**. States like "Needs decision" or "Blocked" are never picked up.
