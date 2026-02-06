#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

SESSION = Path("godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd")
CATALOG = Path("docs/plan/v3-cli-command-catalog.md")

M31_COMMANDS = {
    "open",
    "close",
    "type",
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
    "dialog-accept",
    "dialog-dismiss",
    "resize",
    "go-back",
    "go-forward",
    "reload",
    "press",
    "keydown",
    "keyup",
    "mousemove",
    "mousedown",
    "mouseup",
    "mousewheel",
}

ALLOWED_M31_STATUS = {
    "implemented_gdscript",
    "implemented_gdscript_best_effort",
}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def extract_m31_statuses(catalog_text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in catalog_text.splitlines():
        line = raw.strip()
        if not line.startswith("| `"):
            continue
        parts = [p.strip() for p in line.split("|")[1:-1]]
        if len(parts) < 6:
            continue

        cli_cmd = parts[0].strip("`")
        phase = parts[4].strip("`")
        status = parts[5].strip("`")

        if phase != "M3.1":
            continue
        result[cli_cmd] = status
    return result


def main() -> int:
    if not SESSION.exists():
        return fail(f"missing file: {SESSION}")
    if not CATALOG.exists():
        return fail(f"missing file: {CATALOG}")

    session_text = SESSION.read_text(encoding="utf-8")
    catalog_text = CATALOG.read_text(encoding="utf-8")

    required_markers = [
        "class_name WryPwSession",
        "func _on_browser_completed(",
        "func _save_snapshot_to_file(",
        "func _file_to_upload_entry(",
        "func _set_dialog_mode(",
        "func resize(",
        "_browser.set_view_rect",
        "_start_view_mode",
        "window.__gwry_dialog",
        "DataTransfer",
        "_snapshot_save_map",
        "Marshalls.raw_to_base64",
    ]

    for marker in required_markers:
        if marker not in session_text:
            return fail(f"missing marker in session contract: {marker}")

    forbidden_markers = [
        "unsupported: dialog interception is not implemented yet",
        "unsupported: resize is not implemented yet",
        "unsupported: upload requires native file chooser bridge",
        "unsupported: snapshot --filename is not implemented yet",
    ]
    for marker in forbidden_markers:
        if marker in session_text:
            return fail(f"legacy unsupported marker still present: {marker}")

    expected_errors = [
        "start_error",
        "start_view_error",
        "resize_requires_view_mode",
        "upload_empty",
        "upload_target_not_file_input",
        "upload_datatransfer_unavailable",
        "snapshot_filename_empty",
    ]
    for code in expected_errors:
        if code not in session_text:
            return fail(f"missing error code marker: {code}")

    statuses = extract_m31_statuses(catalog_text)

    missing_commands = sorted(M31_COMMANDS - set(statuses.keys()))
    if missing_commands:
        print("FAIL: missing M3.1 commands in catalog status table:")
        for cmd in missing_commands:
            print(f"  - {cmd}")
        return 1

    bad_status: list[tuple[str, str]] = []
    for cmd in sorted(M31_COMMANDS):
        st = statuses.get(cmd, "")
        if st not in ALLOWED_M31_STATUS:
            bad_status.append((cmd, st))

    if bad_status:
        print("FAIL: invalid M3.1 status values (expected implemented_*)")
        for cmd, st in bad_status:
            print(f"  - {cmd}: {st}")
        return 1

    print("PASS: M3.1 behavior contract is consistent (session semantics + catalog status)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
