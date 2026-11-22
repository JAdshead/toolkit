# toolkit

Reusable agent skills and working rules, shared across projects and across agents: Claude Code, Codex and Gemini CLI.

Skills are plain [Agent Skills](https://agentskills.io) folders (`skills/<name>/SKILL.md`), so every agent reads the same files. Claude Code loads them as a plugin from the marketplace in this repo; Codex and Gemini CLI read them through symlinks in `~/.agents/skills/`.

## Setup

There are three ways in. Most people want 1, and 2 in every repo they work on.

| | Who it's for | Skills | Rules |
|---|---|---|---|
| 1. Install on your machine | you, in every repo, in every agent | Claude Code, Codex, Gemini CLI | global, for all three |
| 2. `toolkit init` in a repo | everyone who works in that repo, toolkit installed or not | Claude Code (plugin enabled in the repo) | committed to the repo's `AGENTS.md`, read by all three |
| 3. Claude Code plugin only | trying it out | Claude Code | added at session start by the plugin's hook |

### 1. Install on your machine

```bash
git clone https://github.com/JAdshead/toolkit.git ~/toolkit
```

```bash
~/toolkit/install.sh
```

`install.sh` is safe to re-run. It:

| What | Where |
|------|-------|
| Links each skill | `~/.agents/skills/<name>` (Codex and Gemini CLI both read this folder) |
| Links the shared rules | `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` → `rules/AGENTS.md` |
| Imports the shared rules for Gemini | adds `@./toolkit-AGENTS.md` to `~/.gemini/GEMINI.md`, with `~/.gemini/toolkit-AGENTS.md` → `rules/AGENTS.md` |
| Links the `toolkit` command | `~/.local/bin/toolkit` |
| Adds this repo as a Claude Code marketplace and installs plugin `toolkit` | skills appear as `toolkit:<name>` |
| Installs [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) from its own source | Claude Code: its marketplace. Codex and Gemini: a clone in `vendor/` (gitignored), linked into `~/.agents/skills/` |

Any existing file in the way is moved to `<file>.bak.<timestamp>`, never deleted.

Gemini gets an import rather than a symlink because Gemini's `save_memory` appends to `~/.gemini/GEMINI.md`; through a symlink those private memories would land in this public repo.

The rules links work in both directions: editing `~/.claude/CLAUDE.md` edits `rules/AGENTS.md` here. Review `git diff` before committing.

Needs `git`. The Claude Code steps are skipped if `claude` isn't on your `PATH`. Restart running agents after installing.

### 2. Set up a repo

The rules installed in step 1 reach only you. To make sure every person and agent working in a repo follows them, and knows when to use skills such as `review-pr`, run this from the repo's root:

```bash
toolkit init
```

It is safe to re-run, and re-running it after `toolkit update` refreshes the rules. It:

| What | Where |
|------|-------|
| Adds the shared rules between `<!-- toolkit:start -->` and `<!-- toolkit:end -->` markers, one heading level down | `AGENTS.md` (created if missing; an existing block is replaced, everything else is kept) |
| Makes Claude Code read `AGENTS.md` | `CLAUDE.md`: created as `@AGENTS.md`, or that line appended. Left alone if it already imports `AGENTS.md` or is a link to it |
| Makes Gemini CLI read `AGENTS.md` | `GEMINI.md`: created as `@./AGENTS.md`, or that line appended. Left alone if it already imports `AGENTS.md` or is a link to it |
| Enables the plugin for everyone who opens the repo in Claude Code | `.claude/settings.json`: adds the `toolkit` marketplace and `toolkit@toolkit`, keeping other keys and any value the repo already set |

Codex reads `AGENTS.md` itself. Needs `jq`. init follows no symlinks (a `CLAUDE.md` or `GEMINI.md` linking to `AGENTS.md` is left as it is) and refuses broken markers or settings that aren't a JSON object; if any check fails it changes nothing. It ends by printing the toolkit's settings as they stand. Review the changes, then commit them. Edit the rules in this repo's `rules/AGENTS.md`, never inside the markers; the next `toolkit init` overwrites the block.

Without `toolkit init`, add the plugin to `.claude/settings.json` by hand:

```json
{
  "extraKnownMarketplaces": {
    "toolkit": { "source": { "source": "github", "repo": "JAdshead/toolkit" } }
  },
  "enabledPlugins": { "toolkit@toolkit": true }
}
```

### 3. Claude Code plugin only

In Claude Code 2.1.275 or later:

```
/plugin install toolkit --marketplace JAdshead/toolkit
```

On earlier versions, `/plugin marketplace add JAdshead/toolkit`, then `/plugin install toolkit@toolkit`.

The plugin's SessionStart hook ([`hooks/session-start`](hooks/session-start)) adds the shared rules to each session, so plugin-only users get them too. It stays silent when the rules already reach the session: the repo has a `toolkit init` block, or `~/.claude/CLAUDE.md` is the rules file from step 1.

### Check it worked

- **Claude Code:** start a new session; `/skills` lists `toolkit:review-pr` and the others.
- **Codex and Gemini CLI:** `ls ~/.agents/skills` shows a link per skill.
- **Rules:** ask the agent "what are your rules for reviewing a pull request?" It should say a fresh-context review using `review-pr`.
- **The toolkit itself:** `toolkit validate`.

## Update

```bash
toolkit update
```

This pulls this repo (`git pull --ff-only`), refreshes ui-ux-pro-max (its Claude Code marketplace and plugin, and the `vendor/` clone), and re-runs `install.sh` so new skills get linked and removed ones get unlinked. Then run `toolkit init` again in each repo you set up, to pick up rule changes.

Claude Code reads the `toolkit` plugin in place from this checkout, because the marketplace was added from a local path. Edits to skills take effect at the next session start, or mid-session with `/reload-plugins`, with no version bump.

### Auto-update and `DISABLE_AUTOUPDATER`

Claude Code's plugin auto-update is **off by default** for any marketplace that isn't Anthropic's official one, including this one and ui-ux-pro-max's. Separately, `DISABLE_AUTOUPDATER=1` (in `~/.claude/settings.json` → `env`) turns off the whole plugin auto-update pass and hides its toggle, even for marketplaces where you turned it on. Set `FORCE_AUTOUPDATE_PLUGINS=1` alongside it to keep plugin auto-updates while Claude Code's own updater stays off. See the [env vars](https://code.claude.com/docs/en/env-vars) and [plugin loading](https://code.claude.com/docs/en/plugins/loading) docs.

None of that matters for `toolkit` itself, which is read live from the checkout. It only affects ui-ux-pro-max, which `toolkit update` refreshes explicitly.

## What belongs here

**Here:** skills and rules that work unchanged in any repo: workflows (collecting feedback into issues, working through issues, tech-debt sweeps), testing and review habits.

**In the project instead:** anything that names a specific product, service, deploy target, data model or team convention; project commands and scripts; rules that only make sense with that codebase's stack. A project's own `CLAUDE.md`/`AGENTS.md` overrides the generic rules here.

This repo is public. Nothing private goes in: no customer or product names, credentials, internal URLs, issue numbers or emails.

## Add a skill

1. Create `skills/<name>/SKILL.md` with frontmatter `name: <name>` (lowercase, hyphens, matching the folder) and a `description` that says what it does and when to use it.
2. Run `toolkit validate` (CI also runs it, plus `claude plugin validate .` and shellcheck).
3. Run `toolkit install` to link it for Codex and Gemini. Claude Code picks it up at the next session.
4. If agents should know when to reach for it beyond its `description`, add one line to `rules/AGENTS.md` naming the skill, and keep the how in the skill itself.

## Skills

| Skill | What it does |
|-------|--------------|
| `collect-feedback` | Rapid-fire capture of bugs, ideas and tasks; organizes them and files GitHub issues after you confirm |
| `place-issues` | Project mode: puts issues on the GitHub Project board with Status, fields and parent issues after you confirm; sets up a board |
| `implement` | Takes one issue or spec change to a reviewed pull request: worktree, test-first, three independent reviewers, CI loop |
| `review-pr` | Fresh-context PR review: lens reviewers on larger PRs, one or two independent owners who each decide MERGE or NOT YET, and a validator that confirms every blocking finding |
| `tackle-issues` | Works through a batch of issues: groups them into PRs, one worktree per group, parallel specialist reviews with a finite exit |
| `tech-debt` | Read-only audit for dead code, duplication, architecture smells and weak tests; files ranked issues after you confirm |
| `glossary` | Builds and refines `GLOSSARY.md`: challenges vague or conflicting terms as they come up, settles one word per concept, audits for drift and bloat |
| `ux-crawl` | Exploratory crawl of a running web app with browser automation; reports UX, bugs, accessibility and console errors |

In Claude Code they appear as `toolkit:<name>`.

## Issue tracking: simple or project

GitHub issues are the way in. Every skill that files work (`collect-feedback`, `tech-debt`, `ux-crawl`) creates plain issues, the same way in every repo. What happens next depends on the repo:

- **Simple:** the issue is where it finishes. Labels, assignees and a `wip` label track it. Good for small projects with a flat list of tasks.
- **Project:** one extra step, the `place-issues` skill, puts new issues on the repo's GitHub Project board: Status, Priority/Size fields, and a parent issue with native sub-issues for larger features. The board then tracks state (Todo, In progress, In review, Done). Needs `gh auth refresh -s project`.

A repo declares its mode in an `Issue tracking` section of its `AGENTS.md`/`CLAUDE.md`; otherwise one board linked to the repo means project mode and none means simple. `place-issues setup` moves a repo from simple to project. The skills that pick up work (`implement`, `tackle-issues`) claim, move and release issues per mode using [`shared/issue-tracking-mode.md`](shared/issue-tracking-mode.md) to settle the mode and [`shared/issue-tracking.md`](shared/issue-tracking.md) for the operations.

## Shared references

Each skill is linked as its own folder, so a skill can't reach files outside it. Text and scripts several skills need live once in `shared/` and are copied into `skills/<name>/references/` or `skills/<name>/scripts/` for every skill whose `SKILL.md` mentions `references/<file>` or `scripts/<file>`. Tests for shared scripts stay in `shared/test/`. Edit the copy in `shared/`, then run `bin/sync-shared` from the checkout you are editing (`toolkit sync` acts on the installed checkout); `toolkit validate` and CI fail if a copy drifts. `bin/sync-shared` also removes a copy once its `SKILL.md` stops mentioning it, but it can't see copies of a file that is gone from `shared/`: when you delete a shared file, delete its copies too.

Prefer more, smaller skills: when a workflow gains a distinct step, give it its own skill rather than growing an existing one.

## License

MIT
