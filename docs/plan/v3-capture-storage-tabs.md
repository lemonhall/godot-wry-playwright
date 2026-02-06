# v3 Plan: Capture + Export + Tabs + Storage

## Goal

补齐页面捕获、标签页与持久化相关命令，让用户能完成完整浏览器工作流。

## PRD Trace

- REQ-101
- REQ-102
- REQ-104
- REQ-106

## Scope

- Capture/Export:
  - `screenshot`, `pdf`
- Tabs:
  - `tab-list`, `tab-new`, `tab-close`, `tab-select`
- State/Storage:
  - `state-save`, `state-load`
  - `cookie-list/get/set/delete/clear`
  - `localstorage-list/get/set/delete/clear`
  - `sessionstorage-list/get/set/delete/clear`

## Acceptance

- A1: 每个命令具备独立 API 映射与参数定义。
- A2: 产物命令（screenshot/pdf/state-save）有文件路径验证。
- A3: state-load/cookie/storage 命令有回放验证路径。

## Files

- Modify: `docs/plan/v3-capture-storage-tabs.md`
- Modify: `docs/plan/v3-cli-command-catalog.md`
- Modify: `godot-wry-playwright/addons/godot_wry_playwright/wry_pw_session.gd`
- Create: `scripts/check_v3_capture_storage_tabs_contract.py`

## Steps

1) Red: 新增 `check_v3_capture_storage_tabs_contract.py` 并运行到红。
2) Green: 在 `WryPwSession` 实现 capture/tabs/state/cookie/storage API。
3) Green verify: 运行 M3.1 + M3.2 + 命令目录覆盖脚本，确认全绿。
4) Refactor: 抽取通用文件 IO、tab 状态、storage JS helper，降低重复。
5) Review: 更新 `v3-index` 里程碑与证据列表。

## Verification

- `python3 scripts/check_v3_capture_storage_tabs_contract.py`
- `python3 scripts/check_v3_core_m31_behavior_contract.py`
- `python3 scripts/check_playwright_cli_command_map.py --cli-doc playwright-cli.md --catalog docs/plan/v3-cli-command-catalog.md`

## Risks

- 3D texture 模式对截图/导出语义存在模式差异，需要明确“页面截图”与“贴图截图”的边界。
- 存储命令的域名边界必须可控，避免跨站数据污染。
