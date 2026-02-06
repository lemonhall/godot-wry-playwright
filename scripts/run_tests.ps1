param(
  [switch]$Quick,
  [switch]$SkipDoc,
  [switch]$SkipRust,
  [switch]$SkipSceneCheck,
  [switch]$RunGodotSmoke,
  [string]$GodotExe = $env:GODOT_WIN_EXE
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $RepoRoot

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )

  Write-Host "`n=== $Name ===" -ForegroundColor Cyan
  & $Action

  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Name (exit=$LASTEXITCODE)"
  }
}

function Invoke-Python {
  param(
    [Parameter(Mandatory = $true)][string[]]$Args
  )

  if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 @Args
    return
  }
  if (Get-Command python -ErrorAction SilentlyContinue) {
    & python @Args
    return
  }
  if (Get-Command python3 -ErrorAction SilentlyContinue) {
    & python3 @Args
    return
  }

  throw "Python executable not found (tried: py -3, python, python3)."
}

function Resolve-FirstExistingPath {
  param(
    [Parameter(Mandatory = $true)][string[]]$Candidates
  )

  foreach ($candidate in $Candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
  }
  return $null
}

try {
  if (-not $SkipDoc) {
    $docHygieneScript = Resolve-FirstExistingPath @(
      (Join-Path $RepoRoot "scripts/doc_hygiene_check.py"),
      "/home/lemonhall/.codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py",
      (Join-Path $env:USERPROFILE ".codex/skills/tashan-development-loop/scripts/doc_hygiene_check.py")
    )

    if ($null -eq $docHygieneScript) {
      Write-Host "Doc hygiene script not found; skipping doc gate (use -SkipDoc to silence)." -ForegroundColor Yellow
    }
    else {
      Invoke-Step -Name "Doc hygiene gate" -Action {
        Invoke-Python @($docHygieneScript, "--root", ".", "--strict")
      }
    }
  }

  if (-not $SkipRust) {
    Invoke-Step -Name "Rust tests: core" -Action {
      cargo test -p godot_wry_playwright_core
    }

    if (-not $Quick) {
      Invoke-Step -Name "Rust tests: pending requests" -Action {
        cargo test -p godot_wry_playwright --test pending_requests_test
      }
    }
  }

  if (-not $SkipSceneCheck) {
    Invoke-Step -Name "Scene static check" -Action {
      Invoke-Python @("scripts/check_texture3d_scene_requirements.py")
    }
  }

  if ($RunGodotSmoke) {
    if ([string]::IsNullOrWhiteSpace($GodotExe)) {
      throw "RunGodotSmoke requested but GODOT_WIN_EXE is empty. Set -GodotExe or env:GODOT_WIN_EXE."
    }
    if (-not (Test-Path $GodotExe)) {
      throw "Godot executable not found: $GodotExe"
    }

    $projectPath = Join-Path $RepoRoot "godot-wry-playwright"
    $scenes = @(
      "res://demo/headeless_demo.tscn",
      "res://demo/2d_demo.tscn",
      "res://demo/3d_demo.tscn"
    )

    foreach ($scene in $scenes) {
      $scenePath = $scene
      Invoke-Step -Name "Godot smoke: $scenePath" -Action {
        & $GodotExe --path $projectPath --scene $scenePath --quit-after 120
      }
    }
  }

  Write-Host "`nAll requested checks passed." -ForegroundColor Green
}
finally {
  Pop-Location
}
