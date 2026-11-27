#!/usr/bin/env bash
# Tests for run-watched: it passes a finished command's exit code through and
# kills a run that goes silent or runs too long, with everything it started.
# Usage: run_watched_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
watched="$here/../run-watched"
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
says() { if grep -qF -- "$2" "$1"; then echo yes; else echo no; fi; }
alive() { if kill -0 "$1" 2>/dev/null; then echo yes; else echo no; fi; }

log="$work/run.log"

"$watched" "$log" 1m 5m -- sh -c 'echo hello; echo oops >&2' 2>/dev/null
check "a finished command's exit code passes through" "0" "$?"
check "the command's output and errors go to the log" "yes yes" "$(says "$log" hello) $(says "$log" oops)"

"$watched" "$log" 1m 5m -- sh -c 'exit 3' 2>/dev/null
check "a failing command's exit code passes through" "3" "$?"

echo "old run" > "$log"
"$watched" "$log" 1m 5m -- true 2>/dev/null
check "each run starts a fresh log" "no" "$(says "$log" "old run")"

"$watched" "$log" 1m 1h -- sh -c 'sleep 2' 2>/dev/null
check "a max in hours is hours, not seconds" "0" "$?"
"$watched" "$log" 1 5m -- sh -c 'sleep 2' 2>/dev/null
check "a bare number is minutes, not seconds" "0" "$?"

start=$(date +%s)
"$watched" "$log" 2s 5m -- sh -c 'echo started; exec sleep 60' 2>"$work/err"
rc=$?
check "a run that goes silent is killed with exit 124" "124" "$rc"
check "it is killed soon after the silent limit" "yes" "$( [ $(( $(date +%s) - start )) -lt 20 ] && echo yes || echo no)"
check "the log says why it was killed" "yes" "$(says "$log" "run-watched: no output for 2s")"
check "so does stderr" "yes" "$(says "$work/err" "no output for 2s")"

start=$(date +%s)
"$watched" "$log" 5s 3s -- sh -c 'while :; do echo tick; sleep 0.3; done' 2>/dev/null
rc=$?
check "a run still printing past the max is killed with exit 124" "124" "$rc"
check "it is killed soon after the max" "yes" "$( [ $(( $(date +%s) - start )) -lt 20 ] && echo yes || echo no)"
check "the log says it ran too long" "yes" "$(says "$log" "run-watched: still running after 3s")"

# shellcheck disable=SC2016
"$watched" "$log" 2s 5m -- sh -c 'sleep 60 & echo $! > "$0"; wait' "$work/child.pid" 2>/dev/null
check "killing a run also kills what it started" "no" "$(alive "$(cat "$work/child.pid")")"

"$watched" "$log" 1m 5m true 2>/dev/null
check "a missing -- is a usage error" "2" "$?"
"$watched" "$log" soon 5m -- true 2>/dev/null
check "a limit that is not a duration is a usage error" "2" "$?"
"$watched" "$log" 0 5m -- true 2>/dev/null
check "a zero limit is a usage error" "2" "$?"
"$watched" 2>"$work/err"
check "no arguments prints the usage line" "2 yes" "$? $(says "$work/err" "usage: run-watched <log> <silent> <max> -- <command>")"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
