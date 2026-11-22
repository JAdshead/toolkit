#!/usr/bin/env bash
# Projects set up with the toolkit follow TDD strictly: the rules that
# `toolkit init` writes demand test-first with no "by default" opt-out, no
# skill softens it, and review-pr blocks untested behaviour.
# Usage: test/tdd_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$here/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

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

mkdir -p "$work/repo"
"$root/bin/toolkit" init "$work/repo" >/dev/null 2>&1
agents="$work/repo/AGENTS.md"

check "an init'd repo's rules require TDD always" "yes" "$(has "$agents" "**TDD, always.**")"
check "an init'd repo's rules forbid code without a failing test" "yes" \
  "$(has "$agents" "No production code without a failing test")"
check "an init'd repo's rules make bug fixes start with a reproducing test" "yes" \
  "$(has "$agents" "Every bug fix starts with a test that reproduces it")"
check "an init'd repo's rules no longer say TDD is only a default" "no" "$(has "$agents" "TDD by default")"
check "an init'd repo's rules block merging untested behaviour" "yes" \
  "$(has "$agents" "not ready to merge")"

softened="$(grep -rliE "where practical,? write a failing test|TDD by default" "$root/skills" "$root/shared" "$root/rules" || true)"
check "no skill or rule softens test-first" "" "$softened"

check "review-pr's Tests lens blocks behaviour with no failing-first test" "yes" \
  "$(has "$root/skills/review-pr/references/lenses.md" "behaviour change with no test that fails without it is P2")"
check "review-pr's owner blocks behaviour with no failing-first test" "yes" \
  "$(has "$root/skills/review-pr/references/owner-review.md" "behaviour change with no test that fails without it")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
