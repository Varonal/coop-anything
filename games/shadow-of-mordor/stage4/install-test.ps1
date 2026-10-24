# Stage 4 install + smoke test: place the proxy in the TEST copy, launch the
# game, wait, check som-coop.log exists and lists registry entries. The owner's
# real install is never touched; bink2w64_orig.dll stays beside the proxy so
# video playback keeps working.
param(
    [string]$GameExeDir = (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a\x64'),
    [int]$WaitSeconds = 45
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$proxy = Join-Path $here 'bink2w64.dll'
if (-not (Test-Path $proxy)) { throw "build first: stage4\build.ps1 (missing $proxy)" }

# snapshot the real save/config folders (stage 1 tool)
$snap = Join-Path $here '..\stage1\snapshot-saves.ps1'
& $snap
if ($LASTEXITCODE -ne 0) { throw 'save snapshot failed' }

Copy-Item $proxy (Join-Path $GameExeDir 'bink2w64.dll') -Force
Write-Host "proxy installed into $GameExeDir"

$logPath = Join-Path $GameExeDir 'som-coop.log'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

Write-Host "launching the game (window will open; let it reach the menu)..."
$p = Start-Process -FilePath (Join-Path $GameExeDir 'ShadowOfMordor.exe') -WorkingDirectory (Split-Path -Parent $GameExeDir) -PassThru
Write-Host "PID $($p.Id); waiting $WaitSeconds s..."
Start-Sleep -Seconds $WaitSeconds

$alive = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
Write-Host "game alive after ${WaitSeconds}s: $([bool]$alive)"
if (Test-Path $logPath) {
    Write-Host '--- som-coop.log (first 40 lines) ---'
    Get-Content $logPath -TotalCount 40 | ForEach-Object { Write-Host "  $_" }
    $count = (Get-Content $logPath | Select-String 'handler').Count
    Write-Host "registry entries logged: $count"
} else {
    Write-Host 'som-coop.log NOT written - the proxy did not run (or the windowed launch failed).'
}

if ($alive) {
    Write-Host 'Close the game yourself, then run:'
    Write-Host "  ..\stage1\snapshot-saves.ps1 -Compare"
}
