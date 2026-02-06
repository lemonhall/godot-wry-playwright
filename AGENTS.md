# Agent Notes: godot-wry-playwright

This repo builds a **Godot 4.6 GDExtension plugin** (Rust) that embeds a WebView via **wry** and exposes a **Playwright-like automation subset** to GDScript.

## 1) Architecture Overview

### Areas

- Godot project (demo + plugin host): `godot-wry-playwright/`
  - current main scene: `godot-wry-playwright/demo/agent_playwright.tscn`
  - canonical demos:
    - headless-ish: `godot-wry-playwright/demo/headeless_demo.tscn`
    - visible 2D: `godot-wry-playwright/demo/2d_demo.tscn`
    - visible 3D texture: `godot-wry-playwright/demo/3d_demo.tscn`
    - agent + chat overlay: `godot-wry-playwright/demo/agent_playwright.tscn`
  - extension registration: `godot-wry-playwright/project.godot` (`[gdextension]` section)
- Godot addons:
  - browser addon: `godot-wry-playwright/addons/godot_wry_playwright/`
  - agent runtime addon: `godot-wry-playwright/addons/openagentic/`
- Local proxy (Node.js): `proxy/`
  - endpoint: `POST /v1/responses` (SSE forwarding)
  - health: `GET /healthz`
- Rust workspace:
  - core protocol + JS shim (cross-platform, unit-tested): `crates/godot_wry_playwright_core/`
  - Godot extension crate (GDExtension classes): `crates/godot_wry_playwright/`
    - Godot class: `crates/godot_wry_playwright/src/wry_browser.rs` (`WryBrowser`)
- Reference-only upstream checkout (DO NOT COMMIT): `wry/` (ignored by `.gitignore`)

### Data Flow

```
GDScript (WryBrowser/WryPwSession/agent_playwright)
  -> Rust GDExtension (assign request_id, send command)
    -> wry WebView evaluate_script("window.__gwry.dispatch(...)")
      -> JS shim executes (querySelector/click/fill/wait)
        -> JS posts IPC JSON: window.ipc.postMessage(...)
          -> Rust ipc_handler parses envelope
            -> Godot signal: completed(request_id, ok, result_json, error)

Agent path (agent_playwright scene)
  -> OpenAgentic.run_npc_turn(...)
    -> proxy /v1/responses (SSE)
      -> tool.use/tool.result
        -> browser_* tools -> WryTextureBrowser (texture) / WryPwSession (session)
          -> overlay chat transcript
```

### Persistence / artifacts

- Godot editor/runtime cache for this repo: `.godot-user/` (local runtime logs and isolated dirs)
- Built binaries copied for Godot to load:
  - Windows: `godot-wry-playwright/addons/godot_wry_playwright/bin/windows/godot_wry_playwright.dll` (ignored)
