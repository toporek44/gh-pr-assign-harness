# Multi-harness install

| Harness | Config merged into | Agent instructions |
|---------|-------------------|-------------------|
| **Cursor** | `~/.cursor/hooks.json` | `~/.cursor/rules/gh-pr-default-assignees.mdc` |
| **Claude Code** | `~/.claude/settings.json` → `hooks` | `~/.claude/PR-ASSIGN-harness.md` |

Shared install root: `~/.local/share/gh-pr-assign-harness`

## Commands

```bash
./install.sh              # both harnesses
./install.sh --cursor-only
./install.sh --claude-only
./install.sh --notify      # + macOS assign alerts
./install.sh --uninstall
```

## Claude Code plugin (optional)

Copy repo path into a marketplace or run install.sh — hooks use absolute paths under `GH_PR_ASSIGN_ROOT`.

For project-scoped Claude hooks, merge `claude/hooks.fragment.json` into `.claude/settings.json` in the repo and set `command` paths to a team install dir or use `$HOME/.local/share/gh-pr-assign-harness/...`.

## Cursor project hooks

Commit `cursor/hooks.fragment.json` paths only if your team shares one install dir; otherwise document `install.sh` in repo README.