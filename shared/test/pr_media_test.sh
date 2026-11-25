#!/usr/bin/env bash
# Tests for scripts/pr-media, run against a local bare repo as origin and
# test/fake-gh-pr-media. Usage: pr_media_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
media="$here/../pr-media"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/gh"
ln -s "$here/fake-gh-pr-media" "$work/bin/gh"
export PATH="$work/bin:$PATH" FAKE_GH_DIR="$work/gh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

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
status_of() { "$@" >/dev/null 2>&1; echo $?; }
contains() { if printf '%s' "$1" | grep -qF -- "$2"; then echo yes; else echo no; fi; }

# A repo whose origin is a local bare repo, with one commit on main.
git init -q --bare "$work/origin.git"
git init -q -b main "$work/repo"
cd "$work/repo" || exit 1
git remote add origin "$work/origin.git"
echo app > app.txt && git add app.txt && git commit -qm init && git push -q origin main

# --- ui: which PRs change the UI ---

ui_files() { printf '%s\n' "$@" > "$FAKE_GH_DIR/files"; echo "Summary" > "$FAKE_GH_DIR/body"; }

ui_files app/views/bookings/show.html.erb app/models/booking.rb
check "a view template makes a UI PR" 0 "$(status_of "$media" ui 7)"
check "ui lists only the UI files" "app/views/bookings/show.html.erb" "$("$media" ui 7 2>/dev/null)"

for f in src/components/Button.tsx web/App.vue app/assets/stylesheets/site.scss styles/main.css \
  config/locales/en.yml public/logo.svg app/components/card_component.rb src/Widget.svelte; do
  ui_files "$f"
  check "$f is a UI file" 0 "$(status_of "$media" ui 7)"
done

for f in app/models/booking.rb spec/views/show_spec.rb src/components/Button.test.tsx README.md \
  docs/guide.md lib/tasks/x.rake test/system/home_test.rb src/Widget.stories.tsx; do
  ui_files "$f"
  check "$f alone is not a UI PR" 1 "$(status_of "$media" ui 7)"
done

ui_files app/models/booking.rb
printf 'Summary\n\n<!-- pr-media:start -->\n## Screenshots\n<!-- pr-media:end -->\n' > "$FAKE_GH_DIR/body"
check "a PR that carries a Screenshots section is a UI PR" 0 "$(status_of "$media" ui 7)"

ui_files app/models/booking.rb
for call in "pr diff" "pr view"; do
  echo "$call" > "$FAKE_GH_DIR/fail"
  check "ui exits 2, not 1 (no UI), when gh $call fails" 2 "$(status_of "$media" ui 7)"
done
rm -f "$FAKE_GH_DIR/fail"
check "ui exits 2 on a PR that isn't a number" 2 "$(status_of "$media" ui x)"

# --- publish: media on a hidden ref, never on a branch ---

shots="$work/shots"
mkdir -p "$shots"
for v in before after; do for d in desktop mobile; do echo "$v-$d" > "$shots/booking-form.$v.$d.png"; done; done
echo new > "$shots/guest-list.after.desktop.png"
echo v2 > "$shots/guest-list.v2.after.mobile.png"
echo gif > "$shots/date-picker.gif"
echo webm > "$shots/date-picker.webm"

section="$("$media" publish 7 "$shots" 2>/dev/null)"
check "publish succeeds" 0 "$?"
sha="$(git ls-remote origin refs/pr-media/7 | cut -f1)"
check "publish pushes refs/pr-media/<pr>" "yes" "$([ -n "$sha" ] && echo yes || echo no)"
check "publish creates no branch" "refs/heads/main" "$(git ls-remote --heads origin | cut -f2)"
check "the media commit has no parent on the first publish" "" "$(git --git-dir="$work/origin.git" rev-list --parents -n1 "$sha" | cut -s -d' ' -f2)"
check "the media commit holds the files" "booking-form.after.desktop.png" \
  "$(git --git-dir="$work/origin.git" ls-tree --name-only "$sha" | grep -m1 after.desktop)"
check "publish leaves the working tree alone" "" "$(git status --porcelain)"
check "publish leaves HEAD alone" "main" "$(git branch --show-current)"
check "a fresh clone does not fetch the media" "" \
  "$(git clone -q "$work/origin.git" "$work/clone" && git -C "$work/clone" for-each-ref | grep pr-media)"

