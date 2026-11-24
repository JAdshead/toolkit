---
name: ui-design
description: Build or restyle UI by looking at it. Follows the project's DESIGN.md (or starts one from a template), proposes two or three distinct directions with screenshots before a new look, builds one screen at a time with every state, avoids banned AI-default styles, screenshots each state on desktop and mobile, and has a fresh subagent critique the screenshots. Use when building, restyling or polishing a page, screen or component, or when the user says the UI looks generic or off.
license: MIT
metadata:
  tags: ui design frontend screenshots visual-review
---

# UI Design

Never call UI work done without seeing it. Plausible CSS read as code produces generic UI; the screenshot is the evidence.

## 1. Design source

Follow the project's `DESIGN.md`. If it has none, copy [references/DESIGN.md](references/DESIGN.md) to the repo root and fill it in with the user before building.

## 2. Directions

For a new look or a restyle, propose two or three genuinely different directions (type, colour, density, layout), each with a screenshot of one key screen, and let the user pick before building. Use the `ui-ux-pro-max` skill for palettes, font pairings and styles when it is available. Record the chosen direction in `DESIGN.md`. Skip this for changes inside an existing look.

## 3. Build

Build one screen at a time. Give it every state: empty, loading, error, long text, many items. Avoid every item in Banned defaults below unless `DESIGN.md` asks for it.

## 4. Look

Screenshot each state at 1280 and 375 px wide (the browser or Playwright tooling this session has). Look at every screenshot and fix what is off (alignment, spacing, overflow, contrast, a banned default) before moving on.

## 5. Critique

Spawn a fresh subagent: no fork, no code, nothing of your reasoning. Give it the screenshots, `DESIGN.md`, this skill's Banned defaults section verbatim, and who the user is and what the screen is for. Ask it to list what looks generic, broken or off-brand, and any banned default it sees, each marked serious or minor.

Fix the serious problems and take new screenshots. Stop when a round finds nothing serious, or after two rounds; hand the remaining minor findings to the user.

## Banned defaults

- **Purple-to-blue gradients** as backgrounds, buttons or headline text.
- **Emoji as icons** in headings, buttons or lists.
- **Glassmorphism** (frosted, blurred translucent cards) without a reason in `DESIGN.md`.
- **Everything centred**: centred hero, centred text blocks, symmetric card grids by default.
- **Three identical feature cards** with an icon, a title and two lines each.
- **Uniform large radius and soft shadow** on every element.
- **Inter or system font everywhere** with no type scale or contrast between levels.
- **Grey-on-grey low-contrast text** below WCAG AA.
- **Placeholder copy** (lorem ipsum, "Welcome to our platform", "Get started today").
