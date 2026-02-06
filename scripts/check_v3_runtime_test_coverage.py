#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SESSION_PATH = Path("godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd")
CATALOG_PATH = Path("docs/plan/v3-cli-command-catalog.md")
TESTS_ROOT = Path("godot-wry-playwright/tests")
TEST_GLOB = "test_wry_pw_session*_runtime.gd"

IMPLEMENTED_PHASES = {"M3.1", "M3.2"}
IMPLEMENTED_STATUS = {
    "implemented_gdscript",
    "implemented_gdscript_best_effort",
}

SESSION_FUNC_RE = re.compile(r"^func\s+([A-Za-z0-9_]+)\s*\(", re.MULTILINE)
SESSION_CALL_RE = re.compile(r"\bvar\s+([A-Za-z0-9_]+)\s*=\s*session\.([A-Za-z0-9_]+)\s*\(")
REQUIRE_RE = re.compile(r"\bT\.(require_[A-Za-z0-9_]+)\(")
NEXT_CALL_RE = re.compile(r"^\s*var\s+[A-Za-z0-9_]+\s*=\s*session\.[A-Za-z0-9_]+\s*\(")


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def parse_catalog_implemented_session_methods(catalog_text: str) -> list[str]:
    methods: set[str] = set()

    for raw in catalog_text.splitlines():
        line = raw.strip()
        if not line.startswith("| `"):
            continue

        parts = [cell.strip() for cell in line.split("|")[1:-1]]
        if len(parts) < 6:
            continue

        addon_api = parts[2].strip("`")
        phase = parts[4].strip("`")
        status = parts[5].strip("`")

        if phase not in IMPLEMENTED_PHASES:
            continue
        if status not in IMPLEMENTED_STATUS:
            continue
        if not addon_api.startswith("session."):
            continue

        method = addon_api.split(".", 1)[1].strip()
        if method:
            methods.add(method)

    return sorted(methods)


def parse_session_public_methods(session_text: str) -> list[str]:
    methods: set[str] = set()
    for match in SESSION_FUNC_RE.finditer(session_text):
        method = match.group(1)
        if method.startswith("_"):
            continue
        methods.add(method)
    return sorted(methods)


def inspect_call_block(lines: list[str], start_index: int, request_id_var: str) -> tuple[bool, dict[str, object]]:
    wait_re = re.compile(
        rf"\bvar\s+([A-Za-z0-9_]+)\s*=\s*await\s+T\.wait_for_completed\(self,\s*pending,\s*{re.escape(request_id_var)}\s*\)"
    )

    wait_index = -1
    response_var = ""
    for index in range(start_index + 1, min(len(lines), start_index + 25)):
        wait_match = wait_re.search(lines[index])
        if wait_match:
            wait_index = index
            response_var = wait_match.group(1)
            break

    if wait_index < 0:
        return False, {"reason": "missing wait_for_completed"}

    next_call_index = len(lines)
    for index in range(wait_index + 1, min(len(lines), wait_index + 80)):
        if NEXT_CALL_RE.search(lines[index]):
            next_call_index = index
            break

    block = lines[wait_index + 1 : next_call_index]
    if not block:
        return False, {"reason": "missing assertion block", "response_var": response_var}

    assertion_names: list[str] = []
    for line in block:
        for match in REQUIRE_RE.finditer(line):
            assertion_names.append(match.group(1))

    if not assertion_names:
        return False, {"reason": "missing T.require_* assertion", "response_var": response_var}

    response_used = any(response_var in line for line in block)
    if not response_used:
        return False, {
            "reason": "response variable not used in assertion block",
            "response_var": response_var,
            "assertions": assertion_names,
        }

    return True, {
        "response_var": response_var,
        "assertions": sorted(set(assertion_names)),
    }


def collect_coverage(runtime_test_file: Path) -> tuple[dict[str, list[dict[str, object]]], list[str]]:
    text = runtime_test_file.read_text(encoding="utf-8")
    lines = text.splitlines()

    by_method: dict[str, list[dict[str, object]]] = {}
    diagnostics: list[str] = []

    for line_index, line in enumerate(lines):
        call_match = SESSION_CALL_RE.search(line)
        if not call_match:
            continue

        request_id_var = call_match.group(1)
        method = call_match.group(2)
        ok, detail = inspect_call_block(lines, line_index, request_id_var)
        if not ok:
            diagnostics.append(
                f"{runtime_test_file.as_posix()}:{line_index + 1} session.{method} -> {detail.get('reason', 'unknown')}"
            )
            continue

        item = {
            "test": runtime_test_file.as_posix(),
            "line": line_index + 1,
            "request_var": request_id_var,
            "response_var": detail.get("response_var", ""),
            "assertions": detail.get("assertions", []),
        }
        by_method.setdefault(method, []).append(item)

    return by_method, diagnostics


