#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${GH_PR_ASSIGN_ROOT:-$HOME/.local/share/gh-pr-assign-harness}"
CURSOR_HOOKS="$HOME/.cursor/hooks.json"
CURSOR_RULES="$HOME/.cursor/rules"
CONFIG_DIR="$HOME/.config/gh"
CONFIG_FILE="$CONFIG_DIR/pr-default-assignees.json"
BIN_DIR="$HOME/.local/bin"
MARKER="# gh-pr-assign-harness"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

install_tree() {
  mkdir -p "$INSTALL_DIR"
  rsync -a --delete \
    --exclude .git \
    --exclude README.md \
    "$SRC/" "$INSTALL_DIR/"
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
  if [[ -f "$INSTALL_DIR/ui/pr-assignees-ui.py" ]]; then
    ln -sf "$INSTALL_DIR/ui/pr-assignees-ui.py" "$CONFIG_DIR/pr-assignees-ui.py"
  fi
}

merge_cursor_hooks() {
  mkdir -p "$(dirname "$CURSOR_HOOKS")"
  python3 "$INSTALL_DIR/scripts/merge_cursor_hooks.py" \
    "$INSTALL_DIR/cursor/hooks.fragment.json" \
    "$CURSOR_HOOKS" \
    "$INSTALL_DIR" \
    "${1:-install}"
}

install_rule() {
  mkdir -p "$CURSOR_RULES"
  cp "$INSTALL_DIR/cursor/rules/gh-pr-default-assignees.mdc" "$CURSOR_RULES/"
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
  launchctl bootstrap "gui/$(id -u)" "$target" 2>/dev/null || launchctl load -w "$target" 2>/dev/null || true
}

uninstall() {
  merge_cursor_hooks uninstall
  rm -f "$BIN_DIR/gh-pr-create" "$BIN_DIR/gh-pr-roster-json" "$BIN_DIR/gh-pr-assignees-ui"
  rm -f "$CURSOR_RULES/gh-pr-default-assignees.mdc"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    launchctl bootout "gui/$(id -u)/com.gh-pr-assign-harness.notify" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.gh-pr-assign-harness.notify.plist"
  fi
  echo "Removed harness hooks and bin links. Config left at $CONFIG_FILE"
}

main() {
  NOTIFY=0
  case "${1:-}" in
    --uninstall) uninstall; exit 0 ;;
    --notify) NOTIFY=1 ;;
  esac
  install_tree
  link_bins
  install_config
  merge_cursor_hooks install
  install_rule
  if [[ "$NOTIFY" == 1 ]]; then
    install_notify
  fi
  echo "Installed to $INSTALL_DIR"
  echo "Restart Cursor. Config: $CONFIG_FILE"
  echo "Roster: gh-pr-roster-json | jq .options"
}

main "$@"