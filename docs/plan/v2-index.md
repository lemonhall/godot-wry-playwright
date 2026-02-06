# v2 Index: 3D “texture simulated render” (Windows-first)

## 0) Snapshot

- Date: 2026-02-06
- Goal: add a 3D-friendly mode that captures WebView frames and feeds them into a Godot texture/material.
- PRD: `docs/prd/2026-02-05-godot-wry-playwright.md`

## 1) Milestones

| Milestone | Scope | DoD (binary) | Verification | Status |
|---|---|---|---|---|
| M2 | Texture mode MVP (Windows) | A 3D demo shows a live-updating WebView texture on a cube face | `docs/plan/v2-texture-mode.md` verification steps | todo |

## 2) Plan Index

- `docs/plan/v2-texture-mode.md`

## 3) Traceability matrix

| Req ID | v2 plan item | tests/commands | Evidence | Key paths | Status |
|---|---|---|---|---|---|
| REQ-011 | `docs/plan/v2-texture-mode.md` | Windows Godot demo | N/A | `crates/godot_wry_playwright/**`, `godot-wry-playwright/demo/texture_3d.*` | todo |

## 4) Review notes

- This mode is explicitly a “simulated render”: it is not a real-time GPU embedded browser.
- Windows-first; other platforms may need different capture APIs or will remain unsupported.
