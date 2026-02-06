# v1 Index: godot-wry-playwright (Windows MVP first)

## 0) Snapshot

- Date: 2026-02-06
- Goal: deliver a Windows desktop MVP for a Godot 4.6 plugin that exposes a Playwright-like automation subset via `wry`.
- PRD: `docs/prd/2026-02-05-godot-wry-playwright.md`

## 1) Milestones

| Milestone | Scope | DoD (binary) | Verification | Status |
|---|---|---|---|---|
| M0 | Docs locked (PRD + v1 plan) | `doc_hygiene_check.py --strict` returns OK | `python3 /home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py --root . --strict` | done |
| M1 | Windows MVP | Demo can `goto/click/fill/wait/eval` against a public page and return results to GDScript | v1 plan commands in `docs/plan/v1-windows-mvp.md` | todo |

## 2) Plan Index

- `docs/plan/v1-windows-mvp.md`

## 3) Known gaps (carry to v2)

- REQ-008 (Android) deferred to v2+
- REQ-009 (navigation allowlist) deferred to v2 unless needed earlier
- macOS/Linux platform work deferred to v2+
- Rendering the WebView into a Godot texture/mesh (still out of scope)

## 4) Traceability matrix

| Req ID | v1 plan item | tests/commands | Evidence | Key paths | Status |
|---|---|---|---|---|---|
| REQ-001 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A (not implemented in this slice) | `addons/godot_wry_playwright/**` | todo |
| REQ-002 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A | `addons/godot_wry_playwright/**` | todo |
| REQ-003 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A | Windows backend files | todo |
| REQ-004 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A | command protocol | todo |
| REQ-005 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A | JS shim | todo |
| REQ-006 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A | IPC envelope | todo |
| REQ-007 | `docs/plan/v1-windows-mvp.md` | (see v1 plan) | N/A | logging | todo |
| REQ-008 | deferred | N/A | N/A | Android backend | deferred |
| REQ-009 | deferred | N/A | N/A | navigation handler | deferred |
| REQ-010 | `docs/plan/v1-windows-mvp.md` | Windows Godot demo scenes | N/A | `godot-wry-playwright/demo/ui_view_*.tscn` | todo |

## 5) PRD Trace (Doc hygiene gate)

PRD Trace: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-009, REQ-010

## 6) Review notes (v1 vs PRD)

- This v1 slice only locks requirements and a verifiable plan. Implementation begins at milestone M1.