url="https://github.com/acme/app/raw/$sha"
check "the section opens with its start marker" "<!-- pr-media:start -->" "$(printf '%s\n' "$section" | head -1)"
check "the section ends with its end marker" "<!-- pr-media:end -->" "$(printf '%s\n' "$section" | tail -1)"
check "the section has a Screenshots heading" "yes" "$(contains "$section" "## Screenshots")"
check "images are pinned to the media commit" "yes" "$(contains "$section" "($url/booking-form.after.desktop.png)")"
check "before and after sit side by side for desktop" "yes" \
  "$(contains "$section" "| Desktop | ![booking form before, desktop]($url/booking-form.before.desktop.png) | ![booking form after, desktop]($url/booking-form.after.desktop.png) |")"
check "before and after sit side by side for mobile" "yes" \
  "$(contains "$section" "| Mobile | ![booking form before, mobile]($url/booking-form.before.mobile.png) | ![booking form after, mobile]($url/booking-form.after.mobile.png) |")"
check "a screen with no before says it is new" "yes" \
  "$(contains "$section" "| Desktop | new | ![guest list after, desktop]($url/guest-list.after.desktop.png) |")"
check "a screen with no mobile shot has no mobile row" "no" "$(contains "$section" "![guest list after, mobile]")"
check "a screen whose name starts with another's gets its own table" "yes" \
  "$(contains "$section" "| Mobile | new | ![guest list.v2 after, mobile]($url/guest-list.v2.after.mobile.png) |")"
check "and adds no row to the other screen's table" "no" "$(contains "$section" "removed")"
check "an interaction GIF shows inline" "yes" "$(contains "$section" "![date picker]($url/date-picker.gif)")"
check "the full video is linked beside its GIF" "yes" "$(contains "$section" "[Full video]($url/date-picker.webm)")"

rm "$shots/guest-list.after.desktop.png"
"$media" publish 7 "$shots" >/dev/null 2>&1
sha2="$(git ls-remote origin refs/pr-media/7 | cut -f1)"
check "a second publish moves the ref" "yes" "$([ "$sha2" != "$sha" ] && echo yes || echo no)"
check "a second publish keeps the first as its parent, so old links still work" "$sha" \
  "$(git --git-dir="$work/origin.git" rev-list --parents -n1 "$sha2" | cut -d' ' -f2)"
check "a second publish holds only the new files" "no" \
  "$(git --git-dir="$work/origin.git" ls-tree --name-only "$sha2" | grep -qx guest-list.after.desktop.png && echo yes || echo no)"

mkdir -p "$work/bad1" "$work/bad2/sub" "$work/empty"
echo x > "$work/bad1/has space.png"
echo x > "$work/bad2/sub/a.png"
check "publish refuses a file name it can't put in a URL as is" 2 "$(status_of "$media" publish 7 "$work/bad1")"
check "publish refuses a folder inside the media folder" 2 "$(status_of "$media" publish 7 "$work/bad2")"
check "publish refuses an empty folder" 2 "$(status_of "$media" publish 7 "$work/empty")"
check "publish refuses a PR that isn't a number" 2 "$(status_of "$media" publish x "$shots")"

# --- attach: the section goes in the PR body, once ---

printf 'Summary\n\nCloses #3\n' > "$FAKE_GH_DIR/body"
"$media" attach 7 "$shots" >/dev/null 2>&1
check "attach succeeds" 0 "$?"
body="$(cat "$FAKE_GH_DIR/body")"
check "attach keeps the body" "yes" "$(contains "$body" "Closes #3")"
check "attach adds the section" "yes" "$(contains "$body" "## Screenshots")"
"$media" attach 7 "$shots" >/dev/null 2>&1
body="$(cat "$FAKE_GH_DIR/body")"
check "attaching again replaces the section rather than adding one" 1 "$(printf '%s\n' "$body" | grep -c "pr-media:start")"
check "attaching again points at the newest media commit" "yes" \
  "$(contains "$body" "raw/$(git ls-remote origin refs/pr-media/7 | cut -f1)/")"
check "attaching again keeps the text after the section" "yes" \
  "$(printf 'Intro\n\n<!-- pr-media:start -->\nold\n<!-- pr-media:end -->\n\nTail\n' > "$FAKE_GH_DIR/body"
     "$media" attach 7 "$shots" >/dev/null 2>&1; contains "$(cat "$FAKE_GH_DIR/body")" "Tail")"
