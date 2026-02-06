# v2: Demo canonicalization (3-scene naming lock)

## Goal

Lock the project demo surface to exactly three canonical scenes with explicit, self-explanatory names.

## PRD Trace

PRD Trace: REQ-010, REQ-011, REQ-012, REQ-013, REQ-014, REQ-015, REQ-016

## Canonical demos (locked)

- `res://demo/headeless_demo.tscn` — headless-ish automation mode
- `res://demo/2d_demo.tscn` — native child-window visible mode (2D UI)
- `res://demo/3d_demo.tscn` — 3D texture mode (computer monitor, camera controls, key `5` reload)

## Rules

- No parallel duplicate demos for the same mode.
- Any future demo additions must either:
  - replace one canonical scene, or
  - be marked temporary and removed in the same milestone.

## URL baseline

- Canonical default URL for current demos: `https://www.baidu.com/`

## Verification

- `python3 scripts/check_texture3d_scene_requirements.py`
- `python3 /home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py --root . --strict`
