# gh-pr-assign-harness

Portable **Cursor harness** hooks for PR assignees: in-chat teammate picker (defaults first), `gh` wrappers, and optional macOS assign notifications.

## Install (one command)

```bash
git clone https://github.com/mtopor/gh-pr-assign-harness.git
cd gh-pr-assign-harness
./install.sh
```

Restart Cursor after install.

Install location: `~/.local/share/gh-pr-assign-harness` (override with `GH_PR_ASSIGN_ROOT`).

## What you get

| Piece | Purpose |
|--------|---------|
| `gh-pr-roster-json` | JSON for agent `AskQuestion` (defaults + team list) |
| `gh-pr-create` | `gh pr create` with default assignees |
| `gh-pr-assignees-ui` | Optional desktop editor for config (macOS system Python) |
| Cursor hooks | session context, assign backfill, optional shell gate |
| Cursor rule | Agent asks in chat before PR create |

Config: `~/.config/gh/pr-default-assignees.json` (created from `config/pr-default-assignees.json.example` on first install).

## Harness hook (Cursor)

`install.sh` merges `cursor/hooks.fragment.json` into `~/.cursor/hooks.json` without removing your other hooks.

Manual merge: copy paths from the fragment and point at `$GH_PR_ASSIGN_ROOT/hooks/...`.

## Agent flow

1. User asks to open a PR.
2. Agent runs `gh-pr-roster-json`, shows `AskQuestion` (`allow_multiple: true`).
3. First option: **Use defaults only** (`__use_defaults__`).
4. Teammates below; defaults listed first with `(Recommended — default)`.
5. User can reply `defaults` / `yes` in chat instead of the form.
6. Agent runs `gh pr create` with `--assignee` for each login.

## Customize

- Edit JSON or run `gh-pr-assignees-ui`.
- `teammates`: picker roster (`login` + `name`).
- `default_assignees`: default assignees and picker order at top.
- `shell_ask_before_pr_create`: `false` by default (stay in chat).

## Optional: assigned-to-you notifications (macOS)

```bash
./install.sh --notify
```

Loads LaunchAgent `optional/launchd/gh-assignment-notify.plist` (5-minute poll).

## Uninstall

```bash
./install.sh --uninstall
```

Removes merged hook entries and symlinks under `~/.local/bin`; does not delete your config JSON.

## Requirements

- `gh`, `jq`, `bash`
- Cursor with user hooks (`~/.cursor/hooks.json`)