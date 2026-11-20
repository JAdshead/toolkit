---
name: tech-debt
description: Analyze a codebase for technical debt (dead code, duplication, architecture smells, deferred work, framework anti-patterns, low-value tests), rank findings by severity, and file them as GitHub issues after the user confirms the list. Use when the user asks for a tech debt audit, a code quality sweep, a list of refactoring candidates, or wants debt turned into tracked issues. Supports a scoped path, a full scan, selected categories and a dry run.
license: MIT
metadata:
  tags: tech-debt code-quality refactoring analysis github issues
---

# Tech Debt Discovery

Analyze the codebase for technical debt and turn the findings into actionable GitHub issues. The analysis is read-only: never change code while running this skill.

## Options

Parse these from the user's request or command arguments:

- **Scope paths**: directories or files to analyze (for example `src/services lib/`).
- **--full**: scan the whole repository, excluding dependency, build and VCS directories (`node_modules`, `vendor`, `.git`, `dist`, `build`, `target`, `tmp`, `log`, virtualenvs, generated code).
- **--dry-run**: report findings without creating issues.
- **--all**: lift the 20 issue cap.
- **--force**: create issues even when a similar open issue exists.
- **--yes**: skip the confirmation prompt (only when the user passes it explicitly).
- **--categories=X,Y**: run only these categories: `dead-code`, `duplication`, `architecture`, `deferred-work`, `patterns`, `tests`.

## Execution model

Each category is analyzed independently. If your agent can spawn parallel subagents, give each category its own subagent with the scope, detected stack and the category's checklist from `references/categories.md`, and have each return the JSON format below. Otherwise run the categories sequentially, one at a time, to stay inside context limits.

A full six category sequential run takes roughly 15 to 30 minutes on a mid-sized codebase. For faster results, suggest `--categories` or a narrower scope.

## Step 1: Determine scope

1. If paths were given, use them.
2. If `--full` was given, scan the repository with the exclusions above.
3. Otherwise auto-detect the main source and test directories that exist (common ones: `src/`, `app/`, `lib/`, `pkg/`, `internal/`, `cmd/`, `test/`, `tests/`, `spec/`). Show:
   `Auto-detected scope: [directories]. About X files. Continue? (use --full for a complete scan)`

Count source files in scope with the extensions the repo actually uses (for example `git ls-files -- <scope> | grep -E '\.(rb|py|ts|tsx|js|go|java|kt|rs|php|cs)$' | wc -l`).

- Over 1,000 files: warn that the run will be long and suggest `--categories`.
- Over 5,000 files: strongly recommend running one category at a time and give a rough time per category.

## Step 2: Pre-analysis checks

Unless `--dry-run`, check the GitHub CLI:

```bash
gh auth status
```

If it fails, set `gh_available=false` and say: "gh CLI not found or not authenticated. Findings will be reported without creating issues. Run `gh auth login` to enable issue creation."

If available, fetch what is needed later:

```bash
gh issue list --state open --limit 200 --json number,title,body,labels
gh label list --limit 200 --json name,description
```

Keep the issue list for duplicate detection and the label list for labelling.

## Step 3: Detect the stack

Detect the language, framework and test runner from the repository instead of assuming one. Typical indicators:

| Indicator | Stack |
|---|---|
| `Gemfile` with `rails`, or `config/application.rb` | Ruby on Rails |
| `manage.py` or `django` in requirements / `pyproject.toml` | Django |
| `pyproject.toml` / `requirements.txt` with `fastapi` or `flask` | Python web |
| `package.json` with `next`, `react`, `vue`, `svelte`, `express`, `nestjs` | JS/TS framework |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pom.xml` / `build.gradle*` | JVM (Spring if present) |
| `composer.json` with `laravel/framework` | Laravel |
| `*.csproj` | .NET |

Also detect the test framework (RSpec, Minitest, pytest, unittest, Jest, Vitest, Mocha, Go `testing`, JUnit, PHPUnit, and so on) and the test directories.

Read the project's own conventions before judging anything: `README`, `CONTRIBUTING`, agent instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`), linter configs and any architecture docs. A pattern the project deliberately chose is not debt.

Report: `Stack detected: [language / framework / test runner]. Analysis rules adjusted accordingly.`

