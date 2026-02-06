param(
  [string]$GodotExe = $env:GODOT_WIN_EXE,
  [string]$ProjectPath = (Join-Path $PSScriptRoot "..\godot-wry-playwright"),
  [string]$One = "",
  [string]$Suite = "",
  [int]$TimeoutSec = 0,
  [string[]]$ExtraArgs = @(),
  [switch]$List,
  [switch]$NoHttpServer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ProjectPath = (Resolve-Path $ProjectPath).Path
$DefaultGodotExe = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
$IsolationRoot = Join-Path $RepoRoot ".godot-user"
$LogsRoot = Join-Path $IsolationRoot "test-logs"

function Resolve-GodotExe {
  param([string]$Explicit)

  $candidates = @(
    $Explicit,
    $env:GODOT_WIN_EXE,
    $DefaultGodotExe
  )

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      continue
    }
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  throw "Godot executable not found. Set -GodotExe or env:GODOT_WIN_EXE (default expected: $DefaultGodotExe)."
}

function Resolve-PythonCommand {
  if (Get-Command py -ErrorAction SilentlyContinue) {
    return @("py", "-3")
  }
  if (Get-Command python -ErrorAction SilentlyContinue) {
    return @("python")
  }
  if (Get-Command python3 -ErrorAction SilentlyContinue) {
    return @("python3")
  }

  throw "Python executable not found (tried: py -3, python, python3)."
}

function Find-FreeTcpPort {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
  $listener.Stop()
  return $port
}

function Ensure-IsolationEnv {
  New-Item -ItemType Directory -Force $IsolationRoot, $LogsRoot | Out-Null

  $env:APPDATA = Join-Path $IsolationRoot "AppData\Roaming"
  $env:LOCALAPPDATA = Join-Path $IsolationRoot "AppData\Local"
  $env:USERPROFILE = Join-Path $IsolationRoot "User"
  $env:HOME = $env:USERPROFILE

  New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null
}

