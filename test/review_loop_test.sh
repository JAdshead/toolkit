#!/usr/bin/env bash
# The review loop (review-pr, address-review, ship-pr) keeps what it needs
# across rounds, and the Finishing rule cleans up only what is safe to touch.
# Usage: test/review_loop_test.sh
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
has() { if grep -qiF -- "$2" "$1"; then echo yes; else echo no; fi; }

review="$root/skills/review-pr/SKILL.md"
ship="$root/skills/ship-pr/SKILL.md"
rules="$root/rules/AGENTS.md"
findings="pr-<pr>-findings.md"

# address-review needs every round's findings; both callers must keep and pass them.
check "review-pr keeps confirmed findings beside problem.md" "yes" "$(has "$review" "$findings")"
check "review-pr passes every round's findings to address-review" "yes" \
  "$(grep -F "address-review" "$review" | grep -qiF "every round so far" && echo yes || echo no)"
check "ship-pr passes every round's findings to address-review" "yes" \
  "$(grep -F "address-review" "$ship" | grep -qiF "every round so far" && echo yes || echo no)"
check "ship-pr names the same findings file" "yes" "$(has "$ship" "$findings")"

finishing="$(awk '/^## Finishing/{on=1; next} /^## /{on=0} on' "$rules")"
check "the Finishing rule pulls only on the default branch" "yes" \
  "$(grep -qiF "clean and on the default branch" <<<"$finishing" && echo yes || echo no)"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
