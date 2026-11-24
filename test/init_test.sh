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

fresh() { rm -rf "${work:?}/repo"; mkdir -p "$work/repo"; echo "$work/repo"; }
# Run init where it is expected to succeed; a non-zero exit fails the run.
# Its output (stdout and stderr) is left in $out.
runs=0
out=""
init() {
  local rc=0
  runs=$((runs + 1))
  out="$("$toolkit" init "$1" 2>&1)" || rc=$?
  check "init run $runs succeeds" "0" "$rc"
}
# Run init where it is expected to fail with exit 1. Its output is left in $out.
fails() {
  local rc=0
  out="$("$toolkit" init "$2" 2>&1)" || rc=$?
  check "$1: init fails" "1" "$rc"
}
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
said() { if grep -qxF -- "$1" <<<"$out"; then echo yes; else echo no; fi; }
check "empty repo: init says it created CLAUDE.md" "yes" "$(said "created CLAUDE.md importing AGENTS.md")"
check "empty repo: the managed comment links to the toolkit" "yes" "$(has "$repo/AGENTS.md" "https://github.com/JAdshead/toolkit")"
check "empty repo: no warning about AGENTS.md" "no" "$(grep -q '^warning:' <<<"$out" && echo yes || echo no)"

repo="$(fresh)"
rc=0
(cd "$repo" && "$toolkit" init >/dev/null 2>&1) || rc=$?
check "with no directory, init succeeds" "0" "$rc"
check "with no directory, init sets up the current directory" "yes" "$(has "$repo/AGENTS.md" "<!-- toolkit:end -->")"
check "with no directory, init finishes the setup" "yes" \
  "$([ -f "$repo/CLAUDE.md" ] && [ -f "$repo/GEMINI.md" ] && [ -f "$repo/.claude/settings.json" ] && echo yes || echo no)"

repo="$(fresh)"
init "$repo"
before="$(cd "$repo" && cat AGENTS.md CLAUDE.md GEMINI.md .claude/settings.json)"
init "$repo"
check "re-running changes nothing" "$before" "$(cd "$repo" && cat AGENTS.md CLAUDE.md GEMINI.md .claude/settings.json)"

repo="$(fresh)"
printf '# My project\n\nUse pnpm.\n' > "$repo/AGENTS.md"
init "$repo"
check "existing AGENTS.md keeps its content first" "# My project" "$(head -n 1 "$repo/AGENTS.md")"
check "existing AGENTS.md keeps its own rules" "yes" "$(has "$repo/AGENTS.md" "Use pnpm.")"
check "existing AGENTS.md gets the block" "yes" "$(has "$repo/AGENTS.md" "<!-- toolkit:end -->")"

# CLAUDE.md importing AGENTS.md shows Claude Code all of it, so init names the
# sections outside the block that Claude Code has not read before.
lists() { if grep -qxF -- "  $1" <<<"$out"; then echo yes; else echo no; fi; }
repo="$(fresh)"
printf '# Old rules\n\n## Landing the plane\nYou must push.\n```sh\n# not a heading\n```\n<!-- toolkit:start -->\n## Stale block heading\n<!-- toolkit:end -->\n' > "$repo/AGENTS.md"
init "$repo"
check "AGENTS.md with its own content: init warns" "yes" "$(grep -q '^warning: .*AGENTS.md' <<<"$out" && echo yes || echo no)"
check "the warning lists the top heading" "yes" "$(lists "# Old rules")"
check "the warning lists a nested heading" "yes" "$(lists "## Landing the plane")"
check "the warning skips a comment inside a code fence" "no" "$(lists "# not a heading")"
check "the warning skips headings inside the toolkit block" "no" "$(lists "## Stale block heading")"
init "$repo"
check "re-running: no warning once CLAUDE.md imports AGENTS.md" "no" "$(grep -q '^warning:' <<<"$out" && echo yes || echo no)"

repo="$(fresh)"
printf '# Old rules\n' > "$repo/AGENTS.md"
printf '# Notes\n@AGENTS.md\n' > "$repo/CLAUDE.md"
init "$repo"
check "CLAUDE.md already imported AGENTS.md: no warning" "no" "$(grep -q '^warning:' <<<"$out" && echo yes || echo no)"

repo="$(fresh)"
printf 'Use pnpm.\n' > "$repo/AGENTS.md"
printf '# Notes\n' > "$repo/CLAUDE.md"
init "$repo"
check "AGENTS.md with text but no headings: init still warns" "yes" "$(grep -q '^warning: .*AGENTS.md' <<<"$out" && echo yes || echo no)"

repo="$(fresh)"
printf '# Evil\033[2K\r\n' > "$repo/AGENTS.md"
init "$repo"
check "control characters in a listed heading never reach the terminal" "no" "$(LC_ALL=C grep -q "$(printf '\033')" <<<"$out" && echo yes || echo no)"

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
check "existing CLAUDE.md: init says it added the import" "yes" "$(said "added @AGENTS.md to CLAUDE.md")"

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
fails "a start marker without an end marker" "$repo"
check "a start marker without an end marker: AGENTS.md is untouched" "$before" "$(cat "$repo/AGENTS.md")"
check "a failed init writes no other file" "no" "$([ -e "$repo/CLAUDE.md" ] || [ -e "$repo/.claude" ] && echo yes || echo no)"

