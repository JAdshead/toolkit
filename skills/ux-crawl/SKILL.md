---
name: ux-crawl
description: Exploratory UX crawl of a running web app through browser automation. Acts like a thoughtful user tester, working through goals or free-form paths and checking UX friction, functional bugs, accessibility, responsive layout, console errors and failed network requests. Writes a severity-ranked report with screenshots, then offers to file deduplicated GitHub issues after confirmation. Use when the user asks for a UX crawl, exploratory or manual-style testing, a usability or accessibility sweep, or "click around the app and find problems".
license: MIT
metadata:
  tags: ux testing exploratory accessibility browser playwright
---

# UX Crawl

Explore a running web app the way a careful human tester would, and find the issues scripted tests miss. This is exploratory, not scripted: you decide where to look, but you record everything you find.

## Requirements

- **Browser automation.** Use whichever browser tools this session provides (for example Playwright MCP: `browser_navigate`, `browser_snapshot`, `browser_click`). Tool names below are examples; map them to your tools. If no browser tool is available, stop and tell the user. Do not fake a crawl from source code.
- **A running app** you can reach, with test data in it.
- **Test accounts** for each role you need to cover.

## Arguments

Read these from whatever the user passed:

| Argument | Mode | Behaviour |
|---|---|---|
| (none) | Goals | Work through every section of the goals file, or the plan you build in step 2 |
| an area name (e.g. `auth`, `checkout`) | Focused | Only that section or area |
| `--free` | Free | Follow your curiosity from the home page |
| `--mobile` | modifier | Run the whole crawl at 375x812 |
| `--issues` | modifier | Offer to file issues at the end without being asked (still needs confirmation) |
| any other text | Ad hoc | Treat it as the objective, e.g. "sign up and change my password" |

Flags combine: `auth --mobile --issues`.

## 1. Discover the app

Find these before opening the browser. Look in the repo first and ask the user only for what you cannot find.

- **Base URL and how to start it.** README, `Procfile*`, `package.json` scripts, `bin/` scripts, `docker-compose*`, `.claude/launch.json` or other launch configs, framework defaults.
- **Routes and pages.** The routes file or router (`config/routes.rb`, `urls.py`, `app/` or `pages/` directories, a router module), plus the nav links you see once the app loads.
- **Roles.** User types, admin areas, permission checks.
- **Test accounts.** Seed files, fixtures, example configs, a dev-login helper. If none exist, ask the user. Do not create accounts on anything that is not a local or clearly marked test environment without asking.
- **A goals file**, if the project has one (e.g. `docs/ux-goals.md`, `ux-goals.md`). It may hold objectives, start points, hints, success criteria and accounts. Follow it when present.

Credentials you find stay in the session. Never write them into the report, screenshots' filenames or issues.

## 2. Plan the crawl

If there is no goals file, write a short plan before you start, and show it to the user in Goals mode:

- One section per major area (auth, onboarding, the core task, settings, admin, ...).
- For each: the role, the start URL, the objective, and what "done" looks like.
- Order by user value: the core flow first, edge areas last.

Keep it to what one session can actually cover. Note what you are deliberately skipping.

## 3. Verify prerequisites

1. Navigate to the base URL and take an accessibility snapshot.
2. If the page fails to load, report the URL you tried, suggest the start command you found, and stop.
3. If `--mobile` is set, resize to 375x812 now.
4. Choose a writable output location: `ux-report.md` and a `screenshots/` folder at the repo root unless the project already has a place for these (e.g. `docs/`). Do not commit them.

## 4. Explore

Principles:

1. **Happy path first.** Does the obvious flow work?
2. **Then the edges.** Blank fields, invalid input, double submit, back button, refresh mid-flow, deep links while signed out, very long text.
3. **Notice friction.** Anything confusing, slow, unclear or inconsistent is a finding.
4. **Keyboard and screen reader.** Tab through each page you visit.
5. **Record as you go.** Write each finding down the moment you see it.
6. **Stay curious.** Open menus, try unexpected orders, follow links you were not asked to.
7. **Wait for dynamic content.** After any click that triggers an AJAX, SPA or partial-page update, wait for the expected text (or for a spinner to disappear) before judging the result.

By mode:

