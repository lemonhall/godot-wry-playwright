#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

: "${CARGO_HOME:=/tmp/godot-wry-playwright-cargo-home}"
: "${RUSTUP_HOME:=/tmp/godot-wry-playwright-rustup-home}"
export CARGO_HOME RUSTUP_HOME

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

# Ensure a usable toolchain exists inside $RUSTUP_HOME (we default it to /tmp in sandboxed envs).
rustup toolchain install stable --profile minimal >/dev/null
rustup default stable >/dev/null
rustup target add "$target_triple" >/dev/null

echo "Building Windows DLL ($target_triple)..."
cargo build -p godot_wry_playwright --release --target "$target_triple"

src="target/$target_triple/release/$dll_name"
dst_dir="godot-wry-playwright/addons/godot_wry_playwright/bin/windows"
dst="$dst_dir/$dll_name"

mkdir -p "$dst_dir"
cp -f "$src" "$dst"

# Bundle MinGW runtime DLLs so Godot can load the Windows-GNU build on a stock Windows machine.
runtime_dlls=(libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll)
for dll in "${runtime_dlls[@]}"; do
  dll_path="$(x86_64-w64-mingw32-gcc -print-file-name="$dll" || true)"
  if [[ -n "${dll_path}" && -f "${dll_path}" ]]; then
    cp -f "${dll_path}" "${dst_dir}/${dll}"
  fi
done

echo "Copied: $dst"
