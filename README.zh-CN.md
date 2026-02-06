# godot-wry-playwright

面向 Godot 4.6 的 Rust GDExtension 插件：基于 `wry` 嵌入 WebView，并向 GDScript 暴露一个**语义上接近 Playwright（子集）**的自动化接口。

本项目的目标是让你的 GDScript Agent（未来可与 LLM Tool/Skill 组合）在 Godot 应用内“浏览网页”：加载外部 URL、用选择器定位 DOM、点击/输入、执行 JavaScript，并把结果以可等待的异步形式返回给 GDScript。

语言：`README.md`

## 状态

- 当前优先级：**Windows 桌面端 MVP**（通过 `wry` 使用 WebView2）
- 已提供 Agent 集成场景：`res://demo/agent_playwright.tscn`（聊天 overlay + OpenAgentic tool-calling）
- 计划：macOS/Linux，然后 Android；iOS 更后
- 这不是 Playwright 的完整替代品（见“非目标”）

## 这是什么 / 不是什么

**这是什么：**
- 一个可复用、可导入的 Godot 插件（`addons/...`）+ 小而清晰的 GDScript API
- 进程内运行的 `wry` WebView
- 通过 **JS 注入 + IPC** 实现的 DOM 自动化
- 场景脚本统一单一公开入口：`WryPwSession`
-（Windows MVP）提供一个**可视 WebView overlay**：原生子窗口 WebView，可由 Godot UI 控制位置与尺寸
-（Windows only，计划中）提供一个**3D“模拟渲染”模式**：周期性捕获 WebView 画面并作为纹理贴到 3D 场景（非实时 GPU 嵌入）

**这不是什么：**
- 具备 Playwright 全量能力的浏览器自动化框架（网络拦截、HAR、tracing、稳定 Locator 等不在 MVP 范围）
- 可跨平台保证“严格 headless”的方案。桌面端可以创建隐藏窗口；移动端 WebView 通常必须挂在真实 view/window 上。

## 仓库结构

- `godot-wry-playwright/`：用于开发/验证的最小 Godot 工程
- `proxy/`：本地 Node.js 代理（给 OpenAgentic/agent 场景转发 `/v1/responses` SSE）
- `wry/`：上游 `wry` 仓库（本地检出；除非明确要更新上游，否则视为只读）
- `docs/prd/`：PRD/Spec（带 Req ID 的需求列表）
- `docs/plan/`：版本化计划（`vN-*`），并与 PRD 可追溯

## 架构（高层）

### 核心链路

1. GDScript 调用一个 Playwright 风格方法（例如 `goto` / `click` / `fill` / `wait_for_selector` / `eval`）。
2. Rust 扩展通过注入 JavaScript 把命令送入 WebView（`wry::WebView::evaluate_script`）。
3. 页面内 JS 执行操作，并用 IPC 把结果回传：
   - JS → `window.ipc.postMessage(JSON.stringify({ id, ok, result, error }))`
   - Rust → `ipc_handler` 收到消息后发 Godot signal / 完成一次 await

### 为什么统一用 IPC 回传结果

`wry::WebView::evaluate_script_with_callback` 在文档中标注 **Android 未实现**。为了跨平台一致性，结果回传统一走 IPC。

### “类 Playwright”语义（子集）

MVP 目标接口：
- `goto(url)`
- `eval(js)`
- `click(selector)`
- `fill(selector, text)`
- `text(selector)` / `attr(selector, name)`
- `wait_for_selector(selector, timeout_ms)`
- `wait_for_load_state(state, timeout_ms)`（基础版）

所有调用都以异步形式提供：带 `request_id`、超时、可追踪错误。

## 安全提示

该组件会加载外部 URL，并注入自动化脚本。默认把页面内容视为不可信：
- 建议使用 allowlist 控制可导航域名/协议
- 不把敏感信息注入页面 JS 环境
- 条件允许时优先对受控页面做自动化

## 文档（塔山循环）

- PRD/Spec：`docs/prd/2026-02-05-godot-wry-playwright.md`
- PRD/Spec（v4 单一入口统一）：`docs/prd/2026-02-06-addon-surface-unification.md`
- v1 计划入口：`docs/plan/v1-index.md`
- v4 计划入口（单一公开接口 + demo 迁移）：`docs/plan/v4-index.md`

