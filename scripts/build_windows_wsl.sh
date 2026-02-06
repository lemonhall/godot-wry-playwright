#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

target_triple="x86_64-pc-windows-gnu"
dll_name="godot_wry_playwright.dll"

if ! command -v rustup >/dev/null 2>&1; then
  echo "rustup not found. Install Rust toolchain first." >&2
  exit 1
fi

if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "mingw-w64 not found. Install it:" >&2
  echo "  sudo apt update && sudo apt install -y mingw-w64" >&2
  exit 1
fi

rustup target add "$target_triple" >/dev/null

echo "Building Windows DLL ($target_triple)..."
cargo build -p godot_wry_playwright --release --target "$target_triple"

src="target/$target_triple/release/$dll_name"
dst_dir="godot-wry-playwright/addons/godot_wry_playwright/bin/windows"
dst="$dst_dir/$dll_name"

mkdir -p "$dst_dir"
cp -f "$src" "$dst"

echo "Copied: $dst"

