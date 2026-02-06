#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


SCAN_ROOTS = [
    Path("godot-wry-playwright/demo"),
    Path("godot-wry-playwright/tests"),
]

LEGACY_PATTERNS = {
    "WryView": "legacy class reference",
    "wry_view.gd": "legacy script path reference",
}


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    for root in SCAN_ROOTS:
        if not root.exists():
            return fail(f"missing scan root: {root.as_posix()}")

    violations: list[str] = []
    for root in SCAN_ROOTS:
        for path in sorted(root.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix.lower() not in {".gd", ".tscn"}:
                continue

            text = path.read_text(encoding="utf-8")
            for idx, line in enumerate(text.splitlines(), start=1):
                for pattern, reason in LEGACY_PATTERNS.items():
                    if pattern in line:
                        violations.append(f"{path.as_posix()}:{idx}: {reason} [{pattern}]")

    if violations:
        print("FAIL: v4 legacy-surface gate detected references in demo/tests:")
        for item in violations:
            print(f"  - {item}")
        return 1

    print("PASS: v4 legacy-surface gate (demo/tests) has no WryView references")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

