param(
  [Parameter(Mandatory = $false)]
  [ValidateSet("debug", "release")]
  [string]$Profile = "release"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$DllName = "godot_wry_playwright.dll"
$PdbName = "godot_wry_playwright.pdb"
$WebView2LoaderName = "WebView2Loader.dll"

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

function Ensure-WebView2Loader {
  param(
    [Parameter(Mandatory = $true)]
    [string]$DstPath
  )

  if (Test-Path $DstPath) { return }

  $indexUrl = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/index.json"
  $index = Invoke-RestMethod -Uri $indexUrl -Method Get
  $versions = $index.versions
  if (-not $versions -or $versions.Count -lt 1) {
    throw "Failed to get Microsoft.Web.WebView2 versions from NuGet"
  }

  $ver = $versions[$versions.Count - 1]
  $nupkgUrl = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$ver/microsoft.web.webview2.$ver.nupkg"
  $tmp = Join-Path $env:TEMP ("webview2.$ver.nupkg")

  Invoke-WebRequest -Uri $nupkgUrl -OutFile $tmp
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($tmp)
  try {
    $entries = $zip.Entries | Where-Object { $_.FullName -match 'WebView2Loader\.dll$' }
    $x64 = $entries | Where-Object { $_.FullName -match '/x64/' }
    $pick = if ($x64) { $x64[0] } else { $entries[0] }
    if (-not $pick) { throw "WebView2Loader.dll not found in NuGet package" }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($pick, $DstPath, $true)
  } finally {
    $zip.Dispose()
  }
}

$LoaderDst = Join-Path $DstDir $WebView2LoaderName
Ensure-WebView2Loader -DstPath $LoaderDst

Write-Host ("Copied " + $DllName + " to " + $DstDir)
