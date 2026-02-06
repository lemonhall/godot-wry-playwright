# v2 Index: 3D “texture simulated render” (Windows-first)

## 0) Snapshot

- Date: 2026-02-06
- Goal: add a 3D-friendly mode that captures WebView frames and feeds them into a Godot texture/material.
- PRD: `docs/prd/2026-02-05-godot-wry-playwright.md`

## 1) Milestones

| Milestone | Scope | DoD (binary) | Verification | Status |
|---|---|---|---|---|
| M2 | Texture mode MVP (Windows) | A 3D demo shows a captured WebView texture on a 3D screen surface | `docs/plan/v2-texture-mode.md` verification steps | doing |
| M2.1 | Computer model integration + controls | Model moved to `assets/models`, monitor overlay in scene, camera controls + key `5` reload implemented | `docs/plan/v2-computer-scene-integration.md` verification steps | doing |

## 2) Plan Index

- `docs/plan/v2-texture-mode.md`
- `docs/plan/v2-computer-scene-integration.md`

## 3) Traceability matrix

| Req ID | v2 plan item | tests/commands | Evidence | Key paths | Status |
|---|---|---|---|---|---|
| REQ-011 | `docs/plan/v2-texture-mode.md` | Rust tests + Windows Godot demo | Rust/build evidence recorded; Godot manual pending | `crates/godot_wry_playwright/**`, `godot-wry-playwright/demo/texture_3d.*` | doing |
| REQ-012 | `docs/plan/v2-computer-scene-integration.md` | `python3 scripts/check_texture3d_scene_requirements.py` + Godot scene run | static check pass; Godot manual pending | `godot-wry-playwright/assets/models/computer/**`, `godot-wry-playwright/demo/texture_3d.tscn` | doing |
| REQ-013 | `docs/plan/v2-computer-scene-integration.md` | static scene structure check + Godot scene run | static check pass; Godot manual pending | `godot-wry-playwright/demo/texture_3d.tscn`, `godot-wry-playwright/demo/texture_3d.gd` | doing |
| REQ-014 | `docs/plan/v2-computer-scene-integration.md` | script static checks + manual input run | static check pass; manual input pending | `godot-wry-playwright/demo/texture_3d.gd` | doing |
| REQ-015 | `docs/plan/v2-computer-scene-integration.md` | key `5` static check + manual reload run | static check pass; manual reload pending | `godot-wry-playwright/demo/texture_3d.gd`, `crates/godot_wry_playwright/src/wry_texture_browser.rs` | doing |
| REQ-016 | `docs/plan/v2-computer-scene-integration.md` | static script-injection check + manual scene run | pending | `crates/godot_wry_playwright/src/wry_texture_browser.rs` | doing |

## 4) Review notes

- This mode is explicitly a “simulated render”: it is not a real-time GPU embedded browser.
- Windows-first; other platforms may need different capture APIs or will remain unsupported.
- Current loop evidence: `python3 scripts/check_texture3d_scene_requirements.py` and Rust tests are green; latest DLL was rebuilt via offline cargo and copied to addon bin.
