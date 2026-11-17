#!/usr/bin/env python3
"""Merge gh-pr-assign-harness hooks into ~/.claude/settings.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HOOK_EVENTS = ("SessionStart", "PreToolUse", "PostToolUse")


def load(path: Path) -> dict:
    if path.exists():
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    return {}


def subst(fragment: dict, install_dir: str) -> dict:
    return json.loads(json.dumps(fragment).replace("@INSTALL_DIR@", install_dir))


def merge_event_simple(existing: list, incoming: list, install_dir: str) -> list:
    out = [
        g
        for g in existing
        if not any(install_dir in (x.get("command") or "") for x in g.get("hooks", []))
    ]
    out.extend(incoming)
    return out


def main() -> None:
    if len(sys.argv) != 5:
        print(
            "usage: merge_claude_settings.py fragment settings.json install_dir install|uninstall",
            file=sys.stderr,
        )
        sys.exit(2)
    fragment_path, settings_path, install_dir, mode = sys.argv[1:5]
    fragment = subst(json.loads(Path(fragment_path).read_text(encoding="utf-8")), install_dir)
    target = Path(settings_path)
    doc = load(target)
    doc.setdefault("hooks", {})

    if mode == "uninstall":
        for key in HOOK_EVENTS:
            if key in doc["hooks"]:
                doc["hooks"][key] = [
                    g
                    for g in doc["hooks"][key]
                    if not any(install_dir in (x.get("command") or "") for x in g.get("hooks", []))
                ]
    else:
        for key in HOOK_EVENTS:
            incoming = fragment.get(key, [])
            if not incoming:
                continue
            doc["hooks"][key] = merge_event_simple(doc["hooks"].get(key, []), incoming, install_dir)

    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()