check "the old section is gone" "no" "$(contains "$(cat "$FAKE_GH_DIR/body")" "old")"
printf 'Intro\n\n<!-- pr-media:start -->\nhalf\n\nTail\n' > "$FAKE_GH_DIR/body"
check "attach refuses a body whose section has no end marker" 2 "$(status_of "$media" attach 7 "$shots")"
before_refused="$(git ls-remote origin refs/pr-media/7 | cut -f1)"
"$media" attach 7 "$shots" >/dev/null 2>&1
check "and pushes nothing" "$before_refused" "$(git ls-remote origin refs/pr-media/7 | cut -f1)"
check "and leaves that body alone" "yes" "$(contains "$(cat "$FAKE_GH_DIR/body")" "Tail")"

# --- signoff: the owner's label, applied after the latest push ---

pr_json() { # labels-json timeline-json [is-cross-repository]
  cat > "$FAKE_GH_DIR/pr.json" <<JSON
{"data":{"repository":{"pullRequest":{"headRefOid":"abc","isCrossRepository":${3:-false},
 "labels":{"nodes":$1},
 "commits":{"nodes":[{"commit":{"oid":"abc","committedDate":"2026-11-20T10:00:00Z"}}]},
 "timelineItems":{"nodes":$2}}}}}
JSON
}
labeled() { echo "{\"__typename\":\"LabeledEvent\",\"createdAt\":\"$1\",\"actor\":{\"login\":\"$2\"},\"label\":{\"name\":\"${3:-visual-ok}\"}}"; }
echo admin > "$FAKE_GH_DIR/perm-owner"
echo write > "$FAKE_GH_DIR/perm-dev"

pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T11:00:00Z owner)]"
check "the owner's label after the head commit signs off" 0 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T11:00:00Z dev)]"
check "a writer's label signs off" 0 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T09:00:00Z owner)]"
check "a label from before the head commit does not" 1 "$(status_of "$media" signoff 7)"
check "it says why" "yes" "$(contains "$("$media" signoff 7 2>&1)" "before the latest commit")"
pr_json '[{"name":"visual-ok"}]' \
  "[$(labeled 2026-11-20T11:00:00Z owner),{\"__typename\":\"HeadRefForcePushedEvent\",\"createdAt\":\"2026-11-20T12:00:00Z\"}]"
check "a force-push after the label voids it" 1 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T11:00:00Z guest)]"
check "a label from someone without write access does not" 1 "$(status_of "$media" signoff 7)"
pr_json '[]' "[$(labeled 2026-11-20T11:00:00Z owner)]"
check "a label since removed does not" 1 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T08:00:00Z owner),$(labeled 2026-11-20T11:00:00Z owner)]"
check "the latest labeling counts" 0 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T11:00:00Z owner),$(labeled 2026-11-20T08:00:00Z owner)]"
check "the latest labeling counts whatever the event order" 0 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"looks-good"}]' "[$(labeled 2026-11-20T11:00:00Z owner looks-good)]"
check "another label does not" 1 "$(status_of "$media" signoff 7)"
check "PR_MEDIA_SIGNOFF_LABEL names the label" 0 "$(PR_MEDIA_SIGNOFF_LABEL=looks-good status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T11:00:00Z owner)]"
sed -i.bak 's/"headRefOid":"abc"/"headRefOid":"def"/' "$FAKE_GH_DIR/pr.json"
check "a head that isn't the last listed commit does not" 1 "$(status_of "$media" signoff 7)"
pr_json '[{"name":"visual-ok"}]' "[$(labeled 2026-11-20T11:00:00Z owner)]" true
check "a label on a fork's PR does not, since the fork sets its commit dates" 1 "$(status_of "$media" signoff 7)"
check "it says to sign off in the session" "yes" "$(contains "$("$media" signoff 7 2>&1)" "in the session")"
pr_json '[]' '[]'
check "no label does not" 1 "$(status_of "$media" signoff 7)"

# --- gif: a recording becomes an inline GIF ---

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -loglevel error -f lavfi -i testsrc=size=320x200:rate=25:duration=1 "$work/clip.webm"
  "$media" gif "$work/clip.webm" "$work/clip.gif" >/dev/null 2>&1
  check "gif writes a GIF" "GIF89a" "$(head -c 6 "$work/clip.gif" 2>/dev/null)"
else
  echo "skip gif: ffmpeg not installed"
fi

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