## Windows MVP 构建（本机）

### 方案 A（推荐）：在 WSL2 编译，然后用 Windows Godot 运行验收

在仓库根目录（WSL2 bash）：

- `bash scripts/build_windows_wsl.sh`

然后在 Windows 上用 Godot 4.6 打开 `godot-wry-playwright/` 运行 demo。

### 方案 B：在 Windows 本机编译

在仓库根目录（Windows PowerShell）：

- 编译扩展：`cargo build -p godot_wry_playwright --release`
- 拷贝 DLL 到 Godot 工程：`powershell -ExecutionPolicy Bypass -File scripts/copy_bins.ps1 -Profile release`
- 用 Godot 4.6 打开 `godot-wry-playwright/` 并运行 demo（已设为主场景）。

## Demos

- “类 headless”自动化：`res://demo/headeless_demo.tscn`
- 可视 UI（2D）：`res://demo/2d_demo.tscn`（窗口左侧 2/3）
- 贴图模式（3D 模拟渲染，Windows-only）：`res://demo/3d_demo.tscn`（电脑屏幕贴图）
- Agent + 浏览器控制（聊天 overlay）：`res://demo/agent_playwright.tscn`

当前默认主场景是 `res://demo/agent_playwright.tscn`。

提示：2D 可视模式是**原生子窗口 overlay**，不是渲染到 Godot 纹理的浏览器。

## v4 迁移说明（单一公开入口）

- 场景脚本公开 API 统一为 `WryPwSession`。
- `WryView` 已 deprecated，仅作过渡保留。
- demo 中不应再直接 `new WryBrowser` / `new WryTextureBrowser`。

最小迁移模板：

```gdscript
var session := WryPwSession.new()
session.auto_start = false
add_child(session)
session.completed.connect(_on_completed)
session.open("https://example.com", {"timeout_ms": 10_000})
```

2D 原生 view 模式：

```gdscript
session.open(url, {
  "timeout_ms": 10_000,
  "view_rect": {"x": 20, "y": 20, "width": 960, "height": 640},
})
```

3D texture 模式：

```gdscript
session.frame_png.connect(_on_frame_png)
session.open(url, {
  "timeout_ms": 10_000,
  "texture": {"width": 1024, "height": 768, "fps": 3},
})
```

## Win11 快速启动（proxy + agent 场景）

### 1）启动 proxy（PowerShell 窗口 A）

在仓库根目录：

- `cd proxy`
- `$env:OPENAI_API_KEY="<你的key>"`
- `$env:OPENAI_BASE_URL="https://api.openai.com/v1"`
- `node .\server.mjs`

健康检查：

- `irm http://127.0.0.1:8787/healthz`

预期返回：`ok: true`。

### 2）启动 Godot 场景（PowerShell 窗口 B）

- `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe --path E:\development\godot-wry-playwright\godot-wry-playwright`

`agent_playwright` 默认配置：

- proxy base URL：`http://127.0.0.1:8787/v1`
- model：`gpt-5.2`

可在 `AgentPlaywright` 节点 Inspector 中覆盖：

- `agent_proxy_base_url`
- `agent_model`
- `agent_auth_token`

### 3）运行 runtime 测试套件

- `powershell -ExecutionPolicy Bypass -File scripts/run_godot_tests.ps1 -Suite agent_playwright`
- `powershell -ExecutionPolicy Bypass -File scripts/run_godot_tests.ps1 -Suite wry_pw_session`

### 4）重要 API 约束

OpenAI Responses 的工具名必须匹配 `^[a-zA-Z0-9_-]+$`。

- 错误示例：`browser.open`
- 正确示例：`browser_open`

## 运行模式（路线图）

本项目目标演进为 3 种运行模式：

1）`headless`：创建隐藏/离屏的原生窗口，用于自动化（桌面端友好）  
2）`view（2D UI）`：原生 WebView overlay，尺寸/位置由 Godot `Control` 驱动  
3）`texture（3D 模拟）`：捕获 WebView 帧（PNG）并更新 Godot 纹理/材质（Windows-only、低 FPS、高延迟）

## 许可证

待定（提示：上游 `wry` 为 MIT/Apache-2.0 双许可证；本仓库会单独明确自身许可证）。