- OpenAgentic runtime data (user://): `user://openagentic/saves/<save_id>/...`
- CI artifacts:
  - GitHub Actions uploads Windows addon binaries (see `.github/workflows/build-windows.yml`)

## 2) Code Conventions (Negative Knowledge)

- Do not commit `wry/`
  - Why: large upstream checkout, not source-of-truth for this repo.
  - Do instead: treat `wry/` as read-only reference, depend on crates.io `wry` in Cargo.
  - Verify: `git status` should not show `wry/`.

- Do not commit `addons/**/bin/**` by default
  - Why: platform-specific binaries make review noisy; CI provides artifacts.
  - Do instead: build locally for manual verify; share via CI artifacts.
  - Verify: `.gitignore` ignores `godot-wry-playwright/addons/**/bin/`.

- Do not change GDExtension entry symbol unless `.gdextension` is updated together
  - Why: mismatch causes Godot load failure.
  - Do instead: keep default `gdext_rust_init`.
  - Verify: `godot-wry-playwright/addons/godot_wry_playwright/godot_wry_playwright.gdextension`.

- Do not rely on `evaluate_script_with_callback` for result path
  - Why: Android behavior diverges (`wry` documents missing support).
  - Do instead: use IPC envelope (`postMessage` -> `ipc_handler`) everywhere.
  - Verify: `cargo test -p godot_wry_playwright_core`.

- Do not break JS shim contract without tests
  - Why: dispatch scripts assume `window.__gwry.dispatch(...)` API contract.
  - Do instead: update shim + tests together.
  - Verify: `cargo test -p godot_wry_playwright_core`.

- Do not block Godot main thread waiting for browser results
  - Why: freezes engine and input loop.
  - Do instead: async by request IDs and `completed` signal.

- Do not use dot (`.`) in OpenAI tool names
  - Why: OpenAI Responses requires `tools[].name` to match `^[a-zA-Z0-9_-]+$`.
  - Do instead: use `browser_open`, `browser_click`, etc.
  - Verify: no HTTP 400 `Invalid 'tools[0].name'` from proxy/provider logs.

- Do not modify legacy demos when building agent UX
  - Why: `3d_demo` is baseline render/behavior reference.
  - Do instead: add/iterate in `agent_playwright.*` to keep old demos stable.
  - Verify: `scripts/check_texture3d_scene_requirements.py` and `-Suite wry_pw_session` stay green.

## 3) Testing Strategy

### Full (fastest confidence loop right now)

- Doc gate (Tashan):
  - `python3 C:\Users\lemon\.codex\skills\tashan-development-loop\scripts\doc_hygiene_check.py --root . --strict`

- Rust unit tests (core protocol + shim):
  - `cargo test -p godot_wry_playwright_core`

- Rust unit tests (extension-side utilities):
  - `cargo test -p godot_wry_playwright --test pending_requests_test`

- Windows Godot runtime suites:
  - `scripts\run_godot_tests.ps1 -Suite wry_pw_session`
  - `scripts\run_godot_tests.ps1 -Suite agent_playwright`

### One-command checks (Windows PowerShell)

From repo root:

- `scripts\run_tests.ps1` (doc + Rust + runtime suites + static checks)
- `scripts\run_tests.ps1 -Quick` (skip second Rust group)
- `scripts\run_tests.ps1 -SkipGodotRuntime` (skip runtime suites)
- `scripts\run_tests.ps1 -RunGodotSmoke -GodotExe "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"`

Static gates:

- `python3 scripts/check_texture3d_scene_requirements.py`
- `python3 scripts/check_v3_core_api_surface.py`
- `python3 scripts/check_v3_core_m31_slice2.py`
- `python3 scripts/check_v3_core_m31_slice3.py`
- `python3 scripts/check_v3_core_m31_behavior_contract.py`
- `python3 scripts/check_v3_capture_storage_tabs_contract.py`
- `python3 scripts/check_v3_runtime_test_coverage.py`

### Godot runtime tests (Windows, deterministic)

- Default exe: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Override exe: set `GODOT_WIN_EXE` or pass `-GodotExe`
- Timeout: set `GODOT_TEST_TIMEOUT_SEC` (default 120)
- Local fixture HTTP server is auto-started by `scripts\run_godot_tests.ps1`

Current runtime suite files:

- `godot-wry-playwright/tests/test_wry_pw_session_core_runtime.gd`
- `godot-wry-playwright/tests/test_wry_pw_session_upload_runtime.gd`
- `godot-wry-playwright/tests/test_wry_pw_session_capture_storage_tabs_runtime.gd`
- `godot-wry-playwright/tests/test_wry_pw_session_start_modes_runtime.gd`
- `godot-wry-playwright/tests/test_agent_playwright_scene_smoke.gd`
- `godot-wry-playwright/tests/test_agent_playwright_browser_tools_runtime.gd`
- `godot-wry-playwright/tests/test_agent_playwright_chat_flow_runtime.gd`

Notes:

- Treat `TEST_FAIL` marker or non-zero exit as failure; ignore known Godot noisy shutdown diagnostics.
- Runtime tests are authoritative for behavior. Static checks alone are not sufficient for completion claims.

### Proxy + agent scene manual verification (Win11)

- Start proxy:
  - `cd proxy`
  - `$env:OPENAI_API_KEY="<your_key>"`
  - `$env:OPENAI_BASE_URL="https://api.openai.com/v1"`
  - `node .\server.mjs`
- Health check:
  - `irm http://127.0.0.1:8787/healthz`
- Start Godot main scene:
  - `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe --path E:\development\godot-wry-playwright\godot-wry-playwright`

## 4) Build / Release Notes

- WSL2 -> Windows DLL build: `scripts/build_windows_wsl.sh`
- Windows local copy step: `scripts/copy_bins.ps1`
- CI builds Windows artifact: `.github/workflows/build-windows.yml`
