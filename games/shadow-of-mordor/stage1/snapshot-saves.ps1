# Stage 1: hash every folder the game might write outside the test copy, so a
# test run can be PROVEN not to have touched the owner's real saves/config.
# From playbook/methods.md (Shadow of War pitfall): the game saves frequently and
# Steam's remote-storage service (steam.exe) writes into Steam userdata even with
# cloud off; back up AND hash before the first launch, compare after every run.
param(
    [switch]$Compare
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path


# Folders Shadow of Mordor (Steam 241930) may write outside its install.
# Confirmed for the sequel (Shadow of War) and reported for this game in 2025
# Steam forum posts; exact save folder for the current build is still unverified
# (NOTES.md unknowns) - so we hash every plausible location.
$targets = @(
    (Join-Path $env:LOCALAPPDATA 'WB Games'),
    (Join-Path $env:APPDATA 'WB Games'),
    (Join-Path $env:USERPROFILE 'Documents\WB Games'),
    (Join-Path $env:USERPROFILE 'Documents\Shadow of Mordor'),
    (Join-Path $env:USERPROFILE 'Saved Games\WB Games'),
    (Join-Path $env:PROGRAMDATA 'WB Games')
)
# Steam userdata for this app: Steam\userdata\<id>\241930
$steamRoots = @()
foreach ($s in @((Join-Path ${env:ProgramFiles(x86)} 'Steam'), (Join-Path $env:ProgramFiles 'Steam'))) {
    if (Test-Path (Join-Path $s 'userdata')) { $steamRoots += (Join-Path $s 'userdata') }
}
foreach ($ud in $steamRoots) {
    $appdirs = Get-ChildItem $ud -Directory -ErrorAction SilentlyContinue
    foreach ($u in $appdirs) {
        $a = Join-Path $u.FullName '241930'
        if (Test-Path $a) { $targets += $a }
    }
}

function Hash-Tree {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $rows = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
    $rows | ForEach-Object {
        $rel = $_.FullName.Substring($Path.Length + 1)
        $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        "{0}`t{1}`t{2}" -f $rel, $h, $_.Length
    }
}

if ($Compare) {
    $anyBefore = Get-ChildItem -Path $here -Filter 'saves-before__*.tsv' -ErrorAction SilentlyContinue
    if (-not $anyBefore) { throw "no 'before' snapshots in $here - run snapshot-saves.ps1 without -Compare first (before launching the game)" }
    $diffFound = $false
    foreach ($t in $targets) {
        $snap = Hash-Tree -Path $t
        $name = ($t -replace '[\\/:]', '_')
        $beforeFile = Join-Path $here ("saves-before__" + $name + ".tsv")
        $old = if (Test-Path $beforeFile) { @(Get-Content $beforeFile) } else { @() }
        $new = if ($snap) { @($snap) } else { @() }
        if ($old.Count -eq 0 -and $new.Count -eq 0) {
            Write-Host ("{0}: absent" -f $t)
            continue
        }
        $changed = Compare-Object -ReferenceObject $old -DifferenceObject $new
        $status = if ($changed) { 'CHANGED' } else { 'identical' }
        Write-Host ("{0}: {1} (before {2} files, after {3} files)" -f $t, $status, $old.Count, $new.Count)
        if ($changed) {
            $diffFound = $true
            $changed | Select-Object -First 10 | ForEach-Object { Write-Host ("   " + $_.InputObject) }
        }
    }
    if ($diffFound) {
        Write-Host ''
        Write-Host 'RESULT: CHANGES FOUND outside the test copy. If the game ran, it wrote to the'
        Write-Host 'owner real save/store folders - fix isolation before the next run (see'
        Write-Host 'playbook/methods.md: save-folder redirect and ISteamRemoteStorage write block).'
        exit 1
    }
    Write-Host 'RESULT: no changes - the test run stayed inside the test copy.'
    exit 0
}

# before snapshot
foreach ($t in $targets) {
    $name = ($t -replace '[\\/:]', '_')
    $out = Join-Path $here ("saves-before__" + $name + ".tsv")
    if (Test-Path $t) {
        Hash-Tree -Path $t | Out-File $out -Encoding utf8
        $n = @(Get-Content $out).Count
        Write-Host ("snapshot: {0} ({1} files) -> {2}" -f $t, $n, (Split-Path -Leaf $out))
    } else {
        Write-Host ("snapshot: {0} (absent)" -f $t)
    }
}
Write-Host ''
Write-Host 'Also make a BACKUP COPY of any folder that exists and has files, before the first launch:'
foreach ($t in $targets) {
    if (Test-Path $t) {
        $any = Get-ChildItem $t -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($any) {
            $bak = Join-Path $here ("backup__" + (($t -replace '[\\/:]', '_') ) + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
            Write-Host ("  COPY-ITEM `"{0}`" `"{1}`" -Recurse" -f $t, $bak)
        }
    }
}
Write-Host '(Backup commands are printed, not run: ask the owner where they want backups.)'
