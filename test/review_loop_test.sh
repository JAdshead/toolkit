#!/usr/bin/env bash
# The review loop (review-pr, address-review, ship-pr) keeps what it needs
# across rounds, the Fixes rules stop fixes built on a wrong premise, and the
# Finishing rule cleans up only what is safe to touch.
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
check "ship-pr names a fork PR's local branch itself" "yes" "$(has "$ship" "gh pr checkout <n> --branch pr-<n>")"
check "ship-pr cleans up only its own fork branch" "yes" "$(has "$ship" "delete only \`pr-<n>\`")"
check "ship-pr asks before running a fork's code" "yes" "$(has "$ship" "runs the contributor's code")"
check "ship-pr pushes a fork fix to the fork's head ref" "yes" \
  "$(has "$ship" "git push \"\$(git config branch.pr-<n>.remote)\" \"HEAD:refs/heads/\$ref\"")"
check "ship-pr never pastes the fork's ref name into a command" "no" "$(has "$ship" "HEAD:<headRefName>")"
check "ship-pr stops when the user declines running fork code" "yes" "$(has "$ship" "on a no, stop and report")"
check "ship-pr treats a repo with no checks as green" "yes" "$(has "$ship" "no checks reported")"
check "ship-pr says what keep going does to the review cap" "yes" "$(has "$ship" "three more reviews")"
check "ship-pr maps squash to its repo setting" "yes" "$(has "$ship" "allow_squash_merge\` → \`--squash")"
check "ship-pr no longer says it updates main" "" "$(grep -niE "main updated|local main" "$ship" "$root/README.md" || true)"

fixes="$(awk '/^## Fixes/{on=1; next} /^## /{on=0} on' "$rules")"
check "the Fixes rules say to attack the premise" "yes" \
  "$(grep -qF "**Attack the premise.**" <<<"$fixes" && echo yes || echo no)"
check "the Fixes rules say to fix the root cause" "yes" \
  "$(grep -qF "**Fix the root cause.**" <<<"$fixes" && echo yes || echo no)"

finishing="$(awk '/^## Finishing/{on=1; next} /^## /{on=0} on' "$rules")"
check "the Finishing rule pulls only on the default branch" "yes" \
  "$(grep -qiF "clean and on the default branch" <<<"$finishing" && echo yes || echo no)"

review_loops="$(awk '/^## Review loops/{on=1; next} /^## /{on=0} on' "$rules")"
check "the Review loops rules say findings are done now or dropped" "yes" \
  "$(grep -qF "**Review findings are done now or dropped.**" <<<"$review_loops" && echo yes || echo no)"
check "no skill or rule files minor findings as a follow-up issue" "" \
  "$(grep -rniE "follow-up issue|follow-up note or issue" "$root/skills" "$root/rules" "$root/shared" || true)"
check "the lens brief's P3 drops what isn't worth doing now" "yes" \
  "$(has "$root/shared/lenses.md" "If it isn't worth doing now, don't report it.")"
check "the owner brief's P3 drops what wouldn't be fixed soon" "yes" \
  "$(has "$root/skills/review-pr/references/owner-review.md" "If you wouldn't fix it soon, don't report it.")"
check "tackle-issues files an issue only for an ELSEWHERE finding" "yes" \
  "$(has "$root/skills/tackle-issues/SKILL.md" "The only issue this loop files is for an ELSEWHERE finding")"
check "review-pr never offers P3s as an issue" "yes" "$(has "$review" "Never offer them as an issue.")"
check "ship-pr fixes a MERGE's P3s once before merging" "yes" "$(has "$ship" "**P3s first.** If the MERGE lists follow-ups (P3)")"
check "ship-pr leaves P3s it doesn't fix for one follow-up PR" "yes" "$(has "$ship" "are left for one follow-up PR")"
check "ship-pr's follow-up PR never spawns another" "yes" "$(has "$ship" "A P3 follow-up PR gets no P3 round of its own and makes no Left P3s offer")"
check "ship-pr's report lines carry ELSEWHERE findings" "yes" "$(has "$ship" "stopped after 3 reviews: <open findings>; ELSEWHERE: <list>, or none")"
check "the validator refutes an old problem that is neither P3 nor ELSEWHERE" "yes" "$(has "$root/skills/review-pr/references/validate-findings.md" "Anything else that was already there is REFUTED")"
check "ship-pr records its P3 round in the findings file" "yes" "$(has "$ship" "## P3 round <n> at <sha>")"
check "ship-pr runs a P3 round only while the review cap has room" "yes" "$(has "$ship" "the review cap in step 1 leaves room for one more review")"
check "ship-pr offers ELSEWHERE findings as issues" "yes" "$(has "$ship" "**ELSEWHERE findings**, from every review: file each as an issue")"
check "address-review takes a MERGE's P3s" "yes" "$(has "$address" "only the MERGE's follow-ups (P3)")"
check "address-review never re-solves for P3s" "yes" "$(has "$address" "**A P3 round always patches.**")"
check "review-pr keeps ELSEWHERE findings whatever the verdict" "yes" "$(has "$review" "Whatever the verdict, keep this round's ELSEWHERE findings")"
check "the validator no longer lowers fix-later problems to P3" "" \
  "$(grep -niF "merge and fix later" "$root/skills/review-pr/references/validate-findings.md" || true)"
for brief in skills/review-pr/references/lenses.md skills/review-pr/references/owner-review.md \
  skills/review-pr/references/validate-findings.md shared/lenses.md skills/implement/references/lenses.md \
  skills/tackle-issues/references/lenses.md; do
  check "$brief has a place for a bug in unrelated code" "yes" \
    "$(grep -qF -- "ELSEWHERE" "$root/$brief" && echo yes || echo no)"
done
check "implement reruns the gate after fixing minor findings" "yes" \
  "$(has "$root/skills/implement/SKILL.md" "fix the worthwhile ones in this change, rerun the full local gate")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
