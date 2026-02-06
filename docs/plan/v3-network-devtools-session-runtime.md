# v3 Plan: Network + DevTools + Runtime/Session

## Goal

定义网络拦截、可观测能力与会话运行时管理接口，补齐自动化可运维性。

## PRD Trace

- REQ-101
- REQ-102
- REQ-104
- REQ-106
- REQ-110

## Scope

- Network:
  - `route`, `route-list`, `unroute`
- DevTools:
  - `console`, `network`, `run-code`, `tracing-start`, `tracing-stop`, `video-start`, `video-stop`
- Runtime/Session:
  - `install`, `install-browser`, `config`, `delete-data`
  - `-s=name <cmd>`, `-s=name close`, `-s=name delete-data`
  - `list`, `close-all`, `kill-all`

## Acceptance

- A1: 在当前架构无法稳定实现的 M3.3 命令，`v3-cli-command-catalog.md` 必须保持 `missing`（禁止虚假改为 implemented）。
- A2: 任何 M3.3 命令从 `missing` 改为 `implemented_*`，必须附带 runtime 测试证据（`test_*.gd` + 通过命令）。
- A3: 命令目录覆盖脚本、文档门禁、runtime 覆盖门禁在该域变更后仍通过。

## Files

- Modify: `docs/plan/v3-network-devtools-session-runtime.md`
- Reference: `docs/plan/v3-cli-command-catalog.md`
- Future code targets:
  - `godot-wry-playwright/addons/godot_wry_playwright/`
  - `godot-wry-playwright/tests/`
  - `crates/godot_wry_playwright/src/`

## Reality Check (2026-02-06)

当前 M3.3 条目大多属于“CLI 语义存在，但在本项目当前 Godot + wry 嵌入架构下不可直接兑现”的能力域：

| Command Group | Current Feasibility | Primary Blocker |
|---|---|---|
| `route / route-list / unroute` | blocked | 现有桥接层无稳定请求拦截管线（缺少等价 Playwright route 能力） |
| `console / network` | blocked | 无持续事件流采集与回放通道（仅一次性 eval 返回） |
| `run-code` | blocked | 缺少 Playwright 代码执行沙箱与权限模型 |
| `tracing-* / video-*` | blocked | 当前无 tracing/video 采集后端与产物管线 |
| `install --skills / install-browser` | n/a | 插件依赖嵌入式 WebView2 环境，不走 Playwright 浏览器安装流程 |
| runtime session manager (`list/close-all/kill-all/...`) | planned-not-implemented | 尚未引入独立 `WryPwRuntime` 生命周期管理层 |

结论：M3.3 目前状态应是“文档规划 + `missing` 映射”，不是“已实现”。

## Degradation Contract (until implemented)

在 CLI 适配层落地前，M3.3 命令统一按“不可用”处理，不得伪造成功：

- 返回 `ok=false`。
- `error_code` 使用 `not_implemented_m33`（或更细分子码）。
- `error_message` 必须包含具体命令名。
- `hint` 指向本文件，便于使用者理解边界。

## Anti-Fake-Done Gate

M3.3 命令状态从 `missing` -> `implemented_*` 前，必须同时满足：

1) 有真实 API 实现（对应 addon 方法存在且可调用）。
2) 有对应 runtime `test_*.gd`，并可通过 `run_godot_tests.ps1 -One` 复现。
3) 通过覆盖门禁与目录校验（防止仅改文档状态）。

未满足任一条时，catalog 状态必须保持 `missing`。

## Verification

- `python3 scripts/check_playwright_cli_command_map.py --cli-doc playwright-cli.md --catalog docs/plan/v3-cli-command-catalog.md`
- `python3 scripts/check_v3_runtime_test_coverage.py`
- `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1 -Quick -SkipDoc`

## Steps

1) Red: 为 route/devtools/session 命令写接口契约测试。
2) Red verify: 未实现命令触发预期失败。
3) Green: 实现 runtime/session API 与最小消息模型。
4) Green verify: 测试通过并保留日志证据。
5) Refactor: 抽离监控事件和会话生命周期状态机。

## Risks

- WebView2 与 Playwright 的网络拦截能力并非完全等价，需要标注可用子集。
- tracing/video 在不同模式下资源成本高，需要上限策略。
