# v2: Texture mode (3D simulated render, Windows-first)

## Goal

Add a third runtime mode that makes WebView content usable in 3D: capture the WebView as PNG frames and update a Godot `ImageTexture` for use on a mesh surface.

## PRD Trace

PRD Trace: REQ-011

Follow-up slice for scene integration and controls is tracked in:

- `docs/plan/v2-computer-scene-integration.md` (REQ-012/013/014/015)

## Scope

### In scope (v2 MVP)

- Windows-only backend that:
  - creates a WebView (WebView2) in a hidden native window
  - periodically captures the rendered content as PNG bytes
  - emits frames to GDScript
- A 3D demo scene that:
  - shows the captured frames on a cube face
  - simulates “top-to-bottom progressive render” when a new frame arrives (visual effect only)

### Out of scope (v2 MVP)

- High-FPS or low-latency rendering (this is a simulated capture pipeline).
- Full input mapping from 3D raycasts → webview mouse/keyboard events.
- Cross-platform capture APIs (macOS/iOS/WKWebView, Linux/WebKitGTK, Android WebView).

## Acceptance (binary)

- A1: In `res://demo/texture_3d.tscn`, the computer monitor overlay surface shows the `https://example.com` page.
- A2: The demo visually shows a “top-to-bottom reveal” effect when updating frames.
- A3: The plugin API keeps modes isolated: texture mode is a separate class/API surface (no breaking changes to `WryBrowser` / `WryView`).

Follow-up acceptance for model placement, camera controls, and key reload is defined in `docs/plan/v2-computer-scene-integration.md`.

## Verification

### Rust

- `cargo test -p godot_wry_playwright_core`
- `cargo test -p godot_wry_playwright`

### Windows build (WSL2)

- `bash scripts/build_windows_wsl.sh`

### Godot (Windows)

- Open `godot-wry-playwright/` in Godot 4.6
- Run `res://demo/texture_3d.tscn`

Expected:
- the cube face updates with captured frames
- console logs show frame arrivals (optional)

## Files

- Create: `crates/godot_wry_playwright/src/wry_texture_browser.rs`
- Modify: `crates/godot_wry_playwright/src/lib.rs`
- Create: `godot-wry-playwright/demo/texture_3d.tscn`
- Create: `godot-wry-playwright/demo/texture_3d.gd`
- Create: `godot-wry-playwright/demo/texture_reveal.gdshader`

## Steps (implementation outline)

1) Add a new GodotClass `WryTextureBrowser` (Windows-only backend) that emits `frame_png(png_bytes)` and `completed(...)` for commands.
2) Implement periodic capture using WebView2 `CapturePreview` into an in-memory stream and forward PNG bytes to Godot.
3) Add a 3D demo that:
   - calls `goto("https://example.com")`
   - updates a cube material from PNG bytes
   - uses a shader param to reveal from top-to-bottom.
