# v3 Plan: Migration + Docs UX

## Goal

保证旧 API 使用者可迁移，且新使用者可以从 CLI 心智模型直接上手 addon API。

## PRD Trace

- REQ-103
- REQ-108
- REQ-109
- REQ-110

## Scope

- legacy API (`goto/eval/click/fill/wait_for_selector/start/start_view/...`) 到 v3 API 的对照与 alias。
- 弃用策略：告警周期、移除窗口、示例迁移。
- 文档结构：
  - CLI -> addon 速查表
  - 最小工作流（headless/2D/3D）
  - 常见错误码与排障指引

## Acceptance

- A1: 对照表覆盖当前公开 API 与 v3 对应命令。
- A2: 每条弃用项有版本窗口与替代接口。
- A3: 文档门禁通过，无未追溯需求 ID。

## Files

- Modify: `docs/plan/v3-migration-and-ux.md`
- Future docs targets:
  - `README.md`
  - `README.zh-CN.md`

## Steps

1) Red: 编写迁移对照检查（至少保证无空替代项）。
2) Red verify: 旧 API 覆盖不足时失败。
3) Green: 增加 alias、告警与文档迁移示例。
4) Green verify: 迁移检查通过，示例可运行。
5) Refactor: 清理重复示例与多处术语分叉。

## Risks

- 若 alias 与新接口参数顺序不一致，容易引入静默错误。
- 文档若不与命令目录联动，后续会再次漂移。
