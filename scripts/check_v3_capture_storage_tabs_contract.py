#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

SESSION = Path("godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd")
CATALOG = Path("docs/plan/v3-cli-command-catalog.md")

M32_METHODS = {
    "screenshot",
    "pdf",
    "tab_list",
    "tab_new",
    "tab_close",
    "tab_select",
    "state_save",
    "state_load",
    "cookie_list",
    "cookie_get",
    "cookie_set",
    "cookie_delete",
    "cookie_clear",
    "localstorage_list",
    "localstorage_get",
    "localstorage_set",
    "localstorage_delete",
    "localstorage_clear",
    "sessionstorage_list",
    "sessionstorage_get",
    "sessionstorage_set",
    "sessionstorage_delete",
    "sessionstorage_clear",
}

M32_COMMANDS = {
    "screenshot",
    "pdf",
    "tab-list",
    "tab-new",
    "tab-close",
    "tab-select",
    "state-save",
    "state-load",
    "cookie-list",
    "cookie-get",
    "cookie-set",
    "cookie-delete",
    "cookie-clear",
    "localstorage-list",
    "localstorage-get",
    "localstorage-set",
    "localstorage-delete",
    "localstorage-clear",
    "sessionstorage-list",
    "sessionstorage-get",
    "sessionstorage-set",
    "sessionstorage-delete",
    "sessionstorage-clear",
}

ALLOWED_M32_STATUS = {
    "implemented_gdscript",
    "implemented_gdscript_best_effort",
}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def extract_m32_statuses(catalog_text: str) -> dict[str, str]:
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

        if phase != "M3.2":
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

    missing_methods: list[str] = []
    for method_name in sorted(M32_METHODS):
        pattern = rf"^func\s+{re.escape(method_name)}\s*\("
        if not re.search(pattern, session_text, flags=re.MULTILINE):
            missing_methods.append(method_name)

    if missing_methods:
        print("FAIL: missing M3.2 methods in session API:")
        for method_name in missing_methods:
            print(f"  - {method_name}")
        return 1

    required_markers = [
        "_normalize_output_path",
        "func state_save(",
        "func state_load(",
        "func cookie_list(",
        "func localstorage_list(",
        "func sessionstorage_list(",
    ]
    for marker in required_markers:
        if marker not in session_text:
            return fail(f"missing marker in session file: {marker}")

    status_map = extract_m32_statuses(catalog_text)

    missing_commands = sorted(M32_COMMANDS - set(status_map.keys()))
    if missing_commands:
        print("FAIL: missing M3.2 commands in catalog:")
        for command_name in missing_commands:
            print(f"  - {command_name}")
        return 1

    bad_status: list[tuple[str, str]] = []
    for command_name in sorted(M32_COMMANDS):
        status = status_map.get(command_name, "")
        if status not in ALLOWED_M32_STATUS:
            bad_status.append((command_name, status))

    if bad_status:
        print("FAIL: invalid M3.2 catalog status values:")
        for command_name, status in bad_status:
            print(f"  - {command_name}: {status}")
        return 1

    print("PASS: M3.2 capture/storage/tabs contract is consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
