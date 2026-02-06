# Agent Notes: godot-wry-playwright

This repo builds a **Godot 4.6 GDExtension plugin** (Rust) that embeds a WebView via **wry** and exposes a **Playwright-like automation subset** to GDScript.

## 1) Architecture Overview

### Areas

- Godot project (demo + plugin host): `godot-wry-playwright/`
  - main scene: `godot-wry-playwright/demo/3d_demo.tscn`
  - demos:
    - headless-ish: `godot-wry-playwright/demo/headeless_demo.tscn`
    - visible 2D: `godot-wry-playwright/demo/2d_demo.tscn`
    - visible 3D texture: `godot-wry-playwright/demo/3d_demo.tscn`
  - extension registration: `godot-wry-playwright/project.godot` (`[gdextension]` section)
- Plugin (Godot-side entry):
  - `.gdextension`: `godot-wry-playwright/addons/godot_wry_playwright/godot_wry_playwright.gdextension`
  - binaries (copied artifacts): `godot-wry-playwright/addons/godot_wry_playwright/bin/`
  - GDScript UI wrapper (native overlay): `godot-wry-playwright/addons/godot_wry_playwright/wry_view.gd` (`WryView`)
- Rust workspace:
  - core protocol + JS shim (cross-platform, unit-tested): `crates/godot_wry_playwright_core/`
  - Godot extension crate (GDExtension classes): `crates/godot_wry_playwright/`
    - Godot class: `crates/godot_wry_playwright/src/wry_browser.rs` (`WryBrowser`)
- Reference-only upstream checkout (DO NOT COMMIT): `wry/` (ignored by `.gitignore`)

### Data Flow

```
GDScript (WryBrowser.*) 
  -> Rust GDExtension (assign request_id, send command)
    -> wry WebView evaluate_script("window.__gwry.dispatch(...)")
      -> JS shim executes (querySelector/click/fill/wait)
        -> JS posts IPC JSON: window.ipc.postMessage(...)
          -> Rust ipc_handler parses envelope
            -> Godot signal: completed(request_id, ok, result_json, error)
```

### Persistence / artifacts

- Godot editor cache: `godot-wry-playwright/.godot/` (ignored)
- Built binaries copied for Godot to load:
  - Windows: `godot-wry-playwright/addons/godot_wry_playwright/bin/windows/godot_wry_playwright.dll` (ignored)
- CI artifacts:
  - GitHub Actions uploads Windows addon binaries (see `.github/workflows/build-windows.yml`)

## 2) Code Conventions (Negative Knowledge)

- Do not commit `wry/`
  - Why: it is a large upstream reference checkout; it will bloat history and is not the source of truth for this repo.
  - Do instead: treat `wry/` as read-only reference; depend on crates.io `wry` from `crates/godot_wry_playwright/Cargo.toml`.
  - Verify: `git status` should never show `wry/`.

- Do not commit `addons/**/bin/**` by default
  - Why: native binaries are platform-specific and make reviews/releases noisy; CI provides artifacts.
  - Do instead: build locally and copy into the Godot project for manual verification; use CI artifacts for sharing.
  - Verify: `.gitignore` ignores `godot-wry-playwright/addons/**/bin/`.

- Do not change the GDExtension entry symbol unless you also change the `.gdextension`
  - Why: Godot loads the dynamic library entry by name; mismatch = “library failed to load”.
  - Do instead: keep the default `gdext_rust_init` (godot-rust default).
  - Verify: `godot-wry-playwright/addons/godot_wry_playwright/godot_wry_playwright.gdextension` has `entry_symbol = "gdext_rust_init"`.

- Do not rely on `evaluate_script_with_callback` for results
  - Why: `wry` documents it as not implemented on Android; using it would fork semantics per platform.
  - Do instead: always return results via IPC envelope (JS `postMessage` → Rust `ipc_handler`).
  - Verify: protocol tests in `crates/godot_wry_playwright_core/tests/`.

- Do not break the JS shim contract without updating tests
  - Why: Rust generates dispatch scripts that call `window.__gwry.dispatch(...)`.
  - Do instead: change `automation_shim_js()` + update `shim_test.rs`.
  - Verify: `cargo test -p godot_wry_playwright_core`.

- Don’t block Godot’s main thread waiting for browser results
  - Why: the engine will freeze; results are delivered asynchronously via the `completed` signal.
  - Do instead: drive everything by request IDs and signals/await on the GDScript side.

