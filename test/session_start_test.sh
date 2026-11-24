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
  rm -rf "${work:?}/home" "${work:?}/project"
  mkdir -p "$work/home" "$work/project"
}
run() { HOME="$work/home" CLAUDE_PROJECT_DIR="$work/project" CLAUDE_PLUGIN_ROOT="$root" "$hook"; }
# Capture the output first: grep -q stops reading early, and under pipefail
# the writer's SIGPIPE would make the result depend on timing.
first_rule_line="$(head -n 1 "$root/rules/AGENTS.md")"
mentions_rules() { local out; out="$(run)"; if grep -qxF "$first_rule_line" <<<"$out"; then echo yes; else echo no; fi; }

fresh
check "no rules anywhere: the hook adds them" "yes" "$(mentions_rules)"
check "the hook exits cleanly" "0" "$(run >/dev/null; echo $?)"

block='x\n<!-- toolkit:start -->\nrules\n<!-- toolkit:end -->\n'

fresh
printf '%b' "$block" > "$work/project/AGENTS.md"
printf '# Notes\n@AGENTS.md\n' > "$work/project/CLAUDE.md"
check "project AGENTS.md has the block and CLAUDE.md imports it: silent" "" "$(run)"

fresh
printf '%b' "$block" > "$work/project/AGENTS.md"
ln -s AGENTS.md "$work/project/CLAUDE.md"
check "project AGENTS.md has the block and CLAUDE.md links to it: silent" "" "$(run)"

fresh
printf '%b' "$block" > "$work/project/AGENTS.md"
check "project AGENTS.md has the block but there is no CLAUDE.md: the hook adds the rules" "yes" "$(mentions_rules)"

fresh
printf '%b' "$block" > "$work/project/AGENTS.md"
printf '# Notes\n@AGENTS.md.old\n' > "$work/project/CLAUDE.md"
check "project AGENTS.md has the block but CLAUDE.md does not import it: the hook adds the rules" "yes" "$(mentions_rules)"

fresh
printf '<!-- toolkit:start -->\nrules\n<!-- toolkit:end -->\n' > "$work/project/CLAUDE.md"
check "project CLAUDE.md has the block: silent" "" "$(run)"

fresh
mkdir -p "$work/home/.claude"
ln -s "$root/rules/AGENTS.md" "$work/home/.claude/CLAUDE.md"
check "global CLAUDE.md is the toolkit rules: silent" "" "$(run)"

fresh
mkdir -p "$work/home/.claude"
cp "$root/rules/AGENTS.md" "$work/home/.claude/CLAUDE.md"
check "global CLAUDE.md is a plain copy of the toolkit rules: silent" "" "$(run)"

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
printf '@AGENTS.md\r\n' > "$work/project/CLAUDE.md"
check "an indented CRLF block imported with a CRLF line counts: silent" "" "$(run)"

fresh
mkdir -p "$work/plugin"
check "the plugin has no rules file: the hook exits cleanly and says nothing" "0:" \
  "$(out="$(HOME="$work/home" CLAUDE_PROJECT_DIR="$work/project" CLAUDE_PLUGIN_ROOT="$work/plugin" "$hook")"; echo "$?:$out")"

printf '%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
