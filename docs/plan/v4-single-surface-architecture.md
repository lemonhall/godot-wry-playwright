# v4 Plan: Single Surface Architecture (`WryPwSession` only)

## Goal

把 addon 的公开能力收敛到一个类：`WryPwSession`，并把 legacy 入口降为内部实现细节或弃用对象。

## PRD Trace

- REQ-201
- REQ-203
- REQ-206
- REQ-207

## Scope

- 明确公开 API：业务脚本、demo、测试只允许 `WryPwSession`。
- 为 `WryPwSession` 增加统一启动配置（headless/view/texture），屏蔽底层类差异。
- `WryBrowser`、`WryTextureBrowser`、`WryView` 不再作为推荐入口出现在 demo。

## Acceptance

- A1: 在 `godot-wry-playwright/demo/` 与 `godot-wry-playwright/tests/` 中，无 `WryBrowser.new()` / `WryTextureBrowser.new()` / `WryView` 直接依赖。
- A2: `WryPwSession` 提供可用于三模式的统一配置入口，并有最小运行时证据。
- A3: `AGENTS.md` 与 README 只把 `WryPwSession` 作为公开入口描述。

## Verification

- `python scripts/check_v4_single_surface_usage.py`
- `python3 C:\Users\lemon\.codex\skills\tashan-development-loop\scripts\doc_hygiene_check.py --root . --strict`

## Steps

1) Red: 写 usage gate，先让现状 fail（识别 legacy 直接依赖）。
2) Green: 在 `WryPwSession` 添加统一模式配置入口。
3) Green: demo 改为只使用 `WryPwSession`。
4) Refactor: 清理重复脚本逻辑，保留最小桥接层。

## Risks

- `WryPwSession` 当前主要是自动化语义，补齐 3D texture 控制时可能引入过宽职责。
- 2D `Control` 生命周期与 session 节点生命周期耦合点需明确。

