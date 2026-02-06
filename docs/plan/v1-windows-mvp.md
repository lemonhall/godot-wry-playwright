# v1: Windows MVP (Godot 4.6 plugin + wry)

## Goal

Deliver a Windows desktop MVP: a Godot 4.6 plugin that can create a `wry` WebView (WebView2), load an external URL, and perform a Playwright-like automation subset via JS injection + IPC.

## PRD Trace

PRD Trace: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-010

## Scope

### In scope

- Plugin packaging under `addons/godot_wry_playwright/` (GDExtension + minimal GDScript wrapper).
- Windows backend: create a hidden/native window + `wry` WebView2 instance.
- JS automation shim injected at document start.
- IPC envelope for async results.
- Timeouts and cancellation at the command layer.

### Out of scope (v1)

- Android/iOS backends (REQ-008 deferred).
- Network interception / tracing artifacts / HAR.
- Rendering the WebView into Godot’s rendering view (texture/material/mesh).

## Acceptance (binary)

- A1: In the demo project, calling `goto("https://www.baidu.com/")` completes within 10s and `eval("() => document.title")` returns a non-empty title JSON string.
- A2: `wait_for_selector("h1", 5000)` completes with ok.
- A3: When a selector does not appear, `wait_for_selector(..., timeout)` returns an error and includes `request_id`.
- A4: All results are delivered through IPC envelope JSON and can be parsed as UTF-8.
- A5: Visible UI demo: WebView is visible as a native overlay and occupies the left 2/3 of the Godot window in both 2D and 3D demo scenes.

## Verification commands (planned)

These are the intended verification commands (Windows):

- Build the extension (Windows):
  - `cargo build -p godot_wry_playwright --release`
- Or build from WSL2 (cross-compile Windows GNU):
  - `bash scripts/build_windows_wsl.sh`
- Copy the DLL into the Godot project:
  - `powershell -ExecutionPolicy Bypass -File scripts/copy_bins.ps1 -Profile release`
- Run demo in Godot:
  - open `godot-wry-playwright/` in Godot 4.6 and run:
    - headless-ish: `res://demo/headeless_demo.tscn`
    - visible 2D: `res://demo/2d_demo.tscn`
- Doc gate (must stay green):
  - `python3 /home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py --root . --strict`

## Files (planned)

- `godot-wry-playwright/addons/godot_wry_playwright/godot_wry_playwright.gdextension`
- `godot-wry-playwright/addons/godot_wry_playwright/bin/windows/godot_wry_playwright.dll` (copied artifact)
- `godot-wry-playwright/demo/headeless_demo.gd`
- `godot-wry-playwright/demo/headeless_demo.tscn`
- `godot-wry-playwright/demo/2d_demo.gd`
- `godot-wry-playwright/demo/2d_demo.tscn`
- `godot-wry-playwright/addons/godot_wry_playwright/wry_view.gd`
- `crates/godot_wry_playwright/**` (Rust extension crate)
- `crates/godot_wry_playwright_core/**` (protocol + JS shim)

## Steps

1) Create plugin skeleton (`addons/...`) and a minimal GDScript API wrapper.
2) Add a Rust GDExtension crate that exposes a `WryBrowser` object and signals for completion/errors.
3) Implement Windows WebView creation using `wry` + a hidden window/event loop (threaded).
4) Inject JS shim (`with_initialization_script`) that:
   - implements selector ops (`click`, `fill`, `text`, `attr`)
   - implements waits using `MutationObserver` with timeout
   - posts results via `window.ipc.postMessage(...)`
5) Implement command routing:
   - Rust assigns `request_id`
   - Rust injects `__gwry.dispatch({id, cmd, args})`
   - Rust receives IPC envelope and resolves the matching request
6) Add timeouts and error normalization (one error shape for all commands).
7) Add a demo scene/script in `godot-wry-playwright/` that exercises A1–A3.

## Risks & mitigations

- WebView lifecycle vs Godot lifecycle: ensure clean shutdown and avoid thread leaks.
- Hidden window behavior: document known constraints; keep MVP to Windows first.
- Selector stability: provide clear errors and encourage using stable selectors.
