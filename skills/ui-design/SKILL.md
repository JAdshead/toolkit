---
name: ui-design
description: Build or restyle web UI by looking at it, not guessing. Follows the project's DESIGN.md (creates one from a template if missing), proposes two or three distinct directions before a new look is built, avoids generic AI-default styling, checks every screen in a real browser at desktop and mobile widths, and has a fresh-context subagent critique the screenshots before calling it done. Use when the user asks to build, design, restyle or polish a page, screen, component or web app UI.
license: MIT
metadata:
  tags: ui ux design frontend screenshots critique
---

# UI Design

A screen is done only when you have seen it rendered and a reviewer who didn't build it has critiqued the screenshots.

Code written without looking produces plausible CSS and a generic result. So every change goes through the browser, and the critique goes to someone who never saw the code.

## Requirements

A browser tool that can open the running app and take screenshots (for example the built-in browser pane or Playwright). If there is none, stop and tell the user. Do not design blind.

## 1. Load the design system

Read `DESIGN.md` at the repo root, or wherever the project's `AGENTS.md` points. Use its tokens: no colour, font size, spacing or radius that isn't in it. Read the existing theme (Tailwind config, CSS variables) and component library too, and build with what is there.

If there is no `DESIGN.md`, copy [`references/DESIGN.md`](references/DESIGN.md) to the repo root. Fill in what the code already decides, then go to step 2 to settle the rest.

Know who uses the screen and the one thing they come to do. That decides what is biggest and first. If `DESIGN.md` doesn't say, ask the user and write it down.

## 2. Propose directions

For a new app, a new look, or a restyle, propose two or three directions before building. Skip this when `DESIGN.md` already sets the direction and the task is a screen inside it.

Make them really different, not three shades of one idea. Each one gets:

- a name and a one-line reference ("dense and quiet, like a terminal"; "airy, editorial, big type")
- a palette (neutral ramp plus one accent), a type pairing and a density
- a quick render of the main screen and a screenshot of it

If the `ui-ux-pro-max` skill is available, use it to ground styles, palettes and font pairings. Show the screenshots, let the user pick or mix, and write the chosen tokens into `DESIGN.md`.

## 3. Build one screen at a time

Build with the project's components and `DESIGN.md` tokens. Avoid everything in Banned defaults below unless `DESIGN.md` asks for it.

Build every state, not just the full one: empty, loading, error, very long text, many items, and signed-out if it applies.

## 4. Look at it

Run the app (the project's launch config, or the `run` skill if available). Screenshot each state at 1280 and 375 px wide. Check against `DESIGN.md` and the chosen direction: alignment, spacing on the scale, one clear focal point, readable contrast, visible keyboard focus, no console errors. Fix what is off and screenshot again.

## 5. Critique with fresh eyes

Spawn a fresh subagent (not a fork) and give it the screenshot paths, `DESIGN.md`, and the user and task from step 1. Do not give it the code or your reasoning. Tell it:

> You are a senior product designer reviewing these screenshots. List the problems, most serious first: visual hierarchy, alignment, spacing consistency, contrast, typography, missing or broken states, anything that breaks `DESIGN.md`, and anything on its Don't list. For each, name the screenshot, say what is wrong and give the fix. Mark each one serious or minor. If nothing is serious, say so.

Fix the serious problems, then go back to step 4. Stop when a round finds nothing serious, or after two rounds. List the minor problems left for the user instead of looping again.

## 6. Report

Show the user the final screenshots, the direction used, what the critique found, and what is left. For a whole-app check once several screens exist, suggest the `ux-crawl` skill.

## Banned defaults

These make UI look machine-made. Avoid them unless `DESIGN.md` asks for one.

- Purple, indigo or pink gradients; gradient text
- Cards inside cards; border, shadow and tinted background all on one element
- Emoji used as icons
- Everything centred; every element the same size and weight
- More than one accent colour; grey text on a coloured background
- Spacing or font sizes off the scale (13px, 22px)
- A default font at one weight with no reason given in `DESIGN.md`
- Filler copy: "Welcome to X", "Unlock the power of", lorem ipsum in a finished screen
