# v2: Computer model scene integration + camera + reload key (Windows-first)

## Goal

Upgrade `res://demo/texture_3d.tscn` from a synthetic box demo to a computer-model demo where the captured webpage is shown on the monitor area, camera controls are game-like, and key `5` triggers a reload-and-refresh cycle.

## PRD Trace

PRD Trace: REQ-012, REQ-013, REQ-014, REQ-015

## Scope

### In scope

- Move model assets from project root to `res://assets/models/computer/` and update scene references.
- Integrate the computer model into `texture_3d.tscn` as the main visible object.
- Attach webpage texture to a dedicated “screen overlay quad” placed at monitor front area.
- Add camera controls in `texture_3d.gd`:
  - wheel zoom
  - RMB orbit
  - MMB pan
- Add key `5` action (`reload_page`) and logic to reload URL and refresh one frame.

### Out of scope

- Accurate mesh/UV editing in DCC tool (Blender) for perfect native monitor UV mapping.
- Click-through interaction mapping from 3D screen to DOM coordinates.
- Multi-key customizable input settings UI.

## Acceptance (binary)

- A1 (REQ-012): `res://Computer.glb` is no longer used by demo scene; scene uses `res://assets/models/computer/Computer.glb`.
- A2 (REQ-013): in `res://demo/texture_3d.tscn`, webpage appears on monitor-facing overlay quad attached to computer model.
- A3 (REQ-014): running scene supports RMB orbit, MMB pan, mouse wheel zoom with no script errors.
- A4 (REQ-015): pressing key `5` reloads current URL (`https://example.com`) and screen gets a newly refreshed frame.
- A5: per-load capture policy stays deterministic: exactly one displayed frame per navigation cycle unless user triggers reload key again.

## Verification

### Doc gate

- `python3 /home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py --root . --strict`

### Rust

- `CARGO_HOME=/tmp/cargo-home cargo test -p godot_wry_playwright_core`
- `CARGO_HOME=/tmp/cargo-home cargo test -p godot_wry_playwright --test pending_requests_test`

### Build

- `bash scripts/build_windows_wsl.sh`

### Godot (Windows manual)

- Open `godot-wry-playwright/`
- Run `res://demo/texture_3d.tscn`
- Verify:
  - monitor shows webpage image (not side wall panel)
  - RMB rotates, MMB pans, wheel zooms
  - press `5` and observe one new refresh cycle + frame update logs

## Files

- Move: `godot-wry-playwright/Computer.glb` → `godot-wry-playwright/assets/models/computer/Computer.glb`
- Move: `godot-wry-playwright/Computer.glb.import` → `godot-wry-playwright/assets/models/computer/Computer.glb.import`
- Move: `godot-wry-playwright/Computer_Computer Texture.png` → `godot-wry-playwright/assets/models/computer/Computer_Computer Texture.png`
- Move: `godot-wry-playwright/Computer_Computer Texture.png.import` → `godot-wry-playwright/assets/models/computer/Computer_Computer Texture.png.import`
- Modify: `godot-wry-playwright/demo/texture_3d.tscn`
- Modify: `godot-wry-playwright/demo/texture_3d.gd`
- Modify: `docs/plan/v2-index.md`
- Modify: `docs/plan/v2-texture-mode.md`

## Risks

- R1: Overlay quad placement may need iterative offset tuning due to source model scale/pivot.
- R2: Camera input may conflict with editor shortcut expectations if action names overlap.
- R3: Reload may start capture too early if navigation-state reset is missing.

## Steps (Tashan + TDD)

1) Red: add static checks ensuring scene references moved model path and reload action.
2) Green: move model files and update scene references.
3) Red: add static checks for camera-control variables and input handling branches.
4) Green: implement orbit/pan/zoom controls in `texture_3d.gd`.
5) Red: add static check for key `5` reload branch and per-cycle frame-freeze reset.
6) Green: implement reload logic and first-frame-per-load behavior.
7) Refactor: clean constants/naming and keep behavior unchanged.
8) Verify: run doc gate + Rust tests + Windows DLL build.
