#!/usr/bin/env bash
# Tests for pr-media, run against pr-media-fake-gh and a local bare repo as
# origin. Usage: pr_media_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
media="$here/../pr-media"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/gh"
ln -s "$here/pr-media-fake-gh" "$work/bin/gh"
export PATH="$work/bin:$PATH" FAKE_GH_DIR="$work/gh"
export GIT_AUTHOR_NAME=Tester GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=Tester GIT_COMMITTER_EMAIL=t@example.com

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

# --- ui ---

printf 'lib/money.rb\napp/views/stays/show.html.erb\n' > "$work/gh/files.txt"
out="$("$media" ui 5 2>/dev/null)"
check "a PR touching a view is a UI PR and names the file" "0 app/views/stays/show.html.erb" "$? $out"

printf 'lib/money.rb\nspec/money_spec.rb\n' > "$work/gh/files.txt"
"$media" ui 5 >/dev/null 2>&1
check "a PR touching no view, component, style or copy is not a UI PR" "1" "$?"

for f in app/components/card.tsx web/src/Button.vue assets/site.scss config/locales/en.yml; do
  echo "$f" > "$work/gh/files.txt"
  "$media" ui 5 >/dev/null 2>&1
  check "$f makes a UI PR" "0" "$?"
done

FAKE_GH_FAIL=pulls/5/files "$media" ui 5 >/dev/null 2>&1
check "ui exits 2, not 1, when gh cannot list the files" "2" "$?"

# --- attach ---

git init -q --bare "$work/origin.git"
git clone -q "$work/origin.git" "$work/clone" 2>/dev/null
git -C "$work/clone" commit -q --allow-empty -m base
git -C "$work/clone" push -q origin HEAD 2>/dev/null
printf 'png-one' > "$work/desktop.png"
printf 'gif-two' > "$work/flow.gif"
printf 'webm-three' > "$work/flow.webm"
printf 'png-four' > "$work/mobile.png"
printf 'Fixes the card.\r\n\r\nCloses #4\r\n' > "$work/gh/body.txt"
echo 1111111111111111111111111111111111111111 > "$work/gh/head.txt"
remote_ref() { git -C "$work/clone" ls-remote origin refs/pr-media/5 | cut -f1; }
attach() { (cd "$work/clone" && "$media" attach 5 "$@"); }

head_before="$(git -C "$work/clone" rev-parse HEAD)"
attach "$work/desktop.png" "$work/flow.gif" "$work/flow.webm" >/dev/null 2>&1
check "attach succeeds" "0" "$?"
first="$(remote_ref)"
check "attach pushes a commit to refs/pr-media/5" "yes" "$([ -n "$first" ] && echo yes || echo no)"
check "attach pushes no branch" "" "$(git -C "$work/clone" ls-remote --heads origin | grep -v "$head_before")"
git -C "$work/clone" fetch -q origin refs/pr-media/5
check "the first publish is an orphan commit" "1" "$(git -C "$work/clone" rev-list --count "$first")"
check "the commit holds the files" "png-one|webm-three" \
  "$(git -C "$work/clone" show "$first:desktop.png")|$(git -C "$work/clone" show "$first:flow.webm")"
check "attach leaves the checkout alone" "$head_before|" \
  "$(git -C "$work/clone" rev-parse HEAD)|$(git -C "$work/clone" status --porcelain)"
