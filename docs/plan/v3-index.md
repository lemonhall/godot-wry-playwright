# v3 Index: Playwright CLI 语义对齐

## 0) Snapshot

- Date: 2026-02-06
- Goal: 建立“CLI 命令 → addon API”一对一语义基线，先完成 PRD 与计划拆分。
- PRD: `docs/prd/2026-02-06-playwright-cli-alignment.md`

## 1) Design Options

### Option A: 单一大类（70+ 方法）

- 优点：入口少。
- 缺点：对象职责过重，session/runtime 混杂，维护成本高。

### Option B（Recommended）: Runtime + Session 双层接口

- `WryPwRuntime`: 会话、安装、配置、全局管理。
- `WryPwSession`: 页面、输入、存储、网络、捕获。
- 优点：语义清晰，与 CLI 结构天然对应。
- 取舍：需要定义统一返回 envelope，接口数量增加。

### Option C: 统一 `execute(command, args)`

- 优点：实现路径短。
- 缺点：类型信息弱，IDE 自动补全差，用户仍需记字符串命令。

## 2) Milestones

| Milestone | Scope | DoD (binary) | Verification | Status |
|---|---|---|---|---|
| M3.0 | 文档基线：PRD + v3 拆分计划 + 全命令目录 | 覆盖脚本 PASS；doc hygiene PASS | `python3 scripts/check_playwright_cli_command_map.py` + doc gate | done |
| M3.1 | Core/Navigation/Keyboard/Mouse API 对齐 | 该域命令全部具备 public API + 基础测试 | see `v3-core-navigation-input.md` | done |
| M3.2 | Capture/Export/Tabs/Storage API 对齐 | 该域命令具备 API + 验证脚本 | see `v3-capture-storage-tabs.md` | done |
| M3.3 | Network/DevTools/Runtime/Session API 对齐 | 该域命令具备 API + 验证脚本 | see `v3-network-devtools-session-runtime.md` | todo |
| M3.4 | 迁移与文档落地 | legacy API 有 alias + 弃用提示 + 速查文档 | see `v3-migration-and-ux.md` | todo |

## 3) Plan Index

- `docs/plan/v3-cli-command-catalog.md`
- `docs/plan/v3-api-surface-and-contract.md`
- `docs/plan/v3-core-navigation-input.md`
- `docs/plan/v3-capture-storage-tabs.md`
- `docs/plan/v3-network-devtools-session-runtime.md`
- `docs/plan/v3-migration-and-ux.md`

## 4) Support Matrix (planning baseline)

| Domain | headless | 2D view | 3D texture | Windows |
|---|---|---|---|---|
| Core/Navigation/Input | planned | planned | planned | P0 |
| Capture/Export | planned | planned | planned | P0 |
| Tabs/Storage | planned | planned | planned | P0 |
| Network/DevTools | planned | planned | planned | P1 |
| Runtime/Session mgmt | planned | planned | planned | P1 |

## 5) Traceability Matrix

| Req ID | v3 plan item | tests/commands | Evidence target | Status |
|---|---|---|---|---|
| REQ-101 | `v3-cli-command-catalog.md` | command map check | coverage PASS | doing |
| REQ-102 | `v3-cli-command-catalog.md` + `v3-api-surface-and-contract.md` | command map check | non-empty mapping | doing |
| REQ-103 | `v3-api-surface-and-contract.md` | grep naming rule | naming section exists | doing |
| REQ-104 | `v3-cli-command-catalog.md` | markdown signature check | signature per command | doing |
| REQ-105 | `v3-api-surface-and-contract.md` | grep envelope model | async contract documented | doing |
| REQ-106 | `v3-index.md` + domain plans | support matrix checks | per-domain matrix | doing |
| REQ-107 | `v3-index.md` | plan index checks | split plan files listed | doing |
| REQ-108 | `v3-migration-and-ux.md` | grep alias/deprecation | migration path documented | todo |
| REQ-109 | `v3-migration-and-ux.md` | grep cheat sheet | docs plan exists | todo |
| REQ-110 | `v3-cli-command-catalog.md` + script | run both gates | gates pass | doing |

## 6) Review Notes

- v3 先锁语义与追溯，再进入逐域实现；防止“先写功能再补文档”导致回退。
- 当前 addon 已有 `goto/eval/click/fill/wait_for_selector`，但与 CLI 语义不是一对一关系，必须在 v3 做统一接口层。


## 7) Current Evidence

- M3.1 scaffold evidence: `godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd`
- M3.1 API surface check: `python3 scripts/check_v3_core_api_surface.py`
- M3.1 slice2 check: `python3 scripts/check_v3_core_m31_slice2.py`
- M3.1 slice3 check: `python3 scripts/check_v3_core_m31_slice3.py`
- M3.1 behavior contract check: `python3 scripts/check_v3_core_m31_behavior_contract.py`
- M3.2 contract check: `python3 scripts/check_v3_capture_storage_tabs_contract.py`
- M3.x runtime validation (Windows Godot): `powershell -ExecutionPolicy Bypass -File scripts/run_godot_tests.ps1 -Suite wry_pw_session`

## 8) Gap Review (2026-02-06)

- Prior issue: v3 M3.1/M3.2 "done" primarily depended on static scripts; runtime `test_*.gd` coverage was missing.
- Action: added deterministic Windows runtime suite under `godot-wry-playwright/tests/` and wired it into `scripts/run_tests.ps1`.
- Runtime scope now includes:
  - Core/navigation/input roundtrip (`test_wry_pw_session_core_runtime.gd`)
  - Upload/file semantics (`test_wry_pw_session_upload_runtime.gd`)
  - Capture/storage/tabs behaviors (`test_wry_pw_session_capture_storage_tabs_runtime.gd`)
  - Start/resize mode guardrails (`test_wry_pw_session_start_modes_runtime.gd`)
- Result: "M3.1/M3.2 done" now requires both static contract checks and runtime suite pass on Windows Godot.
