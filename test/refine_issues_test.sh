#!/usr/bin/env bash
# The refine-issues skill selects open issues oldest first, skips parents with
# open sub-issues, and writes issue text through a quoted heredoc.
# Usage: test/refine_issues_test.sh
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

skill="$root/skills/refine-issues/SKILL.md"
check "the refine-issues skill exists" "yes" "$([ -f "$skill" ] && echo yes || echo no)"
check "GitHub sorts oldest first, so a large backlog still reaches its oldest issues" "yes" "$(has "$skill" '--search "sort:created-asc"')"
check "a keyword focus folds into the same search as the sort" "yes" "$(has "$skill" '--search "<keyword> sort:created-asc"')"
check "a label focus keeps the oldest-first sort" "yes" "$(has "$skill" '--label <label> --search "sort:created-asc"')"
check "the skill no longer sorts by createdAt after fetching" "no" "$(has "$skill" "sort by \`createdAt\`")"
check "open sub-issues means total greater than completed" "yes" "$(has "$skill" "total > completed")"
check "a text containing the heredoc delimiter gets another delimiter" "yes" "$(has "$skill" "line that is exactly \`GH_TEXT\`")"
check "the proposer brief asks for a plain-words summary for a reader who hasn't seen the issue" "yes" "$(has "$skill" "two-sentence plain-words summary")"
check "Decide shows each issue as its own clickable choice" "yes" "$(has "$skill" "own clickable choice")"
check "Decide asks one decision per issue" "yes" "$(has "$skill" "one decision per issue")"
check "Decide no longer shows the batch one line per issue" "no" "$(has "$skill" "one line per issue")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
