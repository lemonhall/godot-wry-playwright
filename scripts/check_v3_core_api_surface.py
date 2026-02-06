#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

SESSION_PATH = Path("godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd")

REQUIRED_METHODS = [
    "open",
    "close",
    "type_text",
    "click",
    "dblclick",
    "fill",
    "drag",
    "hover",
    "select",
    "upload",
    "check",
    "uncheck",
    "snapshot",
    "eval",
    "dialog_accept",
    "dialog_dismiss",
    "resize",
    "go_back",
    "go_forward",
    "reload",
    "press",
    "keydown",
    "keyup",
    "mouse_move",
    "mouse_down",
    "mouse_up",
    "mouse_wheel",
]


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    if not SESSION_PATH.exists():
        return fail(f"missing session API file: {SESSION_PATH}")

    text = SESSION_PATH.read_text(encoding="utf-8")

    if "class_name WryPwSession" not in text:
        return fail("missing class_name WryPwSession")

    if "signal completed(" not in text:
        return fail("missing completed signal")

    missing_methods: list[str] = []
    for method_name in REQUIRED_METHODS:
        pattern = rf"^func\s+{re.escape(method_name)}\s*\("
        if not re.search(pattern, text, flags=re.MULTILINE):
            missing_methods.append(method_name)

    if missing_methods:
        print("FAIL: missing required methods:")
        for method_name in missing_methods:
            print(f"  - {method_name}")
        return 1

    print(f"PASS: v3 core API surface exists ({len(REQUIRED_METHODS)} methods)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
