# v4 Plan: Single Surface Architecture (`WryPwSession` only)

## Goal

将 addon 的公开能力收敛到单一类：`WryPwSession`，并把 legacy 入口从 scene-facing 代码中移除。

## PRD Trace

- REQ-201
- REQ-203
- REQ-206
- REQ-207

## Scope

- 明确公开 API：业务脚本、demo、tests 只允许 `WryPwSession`。
- 在 `WryPwSession` 中统一启动配置（headless/view/texture），屏蔽底层差异。
- `WryBrowser` / `WryTextureBrowser` 仅作为 session 内部实现细节。

## Acceptance

- A1: 在 `godot-wry-playwright/demo/` 与 `godot-wry-playwright/tests/` 中无 `WryBrowser.new()` / `WryTextureBrowser.new()` / `WryView` 直接依赖。
- A2: `agent_playwright.gd` 仅保留 `WryPwSession` 单一路径（无 texture/session 双驱动分支）。
- A3: README/AGENTS 对外入口描述统一为 `WryPwSession`。

## Verification

- `python scripts/check_v4_single_surface_usage.py`
- `python scripts/check_v4_legacy_surface_refs.py`
- `python3 C:\Users\lemon\.codex\skills\tashan-development-loop\scripts\doc_hygiene_check.py --root . --strict`

## Steps

1) Red: 先让 usage gate 检出 legacy 直连依赖。
2) Green: 将 demo 场景改为只使用 `WryPwSession`。
3) Green: 将 `agent_playwright` 从双驱动收敛为单驱动。
4) Refactor: 清理遗留 helper 与重复路径，保持最小入口。

## Risks

- `WryPwSession` 承担更多语义后，内部复杂度会增加。
- 2D/3D 模式启动参数若不统一，容易产生“同 API 不同行为”。

