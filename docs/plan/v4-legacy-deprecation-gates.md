# v4 Plan: Legacy Surface Removal & Gates

## Goal

彻底移除 legacy 入口（尤其 `wry_view.gd`），并建立门禁防止回流到多入口状态。

## PRD Trace

- REQ-203
- REQ-206
- REQ-207

## Scope

- 删除 `wry_view.gd` 及其 `.uid`，彻底移除该 legacy surface。
- 新增静态门禁脚本，阻止 demo/tests 新增 legacy 引用。
- 在 README/README.zh-CN/AGENTS 记录移除状态和替代路径（`WryPwSession`）。

## Acceptance

- A1: `wry_view.gd` 与 `wry_view.gd.uid` 已从仓库移除。
- A2: `python scripts/check_v4_legacy_surface_refs.py` PASS。
- A3: 文档门禁通过，且双语 README/AGENTS 与代码一致。

## Verification

- `python scripts/check_v4_legacy_surface_refs.py`
- `python3 C:\Users\lemon\.codex\skills\tashan-development-loop\scripts\doc_hygiene_check.py --root . --strict`

## Steps

1) Red: 写 legacy 引用检测脚本并让现状 fail。
2) Green: 迁移所有 demo/tests legacy 引用。
3) Green: 删除 legacy 文件（`wry_view.gd`/`.uid`）。
4) Refactor: 更新文档与开发脚本默认路径，减少误用机会。

## Risks

- 外部旧项目可能仍引用 `WryView`；需要给出可操作迁移示例。
- 一次性硬删除会打破旧项目兼容性；本仓库明确选择“单用户硬迁移”策略。

