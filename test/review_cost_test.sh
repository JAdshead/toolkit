#!/usr/bin/env bash
# review-pr keeps its token cost in proportion to the work: reviewers hand each
# other files instead of the orchestrator re-typing their output (#63), and a
# later round is sized by what changed since the last reviewed commit (#62).
# Usage: test/review_cost_test.sh
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
lenses="$root/skills/review-pr/references/lenses.md"
owner="$root/skills/review-pr/references/owner-review.md"
validate="$root/skills/review-pr/references/validate-findings.md"
ship="$root/skills/ship-pr/SKILL.md"
out='<scratch>/pr-<pr>-out'

# #63: reviewer output goes through files, never through the orchestrator's prompts.
check "review-pr names an output directory apart from the inputs" "yes" "$(has "$review" "$out")"
check "review-pr no longer collects lens output verbatim" "no" "$(has "$review" "Collect their outputs verbatim")"
check "review-pr no longer pastes lens output into owner prompts" "no" "$(has "$review" "followed by their outputs verbatim")"
check "a lens writes its output to the file its prompt names" "yes" "$(has "$lenses" "Write your output to the file your prompt names")"
check "a lens replies with only its verdict line" "yes" "$(has "$lenses" "reply with only its VERDICT line")"
check "an owner writes its output to the file its prompt names" "yes" "$(has "$owner" "Write your output to the file your prompt names")"
check "an owner never reads another owner's output" "yes" "$(has "$owner" "Never read another owner's output")"
check "owners are pointed at the lens files" "yes" "$(has "$review" "Other reviewers' findings are in $out/lens-*.md")"
check "the validator is pointed at the owner files" "yes" "$(has "$review" "$out/owner-a.md")"
check "the validator reads the owner files it is given" "yes" "$(has "$validate" "owner files your prompt names")"
check "review-pr makes the output directory" "yes" "$(has "$review" "out=\"$out\"; rm -rf \"\$out\"; mkdir -p \"\$out\"")"
check "the output directory is removed with the round" "yes" "$(has "$review" "rm -rf \"\$in\" \"\$out\"")"

# #62: later rounds are sized by the change since the last reviewed sha.
check "review-pr records each round's sha in the findings file" "yes" "$(has "$review" "## Round <n> at <sha>")"
check "ship-pr records the round's sha the same way" "yes" "$(has "$ship" "## Round <n> at <sha>")"
check "review-pr diffs from the last reviewed sha" "yes" "$(has "$review" "diff --stat <last-sha> <sha>")"
check "a targeted fix gets the finding's lens and one owner" "yes" "$(has "$review" "the lens each finding falls under, plus one owner")"
check "a targeted fix may add tests for the named files" "yes" "$(has "$review" "in files the last round's findings named or in test files")"
check "a tests-only change gets the Tests lens and one owner" "yes" "$(has "$review" "the Tests lens plus one owner")"
check "a PR-text-only fix needs only the validator" "yes" "$(has "$review" "only the validator")"
check "a broad change gets a full round" "yes" "$(has "$review" "a full round")"
check "a small PR's later round still gets no lens" "yes" "$(has "$review" "Part 1 skips it still gets no lens")"
check "a later round keeps two owners for security-sensitive files" "yes" "$(has "$review" "Two owners in a later round only when a changed file is security-sensitive")"
check "a sized round still never tells reviewers what changed" "yes" "$(has "$review" "never told what changed")"

# #80: follow-ups from the reviews of #79.
check "a lens may write its output file despite \"do not edit\"" "yes" "$(has "$lenses" "The one file you write is your output")"
check "a whole-output reply is saved before the file is checked" "yes" "$(has "$review" "save that reply to its file unchanged, with your file-write tool, never through a shell command, before checking it")"
check "a lens still missing after its rerun is reported, not rerun again" "yes" "$(has "$review" "go on without that lens and tell the user")"
check "each round records every owner's verdict" "yes" "$(has "$review" "Owners: <letter> <verdict>")"
check "step 6 reads owner disagreement from the Owners line" "yes" "$(has "$review" "the last round's owners disagreed (the unindented \`Owners:\` line directly under a round heading")"
check "a validator-only round always runs the validator" "yes" "$(has "$review" "A validator-only round has no owners: it always runs the validator")"
check "a validator-only round also checks the rewritten PR text" "yes" "$(has "$review" "Also check every claim in the PR's current title and description against the code.")"
check "the validator labels new PR-text findings V1, V2" "yes" "$(has "$validate" "labelled \`V1\`, \`V2\`")"
check "an unresolvable last sha falls back to a full round" "yes" "$(has "$review" "If that diff fails (\`<last-sha>\` is gone")"
check "ship-pr's sizing clause ends before address-review" "yes" "$(has "$ship" "sized by what changed, and run the \`address-review\` skill")"

# #86: follow-ups from the reviews of #87.
check "a validator-only round's result rule is stated once, in the MERGE bullet" "no" "$(has "$review" "its result comes from the validator's verdicts alone")"
check "MERGE from owners needs a round with owners" "yes" "$(has "$review" "every owner said MERGE, in a round with owners")"
check "a validator-only round records Owners: none" "yes" "$(has "$review" "\`Owners: none\` in a validator-only round")"
check "the whole-output rule names no cause the orchestrator can't know" "no" "$(has "$review" "could not write its file")"
check "a whole-output reply is saved with a file-write tool, never a shell" "yes" "$(has "$review" "with your file-write tool, never through a shell command")"
check "step 6 looks back past Owners: none, to the latest round that had owners" "yes" "$(has "$review" "the latest round whose line is not \`none\`")"
check "step 6 no longer matches any Owners: line in the file" "no" "$(has "$review" "the last \`Owners:\` line that is not \`none\`")"
check "a missing lens leaves the owners' review whole" "yes" "$(has "$review" "the owners still review the whole PR")"
check "findings are indented so none reads as a round heading" "yes" "$(has "$review" "indented four spaces, so no line of it can read as a heading")"
check "new V labels follow any already in the findings file" "yes" "$(has "$validate" "after the highest \`V\` label already listed")"
check "a V finding falls under the Correctness lens" "yes" "$(has "$review" "Correctness for a validator's \`V\` finding")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
