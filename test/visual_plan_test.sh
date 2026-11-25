#!/usr/bin/env bash
# The visual-plan skill shows plans and decisions as visuals and clickable
# choices instead of walls of text, one decision at a time, and checks the
# plan landed with a short quiz before asking for approval.
# Usage: test/visual_plan_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$here/.."

failures=0
passes=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passes=$((passes + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual"
  fi
}
has() { if [ -f "$1" ] && grep -qiF -- "$2" "$1"; then echo yes; else echo no; fi; }

skill="$root/skills/visual-plan/SKILL.md"
check "the visual-plan skill exists" "yes" "$([ -f "$skill" ] && echo yes || echo no)"
check "the plan's shape comes before its detail" "yes" "$(has "$skill" "shape first")"
check "what changes is shown as before and after" "yes" "$(has "$skill" "before and after")"
check "decisions are asked one at a time" "yes" "$(has "$skill" "one decision at a time")"
check "choices are clickable, not typed" "yes" "$(has "$skill" "clickable")"
check "a quiz card checks the plan landed before approval" "yes" "$(has "$skill" "quiz card")"
check "a progress map shows where we are" "yes" "$(has "$skill" "you are here")"
check "text is capped by structure, not a line count" "yes" "$(has "$skill" "one topic")"
check "it falls back to text visuals where widgets are unavailable" "yes" "$(has "$skill" "no widget")"
check "it points to show-me for diagram formats" "yes" "$(has "$skill" "\`show-me\`")"

rules="$root/rules/AGENTS.md"
check "the shared rules send plans and decisions to visual-plan" "yes" "$(has "$rules" "\`visual-plan\` skill")"
check "the README lists visual-plan" "yes" "$(has "$root/README.md" "| \`visual-plan\` |")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
