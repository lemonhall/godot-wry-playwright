param(
  [Parameter(Mandatory = $false)]
  [ValidateSet("debug", "release")]
  [string]$Profile = "release"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$DllName = "godot_wry_playwright.dll"
$PdbName = "godot_wry_playwright.pdb"

$SrcDir = Join-Path $RepoRoot ("target\" + $Profile)
$DstDir = Join-Path $RepoRoot "godot-wry-playwright\addons\godot_wry_playwright\bin\windows"

New-Item -ItemType Directory -Force -Path $DstDir | Out-Null

$DllSrc = Join-Path $SrcDir $DllName
$DllDst = Join-Path $DstDir $DllName
Copy-Item -Force $DllSrc $DllDst

$PdbSrc = Join-Path $SrcDir $PdbName
if (Test-Path $PdbSrc) {
  Copy-Item -Force $PdbSrc (Join-Path $DstDir $PdbName)
}

Write-Host ("Copied " + $DllName + " to " + $DstDir)

