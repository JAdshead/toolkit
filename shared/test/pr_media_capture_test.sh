#!/usr/bin/env bash
# Tests for pr-media capture against a local static site: it signs in and
# keeps the session, opens <details>, crops to the first match, and keeps
# sticky and fixed elements off a crop unless told not to. Needs Node and
# Playwright with Chromium: run it from, or point PLAYWRIGHT_PROJECT at, a
# directory whose node_modules has playwright. Skips when it can't find one,
# unless PLAYWRIGHT_PROJECT is set: then it fails, so CI can't pass by
# skipping. Usage: pr_media_capture_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
media="$here/../pr-media"
project="${PLAYWRIGHT_PROJECT:-$PWD}"
if ! (cd "$project" && node -e "require.resolve('playwright')" 2>/dev/null); then
  if [ -n "${PLAYWRIGHT_PROJECT:-}" ]; then
    echo "FAIL no Playwright under PLAYWRIGHT_PROJECT=$PLAYWRIGHT_PROJECT"
    exit 1
  fi
  echo "skip: no Playwright under $project (set PLAYWRIGHT_PROJECT)"
  exit 0
fi

work="$(mktemp -d)"
site="$work/site"
mkdir -p "$site" "$work/out"
server=""
cleanup() { [ -n "$server" ] && kill "$server" 2>/dev/null && wait "$server" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

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
png_width() { python3 -c 'import struct,sys; d=open(sys.argv[1],"rb").read(24); print(struct.unpack(">I", d[16:20])[0] if d[:8]==b"\x89PNG\r\n\x1a\n" else "not-png")' "$1"; }
# The top-left pixel as rrggbb. The first pixel of the first row is stored
# unfiltered whatever the row's filter, so it is the bytes after the filter byte.
top_left() {
  python3 -c '
import struct, sys, zlib
d = open(sys.argv[1], "rb").read()
i, idat = 8, b""
while i < len(d):
    n = struct.unpack(">I", d[i:i+4])[0]
    if d[i+4:i+8] == b"IDAT":
        idat += d[i+8:i+8+n]
    i += 12 + n
raw = zlib.decompress(idat)
print("%02x%02x%02x" % (raw[1], raw[2], raw[3]))' "$1"
}

cat > "$site/login.html" <<'HTML'
<!doctype html><title>Sign in</title>
<button id="tab" onclick="document.querySelector('form').hidden = false">Password</button>
<form action="/home.html" method="get" onsubmit="document.cookie = 'session=1; path=/'" hidden>
  <input id="email" name="email"><input id="password" name="password" type="password">
  <button id="go" type="submit">Sign in</button><button id="stay" type="button">Nothing</button>
</form>
HTML
cat > "$site/home.html" <<'HTML'
<!doctype html><title>Home</title>
<style>
  body { margin: 0; background: #fff; }
  header { position: sticky; top: 0; height: 60px; background: #f00; }
  .card { height: 50px; margin: 10px; background: #00f; }
  .card.one { width: 200px; } .card.two { width: 300px; }
  #inside { width: 150px; height: 40px; background: #0f0; }
  #bar { position: fixed; top: 0; left: 0; width: 100%; height: 20px; background: #f0f; transition: all 5s; }
  #intro { position: static; width: 120px; height: 30px; background: #0ff; }
  #late { height: 20px; background: #ff0; top: 0; left: 0; width: 100%; }
  #drawer { position: fixed; bottom: 0; right: 0; width: 60px; height: 60px; transition: all 5s; }
  #drawer-item { width: 50px; height: 50px; background: #000; transition: all .3s; }
  .dup { width: 70px; height: 20px; background: #0f0; }
  #account { width: 80px; height: 20px; background: #0f0; }
  #tall { width: 100px; height: 900px; background: #00f; }
</style>
<header>Header</header><div id="bar"><div class="dup"></div></div><div id="late"></div><div id="drawer"><div id="drawer-item"></div></div>
<script>addEventListener('scroll', () => { if (scrollY > 100) document.getElementById('late').style.position = 'fixed'; });</script>
<div class="card zero" style="display: none"></div><div class="card one"></div><div class="card two"></div>
<details><summary>More</summary><div id="inside"></div></details>
<article><header id="intro"></header></article>
<div id="account" hidden></div>
<script>if (document.cookie.includes('session=1')) document.getElementById('account').hidden = false;</script>
<div style="height: 1500px"></div><div id="tall"></div><div style="height: 2000px"></div><div class="dup" style="width: 90px"></div>
HTML

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$site" 2>"$work/server.log" >/dev/null &
server=$!
for _ in $(seq 50); do curl -fs "http://127.0.0.1:$port/login.html" >/dev/null && break; sleep 0.1; done

spec() {
  cat > "$work/spec.json" <<JSON
{
  "baseUrl": "http://127.0.0.1:$port",
  "out": "$work/out",
  "signIn": { "path": "/login.html", "clickFirst": ["#tab"], "fields": { "#email": "tester@example.com", "#password": "secret" }, "submit": "$1" },
  "shots": $2
}
JSON
}
capture() { out="$(cd "$project" && "$media" capture "$work/spec.json" 2>"$work/err")"; rc=$?; }

spec "#go" '[
  { "name": "card", "path": "/home.html", "crop": ".card" },
  { "name": "inside", "path": "/home.html", "crop": "#inside" },
  { "name": "page", "path": "/home.html" },
  { "name": "account", "path": "/home.html", "crop": "#account" },
  { "name": "tall", "path": "/home.html", "crop": "#tall" },
  { "name": "tall-sticky", "path": "/home.html", "crop": "#tall", "keepSticky": true }
]'
capture
check "capture succeeds" "0" "$rc"
check "it prints one path per shot and width" "12" "$(grep -c '\.png$' <<<"$out")"
check "it names files <name>-<width>.png" "yes yes" \
  "$( [ -f "$work/out/card-1280.png" ] && echo yes || echo no) $( [ -f "$work/out/card-375.png" ] && echo yes || echo no)"
check "it signs in with the given fields, after clicking what reveals them" "yes" "$(says "$work/server.log" "home.html?email=tester%40example.com&password=secret")"
check "a crop matching several elements takes the first visible one" "200" "$(png_width "$work/out/card-1280.png")"
check "a crop inside <details> works because details are opened" "150" "$(png_width "$work/out/inside-375.png")"
check "a full page is the viewport's width" "375" "$(png_width "$work/out/page-375.png")"
check "shots are taken signed in" "80" "$(png_width "$work/out/account-1280.png")"
# #tall is as high as the viewport, so a crop of it starts at the viewport's top.
check "sticky and fixed elements don't cover a crop" "0000ff" "$(top_left "$work/out/tall-1280.png")"
check "keepSticky leaves them" "yes" "$( [ "$(top_left "$work/out/tall-sticky-1280.png")" != 0000ff ] && echo yes || echo no)"

# #late turns fixed only once the page scrolls, which the crop's own scroll does.
spec "#go" '[{ "name": "late", "path": "/home.html", "crop": "#tall" }]'
capture
check "an element that turns fixed on scroll doesn't cover a crop" "0 0000ff" "$rc $(top_left "$work/out/late-1280.png")"

spec "#go" '[{ "name": "drawer", "path": "/home.html", "crop": "#drawer-item" }]'
capture
check "a crop inside a fixed element exits 2 and points to keepSticky" "2 yes yes" "$rc $(says "$work/err" "inside a fixed element") $(says "$work/err" "keepSticky")"
spec "#go" '[{ "name": "drawer", "path": "/home.html", "crop": "#drawer-item", "keepSticky": true }]'
capture
check "with keepSticky, a crop inside a fixed element works" "0 50" "$rc $(png_width "$work/out/drawer-1280.png")"

# .dup's first match is inside #bar; another, 90px wide and outside any fixed element, comes later.
spec "#go" '[{ "name": "dup", "path": "/home.html", "crop": ".dup" }]'
capture
check "a crop takes the first visible match outside a fixed element, uncovered" "0 90 00ff00" "$rc $(png_width "$work/out/dup-1280.png") $(top_left "$work/out/dup-1280.png")"

spec "#go" '[{ "name": "intro", "path": "/home.html", "crop": "#intro" }]'
capture
check "a header that is not sticky or fixed stays visible" "0 120" "$rc $(png_width "$work/out/intro-1280.png")"

spec "#stay" '[{ "name": "card", "path": "/home.html", "crop": ".card" }]'
capture
check "a sign-in that never leaves the sign-in page exits 2" "2 yes" "$rc $(says "$work/err" "sign-in")"

spec "#go" '[{ "name": "bad name!", "path": "/home.html" }]'
capture
check "a shot name outside letters, digits, . _ - exits 2" "2" "$rc"

spec "#go" '[{ "name": "missing", "path": "/home.html", "crop": ".nothing-here" }]'
capture
check "a crop that matches nothing exits 2 and says so" "2 yes" "$rc $(says "$work/err" "nothing visible matches .nothing-here on /home.html")"

spec "#go" '[]'
capture
check "a spec with no shots exits 2" "2" "$rc"

"$media" capture "$work/missing.json" 2>/dev/null
check "a missing spec file exits 2" "2" "$?"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
