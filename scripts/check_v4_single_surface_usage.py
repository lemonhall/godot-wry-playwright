#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


TARGET_FILES = [
    Path("godot-wry-playwright/demo/headeless_demo.gd"),
    Path("godot-wry-playwright/demo/2d_demo.gd"),
    Path("godot-wry-playwright/demo/3d_demo.gd"),
    Path("godot-wry-playwright/demo/agent_playwright.gd"),
    Path("godot-wry-playwright/demo/2d_demo.tscn"),
]

FORBIDDEN_MARKERS = {
    "WryBrowser.new(": "legacy direct browser constructor",
    "WryTextureBrowser.new(": "legacy direct texture constructor",
    "WryView": "legacy WryView surface reference",
    "wry_view.gd": "legacy WryView script binding",
}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    missing = [p.as_posix() for p in TARGET_FILES if not p.exists()]
    if missing:
        return fail(f"missing target files: {', '.join(missing)}")

    violations: list[str] = []
    for path in TARGET_FILES:
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        for idx, line in enumerate(lines, start=1):
            for marker, reason in FORBIDDEN_MARKERS.items():
                if marker in line:
                    violations.append(f"{path.as_posix()}:{idx}: {reason} [{marker}]")

    if violations:
        print("FAIL: v4 single-surface usage gate detected legacy references:")
        for item in violations:
            print(f"  - {item}")
        return 1

    print("PASS: v4 single-surface usage gate (canonical demos) has no legacy surface references")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
