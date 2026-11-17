#!/usr/bin/env python3
"""Merge gh-pr-assign-harness hook fragment into ~/.cursor/hooks.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HOOK_KEYS = (
    "sessionStart",
    "beforeShellExecution",
    "afterShellExecution",
)


def load_json(path: Path) -> dict:
    if path.exists():
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    return {"version": 1, "hooks": {}}


def subst_hooks(fragment: dict, install_dir: str) -> dict:
    raw = json.dumps(fragment)
    raw = raw.replace("@INSTALL_DIR@", install_dir)
    return json.loads(raw)


def hook_id(entry: dict) -> str:
    return entry.get("command", "")


def merge_lists(existing: list, incoming: list) -> list:
    ids = {hook_id(e) for e in existing}
    out = list(existing)
    for e in incoming:
        cmd = hook_id(e)
        if cmd in ids:
            out = [x if hook_id(x) != cmd else e for x in out]
        else:
            out.append(e)
    return out


def remove_harness(entries: list, install_dir: str) -> list:
    prefix = f"{install_dir}/hooks/"
    return [e for e in entries if not str(e.get("command", "")).startswith(prefix)]


def main() -> None:
    if len(sys.argv) != 5:
        print("usage: merge_cursor_hooks.py fragment hooks.json install_dir install|uninstall", file=sys.stderr)
        sys.exit(2)
    fragment_path, hooks_path, install_dir, mode = sys.argv[1:5]
    fragment = subst_hooks(json.loads(Path(fragment_path).read_text(encoding="utf-8")), install_dir)
    target = Path(hooks_path)
    doc = load_json(target)
    doc.setdefault("hooks", {})
    frag_hooks = fragment.get("hooks", {})

    if mode == "uninstall":
        for key in HOOK_KEYS:
            if key in doc["hooks"]:
                doc["hooks"][key] = remove_harness(doc["hooks"][key], install_dir)
        if not doc["hooks"]:
            doc["hooks"] = {}
    else:
        for key in HOOK_KEYS:
            incoming = frag_hooks.get(key, [])
            if not incoming:
                continue
            doc["hooks"][key] = merge_lists(doc["hooks"].get(key, []), incoming)

    doc.setdefault("version", 1)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()