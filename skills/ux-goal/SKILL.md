---
name: ux-goal
description: Judge a running web app against one user goal. A fresh subagent that has never seen the source code tries the goal in a browser like a first-time user, logging what it expected at each step and what happened. The orchestrator then scores the attempt against an observable success state and the shortest path in the code, and writes a verdict (Completed, Completed with workaround, Failed) with friction ranked by how much it cost the goal. Use when the user gives a goal or task to test ("can a new user invite a teammate?"), asks for a targeted or goal-based UX test, or wants to know whether a flow works for real users.
license: MIT
metadata:
  tags: ux testing usability goal task-success browser
---

# UX Goal

Find out whether a real user could reach this goal, and what it cost them on the way.

A tester who has read the code knows where everything is and finds the path no real user would. So the attempt goes to a fresh subagent that only has the browser, and you judge its run afterwards against what the code says the path should be.

For a broad sweep with no single goal, use the `ux-crawl` skill instead.

## Requirements

- A browser tool that can open the running app and take screenshots. If there is none, stop and tell the user. Do not judge a goal from the source code.
- A running app with test data, and a test account for the persona's role. Find them as in `ux-crawl` step 1; never use real credentials or personal data.

## 1. Frame the goal

Write these down and show them to the user before the attempt. Ask only for what you cannot work out:

- **Goal:** in the user's words ("invite a teammate to my project").
- **Persona:** who is trying, and what they already know ("signed up yesterday, has never seen settings").
- **Start:** the URL and state they begin in (signed out, signed in, empty account, account with data).
- **Success:** an observable end state that a screenshot or the page can prove ("the teammate's email appears under Members with status Invited"). "The user feels done" is not one.

Several goals: frame each one and run them one after another, never in parallel in the same browser.

## Give-up rule

A real user doesn't search forever. The attempter stops and records Failed when any of these happens:

- three tries at the same step without progress
- 25 actions in total (for a long goal, the user can raise the cap when you frame it)
- it would need something a real user wouldn't do: typing a URL it guessed, reading page source, or using dev tools

## 2. Attempt

Spawn a fresh subagent (not a fork). Give it the goal, persona, start, success state, the test account, and the give-up rule, and never the source code, routes, your shortest path, or your guesses about where things are. Tell it:

> You are this persona, using this app for the first time. Using only the browser, try to reach the goal. Before each action, write what you expect to happen; after it, write what happened. Note every moment you hesitate, guess, backtrack or misread something, and screenshot it. Stop at success or under the give-up rule. Do not change any code. Return the log as a table: `| Step | Action | Expected | Happened |`, then the outcome, the screenshots, and any console errors or failed requests you saw.

If you cannot start a fresh subagent, do the attempt yourself before you read any code for this app, and say so in the report.

## 3. Find the shortest path

Now read the code (routes, nav, the forms involved) and write the shortest path a user could take from start to success, as numbered steps. Note anything the path depends on that a first-time user cannot see: an item in a hidden menu, a setting that must be on, a label that only makes sense if you know the data model.

## 4. Evaluate

Compare the attempt's log with the shortest path. Check the success state yourself from the final page or screenshot; do not take the attempter's word for it.

- **Verdict:** Completed | Completed with workaround | Failed. A workaround is anything off the intended path that a real user might not find (a search, a guessed link, a retry after an unexplained error).
- **Efficiency:** steps taken vs steps on the shortest path, and where the detours began.
- **Friction:** every step where Expected and Happened differ, plus each hesitation, backtrack and error. Rate each by what it cost the goal:
  - **HIGH:** blocked the goal or forced a workaround
  - **MEDIUM:** caused a detour or a retry
  - **LOW:** slowed or confused, but the next step was still found
- **Confirmation:** did the persona know they had succeeded, without checking elsewhere?
- **Recovery:** when something went wrong, did the page say what and how to fix it?

For each friction point, propose the smallest change that would have kept the persona on the shortest path (a label, a link, moving an item out of a menu, an error message).

## 5. Report

Write `ux-goal-report.md` next to the screenshots, in the place `ux-crawl` step 3 would choose, and do not commit it:

```markdown
# UX Goal Report

**Goal**: ...
**Persona**: ...
**Start**: ...
**Success state**: ...
**Verdict**: Completed | Completed with workaround | Failed
**Steps**: taken N, shortest path M

## Attempt
| Step | Action | Expected | Happened |
|------|--------|----------|----------|

## Shortest path
1. ...

## Friction
| # | Severity | Step | What happened | Smallest fix |
|---|----------|------|---------------|--------------|

## What worked well
- ...
```

Tell the user the verdict, steps taken vs shortest, and the top three friction points in one line each.

## 6. File issues (only after confirmation)

Offer to file the HIGH and MEDIUM friction points as GitHub issues, and do it only on the user's yes, the way `ux-crawl` step 9 does: existing labels only, dedupe first, show the plan and wait. Each issue names the goal and persona, the step, what happened, and the smallest fix.
