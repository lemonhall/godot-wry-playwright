# v4 Index: Addon 单一入口统一与 Legacy 退役

## 0) Snapshot

- Date: 2026-02-06
- Goal: 让 addon 对外只保留 `WryPwSession`，并把三个 canonical demo 迁移到统一入口。
- PRD: `docs/prd/2026-02-06-addon-surface-unification.md`

## 1) 设计选项

### Option A: 保留多入口，仅补文档说明

- 优点：改动小。
- 缺点：根因未解，用户与测试仍分叉。

### Option B（Recommended）: 单一公开入口 + 分层实现

- `WryPwSession` 作为唯一对外 API。
- 内部可按驱动模式调用 `WryBrowser` / `WryTextureBrowser`，但不暴露给业务层。
- 优点：接口稳定、测试集中、迁移成本可控。

### Option C: 新增 façade，旧入口长期共存

- 优点：短期兼容强。
- 缺点：会形成双轨维护，长期更乱。

## 2) Milestones

| Milestone | Scope | DoD (binary) | Verification | Status |
|---|---|---|---|---|
| M4.0 | 文档基线（PRD + v4 拆分计划） | doc gate PASS | `python3 C:\Users\lemon\.codex\skills\tashan-development-loop\scripts\doc_hygiene_check.py --root . --strict` | done |
| M4.1 | 单一入口架构落地 | demo 代码不再直接依赖 `WryBrowser/WryTextureBrowser/WryView` | `python scripts/check_v4_single_surface_usage.py` | todo |
| M4.2 | 三 demo 迁移 + runtime 套件 | `headeless/2d/3d` 迁移测试 PASS | `scripts/run_godot_tests.ps1 -Suite demo_migration_v4` | todo |
| M4.3 | legacy 退役与门禁 | `wry_view.gd` 无 demo 引用 + 退役策略生效 | `python scripts/check_v4_legacy_surface_refs.py` | todo |
| M4.4 | 文档/指南收敛 | README/README.zh-CN/AGENTS 与代码一致 | doc gate + grep checks | todo |

## 3) Plan Index

- `docs/plan/v4-single-surface-architecture.md`
- `docs/plan/v4-demo-migration-runtime.md`
- `docs/plan/v4-legacy-deprecation-gates.md`

## 4) Traceability Matrix

| Req ID | v4 plan item | tests/commands | Evidence target | Status |
|---|---|---|---|---|
| REQ-201 | `v4-single-surface-architecture.md` | `check_v4_single_surface_usage.py` | no legacy direct usage in demos/tests | todo |
| REQ-202 | `v4-demo-migration-runtime.md` | `run_godot_tests.ps1 -Suite demo_migration_v4` | three demos runtime pass | todo |
| REQ-203 | `v4-legacy-deprecation-gates.md` | `check_v4_legacy_surface_refs.py` | no demo references to `wry_view.gd` | todo |
| REQ-204 | `v4-demo-migration-runtime.md` | `check_v4_runtime_coverage.py` + Godot suites | migrated APIs runtime-covered | todo |
| REQ-205 | `v4-demo-migration-runtime.md` | `check_texture3d_scene_requirements.py` | 3D baseline preserved | todo |
| REQ-206 | `v4-legacy-deprecation-gates.md` | doc gate + README/AGENTS grep | docs aligned with single surface | todo |
| REQ-207 | `v4-index.md` | milestone verification commands | no fake done claims | doing |

## 5) Gap Review (start)

- 当前 gap：`2d_demo` 依赖 `WryView`，`headeless_demo` 依赖 `WryBrowser`，`3d_demo` 依赖 `WryTextureBrowser`。
- 目标状态：三 demo 都通过 `WryPwSession` 使用同一 API 语义；内部驱动差异仅在 session 内部实现。
- 迁移风险：2D/3D 视图与纹理启动参数需要在 `WryPwSession` 新增统一配置入口。

