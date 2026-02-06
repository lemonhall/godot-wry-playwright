#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


def normalize_cell(s: str) -> str:
    return s.strip().strip("`")


def extract_cli_commands(cli_doc: Path) -> list[str]:
    commands: list[str] = []
    seen: set[str] = set()

    for raw in cli_doc.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line.startswith("playwright-cli "):
            continue

        parts = line.split()
        if len(parts) < 2:
            continue

        if parts[1].startswith("-s=name"):
            if len(parts) < 3:
                continue
            cmd = f"-s=name {parts[2]}"
        else:
            cmd = parts[1]

        if cmd not in seen:
            commands.append(cmd)
            seen.add(cmd)

    return commands


def extract_catalog_commands(catalog: Path) -> tuple[dict[str, str], list[str]]:
    mapping: dict[str, str] = {}
    duplicates: list[str] = []

    for raw in catalog.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not (line.startswith("|") and line.endswith("|")):
            continue

        cells = [c.strip() for c in line.split("|")[1:-1]]
        if len(cells) < 3:
            continue

        first = normalize_cell(cells[0]).lower()
        if first in {"cli command", "---", ":---", ""}:
            continue
        if re.fullmatch(r"[-: ]+", first):
            continue

        cmd = normalize_cell(cells[0])
        addon_api = normalize_cell(cells[2])

        if cmd in mapping:
            duplicates.append(cmd)
            continue
        mapping[cmd] = addon_api

    return mapping, duplicates


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Playwright CLI command coverage in command catalog markdown.")
    parser.add_argument("--cli-doc", default="playwright-cli.md", help="Path to playwright CLI reference markdown")
    parser.add_argument("--catalog", default="docs/plan/v3-cli-command-catalog.md", help="Path to catalog markdown")
    args = parser.parse_args()

    cli_doc = Path(args.cli_doc)
    catalog = Path(args.catalog)

    if not cli_doc.exists():
        print(f"FAIL: CLI doc not found: {cli_doc}")
        return 1
    if not catalog.exists():
        print(f"FAIL: catalog not found: {catalog}")
        return 1

    cli_commands = extract_cli_commands(cli_doc)
    catalog_map, duplicate_command_rows = extract_catalog_commands(catalog)

    cli_set = set(cli_commands)
    catalog_set = set(catalog_map.keys())

    missing = [cmd for cmd in cli_commands if cmd not in catalog_set]
    extra = [cmd for cmd in sorted(catalog_set) if cmd not in cli_set]
    empty_api = [cmd for cmd, api in catalog_map.items() if api in {"", "TBD", "TODO"}]

    api_to_cmds: dict[str, list[str]] = {}
    for cmd, api in catalog_map.items():
        api_to_cmds.setdefault(api, []).append(cmd)
    duplicate_api_mappings = {api: cmds for api, cmds in api_to_cmds.items() if len(cmds) > 1}

    ok = True

    if duplicate_command_rows:
        ok = False
        print("FAIL: duplicate command rows in catalog:")
        for cmd in duplicate_command_rows:
            print(f"  - {cmd}")

    if missing:
        ok = False
        print("FAIL: commands missing in catalog:")
        for cmd in missing:
            print(f"  - {cmd}")

    if extra:
        ok = False
        print("FAIL: catalog has commands not present in CLI doc:")
        for cmd in extra:
            print(f"  - {cmd}")

    if empty_api:
        ok = False
        print("FAIL: commands without mapped addon API:")
        for cmd in sorted(empty_api):
            print(f"  - {cmd}")

    if duplicate_api_mappings:
        ok = False
        print("FAIL: multiple CLI commands map to the same addon API:")
        for api, cmds in sorted(duplicate_api_mappings.items()):
            joined = ", ".join(sorted(cmds))
            print(f"  - {api}: {joined}")

    print(f"CLI commands: {len(cli_commands)}")
    print(f"Catalog rows: {len(catalog_map)}")

    if not ok:
        return 1

    print("PASS: command catalog fully covers playwright-cli.md with unique non-empty API mapping")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
