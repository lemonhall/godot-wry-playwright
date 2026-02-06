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

- A1: runtime/session 命令具备独立 API 映射。
- A2: 可观测命令具备最小输出 schema（console/network/tracing/video）。
- A3: 命令覆盖脚本与文档门禁在该域变更后仍通过。

## Files

- Modify: `docs/plan/v3-network-devtools-session-runtime.md`
- Reference: `docs/plan/v3-cli-command-catalog.md`
- Future code targets:
  - `crates/godot_wry_playwright/src/`

## Steps

1) Red: 为 route/devtools/session 命令写接口契约测试。
2) Red verify: 未实现命令触发预期失败。
3) Green: 实现 runtime/session API 与最小消息模型。
4) Green verify: 测试通过并保留日志证据。
5) Refactor: 抽离监控事件和会话生命周期状态机。

## Risks

- WebView2 与 Playwright 的网络拦截能力并非完全等价，需要标注可用子集。
- tracing/video 在不同模式下资源成本高，需要上限策略。
