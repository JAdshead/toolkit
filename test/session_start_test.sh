#!/usr/bin/env bash
# Tests for the plugin's SessionStart hook. Usage: test/session_start_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$here/.."
hook="$root/hooks/session-start"
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

fresh() {
  rm -rf "$work/home" "$work/project"
  mkdir -p "$work/home" "$work/project"
}
run() { HOME="$work/home" CLAUDE_PROJECT_DIR="$work/project" CLAUDE_PLUGIN_ROOT="$root" "$hook"; }
mentions_rules() { if run | grep -qF "Review in a fresh context"; then echo yes; else echo no; fi; }

fresh
check "no rules anywhere: the hook adds them" "yes" "$(mentions_rules)"
check "the hook exits cleanly" "0" "$(run >/dev/null; echo $?)"

fresh
printf 'x\n<!-- toolkit:start -->\nrules\n<!-- toolkit:end -->\n' > "$work/project/AGENTS.md"
check "project AGENTS.md has the block: silent" "" "$(run)"

fresh
printf '<!-- toolkit:start -->\nrules\n<!-- toolkit:end -->\n' > "$work/project/CLAUDE.md"
check "project CLAUDE.md has the block: silent" "" "$(run)"

fresh
mkdir -p "$work/home/.claude"
ln -s "$root/rules/AGENTS.md" "$work/home/.claude/CLAUDE.md"
check "global CLAUDE.md is the toolkit rules: silent" "" "$(run)"

fresh
mkdir -p "$work/home/.claude"
printf 'my own rules\n' > "$work/home/.claude/CLAUDE.md"
check "global CLAUDE.md is something else: the hook adds the rules" "yes" "$(mentions_rules)"

fresh
mkdir -p "$work/home/.claude" "$work/other/rules"
printf 'an older copy of the rules\n' > "$work/other/rules/AGENTS.md"
ln -s "$work/other/rules/AGENTS.md" "$work/home/.claude/CLAUDE.md"
check "global CLAUDE.md links to another toolkit checkout's rules: silent" "" "$(run)"

fresh
printf 'see <!-- toolkit:start --> in prose\n' > "$work/project/AGENTS.md"
check "a marker mentioned inside prose does not count: the hook adds the rules" "yes" "$(mentions_rules)"

fresh
printf '  <!-- toolkit:start -->\r\nrules\r\n  <!-- toolkit:end -->\r\n' > "$work/project/AGENTS.md"
check "an indented CRLF block counts: silent" "" "$(run)"

check "the hook runs only on startup, clear and compact" "startup|clear|compact" \
  "$(jq -r '.hooks.SessionStart[0].matcher' "$root/hooks/hooks.json")"

printf '%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
