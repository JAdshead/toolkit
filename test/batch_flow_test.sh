#!/usr/bin/env bash
# A batch run neither hangs unnoticed, merges onto a base that moved, runs the
# full suite or the lens reviews twice, nor waits on the user one question at
# a time. Usage: test/batch_flow_test.sh
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
section() { awk -v h="$2" 'index($0, h) == 1 {on=1; print; next} /^## /{on=0} on' "$1"; }
in_section() { if section "$1" "$2" | grep -qiF -- "$3"; then echo yes; else echo no; fi; }

tackle="$root/skills/tackle-issues/SKILL.md"
templates="$root/skills/tackle-issues/references/subagent-templates.md"
ship="$root/skills/ship-pr/SKILL.md"
review="$root/skills/review-pr/SKILL.md"
media="$root/skills/pr-media/SKILL.md"

# Hung background runs.
check "tackle-issues ships run-watched" "yes" "$( [ -x "$root/skills/tackle-issues/scripts/run-watched" ] && echo yes || echo no)"
check "Phase 6 runs the full verify command through run-watched" "yes" "$(in_section "$tackle" "## Phase 6" "scripts/run-watched")"
check "a background run's log mtime is checked before calling it still running" "yes" "$(has "$tackle" "before reporting a background run as still running")"
check "a run-watched kill is reported as a hang, not a test failure" "yes" "$(has "$tackle" "exit 124")"

# Base drift before merge.
check "ship-pr checks base drift before merging old CI" "yes" "$(has "$ship" "base drift")"
check "ship-pr merges the base into a scratch worktree" "yes" "$(has "$ship" "merge --no-edit \"origin/\$base\"")"
check "ship-pr runs the project's fast affected-tests command" "yes" "$(has "$ship" "fast affected-tests command")"
check "ship-pr can rerun CI on the current base without moving the head" "yes" "$(has "$ship" "closing and reopening the PR")"
check "the drift check comes before gh pr merge" "yes" "$(tr '\n' ' ' <"$ship" | grep -qE 'base drift.*gh pr merge <n>' && echo yes || echo no)"

# Fewer round trips.
check "Phase 6 asks one combined go-ahead" "yes" "$(in_section "$tackle" "## Phase 6" "one combined go-ahead")"
check "the go-ahead covers shipping on visual sign-off" "yes" "$(in_section "$tackle" "## Phase 6" "visual sign-off")"
check "a finished group never waits for its sibling" "yes" "$(has "$tackle" "never hold a finished PR for its sibling")"
check "pr-media runs as each PR opens" "yes" "$(in_section "$tackle" "## Phase 6" "as soon as the PR is open")"
check "tackle-issues re-reads itself after a compaction" "yes" "$(has "$tackle" "After a compaction, re-read this SKILL.md before the next phase")"

# One full test run.
check "subagents run the fast check, not the full suite" "yes" "$(has "$templates" "Check command: <FAST_CMD>")"
check "subagents never run the full verify command" "yes" "$(has "$templates" "never the full \`VERIFY_CMD\`")"
check "the full verify command runs once, in Phase 6, after the review loop" "yes" "$(has "$templates" "runs once, in Phase 6, after the review loop exits")"
check "the full run uses the parallel form when the project has one" "yes" "$(has "$templates" "parallel form")"
check "no subagent prompt still asks for the verify command" "no" "$(has "$templates" "Verify command: <VERIFY_CMD>")"
check "Phase 0 records the fast check command" "yes" "$(in_section "$tackle" "## Phase 0" "FAST_CMD")"

# No duplicate review.
check "review-pr skips Part 1 for supplied lens reports at this sha" "yes" "$(in_section "$review" "## Part 1" "lens reports for this exact \`sha\`")"
check "supplied lens reports reach owners as unverified input" "yes" "$(in_section "$review" "## Part 1" "unverified")"
check "Phase 5 saves each reviewer's report with its sha" "yes" "$(in_section "$tackle" "## Phase 5" "Reviewed: <sha>")"
check "Phase 7 passes the Phase 5 lens reports to review-pr" "yes" "$(in_section "$tackle" "## Phase 7" "lens reports")"

# Screenshot capture.
check "pr-media ships a capture command" "yes" "$(has "$media" "scripts/pr-media capture <spec.json>")"
check "capture runs in a subagent that returns file paths" "yes" "$(has "$media" "subagent that returns")"
check "the capture script never statics every element" "no" "$(grep -qF '*{position:static' "$root/shared/pr-media" && echo yes || echo no)"
check "the capture script neutralises sticky headers" "yes" "$(grep -qF '.sticky,.fixed{position:static !important} header{display:none !important}' "$root/shared/pr-media" && echo yes || echo no)"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