def build_matrix(
    catalog_methods: list[str],
    coverage: dict[str, list[dict[str, object]]],
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for method in sorted(catalog_methods):
        hits = coverage.get(method, [])
        rows.append(
            {
                "method": method,
                "covered": bool(hits),
                "hit_count": len(hits),
                "hits": hits,
            }
        )
    return rows


def matrix_to_markdown(matrix: list[dict[str, object]]) -> str:
    lines = [
        "# v3 Runtime Coverage Matrix (M3.1/M3.2 Session APIs)",
        "",
        "| Method | Covered | Hit Count | Test Locations |",
        "|---|---|---:|---|",
    ]

    for row in matrix:
        method = str(row["method"])
        covered = "yes" if bool(row["covered"]) else "no"
        hit_count = int(row["hit_count"])
        locations = [
            f"`{item['test']}:{item['line']}`"
            for item in row.get("hits", [])
        ]
        location_cell = "<br>".join(locations) if locations else "-"
        lines.append(f"| `{method}` | {covered} | {hit_count} | {location_cell} |")

    covered_count = sum(1 for row in matrix if row["covered"])
    lines.extend(
        [
            "",
            f"Summary: covered `{covered_count}/{len(matrix)}` implemented session methods.",
        ]
    )

    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Gate + report for v3 runtime coverage: "
            "every implemented M3.1/M3.2 session API must be covered by runtime tests."
        )
    )
    parser.add_argument(
        "--report-md",
        default="",
        help="Write coverage matrix markdown report to this path.",
    )
    parser.add_argument(
        "--report-json",
        default="",
        help="Write raw coverage matrix JSON report to this path.",
    )
    parser.add_argument(
        "--print-matrix",
        action="store_true",
        help="Print concise matrix summary to stdout.",
    )
    return parser.parse_args()


def write_optional_reports(
    matrix: list[dict[str, object]],
    diagnostics: list[str],
    args: argparse.Namespace,
) -> None:
    if args.report_md:
        out_path = Path(args.report_md)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(matrix_to_markdown(matrix), encoding="utf-8")
        print(f"WROTE: {out_path.as_posix()}")

    if args.report_json:
        out_path = Path(args.report_json)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "implemented_phases": sorted(IMPLEMENTED_PHASES),
            "implemented_status": sorted(IMPLEMENTED_STATUS),
            "matrix": matrix,
            "diagnostics": diagnostics,
        }
        out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"WROTE: {out_path.as_posix()}")


def print_matrix_summary(matrix: list[dict[str, object]]) -> None:
    print("\nCoverage Matrix Summary")
    for row in matrix:
        covered = "yes" if bool(row["covered"]) else "no"
        print(f" - {row['method']}: {covered} (hits={row['hit_count']})")


def main() -> int:
    args = parse_args()

    if not SESSION_PATH.exists():
        return fail(f"missing session file: {SESSION_PATH}")
    if not CATALOG_PATH.exists():
        return fail(f"missing catalog file: {CATALOG_PATH}")
    if not TESTS_ROOT.exists():
        return fail(f"missing tests root: {TESTS_ROOT}")

    session_text = SESSION_PATH.read_text(encoding="utf-8")
    catalog_text = CATALOG_PATH.read_text(encoding="utf-8")

    session_methods = parse_session_public_methods(session_text)
    if not session_methods:
        return fail("no public methods found in WryPwSession")

    catalog_methods = parse_catalog_implemented_session_methods(catalog_text)
    if not catalog_methods:
        return fail("no implemented M3.1/M3.2 session methods found in catalog")

    missing_in_session = sorted(set(catalog_methods) - set(session_methods))
    if missing_in_session:
        print("FAIL: catalog marks methods as implemented but session API is missing them:")
        for method in missing_in_session:
            print(f"  - {method}")
        return 1

    extra_public_methods = sorted(set(session_methods) - set(catalog_methods))
    if extra_public_methods:
        print("FAIL: session has public methods not marked implemented in M3.1/M3.2 catalog:")
        for method in extra_public_methods:
            print(f"  - {method}")
        return 1

    runtime_tests = sorted(TESTS_ROOT.glob(TEST_GLOB))
    if not runtime_tests:
        return fail(f"no runtime tests matched pattern: {TESTS_ROOT / TEST_GLOB}")

    merged_coverage: dict[str, list[dict[str, object]]] = {}
    diagnostics: list[str] = []
    for runtime_test_file in runtime_tests:
        coverage, issues = collect_coverage(runtime_test_file)
        diagnostics.extend(issues)
        for method, items in coverage.items():
            merged_coverage.setdefault(method, []).extend(items)

    matrix = build_matrix(catalog_methods, merged_coverage)
    write_optional_reports(matrix, diagnostics, args)

    if args.print_matrix:
        print_matrix_summary(matrix)

    covered_methods = {row["method"] for row in matrix if bool(row["covered"])}
    missing_runtime_coverage = sorted(set(catalog_methods) - covered_methods)
    if missing_runtime_coverage:
        print("FAIL: implemented v3 session methods without verified runtime coverage:")
        for method in missing_runtime_coverage:
            print(f"  - {method}")
        if diagnostics:
            print("\nDiagnostics (unverified call sites):")
            for item in diagnostics:
                print(f"  - {item}")
        return 1

    print(
        "PASS: v3 implemented session methods have runtime test coverage "
        f"({len(covered_methods)}/{len(catalog_methods)} methods; tests={len(runtime_tests)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
