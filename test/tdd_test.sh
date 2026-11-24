#!/usr/bin/env bash
# Projects set up with the toolkit write tests first, never write a bad test,
# prove behaviour another way only with before-and-after evidence and a named
# exception, and check the real thing before calling work done. No skill
# softens that, and review-pr blocks behaviour with no proof.
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

check "an init'd repo's rules require tests first" "yes" "$(has "$agents" "**Test first.**")"
check "an init'd repo's rules make bug fixes start with a reproduction" "yes" \
  "$(has "$agents" "Every bug fix starts with a reproduction")"
check "an init'd repo's rules say a bad test is worse than none" "yes" \
  "$(has "$agents" "A bad test is worse than none")"
check "an init'd repo's rules no longer say TDD is only a default" "no" "$(has "$agents" "TDD by default")"
check "an init'd repo's rules require checking the real thing" "yes" \
  "$(has "$agents" "Check the real thing before calling it done")"
check "an init'd repo's rules block merging unproven behaviour" "yes" \
  "$(has "$agents" "A behaviour change with no proof that fails without it is not ready to merge.")"

softened="$(grep -rliE "where practical|TDD by default|cannot be tested first|test(-| )first where (it|one) applies" "$root/skills" "$root/shared" "$root/rules" || true)"
check "no skill or rule softens test-first" "" "$softened"

# Every place that lets a no-behaviour change skip the test names the same list.
exceptions="docs, comments, formatting, plain config"
check "the rules name the no-behaviour exceptions" "yes" "$(has "$root/rules/AGENTS.md" "$exceptions")"
other_list="$(grep -rniE "no(-| )behaviour" "$root/skills" "$root/shared" "$root/rules" | grep -vF "$exceptions" || true)"
check "every no-behaviour exception names the same list" "" "$other_list"
check "address-review names the no-behaviour exceptions" "yes" \
  "$(has "$root/skills/address-review/SKILL.md" "$exceptions")"
fallback="closest repeatable check"
for f in rules/AGENTS.md skills/implement/SKILL.md skills/tackle-issues/references/subagent-templates.md; do
  check "$f allows the same fallback when no good test can reach the behaviour" "yes" "$(has "$root/$f" "$fallback")"
  check "$f checks the real thing before done" "yes" "$(has "$root/$f" "real thing")"
done

# The fallback is never a free pass: wherever it appears, it needs the check
# seen failing before the change and a named exception.
while IFS= read -r f; do
  check "${f#"$root"/} pairs the fallback with failing-before evidence" "yes" "$(has "$f" "failing before the change")"
  check "${f#"$root"/} pairs the fallback with a named exception" "yes" "$(has "$f" "name the exception")"
done < <(grep -rliF "$fallback" "$root/skills" "$root/shared" "$root/rules")

check "review-pr's Tests lens blocks behaviour with no proof" "yes" \
  "$(has "$root/skills/review-pr/references/lenses.md" "behaviour change with no proof that fails without it is P2")"
check "review-pr's owner blocks behaviour with no proof" "yes" \
  "$(has "$root/skills/review-pr/references/owner-review.md" "behaviour change with no proof that fails without it")"
check "review-pr's owner blocks an exception a good test could have covered" "yes" \
  "$(has "$root/skills/review-pr/references/owner-review.md" "a good test could reach")"
# An owner still malformed after its replacement leaves no finding to fix.
malformed_owner="$(grep -F '**NOT YET with the owner output malformed:**' "$root/skills/review-pr/SKILL.md")"
check "review-pr: a twice-malformed owner gives NOT YET with the owner output malformed" "yes" \
  "$(has "$root/skills/review-pr/SKILL.md" "the result is NOT YET with the owner output malformed")"
check "review-pr: a twice-malformed owner's output is shown to the user and the review stops" "yes" \
  "$(grep -qF 'show it, and stop' <<<"$malformed_owner" && echo yes || echo no)"
check "review-pr: a twice-malformed owner is not handed to address-review" "yes" \
  "$(grep -qF "do not hand off to \`address-review\`" <<<"$malformed_owner" && echo yes || echo no)"

implement="$root/skills/implement/SKILL.md"
check "implement's Test quality reviewer accepts a named exception with a before-and-after check" "yes" \
  "$(has "$implement" "an exception named with a repeatable check and its output before and after")"
check "implement's Test quality reviewer blocks an exception a good test could reach" "yes" \
  "$(has "$implement" "an exception that a good test could reach is HIGH")"
check "implement gives the Test quality reviewer the subagent's EXCEPTIONS" "yes" \
  "$(has "$implement" "give the Test quality reviewer the subagent's EXCEPTIONS")"

tackle="$root/skills/tackle-issues/references"
check "tackle-issues' Tests reviewer accepts a named exception with a before-and-after check" "yes" \
  "$(has "$tackle/review-prompts.md" "an exception named with a repeatable check and its output before and after")"
check "tackle-issues' Tests reviewer blocks an exception a good test could reach" "yes" \
  "$(has "$tackle/review-prompts.md" "an exception that a good test could reach is P2")"
check "tackle-issues gives each Phase 5 reviewer the subagents' named exceptions" "yes" \
  "$(grep -F "Each reviewer also receives" "$tackle/review-prompts.md" | grep -qiF "named exceptions" && echo yes || echo no)"
fix_subagent="$work/fix-subagent.md"
awk '/^## Fix subagent/{on=1; next} /^## /{on=0} on' "$tackle/subagent-templates.md" >"$fix_subagent"
check "the tackle-issues fix subagent may use the fallback" "yes" "$(has "$fix_subagent" "$fallback")"
check "the tackle-issues fix subagent shows its check failing before the change" "yes" \
  "$(has "$fix_subagent" "failing before the change")"
check "the tackle-issues fix subagent reports a named exception in NOTES" "yes" \
  "$(has "$fix_subagent" "name the exception, why, and the check in NOTES")"
check "the tackle-issues PR body names exceptions" "yes" "$(has "$tackle/subagent-templates.md" "## Exceptions")"
check "the tackle-issues PR body reports the real-thing check" "yes" \
  "$(has "$tackle/subagent-templates.md" "## Real-thing check")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