## Step 4: Run the category analyses

For each enabled category (all six by default):

1. Announce `Analyzing [Category]... (X of N)`.
2. Apply the checklist for that category in `references/categories.md`, adapted to the detected stack.
3. Collect findings in the JSON format below.
4. Report `[Category] complete: X findings`.

If a category runs far longer than the others (about 5 minutes of active analysis), stop it and mark it `Incomplete (truncated)` in the report rather than stalling the run.

### Finding format

Every category returns:

```json
{
  "category": "Dead Code",
  "findings": [
    {
      "type": "Unused Import",
      "severity": "P3",
      "location": "src/utils/format.ts:5",
      "line_number": 5,
      "description": "Import 'date-fns' is never used in this file",
      "evidence": "import { format } from 'date-fns'",
      "remediation": "Remove the unused import",
      "complexity": "simple"
    }
  ]
}
```

For duplication, put every location in `location`, separated by `, `. For architecture findings, put the metrics in `description` (for example "567 lines, 23 public methods").

## Severity reference

| Pattern | Severity | Category |
|---|---|---|
| Tests that hide security issues | P0 | Test Quality |
| Missing authorization check on resource access | P1 | Pattern Violations |
| God classes (>500 lines or >20 public methods) | P1 | Architecture |
| Circular dependencies | P1 | Architecture |
| Unreachable code | P1 | Dead Code |
| Mock-only tests (the test mocks what it is testing) | P1 | Test Quality |
| Stubbing the subject, then asserting on it | P1 | Test Quality |
| Tautological tests | P1 | Test Quality |
| Empty test bodies | P1 | Test Quality |
| Excessive mocking (>50% of the test is setup) | P1 | Test Quality |
| Stubbing every instance of a class | P1 | Test Quality |
| Mutable state shared across tests | P1 | Test Quality |
| Long functions (>50 lines) | P2 | Architecture |
| High coupling (>10 project imports) | P2 | Architecture |
| Exact or near duplicates | P2 | Duplication |
| Deprecation notices | P2 | Deferred Work |
| Temporary or workaround markers | P2 | Deferred Work |
| Framework anti-patterns | P2 | Pattern Violations |
| Implementation-coupled tests | P2 | Test Quality |
| Tests that only assert "does not raise" | P2 | Test Quality |
| Unreferenced functions, dead branches, orphan files | P2 | Dead Code |
| Deep nesting (>4 levels) | P3 | Architecture |
| Unused imports | P3 | Dead Code |
| TODO / FIXME comments | P3 | Deferred Work |
| Commented-out code | P3 | Deferred Work |
| Convention violations | P3 | Pattern Violations |
| Brittle test assertions | P3 | Test Quality |
| TODOs that reference a ticket | P4 | Deferred Work |

## Complexity guide

- **simple**: under 10 lines, one file, obvious fix (remove an unused import).
- **moderate**: 10 to 50 lines, 2 or 3 files, straightforward refactor (extract a function).
- **complex**: over 50 lines, needs an architectural decision, or cuts across the codebase (split a god class). Note in the remediation that it likely needs a design or proposal before implementation.

## Step 5: Collect and deduplicate

1. Group findings by category + file + line (within 10 lines). In each group keep the finding with the most detailed evidence, at the highest severity in the group.
2. Across categories: if Dead Code and Architecture flag the same class, keep the Architecture finding. If several categories flag the same line, merge them and keep the highest severity.
3. Sort P0 first, then P1 to P4.

## Step 6: Check for existing issues

Skip this step only if `--force` is set. For each finding, look for an open issue that:

- mentions the same file path in its title or body, AND
- covers the same type of problem, or a line within 20 lines of this one.

Prefer issues titled `[TechDebt]` or carrying a tech-debt label, but match any open issue that clearly tracks the same problem. On a match, mark the finding `already tracked as #N` and do not file it. Different problem types in the same file are separate findings.

## Step 7: Confirm, then create issues

Skip creation if `--dry-run` or `gh_available=false`; go straight to the report.

**Cap:** at most 20 issues unless `--all`. Fill slots in order: all P0 and P1, then P2 (prefer spreading across files over many issues in one file), then P3, then P4. With `--all` and more than 50 issues, warn that it will take a while.

