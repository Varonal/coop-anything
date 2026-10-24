# Stage 1: copy the install into an isolated test folder. The source install is
# only READ. Per playbook/methods.md: never work on the owner's install; a copy at
# another path does not isolate saves (that is snapshot-saves.ps1's job to prove).
# Also records a file manifest of the copy so in-place edits are detectable.
$ErrorActionPreference = 'Stop'
param(
    [string]$InstallPath = '',
    [string]$Dest = (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a')
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path


if (-not $InstallPath) {
    $idJson = Join-Path $here 'identity.json'
    if (Test-Path $idJson) {
        $InstallPath = (Get-Content $idJson -Raw | ConvertFrom-Json).install
    } else {
        throw "run identity.ps1 first, or pass -InstallPath <game folder>"
    }
}
if (-not (Test-Path $InstallPath)) { throw "install not found: $InstallPath" }
$dest = $Dest
if (Test-Path $dest) { throw "dest already exists, refusing to overwrite: $dest (delete it yourself if you really want to)" }
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Write-Host "copying $InstallPath -> $dest (this can take a while)..."
Copy-Item -Path (Join-Path $InstallPath '*') -Destination $dest -Recurse -Force -Exclude 'redist'
Write-Host "copy done."

# manifest: relative path, size, mtime. Later re-runs with -ManifestOnly compare.
$files = Get-ChildItem -Path $dest -Recurse -File
Write-Host ("manifest: {0} files" -f $files.Count)
$manifestPath = Join-Path $here 'test-copy.manifest.tsv'
$files | ForEach-Object {
    $rel = $_.FullName.Substring($dest.Length + 1)
    "{0}`t{1}`t{2:O}" -f $rel, $_.Length, $_.LastWriteTimeUtc
} | Out-File $manifestPath -Encoding utf8
Write-Host "wrote $manifestPath"

# locate the exe in the copy and report its hash to prove the copy is faithful
$exeRel = 'x64\ShadowOfMordor.exe'
$exe = Join-Path $dest $exeRel
if (-not (Test-Path $exe)) { $exe = Join-Path $dest 'ShadowOfMordor.exe'; $exeRel = 'ShadowOfMordor.exe' }
if (-not (Test-Path $exe)) { throw "exe not found in the copy" }
$h = (Get-FileHash $exe -Algorithm SHA256).Hash
Write-Host "copy exe ($exeRel) SHA-256: $h"
$idHash = $null
$idJson = Join-Path $here 'identity.json'
if (Test-Path $idJson) { $idHash = (Get-Content $idJson -Raw | ConvertFrom-Json).exe_sha256 }
if ($idHash) {
    if ($h -eq $idHash) { Write-Host 'MATCHES identity.json exe hash - copy is faithful.' }
    else { Write-Host "WARNING: copy hash differs from identity.json ($idHash)!" }
}
Write-Host ''
Write-Host 'Next: run snapshot-saves.ps1 (before snapshot), then launch the test copy.'
