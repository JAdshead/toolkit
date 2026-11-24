#!/usr/bin/env bash
# The ux-goal skill judges an app against one user goal: a fresh attempter
# with no source code tries the goal in a browser, and the result is scored
# against an observable success state and the shortest path in the code.
# Usage: test/ux_goal_test.sh
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
# section FILE HEADING-PREFIX: the lines under a "## " heading, up to the next one.
section() {
  [ -f "$1" ] || return 0
  awk -v h="## $2" 'index($0, h) == 1 { on = 1; next } /^## / { on = 0 } on' "$1"
}

skill="$root/skills/ux-goal/SKILL.md"
check "the ux-goal skill exists" "yes" "$([ -f "$skill" ] && echo yes || echo no)"
check "success is an observable end state" "yes" "$(has "$skill" "observable end state")"
check "the attempt has a give-up rule" "yes" "$(has "$skill" "## Give-up rule")"
check "the give-up cap does not need the shortest path, which is only found after the attempt" "no" "$(has "$skill" "twice the shortest path")"
check "the user can raise the action cap when framing the goal" "yes" "$(has "$skill" "raise the cap")"
check "the attempter is a fresh subagent" "yes" "$(has "$skill" "fresh subagent")"
check "the attempter never sees the source code" "yes" "$(has "$skill" "never the source code")"
check "the attempt logs what the user expected at each step" "yes" "$(has "$skill" "| Step | Action | Expected | Happened |")"
check "the evaluation compares the attempt's log with the shortest path" "yes" \
  "$(section "$skill" "4. Evaluate" | grep -qiF "Compare the attempt's log with the shortest path" && echo yes || echo no)"
check "the verdict has three outcomes" "yes" "$(has "$skill" "Completed | Completed with workaround | Failed")"
check "issues are filed the way ux-crawl files them" "yes" "$(has "$skill" "\`ux-crawl\` step 9")"
check "before the attempt, only the start URL and test accounts are read" "yes" \
  "$(has "$skill" "only the start URL and test accounts")"
check "a guessed URL is not both a workaround and a failure" "no" "$(has "$skill" "a guessed link")"
check "the output folder is chosen when framing the goal" "yes" \
  "$(section "$skill" "1. Frame" | grep -qiF "output folder" && echo yes || echo no)"
check "the attempter is told where to save screenshots" "yes" \
  "$(section "$skill" "2. Attempt" | grep -qiF "output folder" && echo yes || echo no)"
check "the report has a Date line" "yes" "$(has "$skill" "**Date**: YYYY-MM-DD")"
check "the report has an App line" "yes" "$(has "$skill" "**App**:")"

check "ux-crawl points goal-judging runs to ux-goal" "yes" "$(has "$root/skills/ux-crawl/SKILL.md" "\`ux-goal\` skill")"
check "the README lists ux-goal" "yes" "$(has "$root/README.md" "| \`ux-goal\` |")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