- **Goals / Focused:** for each section, go to its start point (sign in as the right role), work toward the objective, check the success criteria, record findings, move on.
- **Free:** start at the home page and wander. Cover navigation, every top-level menu and at least one form per area.
- **Ad hoc:** pick a sensible start point and pursue the objective, recording everything on the way.

**Out of scope** unless the user says otherwise: third-party sign-in, real payments, sending real email or SMS, external APIs and integrations. Note them under "Not tested". Never perform destructive actions on data you did not create, and never use real personal or payment data.

## 5. What to check

**Bugs**
- Buttons and links that do nothing or go to the wrong place; broken links (404).
- Forms that accept invalid data, or reject valid data.
- Missing or stale data after an action; a change that needs a refresh to appear.
- JavaScript errors; failed requests (4xx/5xx).

**UX**
- Confusing navigation; unclear labels, buttons or headings.
- No feedback after an action; no loading state during waits.
- Error messages that do not say what went wrong or how to fix it.
- Dead ends with no way forward or back.
- Inconsistent patterns between similar pages; jargon; empty states with no next step.

**Accessibility**
- Form fields without a label (`<label>`, `aria-label` or `aria-labelledby`).
- No visible focus indicator; illogical tab order; focus not trapped in or returned from modals.
- Images without useful alt text; icon-only buttons without an accessible name.
- Dynamic content without the right ARIA (`aria-live`, `aria-expanded`, `aria-disabled`).
- Low colour contrast; information conveyed by colour alone.
- Heading levels that skip or are missing.

**Responsive** (always with `--mobile`; otherwise spot-check key pages at 375x812, then resize back to 1280x720)
- Any horizontal page scroll.
- Overlapping or clipped elements; text that overflows its container.
- Touch targets smaller than 44x44px.
- Navigation hidden or broken; the mobile menu does not open, close or trap focus correctly.
- Forms, modals and tables that do not fit the viewport (tables need their own scroll container).

**Performance**
- Pages or actions that take noticeably long; interactions that feel unresponsive.

**Security** (observe only; do not attack)
- Another user's record reachable by changing an ID in the URL.
- Error messages that leak stack traces or confirm whether an account exists.

### Health checks

Every 3 to 4 pages, and after every form submission:

- **Console:** read console messages at warning level and above. Report errors and meaningful warnings.
- **Network:** list non-static requests and look for 4xx/5xx. Ignore expected 401s on signed-out requests. A failed request is often the root cause of a visible bug, so link the two in the finding.

## 6. Record findings

Record each one when you see it:

```
Category:    Bug | UX | Accessibility | Responsive | Performance | Security
Severity:    HIGH | MEDIUM | LOW
Location:    URL + element ("Save button in the profile form")
Role:        which role, or signed out
Steps:       the shortest path to reproduce
Observation: what happened
Expected:    what should happen
Evidence:    screenshot path, console line or failing request
```

**Severity**

- **HIGH:** broken functionality, data loss risk, security concern, a blocking accessibility failure (cannot complete a task with a keyboard or screen reader), any 5xx.
- **MEDIUM:** confusing flow, unclear errors, missing feedback, inconsistent behaviour, 4xx on a valid path, responsive breakage on a key page.
- **LOW:** minor visual issues, polish, suggestions.

Judge severity by impact on a real user, not by how easy it is to fix.

### Screenshots

Use the snapshot for navigating and finding element refs; use screenshots only for evidence. Save to the screenshots folder with an area prefix and a description:

- `screenshots/auth-no-error-on-wrong-password.png`
- `screenshots/a11y-no-focus-ring-main-nav.png`
- `screenshots/mobile-settings-horizontal-scroll.png`

Before taking a screenshot, make sure it does not show a password, token or real personal data.

## 7. Practical tips

- **Signing in:** go to the sign-in page, snapshot to get refs, fill the form (a multi-field fill tool if you have one), submit, wait for content only a signed-in user sees, then snapshot to confirm.
- **Several roles:** sign out fully between roles, or use a separate browser context or tab. If one account has several roles, test the switcher and that each view shows the right data.
- **Dialogs:** accept or dismiss native confirm/alert dialogs with the dialog tool; note any destructive action that has no confirmation.
- **Hover states and tooltips:** hover, then snapshot.
- **Keyboard:** press Tab, Shift+Tab, Enter, Escape and arrow keys; snapshot to see where focus went.
- **DOM checks:** use a JavaScript-evaluate tool to read computed styles, ARIA attributes, `document.documentElement.scrollWidth > innerWidth` for horizontal scroll, or element sizes for touch targets.
- **Multi-tab and drag-and-drop:** use the tab and drag tools where the app depends on them.

