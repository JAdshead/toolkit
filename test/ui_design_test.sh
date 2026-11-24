#!/usr/bin/env bash
# The ui-design skill makes agents look at UI before calling it done: an
# init'd repo's rules point to it, and the skill keeps its DESIGN.md template,
# its directions step, one banned-defaults list (the template and the critic
# both use it, nothing copies it), desktop and mobile screenshots, and a
# bounded fresh critique.
# Usage: test/ui_design_test.sh
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
# section FILE HEADING-PREFIX: the lines under a "## " heading, up to the next one.
section() {
  [ -f "$1" ] || return 0
  awk -v h="## $2" 'index($0, h) == 1 { on = 1; next } /^## / { on = 0 } on' "$1"
}

skill="$root/skills/ui-design/SKILL.md"
template="$root/skills/ui-design/references/DESIGN.md"

mkdir -p "$work/repo"
"$root/bin/toolkit" init "$work/repo" >/dev/null 2>&1
agents="$work/repo/AGENTS.md"

check "an init'd repo's rules say never call UI done unseen" "yes" \
  "$(has "$agents" "Never call UI work done without seeing it")"
check "an init'd repo's rules point to the ui-design skill" "yes" "$(has "$agents" "\`ui-design\` skill")"

check "the skill ships a DESIGN.md template" "yes" "$([ -f "$template" ] && echo yes || echo no)"
check "the skill copies in the template when there is no DESIGN.md" "yes" \
  "$(has "$skill" "references/DESIGN.md")"
check "the skill proposes two or three directions before building" "yes" \
  "$(has "$skill" "two or three genuinely different directions")"
check "the skill screenshots at desktop width" "yes" "$(has "$skill" "1280")"
check "the skill screenshots at mobile width" "yes" "$(has "$skill" "375")"

# One banned list, in the skill. Each item leads with a bold name.
banned="$(section "$skill" "Banned defaults" | grep -oE '^- \*\*[^*]+\*\*' | sed -E 's/^- \*\*//; s/\*\*$//')"
check "the skill lists at least five banned defaults" "yes" \
  "$([ "$(printf '%s' "$banned" | grep -c .)" -ge 5 ] && echo yes || echo no)"
check "the template points to the skill's Banned defaults" "yes" "$(has "$template" "Banned defaults")"
copied=""
while IFS= read -r item; do
  [ -n "$item" ] && grep -qiF -- "$item" "$template" 2>/dev/null && copied="$copied$item; "
done <<< "$banned"
check "the template copies no banned default (it points to the list)" "" "$copied"

critique="$(section "$skill" "5.")"
check "a fresh subagent critiques, not a fork" "yes" \
  "$(printf '%s' "$critique" | grep -qiF "fresh subagent" && printf '%s' "$critique" | grep -qiF "no fork" && echo yes || echo no)"
check "the critic is given the Banned defaults" "yes" \
  "$(printf '%s' "$critique" | grep -qiF "Banned defaults" && echo yes || echo no)"
check "the critique stops after two rounds" "yes" \
  "$(printf '%s' "$critique" | grep -qiF "two rounds" && echo yes || echo no)"

check "the README lists the skill" "yes" "$(has "$root/README.md" "| \`ui-design\` |")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
