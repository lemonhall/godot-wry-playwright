#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

TARGET = Path("godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd")


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    if not TARGET.exists():
        return fail(f"missing file: {TARGET}")

    text = TARGET.read_text(encoding="utf-8")

    if "unsupported: upload requires native file chooser bridge" in text:
        return fail("upload is still marked unsupported")

    if "unsupported: snapshot --filename is not implemented yet" in text:
        return fail("snapshot filename is still marked unsupported")

    required_markers = [
        "func _save_snapshot_to_file",
        "func _mime_from_extension",
        "func _file_to_upload_entry",
        "_snapshot_save_map",
    ]

    for marker in required_markers:
        if marker not in text:
            return fail(f"missing marker: {marker}")

    if "Marshalls.raw_to_base64" not in text:
        return fail("upload path does not encode file bytes with Marshalls.raw_to_base64")

    print("PASS: M3.1 slice3 upload/snapshot semantics detected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
