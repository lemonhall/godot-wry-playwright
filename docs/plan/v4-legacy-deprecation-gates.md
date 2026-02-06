# v4 Plan: Legacy Surface Deprecation & Gates

## Goal

制定并执行 legacy 入口（尤其 `wry_view.gd`）的弃用与退役策略，避免未来再次回流到多入口状态。

## PRD Trace

- REQ-203
- REQ-206
- REQ-207

## Scope

- 为 `wry_view.gd` 增加明确 deprecation 信息（运行时 warning + 文档说明）。
- 新增静态门禁脚本，阻止 demo/tests 新增 legacy 引用。
- 在 README/README.zh-CN/AGENTS 记录弃用时间线和替代路径（`WryPwSession`）。

## Acceptance

- A1: `wry_view.gd` 被标记 deprecated，且指向 `WryPwSession`。
- A2: `python scripts/check_v4_legacy_surface_refs.py` PASS。
- A3: 文档门禁通过，且双语 README/AGENTS 与代码一致。

## Verification

- `python scripts/check_v4_legacy_surface_refs.py`
- `python3 C:\Users\lemon\.codex\skills\tashan-development-loop\scripts\doc_hygiene_check.py --root . --strict`

## Steps

1) Red: 写 legacy 引用检测脚本并让现状 fail。
2) Green: 迁移所有 demo/tests legacy 引用。
3) Green: 给 legacy 文件补 deprecation 提示。
4) Refactor: 更新文档与开发脚本默认路径，减少误用机会。

## Risks

- 外部旧项目可能仍引用 `WryView`；需给出可操作迁移示例。
- 过早硬删除可能影响正在使用旧 demo 的用户。

