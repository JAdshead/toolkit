#!/usr/bin/env bash
# Tests for scripts/board, run against test/fake-gh. Usage: board_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
board="$here/../board"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
ln -s "$here/fake-gh" "$work/bin/gh"
export PATH="$work/bin:$PATH" FAKE_GH_STATE="$work/state.json"

failures=0
passes=0

reset_board() {
  cat > "$FAKE_GH_STATE" <<'JSON'
{"items":[
  {"id":"I1","status":"Ready","area":"Payments","priority":"P2","title":"Refund bug","content":{"number":1,"repository":"acme/app"}},
  {"id":"I2","status":"Ready","area":"Calendar","title":"Sync","content":{"number":2,"repository":"acme/app"}},
  {"id":"I3","status":"In progress","agent":"other@host","area":"Payments","title":"Ledger","content":{"number":3,"repository":"acme/app"}},
  {"id":"I4","status":"Backlog","area":"Pricing","title":"Rates","content":{"number":4,"repository":"acme/app"}},
  {"id":"I5","status":"Ready","agent":"stale@host","area":"Pricing","title":"Stale","content":{"number":5,"repository":"acme/app"}},
  {"id":"I6","status":"Ready","assignees":["a-human"],"area":"Calendar","title":"Taken by hand","content":{"number":6,"repository":"acme/app"}},
  {"id":"I7","status":"Done","agent":"old@host","area":"Calendar","title":"Shipped","content":{"number":7,"repository":"acme/app"}},
  {"id":"I9","status":"Ready","area":"Payments","title":"Elsewhere","content":{"number":9,"repository":"acme/other"}}
]}
JSON
}

field_of() { jq -r --argjson n "$1" --arg k "$2" '.items[] | select(.content.number == $n) | .[$k] // ""' "$FAKE_GH_STATE"; }

