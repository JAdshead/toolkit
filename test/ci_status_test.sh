#!/usr/bin/env bash
# Skills read CI only when they need its result, never block reviewers on it,
# and never poll it when the host watches CI (#65). One shared rule says how.
# Usage: test/ci_status_test.sh
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

rule="$root/shared/ci-status.md"
review="$root/skills/review-pr/SKILL.md"
ship="$root/skills/ship-pr/SKILL.md"
implement="$root/skills/implement/SKILL.md"
tackle="$root/skills/tackle-issues/SKILL.md"

# The shared rule.
check "the CI rule exists" "yes" "$( [ -f "$rule" ] && echo yes || echo no)"
check "the rule never polls when the host watches CI" "yes" "$(has "$rule" "never use \`--watch\` or poll")"
check "the rule holds and resumes on the host's report" "yes" "$(has "$rule" "resume when the host reports CI done")"
check "the rule watches once when nothing else does" "yes" "$(has "$rule" "\`gh pr checks <pr> --watch\` once")"
check "the rule treats no checks as green" "yes" "$(has "$rule" "no checks reported")"
check "the rule ties CI to the commit it is about" "yes" "$(has "$rule" "headRefOid")"

# Every skill that waited on CI now follows the rule instead.
for f in "$review" "$ship" "$implement" "$tackle"; do
  name="$(basename "$(dirname "$f")")"
  check "$name follows the shared CI rule" "yes" "$(has "$f" "references/ci-status.md")"
  check "$name no longer watches CI itself" "no" "$(has "$f" "--watch")"
done

# review-pr starts reviewers without waiting, and reads CI before MERGE.
check "review-pr starts reviewers while CI is pending" "yes" "$(has "$review" "reviewers do not need CI's result")"
check "review-pr no longer restarts a round for a pending check" "no" \
  "$(has "$review" "If the head moved, or a check is still pending")"
check "a no-run round still waits for CI, its only evidence" "yes" "$(has "$review" "In a no-run round, CI is the reviewers' evidence")"
check "review-pr reports red CI as NOT YET" "yes" "$(has "$review" "NOT YET (CI red)")"
check "review-pr holds MERGE while CI is pending" "yes" "$(has "$review" "hold MERGE until CI is green")"
# Red CI has no finding to fix: it is reported, never handed to address-review.
check "review-pr Part 4 acts on NOT YET (CI red) on its own" "yes" "$(has "$review" "**NOT YET (CI red):** there is no finding to fix")"
check "ship-pr stops on NOT YET (CI red) instead of fixing" "yes" "$(has "$ship" "On NOT YET (CI red), there is no finding to fix")"

# ship-pr still merges only on green CI at the reviewed commit.
check "ship-pr still treats no checks as green" "yes" "$(has "$ship" "no checks reported")"
check "ship-pr merges only on green CI" "yes" "$(has "$ship" "green CI at \`sha\`")"

# implement and tackle-issues hand off to review-pr without waiting for CI.
check "implement hands off to review-pr while CI runs" "yes" "$(has "$implement" "hand off to the \`review-pr\` skill now")"
check "tackle-issues hands off to review-pr while CI runs" "yes" "$(has "$tackle" "hand off to the \`review-pr\` skill now")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
