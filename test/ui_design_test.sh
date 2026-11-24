#!/usr/bin/env bash
# Projects set up with the toolkit check UI work by looking at it: the rules
# that `toolkit init` writes send UI work to the ui-design skill, and that
# skill ships a DESIGN.md template and its four steps.
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

mkdir -p "$work/repo"
"$root/bin/toolkit" init "$work/repo" >/dev/null 2>&1
agents="$work/repo/AGENTS.md"

check "an init'd repo's rules send UI work to the ui-design skill" "yes" "$(has "$agents" "\`ui-design\` skill")"
check "an init'd repo's rules forbid calling UI done unseen" "yes" \
  "$(has "$agents" "Never call UI work done without seeing it")"

skill="$root/skills/ui-design/SKILL.md"
template="$root/skills/ui-design/references/DESIGN.md"
check "the ui-design skill exists" "yes" "$([ -f "$skill" ] && echo yes || echo no)"
check "the skill ships a DESIGN.md template" "yes" "$([ -f "$template" ] && echo yes || echo no)"
check "the skill points at its template" "yes" "$(has "$skill" "references/DESIGN.md")"
check "the skill proposes directions before building" "yes" "$(has "$skill" "## 2. Propose directions")"
check "the skill bans generic defaults" "yes" "$(has "$skill" "## Banned defaults")"
check "the skill checks screenshots at desktop and mobile" "yes" "$(has "$skill" "at 1280 and 375 px wide")"
check "the skill has a fresh-context critique" "yes" "$(has "$skill" "fresh subagent")"
check "the critique loop has a finite exit" "yes" "$(has "$skill" "after two rounds")"
check "the template points to the skill's banned defaults" "yes" \
  "$(has "$template" "\`ui-design\` skill's Banned defaults")"
banned="$(sed -n '/^## Banned defaults/,/^## /p' "$skill" | grep '^- ')"
copied="$(printf '%s\n' "$banned" | grep -cxF -f - "$template")"
check "the template does not keep its own copy of the banned defaults" "0" "$copied"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
