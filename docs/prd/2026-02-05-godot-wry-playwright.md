# PRD: Godot × wry WebView automation (Playwright-like subset)

## 0) 元信息

- Topic：godot-wry-playwright
- Owner：TBD
- Status：draft
- Version：v1
- Last updated：2026-02-06
- Links：
  - 计划入口：`docs/plan/v1-index.md`

## 1) 背景与问题（Problem Statement）

在 Godot 应用内，需要一个可复用组件，让 GDScript Agent 能够：

- 加载外部 URL（真实网页）
- 通过选择器定位 DOM，执行 click/fill 等交互
- 执行 JS 并获取结果

目标不是“写一个浏览器”，而是提供一个“可被 LLM Tool/Skill 组合调用”的网页交互能力，使 Agent 可以完成信息采集与表单交互等任务。

已知事实/约束：

- 采用 `wry` 作为跨平台 WebView 抽象层；它依赖系统 WebView（Windows WebView2、Apple WKWebView、Linux WebKitGTK、Android WebView）。
- `wry::WebView::evaluate_script_with_callback` 在文档中标注 Android 未实现，因此跨平台返回值需走 IPC。
- “严格 headless（无窗口/无 view）”不可作为跨平台前提；桌面端可用隐藏窗口，移动端通常必须挂到真实 view/window。
- 第一个可验证交付目标是 Windows 桌面端 MVP，其它平台按版本演进。

## 2) 目标（Goals）

- G1：为 Godot 4.6 提供一个可导入的插件化组件（`addons/...`），可在项目间复用。
- G2：对 GDScript 暴露一组语义接近 Playwright 的自动化 API（子集），用于网页浏览与交互。
- G3：Windows 桌面端可加载外部 URL，并能通过选择器实现 click/fill/wait/eval 并获得稳定的异步返回。
- G4：统一的跨平台结果回传协议（IPC JSON envelope），确保未来 Android/iOS 进入时不改变上层语义。
- G5：Windows 桌面端提供一个“可视 WebView UI”演示：在 Godot 窗口中以原生子窗口覆盖的方式显示 WebView（用于调试/演示，不要求渲染到 Godot 纹理）。

## 3) 非目标（Non-goals）

- NG1：实现 Playwright 的全量能力（网络拦截、HAR、tracing、稳定 Locator、跨浏览器引擎选择等）。
- NG2：保证跨平台“严格 headless”。
- NG3：在 MVP 阶段实现“渲染到 Godot 纹理/材质/3D 表面”的 WebView（真实嵌入渲染管线）。
- NG4：在 MVP 阶段提供完整的安全沙箱策略（只提供必要的 allowlist 钩子与默认安全提示）。

## 4) 术语与口径（Glossary / Contracts）

- WebView：由系统提供的网页渲染控件（非完整浏览器进程模型）。
- Command：一次自动化操作（goto/click/fill/eval/wait）。
- Request ID：上层发起命令的唯一标识，用于把 IPC 回传与调用方关联。
- IPC Envelope：JS → Rust 的 JSON 结构：`{ "id": "...", "ok": true/false, "result": <json>, "error": <string|null> }`。

## 5) 用户画像与关键场景（Personas & Scenarios）

- S1：GDScript Agent 打开网页，等待某元素出现，提取文本并返回给 LLM。
- S2：GDScript Agent 登录表单：填入用户名/密码，点击提交，等待跳转完成后提取页面信息。
- S3：GDScript Agent 在多步骤流程中重复：点击 → 等待 → 读取 → 决策 → 再点击。

## 6) 需求清单（Requirements with Req IDs）

| Req ID | 需求描述 | 验收口径（可二元判定） | 验证方式（命令/测试/步骤） | 优先级 | 依赖/风险 |
|---|---|---|---|---|---|
| REQ-001 | 插件化交付：可直接复制 `addons/godot_wry_playwright/` 到任意 Godot 4.6 工程并启用 | 示例工程可加载插件且无启动报错 | Godot 打开工程并启用插件；运行 demo 场景 | P0 | GDExtension 打包与平台产物 |
| REQ-002 | 提供 GDScript API（Playwright 子集）：`goto/eval/click/fill/text/attr/wait_for_selector/wait_for_load_state` | 每个 API 调用都能在超时内返回 ok/err | 自动化 demo：对 `https://example.com` 读取标题/文本 | P0 | JS shim 语义一致性 |
| REQ-003 | Windows MVP：可创建 WebView2 并加载外部 URL | `goto(url)` 后 `url()` 返回目标 URL（或规范化后的等价 URL） | Windows 导出/运行验证 | P0 | WebView2 runtime |
| REQ-004 | 异步命令协议：每条命令都有 Request ID、超时、可追踪错误 | 超时会以明确错误结束，不会悬挂 | 单元/集成测试（v1 计划定义） | P0 | 线程与事件循环 |
| REQ-005 | JS Automation Shim：支持选择器定位、点击、输入、读取属性/文本、等待 DOM 条件 | `wait_for_selector` 在元素出现时返回；超时返回错误 | 集成测试（v1 计划定义） | P0 | WebView 内核差异 |
| REQ-006 | 结果回传统一走 IPC Envelope（JSON），不依赖平台特定回调能力 | 同一协议可覆盖 Windows/macOS/Linux/Android | 协议测试（v1 计划定义） | P0 | 安全与消息大小 |
| REQ-007 | 提供最小可观测性：关键事件日志（导航、命令开始/结束、超时、IPC 错误） | 出错时日志包含 request_id 与错误摘要 | 人工复现 + 日志检查 | P1 | 日志噪音控制 |
| REQ-008 | Android：在导出 App 中可运行同一套 GDScript API（子集一致） | 同一 demo 在 Android 上可跑通 | Android instrumentation / 手动验证 | P2 | UI 线程、生命周期 |
| REQ-009 | 安全边界：提供 allowlist/denylist 钩子控制导航（可选） | 禁止的 URL 不会被加载 | 集成测试（v2） | P2 | URL 规范化 |
| REQ-010 | Windows 可视 UI：提供 `start_view/set_view_rect` + 一个可挂载的 `WryView(Control)`，在 2D/3D 场景中覆盖显示 WebView（占屏幕 2/3） | 运行 demo 时，WebView 可见且随 UI 尺寸变化更新 | Windows Godot 运行：`res://demo/ui_view_2d.tscn` 与 `res://demo/ui_view_3d.tscn` | P1 | DPI/坐标系、原生子窗口限制 |

## 7) 约束与不接受（Constraints）

- 一致性：上层 GDScript API 的语义以“异步 + 超时 + 明确错误”作为硬约束。
- 可追溯：每条需求都必须在 `docs/plan/vN-*` 中有对应条目或明确延期，并在追溯矩阵中可定位。
- 安全：默认不假设页面可信；必须提供最小的导航控制接口（即使默认不启用）。

## 8) 可观测性（最小集）

- 事件：`browser_start`, `goto_start/finish`, `cmd_start/finish`, `timeout`, `ipc_error`
- 字段：`request_id`, `url`, `cmd`, `duration_ms`, `error`

## 9) 追溯矩阵（由实施侧维护，避免漂移）

见 `docs/plan/v1-index.md` 的“追溯矩阵”小节。
