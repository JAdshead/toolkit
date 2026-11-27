#!/usr/bin/env bash
# Skills read CI only when they need its result and never block reviewers on
# it (#65). A step that needs green waits on one background watch, since the
# host's Auto-fix reports failures but never success. One shared rule says how.
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
# Pending CI holds only the step that needs its result, and Auto-fix never reports success.
check "pending CI lets a step that says go on go on" "yes" "$(has "$rule" "go on when the step says go on")"
check "pending CI holds only the step that needs its result" "yes" "$(has "$rule" "hold only the step that needs CI's result")"
check "the rule says the host reports failures, never success" "yes" "$(has "$rule" "never success")"
check "a held step runs one background watch" "yes" "$(has "$rule" "\`gh pr checks <pr> --watch --interval 60\`")"
check "the rule allows at most two watches, never a loop" "yes" "$(has "$rule" "at most two watches: never a loop")"
check "the rule no longer says to watch once, then once more" "no" "$(has "$rule" "--interval 60\` once")"
check "the rule no longer waits on the host to report CI done" "no" "$(has "$rule" "resume when the host reports CI done")"
check "the rule treats no checks as green" "yes" "$(has "$rule" "no checks reported")"
check "the rule ties CI to the commit it is about" "yes" "$(has "$rule" "headRefOid")"
for copy in "$root"/skills/*/references/ci-status.md; do
  check "$(basename "$(dirname "$(dirname "$copy")")") has the shared rule unchanged" "yes" "$(cmp -s "$rule" "$copy" && echo yes || echo no)"
done

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

# #82: follow-ups from the review of #81.
owner="$root/skills/review-pr/references/owner-review.md"
lenses="$root/skills/review-pr/references/lenses.md"
check "an owner does not report pending CI as a finding" "yes" "$(has "$owner" "A check still pending in \`checks.txt\` is not a finding")"
check "a lens does not report pending CI as a finding" "yes" "$(has "$lenses" "a check still pending in \`checks.txt\`")"
check "the rule says what to do when the second read is still pending" "yes" "$(has "$rule" "still pending after that second watch")"
check "review-pr step 3 hands red CI to Part 4's NOT YET (CI red)" "yes" "$(has "$review" "Red: the result is NOT YET (CI red), at the head that read showed; act on it as Part 4 says")"
check "review-pr no longer has a bare red stop in step 3" "no" "$(has "$review" "Red: report it and stop")"
check "the README no longer says implement runs a CI loop" "no" "$(has "$root/README.md" "three independent reviewers, CI loop")"

# #86: follow-ups from the review of #87.
check "red CI at step 3 is reported at the head that read showed" "yes" "$(has "$review" "Tell the user which check failed and at which commit")"
check "review-pr step 5's red CI goes the way of step 3" "yes" "$(has "$review" "the result is NOT YET (CI red), as in step 3")"
check "the README's implement row says it loops only on red CI" "yes" "$(has "$root/README.md" "loops only on red CI")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
