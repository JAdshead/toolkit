#!/usr/bin/env bash
# Tests for bin/sync-shared, run on a scratch tree. Usage: test/sync_shared_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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

# A scratch tree: shared/notes.md and shared/tool, used by skill "alpha",
# which also has a hand-written reference of its own.
fresh() {
  t="$work/tree"
  rm -rf "$t"
  mkdir -p "$t/bin" "$t/shared/test" "$t/skills/alpha"
  cp "$here/../bin/sync-shared" "$t/bin/"
  echo "notes" > "$t/shared/notes.md"
  printf '#!/bin/sh\n' > "$t/shared/tool"
  chmod +x "$t/shared/tool"
  echo "test" > "$t/shared/test/tool_test.sh"
  printf 'Read references/notes.md and run scripts/tool.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
  mkdir -p "$t/skills/alpha/references"
  echo "own" > "$t/skills/alpha/references/own.md"
  "$t/bin/sync-shared" >/dev/null
}
sync() { out="$("$t/bin/sync-shared" "$@" 2>&1)"; rc=$?; }
exists() { if [ -e "$t/skills/alpha/$1" ]; then echo yes; else echo no; fi; }
says() { if grep -qF -- "$1" <<<"$out"; then echo yes; else echo no; fi; }

fresh
sync --check
check "a synced tree passes --check" "0" "$rc"

fresh
echo "edited" >> "$t/skills/alpha/references/notes.md"
sync --check
check "--check fails on a copy whose content differs from shared/" "1 yes" "$rc $(says "FAIL alpha/references/notes.md")"

fresh
chmod -x "$t/skills/alpha/scripts/tool"
sync --check
check "--check fails on a copy that lost its executable bit" "1 yes" "$rc $(says "FAIL alpha/scripts/tool")"

fresh
printf 'Read references/notes.md and references/tool.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync --check
check "a mention under references/ doesn't keep a copy in scripts/" "1 yes" "$rc $(says "FAIL alpha/scripts/tool is stale")"

fresh
rm -f "$t"/shared/notes.md "$t"/shared/tool
sync --check
check "--check fails when shared/ holds no files (folders don't count)" "1 yes" "$rc $(says "nothing to sync")"

fresh
rm -rf "$t/shared"
sync --check
check "--check fails when shared/ is missing" "1" "$rc"

fresh
rm -rf "$t/shared"
sync
check "plain sync fails when shared/ is missing" "1" "$rc"

fresh
printf 'Run scripts/tool.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync --check
check "--check fails on a references/ copy its SKILL.md no longer mentions" \
  "1 yes yes" "$rc $(says "FAIL alpha/references/notes.md") $(exists references/notes.md)"

fresh
printf 'Read references/notes.md.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync --check
check "--check fails on a scripts/ copy its SKILL.md no longer mentions" \
  "1 yes yes" "$rc $(says "FAIL alpha/scripts/tool") $(exists scripts/tool)"

fresh
printf 'Run scripts/tool.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync
check "plain sync removes a stale references/ copy and says so" \
  "0 yes no" "$rc $(says "remove alpha/references/notes.md") $(exists references/notes.md)"

fresh
printf 'Read references/notes.md.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync
check "plain sync removes a stale scripts/ copy and says so" \
  "0 yes no" "$rc $(says "remove alpha/scripts/tool") $(exists scripts/tool)"

fresh
printf 'Read references/notes.md and run scripts/tool.\n' > "$t/skills/alpha/SKILL.md"
sync
check "a hand-written reference with no shared/ file is left alone" \
  "0 yes" "$rc $(exists references/own.md)"
sync --check
check "--check ignores a hand-written reference" "0" "$rc"

fresh
echo "unused" > "$t/shared/orphan.md"
sync --check
check "a shared file no SKILL.md mentions is reported, without failing the run" "0 yes" "$rc $(says "shared/orphan.md")"

fresh
echo "Run scripts/tool." > "$t/shared/notes.md"
printf 'Read references/notes.md.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync
check "plain sync keeps a copy that a shared reference the skill uses mentions" \
  "0 yes" "$rc $(exists scripts/tool)"
sync --check
check "--check passes on a copy that a shared reference the skill uses mentions" "0" "$rc"

fresh
echo "Run scripts/tool." > "$t/skills/alpha/references/own.md"
printf 'Read references/notes.md.\nSee references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync
check "plain sync keeps a copy that a hand-written reference the skill uses mentions" \
  "0 yes" "$rc $(exists scripts/tool)"

fresh
echo "Run scripts/tool." > "$t/shared/notes.md"
"$t/bin/sync-shared" >/dev/null
printf 'See references/own.md.\n' > "$t/skills/alpha/SKILL.md"
sync
check "a copy only a stale reference mentions is removed in the same run" \
  "0 no no" "$rc $(exists references/notes.md) $(exists scripts/tool)"

fresh
printf 'Keep references/notes.md.bak and run scripts/tool.\n' > "$t/skills/alpha/SKILL.md"
sync --check
check "a longer path that starts with a shared file's path is not a mention of it" \
  "1 yes" "$rc $(says "FAIL alpha/references/notes.md is stale")"

fresh
mkdir -p "$work/outside"
mv "$t/skills/alpha/references"/* "$work/outside/"
rmdir "$t/skills/alpha/references"
ln -s "$work/outside" "$t/skills/alpha/references"
printf 'Run scripts/tool.\n' > "$t/skills/alpha/SKILL.md"
sync
check "plain sync refuses to touch a copy behind a symlinked folder" \
  "1 yes" "$rc $([ -e "$work/outside/notes.md" ] && echo yes || echo no)"
rm -rf "$work/outside"

echo "$passes passed, $failures failed"
[ "$failures" = 0 ]
