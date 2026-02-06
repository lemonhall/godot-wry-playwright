# PRD: Addon 单一对外暴露与 Legacy Surface 退役（v4）

## 0) 元信息

- Topic: addon surface unification
- Owner: godot-wry-playwright
- Status: draft
- Version: v4 planning baseline
- Last updated: 2026-02-06
- Input context:
  - `godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd`
  - `godot-wry-playwright/addons/godot_wry_playwright/wry_view.gd`
  - `godot-wry-playwright/demo/headeless_demo.gd`
  - `godot-wry-playwright/demo/2d_demo.gd`
  - `godot-wry-playwright/demo/3d_demo.gd`

## 1) 愿景

建立一个明确、可测试、可迁移的插件外部接口：

- 插件对业务脚本只保留一个公开入口（`WryPwSession`）。
- 三个 canonical demo（headeless/2d/3d）全部迁移到同一入口语义。
- `wry_view.gd` 与旧直连类路径进入弃用流程，最终退役。
- 每个迁移后的能力都必须有运行时测试证据，而不是仅靠静态检查。

## 2) 问题陈述

当前仓库存在多套并行入口：

- `headeless_demo` 直接使用 `WryBrowser`。
- `2d_demo` 使用 `WryView` 包装层。
- `3d_demo` 直接使用 `WryTextureBrowser`。

后果：

- 用户无法快速判断“应该用哪个类”。
- 测试与文档口径分散，迁移成本高。
- Agent 场景与 legacy demo 的实现路径割裂，影响后续演进。

## 3) 范围

### In Scope

- 定义并锁定单一公开入口：`WryPwSession`。
- 为 `WryPwSession` 补齐三种 demo 所需模式的统一调用语义（headless/2d view/3d texture）。
- 迁移三套 legacy demo 到 `WryPwSession`。
- 把 `wry_view.gd` 标记为 deprecated，并在 v4 结束时完成退役策略（删除或仅保留失败提示壳）。
- 新增门禁：禁止 demo/tests 再新增 `WryView` / `WryBrowser` / `WryTextureBrowser` 的直接依赖。

### Out of Scope

- 不包含 v3 M3.3 的 network/devtools/runtime manager 功能实现。
- 不包含跨平台（macOS/Linux/Android/iOS）语义扩展；仍以 Windows 为主验证面。

## 4) 术语

- **Single Public Surface**: 业务脚本只依赖一个 addon 类（`WryPwSession`）。
- **Legacy Surface**: `WryView`、demo 里直接使用 `WryBrowser` / `WryTextureBrowser` 的写法。
- **Runtime Evidence**: `scripts/run_godot_tests.ps1` 可重复执行并通过的 `test_*.gd` 结果。

## 5) 需求（Req IDs）

| Req ID | Requirement | Acceptance (binary) | Verification | Priority | Risk |
|---|---|---|---|---|---|
| REQ-201 | 对外只保留 `WryPwSession` 作为公开入口 | demo/tests/docs 不再出现 legacy 入口调用 | `python scripts/check_v4_single_surface_usage.py` | P0 | 旧示例残留 |
| REQ-202 | 三个 canonical demo 全部迁移到 `WryPwSession` | `headeless/2d/3d` 三场景均可运行并完成最小交互 | `scripts/run_godot_tests.ps1 -Suite demo_migration_v4` | P0 | 2D/3D 模式语义差异 |
| REQ-203 | `wry_view.gd` 进入弃用并可追踪退役 | 调用时有明确弃用提示；v4 结束时无 demo 引用 | `python scripts/check_v4_legacy_surface_refs.py` | P0 | 外部项目兼容成本 |
| REQ-204 | 迁移能力必须有运行时测试 | 每个迁移 API 至少一条 runtime 测试 | `python scripts/check_v4_runtime_coverage.py` + Godot suites | P0 | 只做静态门禁 |
| REQ-205 | 3d demo 迁移后保持既有体验基线 | `check_texture3d_scene_requirements.py` 仍通过 | `python scripts/check_texture3d_scene_requirements.py` | P1 | 视觉回退 |
| REQ-206 | AGENTS/README 双语同步单入口策略 | 文档出现统一入口与弃用说明 | doc gate + grep 检查 | P1 | 文档漂移 |
| REQ-207 | 迁移过程禁止“假实现”声明 | v4 index 中每里程碑有 runtime 验证命令与状态 | `python ...doc_hygiene_check.py --strict` | P0 | 里程碑虚报 |

## 6) 约束

- 不允许“新增一个 façade 同时保留旧入口继续扩散”的折中方案。
- 不允许只改 README 不改测试。
- 不允许把“场景可打开”当作迁移完成；必须有行为断言。

## 7) 非目标

- 本轮不处理 Playwright CLI 的 M3.3 完整落地。
- 本轮不引入新 demo 类型，只处理现有三个 canonical demo 的统一化。

## 8) 追溯入口

- v4 index: `docs/plan/v4-index.md`
- 架构计划: `docs/plan/v4-single-surface-architecture.md`
- demo 迁移计划: `docs/plan/v4-demo-migration-runtime.md`
- legacy 退役计划: `docs/plan/v4-legacy-deprecation-gates.md`

