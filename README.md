# gh-pr-assign-harness

Five files. In-chat assignee picker + Cursor / Claude hooks. No UI.

https://git.dev.box.net/mtopor/gh-pr-assign-harness

<img width="671" height="172" alt="image" src="https://git.dev.box.net/user-attachments/assets/1f6fb1e4-6c65-4abb-a7ad-0120c8a71fa4" />

<img width="1062" height="439" alt="image" src="https://git.dev.box.net/user-attachments/assets/62bb92bf-4bfd-45b3-884f-3a090ef09def" />


## Install

```bash
git clone git@git.dev.box.net:mtopor/gh-pr-assign-harness.git
cd gh-pr-assign-harness && ./install.sh
```

| File | Role |
|------|------|
| `harness.sh` | roster, `gh-pr-create`, all hooks |
| `install.sh` | merge into Cursor + Claude settings |
| `config.example.json` | seed `~/.config/gh/pr-default-assignees.json` |

## Flow

1. `gh-pr-roster-json` → **AskQuestion** (Cursor) or **AskUserQuestion** (Claude): every `options[]` row (`option_count`), never a subset (`__use_defaults__` first).
2. `gh pr create` with `--assignee` each.
3. Hooks: ask before create (backup), add defaults after if no `--assignee`.

## Config

Edit `~/.config/gh/pr-default-assignees.json`: `default_assignees`, `teammates`, `default_gh_host`.

## Flags

`--cursor-only` · `--claude-only` · `--uninstall`
