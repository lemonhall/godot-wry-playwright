# PRD: Addon 单一对外暴露与 Legacy Surface 退役（v4）

## 0) 元信息
- Topic: addon surface unification
- Owner: godot-wry-playwright
- Status: active
- Version: v4 baseline
- Last updated: 2026-02-06
- Input context:
  - `godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd`
  - `godot-wry-playwright/demo/headeless_demo.gd`
  - `godot-wry-playwright/demo/2d_demo.gd`
  - `godot-wry-playwright/demo/3d_demo.gd`
  - `godot-wry-playwright/demo/agent_playwright.gd`

## 1) 愿景

建立明确、可测试、可迁移的插件外部接口：

- 插件对业务脚本只保留一个公开入口：`WryPwSession`。
- canonical demos（`headeless/2d/3d`）与 `agent_playwright` 全部收敛到同一入口语义。
- `wry_view.gd` 与旧直连路径彻底退役并从仓库移除。
- 每个迁移能力必须有 runtime 测试证据，而不只是静态检查。

## 2) 问题陈述

历史上仓库存在多套并行入口（`WryBrowser` / `WryTextureBrowser` / `WryView`），导致：

- 用户和维护者无法快速判断“应该用哪个类”。
- 文档、测试、代码口径分裂，迁移成本高。
- agent 场景与 demo 场景存在实现分叉，影响后续演进。

## 3) 范围

### In Scope

- 锁定 `WryPwSession` 为唯一公开入口。
- `WryPwSession` 提供统一启动语义（headless / view / texture）。
- 迁移 `headeless/2d/3d/agent_playwright` 到 `WryPwSession`。
- 删除 `wry_view.gd` 与 `wry_view.gd.uid`。
- 新增门禁：禁止 demo/tests 再新增 `WryView` / `WryBrowser.new()` / `WryTextureBrowser.new()`。

### Out of Scope

- 不包含 v3 M3.3 的 network/devtools/runtime manager 功能实现。
- 不包含跨平台（macOS/Linux/Android/iOS）语义扩展；本轮仍以 Windows 验证为主。

## 4) 术语

- **Single Public Surface**: 业务脚本只依赖 `WryPwSession`。
- **Legacy Surface**: `WryView` 或 demo 中直接构造 `WryBrowser/WryTextureBrowser`。
- **Runtime Evidence**: 通过 `scripts/run_godot_tests.ps1` 执行的 `test_*.gd` 可重复结果。

## 5) 需求（Req IDs）

| Req ID | Requirement | Acceptance (binary) | Verification | Priority | Risk |
|---|---|---|---|---|---|
| REQ-201 | 对外仅保留 `WryPwSession` 作为公开入口 | demo/tests/docs 中不再出现 legacy 入口调用 | `python scripts/check_v4_single_surface_usage.py` | P0 | 旧示例残留 |
| REQ-202 | 四个目标场景迁移到 `WryPwSession` | `headeless/2d/3d/agent_playwright` 均可运行并完成最小交互 | `scripts/run_godot_tests.ps1 -Suite demo_migration_v4` + `-Suite agent_playwright` | P0 | 2D/3D 启动语义差异 |
| REQ-203 | `wry_view.gd` 完全退役 | `wry_view.gd` / `.uid` 不存在且无引用 | `python scripts/check_v4_legacy_surface_refs.py` | P0 | 外部旧项目兼容成本 |
| REQ-204 | 迁移能力必须有 runtime 测试 | 每个迁移 API 至少一条 runtime 断言 | `python scripts/check_v4_runtime_coverage.py` + Godot suites | P0 | 只做静态门禁 |
| REQ-205 | 3D demo 迁移后不回退 | texture 场景基础能力保持可验证 | `python scripts/check_texture3d_scene_requirements.py` | P1 | 视觉/交互回退 |
| REQ-206 | AGENTS/README 双语同步 | 文档仅描述 `WryPwSession` 对外入口 + legacy 已移除 | doc gate + grep | P1 | 文档漂移 |
| REQ-207 | 禁止“假完成”声明 | 每个里程碑含可执行验证命令与状态 | doc gate + milestone checks | P0 | 虚假里程碑 |

## 6) 约束

- 不允许“新增 facade 同时长期保留旧入口并继续扩散”。
- 不允许只改 README 不改测试。
- 不允许把“场景可打开”当作迁移完成；必须有行为断言。

## 7) 非目标

- 本轮不处理 Playwright CLI 的 M3.3 完整实现。
- 本轮不新增 demo 类型，只统一现有目标场景的入口语义。

## 8) 追踪入口

- v4 index: `docs/plan/v4-index.md`
- 架构计划: `docs/plan/v4-single-surface-architecture.md`
- demo 迁移计划: `docs/plan/v4-demo-migration-runtime.md`
- legacy 退役计划: `docs/plan/v4-legacy-deprecation-gates.md`

