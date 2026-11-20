---
name: collect-feedback
description: Rapid-fire issue collection. The user rattles off bugs, ideas and tasks; capture each one silently, show an organized list when they say "done", then file them as GitHub issues after confirmation. Use when the user wants to dump feedback, a brain dump of tasks, or a list of issues to file.
license: MIT
metadata:
  tags: issues github collection triage
---

# Issue Collection

Capture tasks like an assistant taking notes while someone rattles off items. No interruptions: collect, then organize, then file.

## State tracking

**Critical:** keep a running list of captured items. After each user message, update the list before responding. The list lasts for the whole collection session, until the issues are created.

```
CAPTURED:
1. [raw input] | priority: P1/P2/P3
2. [raw input] | priority: P1/P2/P3
```

## Collection mode

Start with:

```
Ready.
```

Then wait for input.

**After each input:**

- Split multi-item messages into separate tasks.
- Detect priority signals.
- Handle removal and undo commands.
- Respond with ONLY the current count in parentheses, e.g. `(3)`.

**Priority:**

- "urgent", "asap", "critical", "important", "right away" → **P1**
- "low priority", "when you can", "eventually", "not urgent", "backlog" → **P3**
- everything else → **P2**

**Removal commands** (act on these, don't capture them):

- "scratch that" / "never mind" / "ignore that" → remove the last item
- "remove the [X] one" / "delete [X]" → remove the matching item
- "start over" / "clear" → empty the list and reply `(0)`

**Exit triggers** (case-insensitive). Only these end collection:

- "done", "finished", "end"
- "that's all" / "thats all", "that's it" / "thats it"
- "create them" / "make them"

If an exit trigger arrives with nothing captured, reply:

```
Nothing captured. Start the collect-feedback skill again when you have items.
```

## Review phase

When the user signals done, show the organized list:

```
## [N] items captured

**Urgent (P1):**
- [item]

**Normal (P2):**

Quick tasks:
- [item]

Needs proposal:
- [item]

**Low priority (P3):**
- [item]

---
Look good? Say "yes" to create, or tell me what to change.
```

The user can adjust: "remove the dashboard one", "make the login one urgent", "the export thing is actually quick", "add one more: fix the footer". After any change, show the updated list again.

### Size

| Size | Signals | Meaning |
|------|---------|---------|
| **Quick** | Bug fix, typo, small change, "just", "quick", "small", single-file work, a specific location named | Ready to implement when picked up |
| **Needs proposal** | New feature, "add [system]", architectural, multi-component, vague scope, "rethink", "redesign" | Needs a design or proposal before implementation |

When in doubt, it needs a proposal.

## Creation phase

Once the user confirms ("yes", "yep", "do it", "looks good", "create"):

1. Check the repo and its labels: `gh repo view --json nameWithOwner` and `gh label list`. Prefer the repo's existing labels over inventing new ones.
2. File each item as an issue. Keep the user's words in the title (tidied, not rewritten). Every body must stand on its own: expand the raw phrasing into requirements, acceptance criteria and any known context such as file paths. When several items are parts of one feature, add `Part of: <feature>` to each body so they can be grouped later.

**Labels** (map to the closest existing label):

- broken / bug / fix / error → `bug`
- add / new / create / implement / feature → `enhancement`
- change / update / refactor / improve → `chore` (or the repo's tech-debt label)
- P1 items also get the repo's urgent or priority label if one exists. If the repo's priority labels mean something else (for example P1 = "blocking decision"), follow the project's own rules instead. If no such label exists, put the priority in the body and list any label you'd suggest creating in the review step; create labels only when the user says yes.

```bash
gh issue create --title "[their phrasing, tidied]" --label "bug" --body "Priority: P2

## Requirements
[what needs doing, expanded from their input]

## Acceptance criteria
[how to verify it's done]

## Context
[file paths, related issues, or: Needs a design/proposal before implementation.]"
```

Create issues in parallel where the agent allows it.

## Final report

```
Created [N] issues:

**Urgent:**
- #41: Fix login bug (P1)

**Normal:**
- #42: Update email validation
- #43: User dashboard (needs proposal)

**Backlog:**
- #44: Fix footer typo (P3)

Run `gh issue list` to see all open work.
```

If the repo tracks work on a GitHub Project board (an `Issue tracking` section saying `Mode: project` in its agent instructions, or a board linked to the repo in `gh repo view --json projectsV2`), offer to run the `place-issues` skill on the new issues.

## Key rules

1. **Track state** across every message.
2. **Minimal during collection:** just `(N)`.
3. **No questions** during collection: work it out from context.
4. **Generous with "needs proposal":** when in doubt, it needs design first.
5. **Preserve their words** in titles; expand only in the body.
6. **Review before creating:** always show the list and get a yes.
7. **Handle adjustments** during review.
