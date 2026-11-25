---
name: visual-plan
description: Present plans and decisions as visuals and clickable choices instead of walls of text, one decision at a time, with a short quiz to check the plan landed before asking for approval. Use whenever you present a plan, propose an approach, compare options, or need the user to decide or approve anything. Built for readers who can't reliably take in long text, such as people with dyslexia.
license: MIT
metadata:
  tags: communication accessibility dyslexia planning decisions visuals
---

# Visual plan

**Show it, don't write it.** Long text gets skimmed, and a skimmed plan gets a blind yes. Every plan or decision should be understood at a glance and answered with a click.

## How

1. **Shape first.** Open with a small diagram of the whole thing: steps, parts, or flow. Detail comes after, and only what the decision needs. A call tree or file tree is often the smallest picture:

   ```
   skills/
   └── visual-plan/
       └── SKILL.md
   ```
2. **Progress map.** For multi-step work, show every step with the current one marked "you are here". Keep the task list in step with it.
3. **Before and after.** Show what changes as a diff of that shape (`+`/`-` lines on the file, call or component tree), not described in a paragraph.
4. **One decision at a time.** Ask, wait, then ask the next. A batch of like items (issues to file, changes to apply) may be confirmed together as one clickable list; separate decisions are still asked one at a time.
5. **Clickable choices.** Offer 2 to 4 options as cards or buttons the user clicks, your pick first. Each option: a 1 to 5 word label, one short line of why.
6. **Quiz card before approval.** Before asking the user to approve a plan, ask 1 or 2 quick clickable questions about it ("What happens to old sessions?"). A wrong answer means the plan wasn't clear: redraw it, don't repeat it louder.

## Text rules

- One topic per message. Split rather than grow.
- Headings and visual anchors (icons, bold keyword first) so the eye can jump.
- Short bullets, one idea each. No paragraphs over 3 lines.
- The ask goes at the top, never buried at the end.
- Pick the one smallest picture that makes the point. Don't stack several views for one point.
- Put each picture beside the short line it supports.

## Tools

Use the richest surface the agent has, in this order:

1. **Question cards** (Claude Code `AskUserQuestion`) for choices and quiz cards. Use `preview` to show what each option looks like.
2. **Inline widgets** (a `show_widget`-style tool) for diagrams, progress maps and before and after, with buttons that send the choice back.
3. **A page** (an Artifact or one HTML file) only when the plan is too big for inline.
4. **Text fallback** (no widget available): draw it in text. A Mermaid diagram, an ASCII flow, a markdown table, and numbered options the user can answer with one digit.

## Keep improving

This is tuned to one reader and is meant to change. When the user says a visual was hard to follow, ask one clickable question about what went wrong, fix it now, and suggest the change to this skill.