body="$(cat "$work/gh/body.txt")"
check "the body keeps its own text" "yes" "$(grep -qF "Closes #4" <<<"$body" && echo yes || echo no)"
check "a screenshot renders inline from the commit" "yes" \
  "$(grep -qF "![desktop.png](https://github.com/acme/app/raw/$first/desktop.png)" <<<"$body" && echo yes || echo no)"
check "a GIF renders inline" "yes" \
  "$(grep -qF "![flow.gif](https://github.com/acme/app/raw/$first/flow.gif)" <<<"$body" && echo yes || echo no)"
check "a video is a link beside it, not an image" "yes|no" \
  "$(grep -qF "[flow.webm](https://github.com/acme/app/raw/$first/flow.webm)" <<<"$body" && echo yes || echo no)|$(grep -qF "![flow.webm]" <<<"$body" && echo yes || echo no)"
check "the section names the PR head it was attached at" "yes" \
  "$(grep -qxF "Head: 1111111111111111111111111111111111111111" <<<"$body" && echo yes || echo no)"

# GitHub returns bodies with CRLF line ends; the section must still be found.
# From a checkout that never fetched the ref, so the previous publish must be
# fetched before chaining on it. --no-local copies objects instead of
# hardlinking them, so the first publish is not already there.
sed 's/$/\r/' "$work/gh/body.txt" > "$work/crlf" && mv "$work/crlf" "$work/gh/body.txt"
echo 2222222222222222222222222222222222222222 > "$work/gh/head.txt"
git clone -q --no-local "$work/origin.git" "$work/other" 2>/dev/null
(cd "$work/other" && "$media" attach 5 "$work/mobile.png") >/dev/null 2>&1
check "a second attach from another clone succeeds" "0" "$?"
second="$(remote_ref)"
git -C "$work/clone" fetch -q origin refs/pr-media/5
check "a second publish is chained on the first, so its links keep working" "$first" \
  "$(git -C "$work/clone" rev-parse "$second^")"
body="$(cat "$work/gh/body.txt")"
check "the section names the new head, not the old" "1|0" \
  "$(grep -cxF "Head: 2222222222222222222222222222222222222222" <<<"$body")|$(grep -c "1111111111111111111111111111111111111111" <<<"$body")"
check "a second attach replaces the section in a CRLF body instead of adding one" "1" \
  "$(grep -c "^## Screenshots" <<<"$body")"
check "the section now shows the new file" "yes|no" \
  "$(grep -qF "raw/$second/mobile.png" <<<"$body" && echo yes || echo no)|$(grep -qF "desktop.png" <<<"$body" && echo yes || echo no)"
check "the text after the section survives" "yes" "$(grep -qF "Closes #4" <<<"$body" && echo yes || echo no)"

cp "$work/gh/body.txt" "$work/body.saved"
unchanged() { [ "$(remote_ref)" = "$second" ] && cmp -s "$work/body.saved" "$work/gh/body.txt" && echo yes || echo no; }

GIT_AUTHOR_NAME="" attach "$work/desktop.png" >/dev/null 2>&1
check "a failed commit exits 2" "2" "$?"
check "a failed commit leaves the remote ref and the body alone" "yes" "$(unchanged)"

FAKE_GH_FAIL="repo view" attach "$work/desktop.png" >/dev/null 2>&1
check "attach exits 2 when gh cannot name the repo" "2" "$?"
check "and pushes and edits nothing" "yes" "$(unchanged)"

FAKE_GH_FAIL="json body" attach "$work/desktop.png" >/dev/null 2>&1
check "attach exits 2 when gh cannot read the body" "2" "$?"
check "and pushes and edits nothing" "yes" "$(unchanged)"

FAKE_GH_FAIL="headRefOid" attach "$work/desktop.png" >/dev/null 2>&1
check "attach exits 2 when gh cannot read the PR's head" "2" "$?"
check "and pushes and edits nothing" "yes" "$(unchanged)"

printf '#!/bin/sh\nexit 1\n' > "$work/origin.git/hooks/pre-receive"
chmod +x "$work/origin.git/hooks/pre-receive"
attach "$work/desktop.png" >/dev/null 2>&1
check "attach exits 2 when origin refuses the push" "2" "$?"
check "and edits nothing" "yes" "$(unchanged)"
rm "$work/origin.git/hooks/pre-receive"

for bad in "start with no end" "two sections"; do
  case "$bad" in
    "start with no end") printf 'Fixes it.\n<!-- pr-media:start -->\nold\n\nCloses #4\n' ;;
    "two sections") printf '<!-- pr-media:start -->\na\n<!-- pr-media:end -->\n<!-- pr-media:start -->\nb\n<!-- pr-media:end -->\nCloses #4\n' ;;
  esac > "$work/gh/body.txt"
  cp "$work/gh/body.txt" "$work/body.saved"
  attach "$work/desktop.png" >/dev/null 2>&1
  check "attach exits 2 on a body with $bad" "2" "$?"
  check "and pushes and edits nothing" "yes" "$(unchanged)"
done

printf 'Fixes it.\n\nCloses #4\n' > "$work/gh/body.txt"
cp "$work/gh/body.txt" "$work/body.saved"
FAKE_GH_FAIL="pr edit" attach "$work/desktop.png" >/dev/null 2>&1
check "attach exits 2 when gh cannot write the body" "2" "$?"
check "after the push: the ref moved and the body is unchanged" "yes|yes" \
  "$([ "$(remote_ref)" != "$second" ] && echo yes || echo no)|$(cmp -s "$work/body.saved" "$work/gh/body.txt" && echo yes || echo no)"

attach "$work/missing.png" >/dev/null 2>&1
check "attach exits 2 on a missing file" "2" "$?"
printf 'x' > "$work/has space.png"
attach "$work/has space.png" >/dev/null 2>&1
check "attach exits 2 on a file name that would need escaping in a URL" "2" "$?"

"$media" bogus >/dev/null 2>&1
check "an unknown command exits 2" "2" "$?"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