**Labels:** use only labels that already exist in `gh label list`. Pick the closest match for tech debt (for example `tech-debt`, `technical-debt`, `debt`, `refactor`, `chore`) and, if the repo has them, a priority label matching the severity and a type label (for example `testing`). Never create labels without asking. If no suitable label exists, say so and either file without one or ask the user whether to create `tech-debt`.

**Confirmation (required):** before creating anything, show the full list and wait for the user's answer. Never file issues without it, unless they passed `--yes`.

```
Will create X issues (labels: tech-debt, P2):

1. [P1] [TechDebt] Architecture: Split OrderService (612 lines, 27 public methods)
2. [P1] [TechDebt] Test Quality: Fix mock-only test in payment_test.py:45
3. [P2] [TechDebt] Duplication: Extract address validation (user.ts:40, account.ts:88)
...

Already tracked (skipped): 3. Over the cap (not filed): 12.
Proceed? You can also drop items by number or change labels.
```

Apply any edits the user makes, then create each issue. Every body must stand alone, readable by someone who has not seen this report:

~~~bash
gh issue create \
  --title "[TechDebt] <Category>: <Brief description>" \
  --label "<existing-label>" \
  --body "$(cat <<'EOF'
**Category:** <Category>
**Severity:** P<N>
**Location:** <file:line>

## Problem
<description>

## Evidence
```
<evidence>
```

## Suggested fix
<remediation>

**Complexity:** <simple|moderate|complex>

## Acceptance criteria
- <observable check that the debt is resolved>
- The project's full test suite passes
EOF
)"
~~~

Title examples:

- `[TechDebt] Dead Code: Remove unused imports in format.ts:5-12`
- `[TechDebt] Architecture: Split OrdersController (567 lines, 23 actions)`
- `[TechDebt] Test Quality: Fix mock-only test in payment_service_test.go:45`

If a `gh issue create` call fails, log the error and the command, continue with the rest, and report `Created X issues, Y failed` at the end.

If the repo tracks work on a GitHub Project board (an `Issue tracking` section saying `Mode: project` in its agent instructions, or a board linked to the repo in `gh repo view --json projectsV2`), offer to run the `place-issues` skill on the new issues.

## Step 8: Summary report

```
=== Tech Debt Discovery Report ===

Scope: [paths analyzed]
Files analyzed: [count]
Stack: [language / framework / test runner]
Duration: [time taken]

## Summary
- Total findings: X | Issues created: Y | Already tracked: Z | Over cap: W
- By severity: P0: A, P1: B, P2: C, P3: D, P4: E

## Findings by Category

### Dead Code (X)
- [ ] #N: Remove unused imports in format.ts:5-12 (P3)

### Duplication (X)
- [ ] #N: Extract address validation (user.ts:40, account.ts:88) (P2)

### Architecture (X)
- [ ] #N: Split OrderService (612 lines, 27 public methods) (P1)

### Deferred Work (X)
- [ ] #N: Resolve TODO in billing.py:123 (P3)

### Pattern Violations (X)
- [ ] #N: Fix N+1 query risk in OrdersController#index (P2)

### Test Quality (X)
- [ ] #N: Fix mock-only test in payment_test.py:45 (P1)

## Already Tracked
- billing.py:100 TODO → #N

## Additional Findings (over the cap, not filed)
[list]
Run with --all to file the remaining X findings.

## Skipped (false positive or intentional)
- tests/fixtures/** : fixtures excluded
- TODO(#42) in conftest.py : has a linked ticket (P4)

## Analysis Status
- Dead Code: Complete
- ...
- Test Quality: Incomplete (truncated)

## Errors
[any failed gh commands]
```

For `--dry-run`, replace issue numbers with `[would create]`.

## Principles

1. **Read-only.** No code changes during the analysis.
2. **Conservative.** When unsure, skip rather than report a false positive. A noisy report gets ignored.
3. **Respect the project.** Framework conventions (callbacks, decorators, dependency injection, convention-based routing) and choices documented in the repo are not debt.
4. **Evidence first.** Every finding cites a file, a line and the code that proves it.
5. **Structured output.** Category analyses return JSON so merging and deduplication are reliable.
6. **User confirms before filing.** The list is always shown first.