run() { "$board" acme/7 "$@"; }

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passes=$((passes + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual"
  fi
}

reset_board
check "ready lists unclaimed, unassigned Ready issues in this repo only" \
  "$(printf '1\tP2\tPayments\tRefund bug\n2\t\tCalendar\tSync')" "$(run ready)"

reset_board
check "busy lists claimed issues that are not Done, with their area and agent" \
  "$(printf '3\tIn progress\tPayments\tother@host\n5\tReady\tPricing\tstale@host')" "$(run busy)"

reset_board
run claim me@mac 1 2 >/dev/null
check "claim records the agent" "me@mac me@mac" "$(field_of 1 agent) $(field_of 2 agent)"
check "claim moves the issue to In progress" "In progress" "$(field_of 1 status)"

reset_board
run claim me@mac 1 3 >/dev/null 2>&1
check "claiming an issue another agent holds fails" "1" "$?"
check "a failed claim leaves the other agent's claim alone" "other@host" "$(field_of 3 agent)"
check "a failed claim releases the issues it took in the same call" "Ready|" "$(field_of 1 status)|$(field_of 1 agent)"

reset_board
run claim me@mac 4 >/dev/null 2>&1
check "only Ready issues can be claimed" "1 Backlog" "$? $(field_of 4 status)"

reset_board
run claim me@mac 42 >/dev/null 2>&1
check "an issue not on the board cannot be claimed" "1" "$?"

reset_board
run claim me@mac 5 >/dev/null 2>&1
check "a Ready issue that still carries another agent's claim cannot be taken" "1 stale@host" "$? $(field_of 5 agent)"

reset_board
FAKE_GH_STEAL=rival@box FAKE_GH_STEAL_ITEM=I2 run claim me@mac 1 2 >/dev/null 2>&1
check "losing one issue in a race releases the others claimed with it" "1 Ready| rival@box" "$? $(field_of 1 status)|$(field_of 1 agent) $(field_of 2 agent)"

reset_board
FAKE_GH_STEAL=rival@box run claim me@mac 1 >/dev/null 2>&1
check "losing a race to another agent's write counts as a failed claim" "1 rival@box" "$? $(field_of 1 agent)"

reset_board
run claim me@mac 1 >/dev/null
run claim me@mac 1 >/dev/null 2>&1
check "re-claiming your own issue succeeds (resume)" "0 me@mac" "$? $(field_of 1 agent)"

reset_board
run claim me@mac 1 >/dev/null
run move me@mac "In review" 1 >/dev/null
check "move changes the status of your own issue" "In review" "$(field_of 1 status)"

reset_board
run move me@mac "In review" 3 >/dev/null 2>&1
check "move refuses an issue another agent holds" "1 In progress" "$? $(field_of 3 status)"

reset_board
run claim me@mac 1 >/dev/null
run move me@mac "Shipped" 1 >/dev/null 2>&1
check "move rejects a status the board does not have" "1 In progress" "$? $(field_of 1 status)"

reset_board
run claim me@mac 1 >/dev/null
run release me@mac 1 >/dev/null
check "release clears the agent and returns the issue to Ready" "Ready|" "$(field_of 1 status)|$(field_of 1 agent)"

reset_board
run release me@mac 3 >/dev/null 2>&1
check "release refuses an issue another agent holds" "1 other@host" "$? $(field_of 3 agent)"

reset_board
run claim me@mac 1 2 >/dev/null
run move me@mac "In review" 2 >/dev/null
check "mine lists your issues and their status" \
  "$(printf '1\tIn progress\n2\tIn review')" "$(run mine me@mac)"

reset_board
run approve 4 >/dev/null
check "approve moves an unclaimed issue to Ready" "Ready" "$(field_of 4 status)"

reset_board
run approve 3 >/dev/null 2>&1
check "approve refuses an issue another agent holds" "1 In progress" "$? $(field_of 3 status)"

reset_board
FAKE_GH_BOARD=noagent run ready >/dev/null 2>&1
check "a board with no Agent field exits 2 (use assignee claims)" "2" "$?"

reset_board
"$board" ready >/dev/null 2>&1
check "a missing owner/number is refused" "1" "$?"

reset_board
"$board" acme ready >/dev/null 2>&1
check "a project without a number is refused" "1" "$?"

todo_board() {
  cat > "$FAKE_GH_STATE" <<'JSON'
{"items":[
  {"id":"T1","status":"Todo","title":"Plain board","content":{"number":1,"repository":"acme/app"}}
]}
JSON
}

todo_board
check "on a board without Ready, Todo is the ready status" \
  "$(printf '1\t\t\tPlain board')" "$(FAKE_GH_BOARD=todo run ready)"

todo_board
FAKE_GH_BOARD=todo run claim me@mac 1 >/dev/null
FAKE_GH_BOARD=todo run release me@mac 1 >/dev/null
check "release returns the issue to Todo on such a board" "Todo|" "$(field_of 1 status)|$(field_of 1 agent)"

reset_board
BOARD_READY=Backlog run claim me@mac 4 >/dev/null
check "BOARD_READY names the ready status" "0 In progress me@mac" "$? $(field_of 4 status) $(field_of 4 agent)"

# Status names that don't match exactly, or don't exist: never write half a claim.

todo_board
FAKE_GH_BOARD=github run claim me@mac 1 >/dev/null 2>&1
check "on GitHub's default board (\"In Progress\"), claim sets the agent and the status" \
  "0 In Progress me@mac" "$? $(field_of 1 status) $(field_of 1 agent)"

reset_board
FAKE_GH_BOARD=noprogress run claim me@mac 1 >/dev/null 2>&1
check "claim on a board with no in-progress option fails and writes nothing" \
  "1 Ready|" "$? $(field_of 1 status)|$(field_of 1 agent)"

reset_board
BOARD_IN_PROGRESS=Doing run claim me@mac 1 2 >/dev/null 2>&1
check "claim with a BOARD_IN_PROGRESS the board lacks fails and writes nothing" \
  "1 Ready| Ready|" "$? $(field_of 1 status)|$(field_of 1 agent) $(field_of 2 status)|$(field_of 2 agent)"

reset_board
run claim me@mac 1 >/dev/null
BOARD_READY=Queued run release me@mac 1 >/dev/null 2>&1
check "release with a ready status the board lacks fails and keeps the claim" \
  "1 In progress|me@mac" "$? $(field_of 1 status)|$(field_of 1 agent)"

reset_board
BOARD_READY=Queued run approve 4 >/dev/null 2>&1
check "approve with a ready status the board lacks fails and writes nothing" "1 Backlog" "$? $(field_of 4 status)"

reset_board
run claim me@mac 1 >/dev/null
run move me@mac "in review" 1 >/dev/null 2>&1
check "move matches status names case-insensitively and writes the board's name" "0 In review" "$? $(field_of 1 status)"

reset_board
BOARD_READY=backlog run claim me@mac 4 >/dev/null 2>&1
check "BOARD_READY matches case-insensitively" "0 In progress me@mac" "$? $(field_of 4 status) $(field_of 4 agent)"

echo "$passes passed, $failures failed"
[ "$failures" = 0 ]
