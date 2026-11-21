#!/usr/bin/env bash
# Tests for `toolkit init`. Usage: test/init_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$here/.."
toolkit="$root/bin/toolkit"
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

fresh() { rm -rf "$work/repo"; mkdir -p "$work/repo"; echo "$work/repo"; }
init() { "$toolkit" init "$1" >/dev/null; }
block_of() { awk '/<!-- toolkit:start -->/{on=1} on{print} /<!-- toolkit:end -->/{on=0}' "$1"; }
has() { if grep -qF -- "$2" "$1"; then echo yes; else echo no; fi; }

# The rules, one heading level down, as they should appear inside a project's AGENTS.md.
expected_rules="$(sed 's/^#/##/' "$root/rules/AGENTS.md")"

repo="$(fresh)"
init "$repo"
check "empty repo: AGENTS.md holds the rules between markers" \
  "$expected_rules" "$(block_of "$repo/AGENTS.md" | grep -v '^<!--')"
check "empty repo: CLAUDE.md imports AGENTS.md" "@AGENTS.md" "$(cat "$repo/CLAUDE.md")"
check "empty repo: settings enable the plugin" "true" \
  "$(jq -r '.enabledPlugins["toolkit@toolkit"]' "$repo/.claude/settings.json")"
check "empty repo: settings add the marketplace" "github JAdshead/toolkit" \
  "$(jq -r '.extraKnownMarketplaces.toolkit.source | "\(.source) \(.repo)"' "$repo/.claude/settings.json")"
check "empty repo: GEMINI.md imports AGENTS.md" "@./AGENTS.md" "$(cat "$repo/GEMINI.md")"

before="$(cd "$repo" && cat AGENTS.md CLAUDE.md GEMINI.md .claude/settings.json)"
init "$repo"
check "re-running changes nothing" "$before" "$(cd "$repo" && cat AGENTS.md CLAUDE.md GEMINI.md .claude/settings.json)"

repo="$(fresh)"
printf '# My project\n\nUse pnpm.\n' > "$repo/AGENTS.md"
init "$repo"
check "existing AGENTS.md keeps its content first" "# My project" "$(head -n 1 "$repo/AGENTS.md")"
check "existing AGENTS.md keeps its own rules" "yes" "$(has "$repo/AGENTS.md" "Use pnpm.")"
check "existing AGENTS.md gets the block" "yes" "$(has "$repo/AGENTS.md" "<!-- toolkit:end -->")"

repo="$(fresh)"
printf 'Before.\n\n<!-- toolkit:start -->\nold rules\n<!-- toolkit:end -->\n\nAfter.\n' > "$repo/AGENTS.md"
init "$repo"
check "a stale block is replaced" "no" "$(has "$repo/AGENTS.md" "old rules")"
check "text before a stale block survives" "Before." "$(head -n 1 "$repo/AGENTS.md")"
check "text after a stale block survives" "After." "$(tail -n 1 "$repo/AGENTS.md")"
check "only one block after replacing" "1" "$(grep -c '<!-- toolkit:start -->' "$repo/AGENTS.md")"

repo="$(fresh)"
printf '# Claude notes\n' > "$repo/CLAUDE.md"
init "$repo"
check "existing CLAUDE.md keeps its content" "# Claude notes" "$(head -n 1 "$repo/CLAUDE.md")"
check "existing CLAUDE.md gains the import" "yes" "$(has "$repo/CLAUDE.md" "@AGENTS.md")"

repo="$(fresh)"
printf '# Shared\n' > "$repo/AGENTS.md"
ln -s AGENTS.md "$repo/CLAUDE.md"
init "$repo"
check "CLAUDE.md linked to AGENTS.md stays a link" "AGENTS.md" "$(readlink "$repo/CLAUDE.md")"
check "linked CLAUDE.md gets no import line" "no" "$(has "$repo/AGENTS.md" "@AGENTS.md")"

repo="$(fresh)"
printf '# Gemini\n' > "$repo/GEMINI.md"
init "$repo"
check "existing GEMINI.md gains the import" "yes" "$(has "$repo/GEMINI.md" "@./AGENTS.md")"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '{"permissions":{"allow":["Bash(ls)"]},"enabledPlugins":{"toolkit@toolkit":false}}\n' > "$repo/.claude/settings.json"
init "$repo"
check "settings keep unrelated keys" "Bash(ls)" "$(jq -r '.permissions.allow[0]' "$repo/.claude/settings.json")"
check "settings keep a plugin the repo turned off" "false" \
  "$(jq -r '.enabledPlugins["toolkit@toolkit"]' "$repo/.claude/settings.json")"

repo="$(fresh)"
printf 'Intro.\n<!-- toolkit:start -->\nold rules\nkeep me\n' > "$repo/AGENTS.md"
before="$(cat "$repo/AGENTS.md")"
check "a start marker without an end marker: init fails" "1" "$("$toolkit" init "$repo" >/dev/null 2>&1; echo $?)"
check "a start marker without an end marker: AGENTS.md is untouched" "$before" "$(cat "$repo/AGENTS.md")"
check "a failed init writes no other file" "no" "$([ -e "$repo/CLAUDE.md" ] || [ -e "$repo/.claude" ] && echo yes || echo no)"

repo="$(fresh)"
printf 'Intro.\r\n<!-- toolkit:start -->\r\nold rules\r\n<!-- toolkit:end -->\r\n' > "$repo/AGENTS.md"
init "$repo"
check "CRLF markers: the stale block is replaced" "no" "$(has "$repo/AGENTS.md" "old rules")"

repo="$(fresh)"
printf 'Intro.\n  <!-- toolkit:start -->\nold rules\n  <!-- toolkit:end -->\n' > "$repo/AGENTS.md"
init "$repo"
check "indented markers: the stale block is replaced" "no" "$(has "$repo/AGENTS.md" "old rules")"

repo="$(fresh)"
printf 'Run toolkit init; it adds a <!-- toolkit:start --> block.\n' > "$repo/AGENTS.md"
init "$repo"
check "a marker mentioned inside prose: the block is still added" "yes" "$(has "$repo/AGENTS.md" "Review in a fresh context")"

repo="$(fresh)"
printf '@AGENTS.md.old\n' > "$repo/CLAUDE.md"
init "$repo"
check "a different @-import does not count as importing AGENTS.md" "yes" "$(grep -qx '@AGENTS.md' "$repo/CLAUDE.md" && echo yes || echo no)"

repo="$(fresh)"
printf '@AGENTS.md\n' > "$repo/GEMINI.md"
init "$repo"
check "GEMINI.md that imports @AGENTS.md gets no second import" "1" "$(grep -c 'AGENTS.md' "$repo/GEMINI.md")"

repo="$(fresh)"
ln -s missing.md "$repo/CLAUDE.md"
init "$repo"
check "a dangling CLAUDE.md link is left alone" "no" "$([ -e "$repo/missing.md" ] && echo yes || echo no)"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '[1]\n' > "$repo/.claude/settings.json"
check "settings that are not a JSON object: init fails" "1" "$("$toolkit" init "$repo" >/dev/null 2>&1; echo $?)"
check "settings that are not a JSON object: nothing else is written" "no" "$([ -e "$repo/AGENTS.md" ] && echo yes || echo no)"

check "init fails for a missing directory" "1" "$("$toolkit" init "$work/nope" >/dev/null 2>&1; echo $?)"

printf '%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
