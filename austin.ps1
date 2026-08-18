#Requires -Version 5.1
<#
  AUSTIN - quick launcher.

  Starts the server using the venv that already exists. Unlike
  launch-windows.ps1 (which creates the venv, installs dependencies and runs
  setup on every run), this just starts the app - use it for day-to-day
  launching, and launch-windows.ps1 after pulling upstream changes.

  Usage:
    .\austin.ps1                      # http://127.0.0.1:7000, opens browser
    .\austin.ps1 -Port 7001           # different port
    .\austin.ps1 -NoBrowser           # don't open a browser
    .\austin.ps1 -BindHost 0.0.0.0    # LAN access (see the note below)

  Or just double-click austin.bat.

  Binding 0.0.0.0 exposes the app to your whole network. Keep AUTH_ENABLED=true
  in .env before doing that, and never expose the port straight to the internet.
#>
param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1",
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$venvPy = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
# Browser needs a connectable address; 0.0.0.0 is a bind target, not a destination.
if ($BindHost -eq "0.0.0.0") { $urlHost = "127.0.0.1" } else { $urlHost = $BindHost }
$url = "http://{0}:{1}" -f $urlHost, $Port

function Fail($msg, $hint) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    if ($hint) { Write-Host "       $hint" -ForegroundColor Yellow }
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# 1. The venv must already exist - this launcher deliberately does not build it.
if (-not (Test-Path $venvPy)) {
    Fail "No virtual environment found at venv\Scripts\python.exe." `
         "Run this once to create it:  powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1"
}

# 2. If the port is already serving Austin, don't fail with a cryptic bind error.
$inUse = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).Count -gt 0
if ($inUse) {
    $alreadyAustin = $false
    try {
        $resp = Invoke-WebRequest -Uri "$url/api/health" -UseBasicParsing -TimeoutSec 3
        if ($resp.StatusCode -eq 200) { $alreadyAustin = $true }
    } catch { }

    if ($alreadyAustin) {
        Write-Host ""
        Write-Host "AUSTIN is already running at $url" -ForegroundColor Green
        if (-not $NoBrowser) { Start-Process $url }
        Write-Host "Nothing to do. (Use -Port to run a second instance elsewhere.)"
        Write-Host ""
        exit 0
    }

    Fail "Port $Port is in use by something that isn't Austin." `
         "Pick another port:  .\austin.ps1 -Port 7001"
}

# 3. Open the browser once the server actually answers, not before.
$opener = $null
if (-not $NoBrowser) {
    $opener = Start-Job -ScriptBlock {
        param($target)
        for ($i = 0; $i -lt 180; $i++) {
            Start-Sleep -Milliseconds 500
            try {
                $r = Invoke-WebRequest -Uri "$target/api/health" -UseBasicParsing -TimeoutSec 2
                if ($r.StatusCode -eq 200) { Start-Process $target; return }
            } catch { }
        }
    } -ArgumentList $url
}

Write-Host ""
Write-Host "==> Starting AUSTIN at $url" -ForegroundColor Cyan
Write-Host "    Press Ctrl+C to stop."
Write-Host ""

try {
    # `python -m uvicorn` because the venv's Scripts dir usually isn't on PATH.
    & $venvPy -m uvicorn app:app --host $BindHost --port $Port
} finally {
    if ($opener) { Remove-Job -Job $opener -Force -ErrorAction SilentlyContinue }
}