# Malformed markers: init fails and leaves AGENTS.md exactly as it was.
malformed() {
  local name="$1" content="$2" before
  repo="$(fresh)"
  printf '%b' "$content" > "$repo/AGENTS.md"
  before="$(cat "$repo/AGENTS.md")"
  fails "$name" "$repo"
  check "$name: AGENTS.md is untouched" "$before" "$(cat "$repo/AGENTS.md")"
}
malformed "end marker before start marker" 'a\n<!-- toolkit:end -->\nb\n<!-- toolkit:start -->\nc\n'
malformed "two start markers and one end marker" '<!-- toolkit:start -->\na\n<!-- toolkit:start -->\nb\n<!-- toolkit:end -->\n'
malformed "one start marker and two end markers" '<!-- toolkit:start -->\na\n<!-- toolkit:end -->\nb\n<!-- toolkit:end -->\n'
malformed "an end marker alone" 'a\n<!-- toolkit:end -->\nb\n'

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
check "a marker mentioned inside prose: the block is still added" "yes" "$(has "$repo/AGENTS.md" "<!-- toolkit:end -->")"

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
fails "a dangling CLAUDE.md link" "$repo"
check "a dangling CLAUDE.md link: nothing is created through it" "no" "$([ -e "$repo/missing.md" ] && echo yes || echo no)"

# Before init AGENTS.md is missing, so these links dangle; init creates
# AGENTS.md and leaves the links as they are.
repo="$(fresh)"
ln -s AGENTS.md "$repo/CLAUDE.md"
ln -s ./AGENTS.md "$repo/GEMINI.md"
init "$repo"
check "CLAUDE.md linked to a missing AGENTS.md stays a link" "AGENTS.md" "$(readlink "$repo/CLAUDE.md")"
check "GEMINI.md linked to ./AGENTS.md stays a link" "./AGENTS.md" "$(readlink "$repo/GEMINI.md")"
check "AGENTS.md is created with the block" "yes" "$(has "$repo/AGENTS.md" "<!-- toolkit:end -->")"
check "AGENTS.md gets no import line through the links" "no" "$(has "$repo/AGENTS.md" "@AGENTS.md")"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '[1]\n' > "$repo/.claude/settings.json"
fails "settings that are not a JSON object" "$repo"
check "settings that are not a JSON object: nothing else is written" "no" "$([ -e "$repo/AGENTS.md" ] && echo yes || echo no)"

# Settings init cannot merge into: it fails with its own message and writes nothing.
while IFS='|' read -r name json; do
  repo="$(fresh)"
  mkdir -p "$repo/.claude"
  printf '%s\n' "$json" > "$repo/.claude/settings.json"
  fails "$name" "$repo"
  check "$name: init says what is wrong" "yes" "$(grep -q '^toolkit init: .*settings.json' <<<"$out" && echo yes || echo no)"
  check "$name: nothing else is written" "no" "$([ -e "$repo/AGENTS.md" ] && echo yes || echo no)"
done <<'CASES'
enabledPlugins is a list|{"enabledPlugins":[]}
extraKnownMarketplaces is a string|{"extraKnownMarketplaces":"x"}
two JSON values|{} {}
CASES

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '{"extraKnownMarketplaces":{"toolkit":{"source":{"source":"github","repo":"JAdshead/toolkit"}}},"enabledPlugins":{"toolkit@toolkit":true}}\n' > "$repo/.claude/settings.json"
before="$(cat "$repo/.claude/settings.json")"
init "$repo"
check "settings that already enable the plugin keep their own formatting" "$before" "$(cat "$repo/.claude/settings.json")"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '{"extraKnownMarketplaces":{"toolkit":{"source":{"source":"github","repo":"someone/fork"}}}}\n' > "$repo/.claude/settings.json"
init "$repo"
check "settings keep a toolkit marketplace the repo points elsewhere" "someone/fork" \
  "$(jq -r '.extraKnownMarketplaces.toolkit.source.repo' "$repo/.claude/settings.json")"
check "a toolkit marketplace pointed elsewhere: init warns" "yes" \
  "$(grep -q '^warning: .*marketplace' <<<"$out" && echo yes || echo no)"

repo="$(fresh)"
init "$repo"
check "the toolkit's own marketplace: no warning" "no" "$(grep -q '^warning: .*marketplace' <<<"$out" && echo yes || echo no)"

# init follows no links: any link is refused, wherever it points, except
# CLAUDE.md or GEMINI.md linking to AGENTS.md (tested above). A refused run
# writes nothing, here or through the link. Each target holds a JSON object,
# so only the link check can stop init writing through it.
outside="$work/outside"
keep='{"keep":1}'
refused() {
  fails "$1" "$repo"
  check "$1: the link's target is untouched" "$keep" "$(cat "$2" 2>/dev/null)"
  check "$1: nothing is written in the repo" "no" "$([ -e "$repo/GEMINI.md" ] && echo yes || echo no)"
}

