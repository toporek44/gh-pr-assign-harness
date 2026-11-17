# Cursor harness integration

This repo is a **drop-in Cursor user hook pack**.

## Install

```bash
./install.sh
```

`install.sh`:

1. Copies files to `~/.local/share/gh-pr-assign-harness`
2. Symlinks `bin/*` into `~/.local/bin`
3. Merges `cursor/hooks.fragment.json` into `~/.cursor/hooks.json` (idempotent)
4. Installs `cursor/rules/gh-pr-default-assignees.mdc`
5. Seeds `~/.config/gh/pr-default-assignees.json` from example if missing

## Hook fragment

See `cursor/hooks.fragment.json`. Paths use `@INSTALL_DIR@` replaced at install time.

Events:

| Hook | Script |
|------|--------|
| `sessionStart` | inject roster + AskQuestion instructions |
| `beforeShellExecution` | optional shell gate (`shell_ask_before_pr_create`) |
| `afterShellExecution` | backfill assignees when create had no `--assignee` |

## Herdr / other harnesses

No Herdr daemon required — this is **Cursor agent + gh CLI** only.

Point teammates at the same repo + `install.sh`. Share one `pr-default-assignees.json.example` pattern; each person keeps private config under `~/.config/gh/`.