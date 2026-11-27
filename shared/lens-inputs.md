# Lens review before a pull request

How `implement` and `tackle-issues` run the lenses in `lenses.md`, beside this file, on a branch before it is pushed. Each report is tagged with the commit it reviewed, so `review-pr` can use it in place of its own lens review of that commit.

## Inputs

Build the inputs directory the lens brief reads, for the commit under review. `<slug>` names the work (`implement/<id>` → `implement-<id>`, or the PR group's slug):

```bash
sha=$(git -C "<worktree>" rev-parse HEAD)
in="<scratch>/<slug>-lens-inputs"; rm -rf "$in"; mkdir -p "$in/base-rules"
echo "$sha" > "$in/head.txt"
git -C "<worktree>" diff "origin/<default-branch>...$sha" > "$in/diff.patch"
git -C "<worktree>" ls-tree -r --name-only "origin/<default-branch>" -- AGENTS.md CLAUDE.md GEMINI.md CONTRIBUTING.md .github/workflows |
  while read -r f; do mkdir -p "$in/base-rules/$(dirname "$f")"; git -C "<worktree>" show "origin/<default-branch>:$f" > "$in/base-rules/$f"; done
```

Then write two files with your file-write tool:

- `problem.md`: the title and full text of each issue (or the spec change) this work solves, as you read them.
- `exceptions.md`: every named exception the implementation and fix subagents reported so far (what was proved by a check instead of a test, why, the check, its output before and after), or `none`.

Build it again for each round, since the head moves.

## Reviewers

Before starting a lens, delete its last report, so the new reviewer reads no earlier output and a missing file means it wrote none:

```bash
rm -f "<scratch>/<slug>-lens/<lens>.md"
```

Then run one fresh reviewer per lens, in parallel: a new subagent that saw none of this work (in Claude Code, a new `general-purpose` agent, never a fork). If your agent has no subagents, review one lens at a time yourself, reading the brief as written. Prompt each with only:

```
Review the change on branch <branch> through the <lens> lens. Its head is checked out at <worktree>. Its inputs are in <inputs>.
Read <absolute path to this skill>/references/lenses.md and follow it. Write your output to <scratch>/<slug>-lens/<lens>.md.
```

`<lens>` is `correctness`, `security`, `tests`, `simplicity`, `ux` (only when UI files changed) or `domain-<name>`. For a domain lens, add the project's rules for that area, quoted from its docs. Add nothing else: no summary of the change and nothing about what it is meant to do.

## Reports

If a lens replies with its whole output instead of only its verdict line, save the reply to its file unchanged. Then check each file exists; run a lens whose file is missing again, once. Finally make `Reviewed: <sha>` each file's first line, with the `sha` from `head.txt`. Tag only the reports this round wrote:

```bash
f="<scratch>/<slug>-lens/<lens>.md"; { echo "Reviewed: $sha"; cat "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
```

Once the PR is open, give the folder to `review-pr`: a report whose `Reviewed:` line is the PR's head stands in for its lens review of that commit.
