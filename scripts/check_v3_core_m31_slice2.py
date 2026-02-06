#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd")


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    if not TARGET.exists():
        return fail(f"missing file: {TARGET}")

    text = TARGET.read_text(encoding="utf-8")

    if "func dialog_accept" not in text or "func dialog_dismiss" not in text:
        return fail("missing dialog methods")

    if "unsupported: dialog interception is not implemented yet" in text:
        return fail("dialog methods still marked unsupported")

    if "__gwry_dialog" not in text:
        return fail("dialog hook marker __gwry_dialog not found")

    resize_match = re.search(r"func\s+resize\s*\([^\)]*\)\s*->\s*int:\n([\s\S]*?)(?:\nfunc\s+|\Z)", text)
    if not resize_match:
        return fail("resize method body not found")

    resize_body = resize_match.group(1)
    if "_browser.set_view_rect" not in resize_body:
        return fail("resize does not call _browser.set_view_rect")
    if "_browser.start_view" not in resize_body and "_start_view_mode" not in resize_body:
        return fail("resize does not use start_view path")

    print("PASS: M3.1 slice2 dialog/resize semantics detected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
