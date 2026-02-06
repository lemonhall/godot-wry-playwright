# v4 Plan: Canonical Demo Migration + Runtime Evidence

## Goal

将三套 canonical demo（`headeless/2d/3d`）统一迁移到 `WryPwSession` 接口，并为每个迁移点提供运行时测试证据。

## PRD Trace

- REQ-202
- REQ-204
- REQ-205
- REQ-207

## Scope

- 迁移 `headeless_demo.gd` 到 session API。
- 迁移 `2d_demo.gd/.tscn`，移除 `wry_view.gd` 直接绑定。
- 迁移 `3d_demo.gd` 到 session 驱动（内部可继续调用 texture backend，但对 demo 只暴露 session）。
- 新增 `demo_migration_v4` runtime suite，覆盖三 demo 的最小可用行为。

## Acceptance

- A1: 三 demo 脚本中均不存在 `WryBrowser.new()` / `WryTextureBrowser.new()` / `WryView`。
- A2: `scripts/run_godot_tests.ps1 -Suite demo_migration_v4` PASS。
- A3: `python scripts/check_texture3d_scene_requirements.py` PASS（迁移后 3D 基线不回退）。
- A4: `python scripts/check_v4_runtime_coverage.py` PASS（迁移 API 有 runtime 断言）。

## Verification

- `scripts/run_godot_tests.ps1 -Suite demo_migration_v4`
- `python scripts/check_v4_runtime_coverage.py`
- `python scripts/check_texture3d_scene_requirements.py`

## Steps

1) Red: 新增 `demo_migration_v4` 测试与 coverage 脚本，确认现状 fail。
2) Green: 逐个迁移 headeless/2d/3d demo 到 session。
3) Green: 运行 suite 与覆盖脚本到 PASS。
4) Refactor: 合并 demo 公共调用辅助，降低脚本重复。

## Risks

- 3D demo 纹理更新节奏（fps/reload）在 session 化后可能行为漂移。
- 2D demo 控件绑定改造可能影响可视区域定位。

