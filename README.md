# gh-pr-assign-harness

Portable hooks for **Cursor** and **Claude Code**: in-chat assignee picker, `gh` wrappers, optional macOS notifications.

## Install

```bash
git clone git@git.dev.box.net:mtopor/gh-pr-assign-harness.git
cd gh-pr-assign-harness
./install.sh
```

Installs **both** harnesses by default. See `harness/README.md` for flags.

- Files: `~/.local/share/gh-pr-assign-harness`
- Config: `~/.config/gh/pr-default-assignees.json` (from `config/*.example` on first run)
- Box profile hints: `profiles/mtopor-box.json`

Mirror: [github.com/toporek44/gh-pr-assign-harness](https://github.com/toporek44/gh-pr-assign-harness)

Restart **Cursor** and **Claude Code** after install.

## Behavior

1. Agent runs `gh-pr-roster-json` → **AskQuestion** / AskUserQuestion (defaults first, `__use_defaults__` one-tap).
2. **Pre** hook asks before `gh pr create` if agent skipped chat.
3. **Post** hook adds default assignees when create had no `--assignee`.

## Binaries

| Command | Role |
|---------|------|
| `gh-pr-roster-json` | Picker JSON for agents |
| `gh-pr-create` | `gh pr create` + config assignees |
| `gh-pr-assignees-ui` | Optional roster editor (macOS) |

## Customize

Edit config or `gh-pr-assignees-ui`. Fields: `default_assignees`, `teammates`, `default_gh_host`, `agent_ask_before_pr_create`.

## Uninstall

```bash
./install.sh --uninstall
```

Config JSON is kept.