# godot-wry-playwright

Godot 4.6 + Rust GDExtension plugin that embeds a WebView via `wry`, and exposes a **Playwright-like (subset) automation API** to GDScript.

This project’s goal is to let an agent (GDScript + LLM tooling) *browse* real web pages inside a Godot app: load external URLs, query DOM via selectors, click/fill, and run JavaScript — while keeping the API shape close to Playwright semantics.

Languages: `README.zh-CN.md`

## Status

- Current focus: **Windows desktop MVP** (WebView2 via `wry`)
- Agent integration scene available: `res://demo/agent_playwright.tscn` (chat overlay + OpenAgentic tool-calling)
- Planned: macOS/Linux, then Android; iOS later
- Not a full Playwright replacement (see Non-goals)

## What this is (and is not)

**This is:**
- A reusable, importable Godot plugin (`addons/...`) with a small GDScript-facing API.
- A `wry`-powered WebView running in-process.
- DOM automation implemented by **JS injection + IPC**.
- (Windows MVP) A **visible WebView overlay** mode: a native child-window WebView that can be positioned/sized from Godot UI.
- (Windows-only, planned) A **3D “simulated render”** mode: periodically capture the WebView to an image and use it as a texture in 3D (not real-time GPU embedding).

**This is not:**
- A browser automation framework with Playwright’s full feature set (network interception, HAR, tracing, stable locators, etc.).
- Guaranteed “true headless” across platforms. On desktop we can create a hidden window; on mobile the WebView usually must be attached to a real view/window.

## Repository layout

- `godot-wry-playwright/`: minimal Godot project used for development/testing.
- `proxy/`: local Node.js proxy used by OpenAgentic/agent scenes (`/v1/responses` SSE forwarding).
- `wry/`: upstream `wry` repository (vendored checkout; treat as read-only unless explicitly updating upstream).
- `docs/prd/`: PRD/spec (requirements with Req IDs).
- `docs/plan/`: versioned plans (`vN-*`) with traceability to the PRD.

## Architecture (high level)

### Core idea

1. GDScript calls a Playwright-like method (e.g. `goto`, `click`, `fill`, `wait_for_selector`, `eval`).
2. The Rust extension sends a command into the WebView by injecting JavaScript (`wry::WebView::evaluate_script`).
3. JavaScript executes the operation (query selector, click, etc.) and **returns results through IPC**:
   - JS → `window.ipc.postMessage(JSON.stringify({ id, ok, result, error }))`
   - Rust → `ipc_handler` receives the message and emits a Godot signal / resolves an awaitable.

### Why IPC for results (even on desktop)

`wry::WebView::evaluate_script_with_callback` is documented as **not implemented on Android**; using IPC everywhere keeps the contract consistent across platforms.

### “Playwright-like” semantics (subset)

The initial API targets this slice:
- `goto(url)`
- `eval(js)`
- `click(selector)`
- `fill(selector, text)`
- `text(selector)` / `attr(selector, name)`
- `wait_for_selector(selector, timeout_ms)`
- `wait_for_load_state(state, timeout_ms)` (basic)

All calls are asynchronous with timeouts and request IDs.

## Safety notes

This loads external URLs and injects automation scripts into page contexts. Treat all loaded content as untrusted:
- restrict navigation with allowlists if embedding inside a game/app distributed to users,
- avoid injecting secrets into page JS,
- prefer running automation against controlled pages when possible.

## Docs (Tashan loop)

- PRD/spec: `docs/prd/2026-02-05-godot-wry-playwright.md`
- PRD/spec (v4 single-surface unification): `docs/prd/2026-02-06-addon-surface-unification.md`
- v1 plan index: `docs/plan/v1-index.md`
- v4 plan index (single public surface + demo migration): `docs/plan/v4-index.md`

## Windows MVP build (local)

### Option A (recommended): build from WSL2 and run in Windows Godot

From repo root (WSL2 bash):

- `bash scripts/build_windows_wsl.sh`

Then open `godot-wry-playwright/` in Godot 4.6 on Windows and run the demo.

### Option B: build on Windows

From repo root (PowerShell):

- Build the extension: `cargo build -p godot_wry_playwright --release`
- Copy the DLL into the Godot project: `powershell -ExecutionPolicy Bypass -File scripts/copy_bins.ps1 -Profile release`
- Open `godot-wry-playwright/` in Godot 4.6 and run the demo (main scene).

## Demos

- Headless-ish automation: `res://demo/headeless_demo.tscn`
- Visible UI (2D): `res://demo/2d_demo.tscn` (left 2/3 of window)
- Texture (3D simulated render, Windows-only): `res://demo/3d_demo.tscn` (computer monitor screen)
- Agent + browser control (chat overlay): `res://demo/agent_playwright.tscn`

Current default main scene is `res://demo/agent_playwright.tscn`.

Note: the 2D visible mode is a **native child-window overlay**, not a texture rendered by Godot.

## Win11 quick start (proxy + agent scene)

### 1) Start proxy (PowerShell window A)

From repo root:

- `cd proxy`
- `$env:OPENAI_API_KEY="<your_key>"`
- `$env:OPENAI_BASE_URL="https://api.openai.com/v1"`
- `node .\server.mjs`

Health check:

- `irm http://127.0.0.1:8787/healthz`

Expected: `ok: true`.

### 2) Start Godot scene (PowerShell window B)

- `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe --path E:\development\godot-wry-playwright\godot-wry-playwright`

By default, `agent_playwright` uses:

- proxy base URL: `http://127.0.0.1:8787/v1`
- model: `gpt-5.2`

You can override in Inspector on `AgentPlaywright` node (`agent_proxy_base_url`, `agent_model`, `agent_auth_token`).

### 3) Run runtime suites

- `powershell -ExecutionPolicy Bypass -File scripts/run_godot_tests.ps1 -Suite agent_playwright`
- `powershell -ExecutionPolicy Bypass -File scripts/run_godot_tests.ps1 -Suite wry_pw_session`

### 4) Common API constraint (important)

OpenAI Responses tool names must match `^[a-zA-Z0-9_-]+$`.
Do not use dots in tool names (e.g. `browser.open` is invalid; use `browser_open`).

## Modes (roadmap)

This project is evolving toward 3 runtime modes:

1) `headless`: create an off-screen/hidden native window and run automation (desktop-friendly)
2) `view (2D UI)`: show a native WebView overlay sized/positioned by a Godot `Control`
3) `texture (3D simulated)`: capture WebView frames (PNG) and update a Godot texture/material (Windows-only, lower FPS, higher latency)

## License

TBD (note: upstream `wry` is dual-licensed MIT/Apache-2.0; this repository will document its own license explicitly).