function Convert-ToProjectRelativeTestPath {
  param(
    [Parameter(Mandatory = $true)][string]$InputPath
  )

  $candidate = $InputPath.Trim()
  if ($candidate -eq "") {
    throw "Test path cannot be empty."
  }

  if ($candidate.StartsWith("res://")) {
    $candidate = $candidate.Substring(6)
  }

  $candidate = $candidate.Replace("/", "\")

  if ([System.IO.Path]::IsPathRooted($candidate)) {
    $resolved = (Resolve-Path $candidate).Path
    $prefix = "$ProjectPath\"
    if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Test file must be inside project path: $resolved"
    }
    $candidate = $resolved.Substring($prefix.Length)
  }

  $candidate = $candidate.TrimStart(".", "\", "/")
  if (-not $candidate.StartsWith("tests\", [System.StringComparison]::OrdinalIgnoreCase)) {
    $candidate = "tests\$candidate"
  }

  $fullPath = Join-Path $ProjectPath $candidate
  if (-not (Test-Path $fullPath)) {
    throw "Test file not found: $candidate"
  }

  return $candidate.Replace("\", "/")
}

function Get-TestFiles {
  if (-not [string]::IsNullOrWhiteSpace($One)) {
    return @(Convert-ToProjectRelativeTestPath -InputPath $One)
  }

  $testsRoot = Join-Path $ProjectPath "tests"
  if (-not (Test-Path $testsRoot)) {
    throw "Tests directory not found: $testsRoot"
  }

  $files = Get-ChildItem -Path $testsRoot -Recurse -File -Filter "test_*.gd" |
    Sort-Object FullName |
    ForEach-Object {
      $absolute = $_.FullName
      $prefix = "$ProjectPath\"
      $relative = $absolute.Substring($prefix.Length)
      $relative.Replace("\", "/")
    }

  if (-not [string]::IsNullOrWhiteSpace($Suite)) {
    $suiteToken = $Suite.Trim().Replace("\", "/").ToLowerInvariant()
    $files = $files | Where-Object {
      $pathToken = $_.ToLowerInvariant()
      $pathToken.Contains("tests/$suiteToken/") -or ([System.IO.Path]::GetFileNameWithoutExtension($_)).ToLowerInvariant().Contains($suiteToken)
    }
  }

  return @($files)
}

function Start-LocalHttpFixtureServer {
  param(
    [Parameter(Mandatory = $true)][string]$ServePath
  )

  $pythonCommand = Resolve-PythonCommand
  $pythonExe = $pythonCommand[0]
  $pythonPrefixArgs = @()
  if ($pythonCommand.Count -gt 1) {
    $pythonPrefixArgs = $pythonCommand[1..($pythonCommand.Count - 1)]
  }

  $port = Find-FreeTcpPort
  $baseUrl = "http://127.0.0.1:$port"
  $httpOutLog = Join-Path $LogsRoot "http-fixture-server.out.log"
  $httpErrLog = Join-Path $LogsRoot "http-fixture-server.err.log"

  $httpArgs = @()
  $httpArgs += $pythonPrefixArgs
  $httpArgs += @("-m", "http.server", "$port", "--bind", "127.0.0.1", "--directory", $ServePath)

  $process = Start-Process -FilePath $pythonExe -ArgumentList $httpArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $httpOutLog -RedirectStandardError $httpErrLog

  $ready = $false
  for ($i = 0; $i -lt 40; $i++) {
    try {
      $probeUri = "$baseUrl/tests/fixtures/session_test_page.html"
      $request = [System.Net.WebRequest]::Create($probeUri)
      $request.Method = "HEAD"
      $request.Timeout = 2000
      $response = [System.Net.HttpWebResponse]$request.GetResponse()
      if ($null -ne $response -and [int]$response.StatusCode -ge 200) {
        $ready = $true
        $response.Close()
        break
      }
      if ($null -ne $response) {
        $response.Close()
      }
    }
    catch {
      Start-Sleep -Milliseconds 250
    }
  }

  if (-not $ready) {
    if (-not $process.HasExited) {
      Stop-Process -Id $process.Id -Force
    }
    throw "Failed to start local HTTP fixture server. See logs: $httpOutLog ; $httpErrLog"
  }

  return @{
    Process = $process
    BaseUrl = $baseUrl
  }
}

function Run-GodotTestFile {
  param(
    [Parameter(Mandatory = $true)][string]$Executable,
    [Parameter(Mandatory = $true)][string]$RelativeTestPath,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds
  )

  $safeName = $RelativeTestPath.Replace("/", "__").Replace("\\", "__")
  $logOutPath = Join-Path $LogsRoot "$safeName.out.log"
  $logErrPath = Join-Path $LogsRoot "$safeName.err.log"

  $godotArgs = @(
    "--headless",
    "--rendering-driver", "dummy",
    "--path", $ProjectPath,
    "--script", "res://$RelativeTestPath"
  )
  if ($ExtraArgs.Count -gt 0) {
    $godotArgs += $ExtraArgs
  }

  $argListForLog = $godotArgs | ForEach-Object {
    if ($_ -match "\s") { "`"$_`"" } else { $_ }
  }
  $argLine = ($argListForLog -join " ")
  $invokeScript = @"
`$ErrorActionPreference = 'Continue'
try {
  & `"$Executable`" $argLine 1> `"$logOutPath`" 2> `"$logErrPath`"
  `$exitCode = `$LASTEXITCODE
}
catch {
  `$exitCode = if (`$LASTEXITCODE -ne `$null) { `$LASTEXITCODE } else { 1 }
}
if (`$exitCode -eq `$null) { `$exitCode = 0 }
Set-Content -Encoding ascii `"$logOutPath.exitcode`" ([string]`$exitCode)
exit [int]`$exitCode
"@

  $runnerScriptPath = Join-Path $LogsRoot "$safeName.runner.ps1"
  Set-Content -Encoding utf8 $runnerScriptPath $invokeScript

  Write-Host "`n--- RUN $RelativeTestPath" -ForegroundColor Cyan
  $runnerProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @("-ExecutionPolicy", "Bypass", "-File", $runnerScriptPath) -PassThru -WindowStyle Hidden
  $finished = $runnerProcess.WaitForExit($TimeoutSeconds * 1000)

  if (-not $finished) {
    try {
      Stop-Process -Id $runnerProcess.Id -Force -ErrorAction Stop
    }
    catch {
    }
    return @{
      Test = $RelativeTestPath
      Passed = $false
      Reason = "timeout"
      LogPath = "$logOutPath ; $logErrPath"
      ExitCode = -1
    }
  }

  $logText = ""
  if (Test-Path $logOutPath) {
    $logText += Get-Content -Raw $logOutPath
  }
  if (Test-Path $logErrPath) {
    $logText += "`n"
    $logText += Get-Content -Raw $logErrPath
  }

  $exitCode = 0
  $exitCodePath = "$logOutPath.exitcode"
  if (Test-Path $exitCodePath) {
    $rawExitCode = (Get-Content -Raw $exitCodePath).Trim()
    if (-not [int]::TryParse($rawExitCode, [ref]$exitCode)) {
      $exitCode = $runnerProcess.ExitCode
    }
  }
  else {
    $exitCode = $runnerProcess.ExitCode
  }

  $hasFailMarker = $logText.Contains("TEST_FAIL")
  $passed = ($exitCode -eq 0) -and (-not $hasFailMarker)

  if ($passed) {
    Write-Host "PASS: $RelativeTestPath" -ForegroundColor Green
  }
  else {
    Write-Host "FAIL: $RelativeTestPath (exit=$exitCode)" -ForegroundColor Red
    $tail = ""
    if (Test-Path $logOutPath) {
      $tail = (Get-Content $logOutPath -Tail 20) -join "`n"
    }
    if (Test-Path $logErrPath) {
      $errTail = (Get-Content $logErrPath -Tail 20) -join "`n"
      if ($errTail -ne "") {
        $tail = "$tail`n$errTail"
      }
    }
    if ($tail -ne "") {
      Write-Host $tail -ForegroundColor DarkYellow
    }
  }

  return @{
    Test = $RelativeTestPath
    Passed = $passed
    Reason = if ($passed) { "" } else { "failed" }
    LogPath = "$logOutPath ; $logErrPath"
    ExitCode = $exitCode
  }
}

try {
  $resolvedGodotExe = Resolve-GodotExe -Explicit $GodotExe

  if ($TimeoutSec -le 0) {
    $envTimeout = 0
    if ([int]::TryParse($env:GODOT_TEST_TIMEOUT_SEC, [ref]$envTimeout) -and $envTimeout -gt 0) {
      $TimeoutSec = $envTimeout
    }
    else {
      $TimeoutSec = 120
    }
  }

  Ensure-IsolationEnv

  $tests = @(Get-TestFiles)
  if ($tests.Count -eq 0) {
    throw "No tests selected."
  }

  if ($List) {
    Write-Host "Selected tests:"
    foreach ($test in $tests) {
      Write-Host " - $test"
    }
    return
  }

  $serverProcess = $null
  if (-not $NoHttpServer) {
    $server = Start-LocalHttpFixtureServer -ServePath $ProjectPath
    $serverProcess = $server.Process
    $env:GODOT_TEST_HTTP_BASE_URL = $server.BaseUrl
    Write-Host "HTTP fixture server: $($server.BaseUrl)"
  }
  else {
    $env:GODOT_TEST_HTTP_BASE_URL = ""
  }

  Write-Host "Godot executable: $resolvedGodotExe"
  Write-Host "Project path: $ProjectPath"
  Write-Host "Timeout (sec): $TimeoutSec"
  Write-Host "Total tests: $($tests.Count)"

  $results = @()
  foreach ($test in $tests) {
    $results += Run-GodotTestFile -Executable $resolvedGodotExe -RelativeTestPath $test -TimeoutSeconds $TimeoutSec
  }

  $failed = @($results | Where-Object { -not $_.Passed })
  if ($failed.Count -gt 0) {
    Write-Host "`nGodot test suite failed ($($failed.Count)/$($results.Count))" -ForegroundColor Red
    foreach ($item in $failed) {
      Write-Host " - $($item.Test) [$($item.Reason)] log=$($item.LogPath)" -ForegroundColor Red
    }
    exit 1
  }

  Write-Host "`nAll Godot tests passed ($($results.Count)/$($results.Count))." -ForegroundColor Green
}
finally {
  if (Get-Variable -Name serverProcess -ErrorAction SilentlyContinue) {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
      Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
    }
  }
}