## 8. Write the report

When the goals are covered or you reach a natural stopping point, close the browser and write the report:

```markdown
# UX Crawl Report

**Date**: YYYY-MM-DD
**App**: base URL (local or test environment)
**Mode**: Goals | Focused | Free | Ad hoc
**Areas**: ...
**Roles**: ...
**Viewport**: Desktop 1280x720 | Mobile 375x812 | Both

## Summary

| # | Category | Severity | Location | Issue |
|---|----------|----------|----------|-------|
| 1 | Bug | HIGH | /items/new | Form submits with empty required fields |
| 2 | UX | MEDIUM | /search | No loading state while results load |
| 3 | A11y | LOW | /sign_up | Email field has no visible label |

HIGH: n · MEDIUM: n · LOW: n · Total: n

## Findings

### 1. Form submits with empty required fields
- **Category / Severity**: Bug / HIGH
- **Location**: /items/new, Save button
- **Role**: standard user
- **Steps**: open the form, leave every field blank, click Save
- **Observation**: a blank record is created
- **Expected**: validation errors next to each required field
- **Evidence**: screenshots/items-empty-form-saves.png

## Console errors
(list, or "None detected")

## Failed network requests
(method, path, status; or "None detected")

## What worked well
- ...

## Coverage
- **Explored thoroughly**: ...
- **Lightly touched**: ...
- **Not tested, and why**: ...
```

Order findings by severity, then by area. Merge duplicates: one root cause seen on five pages is one finding with five locations.

Then tell the user: where the report is, counts by severity, and the top three findings in one line each.

## 9. File issues (only after confirmation)

Offer this at the end, and do it only when the user agrees. `--issues` means offer it unprompted; it is not consent.

1. **Check the tracker.** Confirm `gh` is installed and authenticated and that the repo has a GitHub remote. If not, stop at the report.
2. **Read the labels.** `gh label list --limit 200`. Use only labels that exist; map Bug and Security to the repo's bug label, the rest to its enhancement or UX or accessibility label if present. Do not create labels without asking.
3. **Dedupe.** `gh issue list --state open --limit 200 --search "<key words>"` for each finding. Mark each as new, duplicate (link it) or related (link it in the body).
4. **Show the plan and wait.** Present a table: finding, proposed title, labels, and new / duplicate of #N. Default to HIGH and MEDIUM only. Let the user drop, merge, re-rate or add LOW findings. Create nothing until they confirm.
5. **Create** each confirmed issue:

```bash
gh issue create --title "<Category>: <short description>" --label "<existing label>" --body "$(cat <<'EOF'
Found during an exploratory UX crawl on YYYY-MM-DD.

**Severity:** HIGH | MEDIUM | LOW
**Location:** /path, element
**Role:** which role, or signed out
**Viewport:** desktop | mobile

**Steps to reproduce**
1. ...

**Observed**
...

**Expected**
...

**Evidence**
Console or network output, if any.
EOF
)"
```

Each body must stand on its own: a reader who never saw the report can reproduce it. Never include passwords, tokens, session cookies or real personal data; name the role ("a standard test user") instead of the account. Local screenshot paths are useless to others, so describe what the screenshot shows, or attach it only if the user asks and it is safe.

6. **Report back** with the list of created issue URLs and any you skipped as duplicates. If the repo tracks work on a GitHub Project board (an `Issue tracking` section saying `Mode: project` in its agent instructions, or a board linked to the repo in `gh repo view --json projectsV2`), offer to run the `place-issues` skill on the new issues.

## Rules

1. Exploratory, not exhaustive. Cover the plan, poke at the edges, move on.
2. Record findings as you find them, not from memory at the end.
3. Snapshots for navigating, screenshots for evidence.
4. Never use real credentials, real payment details or real personal data. Never put credentials in the report or issues.
5. Do not modify application code during a crawl. Report; do not fix.
6. Close the browser when you are done.
