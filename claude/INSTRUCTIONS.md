# PR assignees (gh-pr-assign-harness)

Config: `~/.config/gh/pr-default-assignees.json` · Roster: `gh-pr-roster-json`

Before `gh pr create`:

1. Run `gh-pr-roster-json`.
2. Use **AskUserQuestion** (multi-select) with `options` from roster, or accept chat `defaults` / `yes`.
3. First option `__use_defaults__` = default assignees only.
4. Run `gh pr create` with `--assignee <login>` for each pick (never `__use_defaults__` on CLI).

Hooks: PreToolUse asks before create; PostToolUse backfills if `--assignee` missing.