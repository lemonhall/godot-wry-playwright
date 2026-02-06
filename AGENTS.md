# Agent Notes: godot-wry-playwright

This repo builds a **Godot 4.6 GDExtension plugin** (Rust) that embeds a WebView via **wry** and exposes a **Playwright-like automation subset** to GDScript.

## 1) Architecture Overview

### Areas

- Godot project (demo + plugin host): `godot-wry-playwright/`
  - main scene: `godot-wry-playwright/demo/ui_view_2d.tscn`
  - demos:
    - headless-ish: `godot-wry-playwright/demo/demo.tscn`
    - visible 2D: `godot-wry-playwright/demo/ui_view_2d.tscn`
    - visible 3D: `godot-wry-playwright/demo/ui_view_3d.tscn`
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
- Then open `godot-wry-playwright/` in Godot and run (main scene is `res://demo/ui_view_2d.tscn`).

Notes:
- WSL2 cross-compile produces a **Windows-GNU** DLL. If Godot fails to load it due to missing runtime DLLs, prefer the **CI Windows artifact** (MSVC) from `.github/workflows/build-windows.yml`.

### Godot test suite conventions (add as we grow)

When adding automated Godot tests, keep them deterministic and avoid external network by default:

- Put tests under: `godot-wry-playwright/tests/` (scenes/scripts)
- Prefer a headless runner script (planned) and add per-test timeouts to avoid hung CI.
- For integration tests that require the network, mark them as “smoke” and keep them optional.

## 4) Build / Release Notes

- WSL2 → Windows DLL build: `scripts/build_windows_wsl.sh`
- Windows local copy step: `scripts/copy_bins.ps1`
- CI builds Windows artifact: `.github/workflows/build-windows.yml`
