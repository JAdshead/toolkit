#!/usr/bin/env bash
# A UI pull request carries its screenshots and waits for its owner's visual
# sign-off: the skills that open PRs attach media with pr-media, the skills
# that merge check the sign-off, and an init'd repo's rules say so. A PR with
# no UI change still merges on MERGE and green CI.
# Usage: test/visual_signoff_test.sh
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
has() { if [ -f "$1" ] && grep -qiF -- "$2" "$1"; then echo yes; else echo no; fi; }

skill() { echo "$root/skills/$1/SKILL.md"; }
media="$(skill pr-media)"
ship="$(skill ship-pr)"
review="$(skill review-pr)"

check "pr-media keeps media on a hidden ref, not a branch" "yes" "$(has "$media" "refs/pr-media/<pr>")"
check "pr-media captures before and after" "yes" "$(has "$media" "<screen>.before.desktop.png")"
check "pr-media captures mobile" "yes" "$(has "$media" ".mobile.")"
check "pr-media records interactions as GIFs" "yes" "$(has "$media" "scripts/pr-media gif")"
check "pr-media warns that a public repo's media is public" "yes" "$(has "$media" "public** repo the media is public")"
check "pr-media never adds the sign-off label itself" "yes" "$(has "$media" "Never add the sign-off label yourself")"

for s in implement tackle-issues; do
  check "$s checks whether its PR changes the UI" "yes" "$(has "$(skill "$s")" "scripts/pr-media ui <pr>")"
  check "$s attaches screenshots with pr-media" "yes" "$(has "$(skill "$s")" "\`pr-media\` skill")"
done
check "ui-design names screenshots so pr-media can attach them" "yes" \
  "$(has "$(skill ui-design)" "<screen>.after.<desktop|mobile>.png")"

check "ship-pr detects a UI PR" "yes" "$(has "$ship" "scripts/pr-media ui <n>")"
check "ship-pr checks the owner's sign-off" "yes" "$(has "$ship" "scripts/pr-media signoff <n>")"
check "ship-pr waits for sign-off rather than merging" "yes" "$(has "$ship" "waiting for visual sign-off")"
check "ship-pr never signs off itself" "yes" "$(has "$ship" "Never add the sign-off label yourself")"
check "ship-pr still merges a PR with no UI change on MERGE and green CI" "yes" \
  "$(has "$ship" "A PR with no UI change merges on MERGE and green CI")"
check "ship-pr's go-ahead does not cover visual sign-off" "yes" "$(has "$ship" "which the go-ahead does not give")"

check "review-pr says a UI PR still needs sign-off after MERGE" "yes" "$(has "$review" "scripts/pr-media ui <pr>")"
check "review-pr merges a UI PR only with sign-off" "yes" "$(has "$review" "a UI PR only once it has its owner's visual sign-off")"

for s in pr-media implement tackle-issues review-pr ship-pr; do
  check "$s ships its own copy of the script" "yes" \
    "$(cmp -s "$root/shared/pr-media" "$root/skills/$s/scripts/pr-media" && echo yes || echo no)"
done

mkdir -p "$work/repo"
"$root/bin/toolkit" init "$work/repo" >/dev/null 2>&1
check "an init'd repo's rules hold UI PRs for the owner's sign-off" "yes" \
  "$(has "$work/repo/AGENTS.md" "Merge it only after the owner's visual sign-off")"
check "the README lists the skill" "yes" "$(has "$root/README.md" "| \`pr-media\` |")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
