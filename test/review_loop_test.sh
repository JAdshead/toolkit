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

address="$root/skills/address-review/SKILL.md"
check "address-review stops on a patch that still fails" "yes" \
  "$(has "$address" "If a patch fails the checks or leaves a finding in place, stop")"
check "address-review never rewrites history for an untrue commit message" "yes" \
  "$(has "$address" "A finding about a commit message goes to the user")"

check "ship-pr keeps the local branch of a dirty worktree it leaves" "yes" \
  "$(has "$ship" "leave it and its local branch")"
check "ship-pr detects a PR from a fork" "yes" "$(has "$ship" "isCrossRepository")"
check "ship-pr checks a fork PR allows maintainer edits" "yes" "$(has "$ship" "maintainerCanModify")"
check "ship-pr treats a repo with no checks as green" "yes" "$(has "$ship" "no checks reported")"
check "ship-pr says what keep going does to the review cap" "yes" "$(has "$ship" "three more reviews")"
check "ship-pr maps squash to its repo setting" "yes" "$(has "$ship" "allow_squash_merge\` → \`--squash")"
check "ship-pr no longer says it updates main" "" "$(grep -niE "main updated|local main" "$ship" "$root/README.md" || true)"

finishing="$(awk '/^## Finishing/{on=1; next} /^## /{on=0} on' "$rules")"
check "the Finishing rule pulls only on the default branch" "yes" \
  "$(grep -qiF "clean and on the default branch" <<<"$finishing" && echo yes || echo no)"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
