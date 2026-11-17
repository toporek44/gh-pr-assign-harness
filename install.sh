#!/usr/bin/env bash
# Install gh-pr-assign-harness into Cursor and/or Claude Code.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${GH_PR_ASSIGN_ROOT:-$HOME/.local/share/gh-pr-assign-harness}"
CURSOR_HOOKS="$HOME/.cursor/hooks.json"
CURSOR_RULES="$HOME/.cursor/rules"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CLAUDE_DOCS="${CLAUDE_DOCS:-$HOME/.claude/PR-ASSIGN-harness.md}"
CONFIG_DIR="$HOME/.config/gh"
CONFIG_FILE="$CONFIG_DIR/pr-default-assignees.json"
BIN_DIR="$HOME/.local/bin"

INSTALL_CURSOR=1
INSTALL_CLAUDE=1
NOTIFY=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  (default)     Install Cursor + Claude Code hooks
  --cursor-only Install Cursor harness only
  --claude-only Install Claude Code hooks only
  --notify      Also enable macOS assign notifications (LaunchAgent)
  --uninstall   Remove harness hooks from Cursor + Claude
  -h, --help    This help
EOF
}

install_tree() {
  mkdir -p "$INSTALL_DIR"
  rsync -a --delete --exclude .git "$SRC/" "$INSTALL_DIR/"
}

link_bins() {
  mkdir -p "$BIN_DIR"
  for b in gh-pr-create gh-pr-roster-json gh-pr-assignees-ui; do
    ln -sf "$INSTALL_DIR/bin/$b" "$BIN_DIR/$b"
  done
}

install_config() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$INSTALL_DIR/config/pr-default-assignees.json.example" "$CONFIG_FILE"
    cp "$INSTALL_DIR/config/pr-default-assignees.schema.json" "$CONFIG_DIR/" 2>/dev/null || true
  fi
  if [[ -f "$INSTALL_DIR/profiles/mtopor-box.json" ]] && [[ ! -f "$CONFIG_DIR/pr-default-assignees.local.json" ]]; then
    cp "$INSTALL_DIR/profiles/mtopor-box.json" "$CONFIG_DIR/pr-default-assignees.local.json.example"
  fi
  ln -sf "$INSTALL_DIR/ui/pr-assignees-ui.py" "$CONFIG_DIR/pr-assignees-ui.py" 2>/dev/null || true
}

merge_cursor_hooks() {
  python3 "$INSTALL_DIR/scripts/merge_cursor_hooks.py" \
    "$INSTALL_DIR/cursor/hooks.fragment.json" \
    "$CURSOR_HOOKS" \
    "$INSTALL_DIR" \
    "${1:-install}"
}

merge_claude_hooks() {
  python3 "$INSTALL_DIR/scripts/merge_claude_settings.py" \
    "$INSTALL_DIR/claude/hooks.fragment.json" \
    "$CLAUDE_SETTINGS" \
    "$INSTALL_DIR" \
    "${1:-install}"
}

install_cursor_rule() {
  mkdir -p "$CURSOR_RULES"
  cp "$INSTALL_DIR/cursor/rules/gh-pr-default-assignees.mdc" "$CURSOR_RULES/"
}

install_claude_instructions() {
  cp "$INSTALL_DIR/claude/INSTRUCTIONS.md" "$CLAUDE_DOCS"
}

install_notify() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "notify: macOS only, skipped"
    return
  fi
  plist="$INSTALL_DIR/optional/launchd/gh-assignment-notify.plist"
  target="$HOME/Library/LaunchAgents/com.gh-pr-assign-harness.notify.plist"
  sed "s|@INSTALL_DIR@|$INSTALL_DIR|g; s|@HOME@|$HOME|g" "$plist" >"$target"
  launchctl bootout "gui/$(id -u)/com.gh-pr-assign-harness.notify" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$target" 2>/dev/null || true
}

uninstall() {
  [[ "$INSTALL_CURSOR" == 1 ]] && merge_cursor_hooks uninstall
  [[ "$INSTALL_CLAUDE" == 1 ]] && merge_claude_hooks uninstall
  rm -f "$BIN_DIR/gh-pr-create" "$BIN_DIR/gh-pr-roster-json" "$BIN_DIR/gh-pr-assignees-ui"
  rm -f "$CURSOR_RULES/gh-pr-default-assignees.mdc"
  rm -f "$CLAUDE_DOCS"
  launchctl bootout "gui/$(id -u)/com.gh-pr-assign-harness.notify" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/com.gh-pr-assign-harness.notify.plist"
  echo "Removed harness. Config kept at $CONFIG_FILE"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall)
        uninstall
        exit 0
        ;;
      --notify) NOTIFY=1 ;;
      --cursor-only) INSTALL_CLAUDE=0 ;;
      --claude-only) INSTALL_CURSOR=0 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        echo "unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  install_tree
  link_bins
  install_config
  if [[ "$INSTALL_CURSOR" == 1 ]]; then
    merge_cursor_hooks install
    install_cursor_rule
    echo "Cursor: merged $CURSOR_HOOKS + rule"
  fi
  if [[ "$INSTALL_CLAUDE" == 1 ]]; then
    merge_claude_hooks install
    install_claude_instructions
    echo "Claude Code: merged $CLAUDE_SETTINGS"
    echo "Claude doc: $CLAUDE_DOCS (link from CLAUDE.md if you want always-on)"
  fi
  [[ "$NOTIFY" == 1 ]] && install_notify
  echo "Installed to $INSTALL_DIR"
  echo "Config: $CONFIG_FILE"
  echo "Test: gh-pr-roster-json | jq '.options[0]'"
  echo "Restart Cursor and/or Claude Code."
}

main "$@"