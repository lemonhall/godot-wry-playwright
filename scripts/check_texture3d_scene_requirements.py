#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TS_CN = ROOT / "godot-wry-playwright/demo/3d_demo.tscn"
TS_GD = ROOT / "godot-wry-playwright/demo/3d_demo.gd"
MODEL_GLB = ROOT / "godot-wry-playwright/assets/models/computer/Computer.glb"
WTB_RS = ROOT / "crates/godot_wry_playwright/src/wry_texture_browser.rs"
DEMO_DIR = ROOT / "godot-wry-playwright/demo"


def fail(msg: str) -> None:
    print(f"FAIL: {msg}")
    sys.exit(1)


def ok(msg: str) -> None:
    print(f"OK: {msg}")


def expect(path: Path, pattern: str, what: str) -> None:
    data = path.read_text(encoding="utf-8")
    if not re.search(pattern, data, flags=re.MULTILINE):
        fail(f"{what} missing in {path}")
    ok(what)


def main() -> int:
    canonical_demo_scenes = [
        DEMO_DIR / "headeless_demo.tscn",
        DEMO_DIR / "2d_demo.tscn",
        DEMO_DIR / "3d_demo.tscn",
    ]
    for scene in canonical_demo_scenes:
        if not scene.exists():
            fail(f"canonical demo scene missing: {scene}")
    ok("three canonical demo scenes exist")

    obsolete_demo_entries = [
        "ui_view_3d.gd",
        "ui_view_3d.gd.uid",
        "ui_view_3d.tscn",
        "visible_2d.gd",
        "visible_2d.gd.uid",
        "visible_2d.tscn",
        "visible_3d.gd",
        "visible_3d.gd.uid",
        "visible_3d.tscn",
    ]
    for name in obsolete_demo_entries:
        p = DEMO_DIR / name
        if p.exists():
            fail(f"obsolete demo file still exists: {p}")
    ok("obsolete demo files removed")

    if not MODEL_GLB.exists():
        fail(f"moved model missing: {MODEL_GLB}")
    ok("moved model exists")

    if (ROOT / "godot-wry-playwright/Computer.glb").exists():
        fail("legacy root model still exists at godot-wry-playwright/Computer.glb")
    ok("legacy root model removed")

    expect(TS_CN, r"path=\"res://assets/models/computer/Computer\.glb\"", "scene references moved GLB")
    expect(TS_CN, r"\[node name=\"WebScreen\" type=\"MeshInstance3D\" parent=\"ComputerRoot\"[^\]]*\]", "web screen overlay node exists")

    expect(TS_GD, r"func _unhandled_input\(event: InputEvent\)", "camera input handler exists")
    expect(TS_GD, r"event\.is_action_pressed\(\"reload_page\"\)", "reload action branch exists")
    expect(TS_GD, r"KEY_5", "key 5 fallback exists")
    expect(TS_GD, r"_begin_navigation_cycle\(\)", "navigation cycle reset hook exists")

    expect(WTB_RS, r"applyTextureFitWidth", "fit-width JS helper exists")
    expect(WTB_RS, r"overflowX\s*=\s*'hidden'", "fit-width script hides horizontal overflow")

    print("PASS: 3d_demo static requirements satisfied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
