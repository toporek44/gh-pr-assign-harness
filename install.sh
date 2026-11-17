#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DIR="${GH_PR_ASSIGN_ROOT:-$HOME/.local/share/gh-pr-assign-harness}"
# Never install from a broken copy under $DIR — use the git clone that contains this script.
if [[ "$(cd "$(dirname "$0")" && pwd)" == "$DIR" ]] && [[ "$(wc -l <"$DIR/harness.sh" 2>/dev/null || echo 0)" -lt 20 ]]; then
  echo "Run: git clone ... && cd gh-pr-assign-harness && ./install.sh" >&2
  exit 1
fi
BIN="$HOME/.local/bin"
CFG="$HOME/.config/gh/pr-default-assignees.json"
CURSOR="$HOME/.cursor/hooks.json"
CLAUDE="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
H="$DIR/harness.sh"

usage() { echo "Usage: ./install.sh | --uninstall | --cursor-only | --claude-only"; }

install_files() {
  mkdir -p "$DIR" "$BIN"
  for f in harness.sh install.sh config.example.json README.md; do
    [[ -f "$SRC/$f" ]] || continue
    if [[ "$f" == *.sh ]]; then install -m 755 "$SRC/$f" "$DIR/$f"
    else install -m 644 "$SRC/$f" "$DIR/$f"; fi
  done
  H="$DIR/harness.sh"
  lines=$(wc -l <"$H" | tr -d ' ')
  if (( lines < 20 )); then
    echo "install: $H looks broken ($lines lines). Run install from git clone, not from \$DIR." >&2
    exit 1
  fi
  rm -f "$BIN/gh-pr-roster-json" "$BIN/gh-pr-create"
  cat >"$BIN/gh-pr-roster-json" <<EOF
#!/usr/bin/env bash
exec "$H" roster
EOF
  cat >"$BIN/gh-pr-create" <<EOF
#!/usr/bin/env bash
exec "$H" create "\$@"
EOF
  chmod +x "$BIN/gh-pr-roster-json" "$BIN/gh-pr-create"
  mkdir -p "$(dirname "$CFG")"
  [[ -f "$CFG" ]] || cp "$SRC/config.example.json" "$CFG"
}

merge_cursor() {
  local mode="${1:-install}"
  python3 - "$H" "$CURSOR" "$mode" <<'PY'
import json, sys
h, path, mode = sys.argv[1:4]
def cmd(mode):
    return f"env HARNESS=cursor HOOK_MODE={mode} {h} hook"
frag = {
  "sessionStart": [{"command": cmd("session"), "timeout": 5}],
  "beforeShellExecution": [{"command": cmd("ask"), "matcher": "gh\\s+pr\\s+create", "timeout": 15}],
  "afterShellExecution": [{"command": cmd("after"), "matcher": "gh\\s+pr\\s+create", "timeout": 45}],
}
doc = {"version": 1, "hooks": {}}
try:
    with open(path) as f:
        doc = json.load(f)
except FileNotFoundError:
    pass
doc.setdefault("hooks", {})
for k, inc in frag.items():
    ex = doc["hooks"].get(k, [])
    ex = [e for e in ex if h not in (e.get("command") or "")]
    if mode != "uninstall":
        ex.extend(inc)
    doc["hooks"][k] = ex
with open(path, "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
}

merge_claude() {
  local mode="${1:-install}"
  python3 - "$H" "$CLAUDE" "$mode" <<'PY'
import json, sys
h, path, mode = sys.argv[1:4]
def chook(mode):
    return {"type": "command", "command": f"env HARNESS=claude HOOK_MODE={mode} {h} hook", "timeout": 20}
frag = {
    "SessionStart": [{"matcher": "^(startup|resume|clear|compact|fork)$", "hooks": [chook("session")]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [chook("ask")]}],
    "PostToolUse": [{"matcher": "Bash", "hooks": [chook("after")]}],
}
doc = {}
try:
    with open(path) as f:
        doc = json.load(f)
except FileNotFoundError:
    pass
doc.setdefault("hooks", {})
for k, inc in frag.items():
    ex = doc["hooks"].get(k, [])
    ex = [g for g in ex if not any(h in (x.get("command") or "") for x in g.get("hooks", []))]
    if mode != "uninstall":
        ex.extend(inc)
    doc["hooks"][k] = ex
with open(path, "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
}

PR_ASSIGN_RULE='Before `gh pr create`: run `gh-pr-roster-json`. **AskQuestion** (multi): one choice per every `options[]` row (same `id` + `label`) — list all teammates; never subset or skip. Then `--assignee` per login (`__use_defaults__` / chat defaults = default_assignees only). Config: `~/.config/gh/pr-default-assignees.json`.'

install_rule() {
  mkdir -p "$HOME/.cursor/rules"
  cat >"$HOME/.cursor/rules/gh-pr-default-assignees.mdc" <<MDC
---
description: PR assignees via gh-pr-assign-harness
alwaysApply: true
---
$PR_ASSIGN_RULE
MDC
}

install_claude_doc() {
  mkdir -p "$HOME/.claude"
  cat >"$HOME/.claude/PR-ASSIGN-harness.md" <<MD
# PR assignees (gh-pr-assign-harness)

$PR_ASSIGN_RULE

Roster CLI: \`gh-pr-roster-json\` (fields: \`options\`, \`option_count\`, \`ask_rule\`).

Claude: **AskUserQuestion** multi-select — same rule: every \`options[]\` entry, no subset.

Hooks: PreToolUse asks before create; PostToolUse backfills if \`--assignee\` missing.
MD
}

case "${1:-}" in
  --uninstall)
    merge_cursor uninstall
    merge_claude uninstall
    rm -f "$BIN/gh-pr-roster-json" "$BIN/gh-pr-create" "$HOME/.cursor/rules/gh-pr-default-assignees.mdc" "$HOME/.claude/PR-ASSIGN-harness.md"
    echo "Uninstalled hooks. Config: $CFG"
    exit 0
    ;;
  --cursor-only) install_files; merge_cursor install; install_rule; echo "Cursor OK → $DIR"; exit 0 ;;
  --claude-only) install_files; merge_claude install; install_claude_doc; echo "Claude OK → $DIR"; exit 0 ;;
  -h|--help) usage; exit 0 ;;
esac

install_files
merge_cursor install
merge_claude install
install_rule
install_claude_doc
echo "Installed $DIR (5-file harness). Config: $CFG"
echo "Restart Cursor + Claude Code."