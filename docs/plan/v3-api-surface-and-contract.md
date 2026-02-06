# v3 Plan: API Surface & Contract

## Goal

定义 v3 的对外接口形状与统一结果契约，使后续每个命令实现都遵循同一语义。

## PRD Trace

- REQ-102
- REQ-103
- REQ-104
- REQ-105
- REQ-108

## Scope

- 定义 `WryPwRuntime` 与 `WryPwSession` 的职责边界。
- 定义命名规则：`playwright-cli foo-bar` -> `foo_bar`。
- 定义统一返回：`request_id` + `completed(request_id, ok, result_json, error_code, error_message)`。
- 定义 legacy API alias 与弃用标注策略。

## Acceptance

- A1: 命名规则文档存在，包含关键字冲突策略（如 `type` -> `type_text`）。
- A2: 结果 envelope 文档存在，包含成功与失败示例 JSON。
- A3: legacy -> v3 API 对照表存在且每条旧接口都有迁移目标。

## Files

- Modify: `docs/plan/v3-api-surface-and-contract.md`
- Reference: `docs/plan/v3-cli-command-catalog.md`
- Future code targets:
  - `crates/godot_wry_playwright/src/wry_browser.rs`
  - `godot-wry-playwright/addons/godot_wry_playwright/wry_view.gd`

## Steps

1) Red: 新增 API 形状约束测试（命名 + envelope）。
2) Red verify: 运行约束测试，预期因未实现 v3 接口而失败。
3) Green: 增加 runtime/session API 壳与统一返回结构。
4) Green verify: 约束测试通过。
5) Refactor: 收敛命名与错误码枚举，避免重复转换。

## Risks

- 旧 demo 依赖现有 API，迁移窗口内可能出现双接口并存。
- `result_json` 的类型表达不足，需要后续引入 typed helper。