while read -r rel text; do
  repo="$(fresh)"; rm -rf "$outside"; mkdir -p "$outside" "$repo/.claude" "$repo/docs"
  printf '%s\n' "$keep" | tee "$outside/t" "$repo/docs/t" "$repo/.claude/AGENTS.md" >/dev/null
  ln -s "$text" "$repo/$rel"
  refused "$rel -> $text" "$(dirname "$repo/$rel")/$text"
done <<'CASES'
AGENTS.md ../outside/t
CLAUDE.md ../outside/t
.claude/settings.json ../../outside/t
AGENTS.md docs/t
.claude/settings.json AGENTS.md
CASES

repo="$(fresh)"; rm -rf "$outside"; mkdir -p "$outside/.claude"
printf '%s\n' "$keep" > "$outside/.claude/settings.json"
ln -s ../outside/.claude "$repo/.claude"
refused ".claude -> ../outside/.claude" "$outside/.claude/settings.json"

repo="$(fresh)"
ln -s .. "$repo/.claude"
fails ".claude -> .." "$repo"
check ".claude -> ..: no settings.json above the repo" "no" "$([ -e "$repo/../settings.json" ] && echo yes || echo no)"

repo="$(fresh)"
git init -q "$repo"
before="$(cat "$repo/.git/config")"
ln -s .git/config "$repo/AGENTS.md"
fails "AGENTS.md -> .git/config" "$repo"
check "AGENTS.md -> .git/config: git config is untouched" "$before" "$(cat "$repo/.git/config")"

repo="$(fresh)"
printf 'not a directory\n' > "$repo/.claude"
fails ".claude is a file" "$repo"
check ".claude is a file: nothing is written" "no" "$([ -e "$repo/AGENTS.md" ] || [ -e "$repo/CLAUDE.md" ] && echo yes || echo no)"

for name in CLAUDE.md GEMINI.md; do
  repo="$(fresh)"
  mkdir "$repo/$name"
  fails "$name is a directory" "$repo"
  check "$name is a directory: nothing is written" "no" "$([ -e "$repo/AGENTS.md" ] && echo yes || echo no)"
done

# init ends by printing the toolkit's settings as they now stand, as JSON.
status() { grep '^toolkit plugin' <<<"$out"; }

repo="$(fresh)"
init "$repo"
check "empty repo: settings are written" "yes" "$(grep -q 'updated .claude/settings.json' <<<"$out" && echo yes || echo no)"
check "empty repo: status shows the plugin enabled from the toolkit marketplace" \
  'toolkit plugin in .claude/settings.json: {"enabled":true,"marketplace":{"source":"github","repo":"JAdshead/toolkit"}}' "$(status)"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '{"extraKnownMarketplaces":{"toolkit":{"source":{"source":"github","repo":"someone/fork"}}},"enabledPlugins":{"toolkit@toolkit":false}}\n' > "$repo/.claude/settings.json"
before="$(cat "$repo/.claude/settings.json")"
init "$repo"
check "settings the repo chose in full are left unchanged" "$before" "$(cat "$repo/.claude/settings.json")"
check "unchanged settings are not reported as written" "no" "$(grep -q 'updated .claude/settings.json' <<<"$out" && echo yes || echo no)"
check "status shows what the repo chose" \
  'toolkit plugin in .claude/settings.json: {"enabled":false,"marketplace":{"source":"github","repo":"someone/fork"}}' "$(status)"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '{"extraKnownMarketplaces":{"toolkit":"x"}}\n' > "$repo/.claude/settings.json"
init "$repo"
check "a toolkit marketplace that is not an object is shown as it is" \
  'toolkit plugin in .claude/settings.json: {"enabled":true,"marketplace":"x"}' "$(status)"
check "a toolkit marketplace that is not an object: init warns, with no jq error" "yes no" \
  "$(grep -q '^warning: .*marketplace' <<<"$out" && echo yes || echo no) $(grep -q 'jq' <<<"$out" && echo yes || echo no)"

repo="$(fresh)"
mkdir -p "$repo/.claude"
printf '{"extraKnownMarketplaces":{"toolkit":{"source":{"source":"github","repo":"evil/x\\u001b[2K\\r"}}},"enabledPlugins":{"toolkit@toolkit":"off\\u001b[2K\\r"}}\n' > "$repo/.claude/settings.json"
init "$repo"
check "control characters from the repo's settings never reach the terminal" "no" "$(LC_ALL=C grep -q "$(printf '\033')" <<<"$out" && echo yes || echo no)"
check "control characters are shown escaped" "yes" "$(grep -qF 'evil/x\u001b' <<<"$out" && echo yes || echo no)"

fails "a missing directory" "$work/nope"

printf '%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
