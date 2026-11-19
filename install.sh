#!/usr/bin/env bash
# Install the toolkit for Claude Code, Codex and Gemini CLI. Safe to re-run.
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

UIPRO_REPO="https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git"
UIPRO_DIR="$TOOLKIT_DIR/vendor/ui-ux-pro-max-skill"
UIPRO_SKILL="$UIPRO_DIR/.claude/skills/ui-ux-pro-max"

SKILL_DIRS=("$HOME/.agents/skills" "$HOME/.gemini/skills")

say() { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

# link SRC DEST: point DEST at SRC, moving any other file at DEST aside first.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak.$TIMESTAMP"
    note "backed up $dest -> $dest.bak.$TIMESTAMP"
  fi
  ln -s "$src" "$dest"
  note "linked $dest -> $src"
}

# Remove links in DIR that point into the toolkit but no longer resolve
# (a skill that was renamed or deleted).
prune_dangling() {
  local dir="$1" entry target
  [ -d "$dir" ] || return 0
  for entry in "$dir"/*; do
    [ -L "$entry" ] || continue
    target="$(readlink "$entry")"
    case "$target" in
      "$TOOLKIT_DIR"/*) [ -e "$entry" ] || { rm "$entry"; note "removed stale $entry"; } ;;
    esac
  done
}

link_skills() {
  say "Linking skills for Codex (~/.agents/skills) and Gemini (~/.gemini/skills)"
  local dir skill
  for dir in "${SKILL_DIRS[@]}"; do
    mkdir -p "$dir"
    for skill in "$TOOLKIT_DIR"/skills/*/; do
      skill="${skill%/}"
      link "$skill" "$dir/$(basename "$skill")"
    done
    prune_dangling "$dir"
  done
}

link_rules() {
  say "Linking shared rules"
  link "$TOOLKIT_DIR/rules/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  link "$TOOLKIT_DIR/rules/AGENTS.md" "$HOME/.codex/AGENTS.md"

  # Gemini's save_memory appends to ~/.gemini/GEMINI.md, so a symlink would
  # write private memories into this public repo. Import the rules instead.
  local gemini_md="$HOME/.gemini/GEMINI.md" import_line="@./toolkit-AGENTS.md"
  link "$TOOLKIT_DIR/rules/AGENTS.md" "$HOME/.gemini/toolkit-AGENTS.md"
  if [ -L "$gemini_md" ]; then
    mv "$gemini_md" "$gemini_md.bak.$TIMESTAMP"
    note "backed up symlinked $gemini_md -> $gemini_md.bak.$TIMESTAMP"
  fi
  touch "$gemini_md"
  if ! grep -qxF "$import_line" "$gemini_md"; then
    cp "$gemini_md" "$gemini_md.bak.$TIMESTAMP"
    { printf '%s\n\n' "$import_line"; cat "$gemini_md.bak.$TIMESTAMP"; } > "$gemini_md"
    note "added $import_line to $gemini_md (backup at $gemini_md.bak.$TIMESTAMP)"
  fi
}

link_cli() {
  say "Linking the toolkit command"
  link "$TOOLKIT_DIR/bin/toolkit" "$HOME/.local/bin/toolkit"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) note "add ~/.local/bin to your PATH to run 'toolkit'" ;;
  esac
}

vendor_uipro() {
  if ! command -v git >/dev/null; then
    note "git not found; skipping ui-ux-pro-max for Codex/Gemini"
    return
  fi
  say "Fetching ui-ux-pro-max into vendor/ for Codex and Gemini"
  if [ -d "$UIPRO_DIR/.git" ]; then
    git -C "$UIPRO_DIR" pull --ff-only --quiet
  else
    mkdir -p "$TOOLKIT_DIR/vendor"
    git clone --depth 1 --quiet "$UIPRO_REPO" "$UIPRO_DIR"
  fi
  local dir
  for dir in "${SKILL_DIRS[@]}"; do
    link "$UIPRO_SKILL" "$dir/ui-ux-pro-max"
  done
}

claude_has_marketplace() {
  claude plugin marketplace list --json | grep -q "\"name\": \"$1\""
}

claude_has_plugin() {
  claude plugin list --json | grep -q "\"id\": \"$1\""
}

install_claude() {
  if ! command -v claude >/dev/null; then
    note "claude not found; skipping the Claude Code plugin"
    return
  fi
  say "Installing Claude Code plugins"
  if ! claude_has_marketplace toolkit; then
    claude plugin marketplace add "$TOOLKIT_DIR"
  fi
  if ! claude_has_plugin toolkit@toolkit; then
    claude plugin install toolkit@toolkit
  fi
  if ! claude_has_marketplace ui-ux-pro-max-skill; then
    claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
  fi
  if ! claude_has_plugin ui-ux-pro-max@ui-ux-pro-max-skill; then
    claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill
  fi
}

main() {
  link_skills
  link_rules
  link_cli
  vendor_uipro
  install_claude
  say "Done. Restart running agents to pick up changes."
}

main "$@"
