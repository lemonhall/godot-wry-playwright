# v4 Plan: Demo Migration + Runtime Evidence

## Goal

将 `headeless/2d/3d/agent_playwright` 全部收敛到 `WryPwSession`，并为迁移能力提供可重复 runtime 证据。

## PRD Trace

- REQ-202
- REQ-204
- REQ-205
- REQ-207

## Scope

- 迁移 `headeless_demo.gd` 到 session API。
- 迁移 `2d_demo.gd/.tscn`，移除 `wry_view.gd` 依赖。
- 迁移 `3d_demo.gd` 到 session 驱动（含 `frame_png`）。
- 迁移 `agent_playwright.gd` 到 session 单路径（移除 `tool_driver_mode` 双分支）。
- 维护 `demo_migration_v4` runtime suite，覆盖三个 canonical demo。
- 维护 `agent_playwright` runtime suite，覆盖 browser tools 与 chat flow。

## Acceptance

- A1: demo 脚本中无 `WryBrowser.new()` / `WryTextureBrowser.new()` / `WryView`。
- A2: `scripts/run_godot_tests.ps1 -Suite demo_migration_v4` PASS。
- A3: `scripts/run_godot_tests.ps1 -Suite agent_playwright` PASS。
- A4: `python scripts/check_v4_runtime_coverage.py` PASS。
- A5: `python scripts/check_texture3d_scene_requirements.py` PASS。

## Verification

- `scripts/run_godot_tests.ps1 -Suite demo_migration_v4`
- `scripts/run_godot_tests.ps1 -Suite agent_playwright`
- `python scripts/check_v4_runtime_coverage.py`
- `python scripts/check_texture3d_scene_requirements.py`

## Steps

1) Red: 先让 migration coverage 在 legacy 状态下 fail。
2) Green: 迁移 `headeless/2d/3d` 到 session。
3) Green: 迁移 `agent_playwright` 到 session 单路径。
4) Refactor: 清理测试中 legacy 参数（如 `tool_driver_mode`）。

## Risks

- 3D texture 刷新节奏（fps/reload）在 session 化后可能漂移。
- agent 场景 tool call 链路若等待策略变化，可能引发间歇性超时。

