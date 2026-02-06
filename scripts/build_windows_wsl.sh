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

# wry(WebView2) depends on WebView2Loader.dll at runtime.
# We fetch it from the NuGet package if it's not already present.
loader_dst="${dst_dir}/WebView2Loader.dll"
if [[ ! -f "${loader_dst}" ]]; then
  echo "Fetching WebView2Loader.dll from NuGet..."
  export DST_DIR="${dst_dir}"
  python3 - <<'PY'
import json
import os
import sys
import tempfile
import urllib.request
import zipfile

dst_dir = os.environ.get("DST_DIR")
if not dst_dir:
  print("DST_DIR env missing", file=sys.stderr)
  sys.exit(2)

index_url = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/index.json"
with urllib.request.urlopen(index_url) as r:
  data = json.load(r)

versions = data.get("versions") or []
if not versions:
  print("No versions found for Microsoft.Web.WebView2", file=sys.stderr)
  sys.exit(2)

version = versions[-1]
nupkg_url = f"https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/{version}/microsoft.web.webview2.{version}.nupkg"

with tempfile.TemporaryDirectory() as td:
  nupkg_path = os.path.join(td, "webview2.nupkg")
  urllib.request.urlretrieve(nupkg_url, nupkg_path)

  with zipfile.ZipFile(nupkg_path) as z:
    # Prefer 64-bit native loader.
    candidates = [
      n for n in z.namelist()
      if n.lower().endswith("webview2loader.dll")
    ]
    prefer = [n for n in candidates if "/x64/" in n.lower() or "\\x64\\" in n.lower()]
    pick = (prefer or candidates)
    if not pick:
      print("WebView2Loader.dll not found in NuGet package", file=sys.stderr)
      sys.exit(2)
    name = pick[0]
    out_path = os.path.join(dst_dir, "WebView2Loader.dll")
    with z.open(name) as src, open(out_path, "wb") as dst:
      dst.write(src.read())

print("Fetched WebView2Loader.dll")
PY
fi

echo "Copied: $dst"
