# PRD: Playwright CLI 语义对齐（Godot Addon）

## 0) 元信息

- Topic: Playwright CLI semantic alignment
- Owner: godot-wry-playwright
- Status: draft
- Version: v3 planning baseline
- Last updated: 2026-02-06
- Input source: `playwright-cli.md`

## 1) 愿景

把 `playwright-cli.md` 的命令语义迁移为 Godot addon 的一等 API：

- 每个独立 CLI 命令都有一个 addon 对外接口；
- 命名、参数、行为与 Playwright CLI 语义一致；
- 调用结果、错误、超时模型一致；
- 文档和实现保持可追溯，不再让使用者猜测 API 行为。

## 2) 问题陈述

当前 addon API 面只覆盖少量能力，命名也以内部实现为中心（例如 `goto/eval/click/fill/wait_for_selector`），与 Playwright CLI 的心智模型不一致。

直接后果：

- 命令能力缺口大；
- 场景切换（headless/2D/3D）语义分裂；
- 用户在“CLI 命令是什么”与“addon 怎么调用”之间反复翻译，认知负担高。

## 3) 范围

### In Scope

- 定义一份完整命令目录：覆盖 `playwright-cli.md` 的全部独立命令。
- 为每条命令定义 addon API 映射（对象、方法名、参数草案、阶段）。
- 定义统一异步协议（request_id + completed 信号 + result/error 结构）。
- 制定 v3 系列拆分计划（按能力域分文件）。

### Out of Scope (本轮)

- 本轮不实现命令行为本体；只完成 PRD + 计划拆分 + 覆盖校验基线。
- 本轮不承诺跨平台全部可用；平台支持按阶段推进并显式标注。

## 4) 术语

- **CLI Command**: `playwright-cli <command>` 的独立命令标识（如 `go-back`、`tab-list`）。
- **Addon API**: Godot/GDScript 可直接调用的对外接口。
- **Runtime API**: 会话管理、配置、安装类命令接口。
- **Session API**: 页面操作、输入、存储、网络等会话内命令接口。

## 5) 需求（Req IDs）

| Req ID | Requirement | Acceptance (binary) | Verification | Priority | Risk |
|---|---|---|---|---|---|
| REQ-101 | 命令覆盖：`playwright-cli.md` 的每条独立命令都出现在 v3 命令目录中 | 覆盖脚本 PASS，missing=0，extra=0 | `python3 scripts/check_playwright_cli_command_map.py --cli-doc playwright-cli.md --catalog docs/plan/v3-cli-command-catalog.md` | P0 | 命令解析规则偏差 |
| REQ-102 | 一命令一接口：每条命令都有非空 addon API 映射 | 覆盖脚本 PASS，empty_api=0 | 同 REQ-101 | P0 | 目录行维护漂移 |
| REQ-103 | 命名规范：CLI kebab-case 到 addon snake_case 有统一规则 | 规则文档存在且有反例约束 | `rg -n "Naming Rule|kebab|snake_case" docs/plan/v3-api-surface-and-contract.md` | P0 | 命名冲突与关键字 |
| REQ-104 | 参数语义对齐：保留 CLI 命令参数意图（ref/button/timeout/filename 等） | 命令目录每行含 signature 草案与语义注记 | `rg -n "\| .* \| .* \| .*\(" docs/plan/v3-cli-command-catalog.md` | P0 | 旧 selector-only 模式不兼容 |
| REQ-105 | 结果语义统一：全部命令走异步 request_id + completed envelope | 合同文档包含统一返回/错误模型 | `rg -n "request_id|completed|error_code" docs/plan/v3-api-surface-and-contract.md` | P0 | 同步/异步混用导致混乱 |
| REQ-106 | 支持矩阵明确：headless/2D/3D、Windows-first 支持状态可查 | 存在支持矩阵并按命令域标注 | `rg -n "Support Matrix|headless|2D|3D|Windows" docs/plan/v3-index.md docs/plan/v3-*.md` | P1 | 平台差异隐藏 |
| REQ-107 | 计划拆分：v3 按能力域拆分为多个可执行计划文件 | `v3-index` 的 Plan Index 完整列出计划文件 | `rg -n "Plan Index|v3-" docs/plan/v3-index.md` | P0 | 计划过度集中 |
| REQ-108 | 迁移策略：旧 API 到新 API 的映射与弃用路径明确 | 迁移计划包含 alias/deprecation 表 | `rg -n "alias|deprecat|legacy|迁移" docs/plan/v3-migration-and-ux.md` | P1 | 破坏现有 demo |
| REQ-109 | 可用性文档：提供“CLI 到 addon”速查文档结构 | 速查清单路径在计划中明确 | `rg -n "cheat sheet|速查|CLI -> addon" docs/plan/v3-migration-and-ux.md` | P1 | 文档再次漂移 |
| REQ-110 | 质量门禁：文档和命令覆盖检查必须可自动运行 | 两个 gate 命令可执行并通过 | `python3 scripts/check_playwright_cli_command_map.py` + `python3 /home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py --root . --strict` | P0 | 只写文档不校验 |

## 6) 约束

- 术语和命名必须在 PRD、计划、后续代码中保持一致。
- 每个命令只能有一个主接口（可有 alias，但 alias 必须标注弃用策略）。
- 不允许把“命令组合器”当成覆盖证明，必须保留单命令接口。

## 7) 非目标

- 本轮不做“功能都实现完”的承诺。
- 本轮不引入新的 demo 模式；仍保持 canonical 三模式。

## 8) 追溯入口

- v3 index: `docs/plan/v3-index.md`
- 命令目录: `docs/plan/v3-cli-command-catalog.md`
