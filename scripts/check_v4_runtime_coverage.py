#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


REQUIRED_TESTS = [
    Path("godot-wry-playwright/tests/test_demo_migration_v4_headless_runtime.gd"),
    Path("godot-wry-playwright/tests/test_demo_migration_v4_2d_runtime.gd"),
    Path("godot-wry-playwright/tests/test_demo_migration_v4_3d_runtime.gd"),
]

REQUIRED_MARKERS = {
    "test_demo_migration_v4_headless_runtime.gd": ["WryPwSession", "T.require_ok_response", "session.open"],
    "test_demo_migration_v4_2d_runtime.gd": ["WryPwSession", "T.require_ok_response", "session.open"],
    "test_demo_migration_v4_3d_runtime.gd": ["WryPwSession", "T.require_ok_response", "session.open"],
}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    missing = [path.as_posix() for path in REQUIRED_TESTS if not path.exists()]
    if missing:
        return fail(f"missing v4 runtime tests: {', '.join(missing)}")

    violations: list[str] = []
    for path in REQUIRED_TESTS:
        text = path.read_text(encoding="utf-8")
        markers = REQUIRED_MARKERS[path.name]
        for marker in markers:
            if marker not in text:
                violations.append(f"{path.as_posix()}: missing marker '{marker}'")

    if violations:
        print("FAIL: v4 runtime coverage gate detected incomplete runtime assertions:")
        for item in violations:
            print(f"  - {item}")
        return 1

    print("PASS: v4 runtime coverage gate (demo migration) found required runtime tests and markers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

