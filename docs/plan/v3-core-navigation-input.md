# v3 Plan: Core + Navigation + Keyboard + Mouse

## Goal

先打通高频交互命令域（Core/Navigation/Keyboard/Mouse），形成最小可用语义闭环。

## PRD Trace

- REQ-101
- REQ-102
- REQ-104
- REQ-105
- REQ-106

## Scope

- 命令域：
  - Core: `open`, `close`, `type`, `click`, `dblclick`, `fill`, `drag`, `hover`, `select`, `upload`, `check`, `uncheck`, `snapshot`, `eval`, `dialog-accept`, `dialog-dismiss`, `resize`
  - Navigation: `go-back`, `go-forward`, `reload`
  - Keyboard: `press`, `keydown`, `keyup`
  - Mouse: `mousemove`, `mousedown`, `mouseup`, `mousewheel`
- 每个命令提供独立 addon API，并保持 CLI 语义。

## Acceptance

- A1: 上述命令均在命令目录中有独立映射。
- A2: 每个命令有最小行为测试（成功路径 + 一个失败路径）。
- A3: 命令结果统一通过 completed envelope 回传。

## Files

- Modify: `docs/plan/v3-core-navigation-input.md`
- Reference: `docs/plan/v3-cli-command-catalog.md`
- Future tests:
  - `crates/godot_wry_playwright_core/tests/`
  - `crates/godot_wry_playwright/tests/`

## Steps

1) Red: 为每个命令写接口存在性与参数契约测试。
2) Red verify: 运行测试，预期未实现命令失败。
3) Green: 分批实现命令映射层（不做额外能力扩展）。
4) Green verify: 域内命令测试通过。
5) Refactor: 抽出统一输入事件转换器与错误处理。

## Risks

- `ref` 与 `selector` 的兼容策略若未统一，会造成行为分叉。
- `type` 命令与 `fill` 命令语义接近，需要严格区分触发事件序列。