## 3) Testing Strategy

### Full (fastest confidence loop right now)

- Doc gate (Tashan):  
  - `python3 /home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py --root . --strict`

- Rust unit tests (core protocol + shim):  
  - `cargo test -p godot_wry_playwright_core`

- Rust unit tests (extension-side utilities):  
  - `cargo test -p godot_wry_playwright --test pending_requests_test`

### Godot runtime verification (Windows)

Manual acceptance is currently done by running the demo scene in Godot 4.6 on Windows:

- Build + copy DLL from WSL2 (cross-compile):  
  - `bash scripts/build_windows_wsl.sh`
- Then open `godot-wry-playwright/` in Godot and run canonical demos:
  - `res://demo/headeless_demo.tscn`
  - `res://demo/2d_demo.tscn`
  - `res://demo/3d_demo.tscn`

Notes:
- WSL2 cross-compile produces a **Windows-GNU** DLL. If Godot fails to load it due to missing runtime DLLs, prefer the **CI Windows artifact** (MSVC) from `.github/workflows/build-windows.yml`.

### One-command checks (Windows PowerShell)

From Windows PowerShell at repo root:

- `scripts\run_tests.ps1` (doc + Rust + scene + v3 M3.1/M3.2 static checks)
- `scripts\run_tests.ps1 -Quick` (skip the second Rust test group)
- `python3 scripts/check_v3_core_api_surface.py` (v3 core API 对齐静态检查)
- `python3 scripts/check_v3_core_m31_slice2.py` (M3.1 第二刀：dialog/resize 语义静态检查)
- `python3 scripts/check_v3_core_m31_slice3.py` (M3.1 第三刀：upload/snapshot 文件语义静态检查)
- `python3 scripts/check_v3_core_m31_behavior_contract.py` (M3.1 行为契约：语义+目录状态联合检查)
- `python3 scripts/check_v3_capture_storage_tabs_contract.py` (M3.2 capture/storage/tabs 契约静态检查)
- `scripts\run_tests.ps1 -RunGodotSmoke -GodotExe "E:\\Godot_v4.6-stable_win64.exe\\Godot_v4.6-stable_win64_console.exe"`

### Running tests (WSL2 + Linux Godot) — recommended for script-only tests

If WSL interop to a Windows `.exe` is flaky, use a Linux Godot binary as a deterministic test runner.

Preferred binary check:

- `export GODOT_LINUX_EXE=/home/lemonhall/godot46/Godot_v4.6-stable_linux.x86_64`
- `"$GODOT_LINUX_EXE" --version`

Required env isolation (prevents crashes when `user://` writes are blocked in real `$HOME`):

- `export HOME=/tmp/oa-home`
- `export XDG_DATA_HOME=/tmp/oa-xdg-data`
- `export XDG_CONFIG_HOME=/tmp/oa-xdg-config`
- `mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"`

Run all Godot script tests (if present):

- `if [ ! -d godot-wry-playwright/tests ]; then echo "No Godot tests under godot-wry-playwright/tests yet"; else (cd godot-wry-playwright && while IFS= read -r t; do echo "--- RUN $t"; timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)" --script "res://$t"; done < <(find tests -type f -name 'test_*.gd' | LC_ALL=C sort)); fi`

Run a single Godot script test:

- `timeout 120s "$GODOT_LINUX_EXE" --headless --rendering-driver dummy --path "$(pwd)/godot-wry-playwright" --script res://tests/<your_test>.gd`

Linux runtime caveat (important):

- This repo currently ships Windows runtime binaries in `addons/.../bin/windows/`.
- On Linux, demo scenes that require `WryBrowser` / `WryTextureBrowser` will fail to load unless a matching `linux.x86_64` extension binary is added.
- Use Windows Godot runtime verification for extension behavior; use Linux Godot mainly for script-only tests/tools.

### Godot test suite conventions (add as we grow)

When adding automated Godot tests, keep them deterministic and avoid external network by default:

- Put tests under: `godot-wry-playwright/tests/` (scenes/scripts)
- Prefer a headless runner script (planned) and add per-test timeouts to avoid hung CI.
- For integration tests that require the network, mark them as “smoke” and keep them optional.

## 4) Build / Release Notes

- WSL2 → Windows DLL build: `scripts/build_windows_wsl.sh`
- Windows local copy step: `scripts/copy_bins.ps1`
- CI builds Windows artifact: `.github/workflows/build-windows.yml`
