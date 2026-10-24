# Stage 1: record the game's identity (store, build, exe SHA-256).
# Read-only against the install. Writes identity.json next to this script.
# From AGENTS.md rule 5: a write-up is only followed if it matches this identity.
param(
    [string]$InstallPath = ''
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-Install {
    param([string]$Hint)
    if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\ShadowOfMordor'),
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\ShadowOfMordor'),
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\Middle-earth Shadow of Mordor'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\Middle-earth Shadow of Mordor')
    )
    # also scan every Steam library declared in libraryfolders.vdf
    foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        $vdf = Join-Path $root 'Steam\steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches).Matches) {
                $p = $m.Groups[1].Value -replace '\\\\', '\'
                $candidates += @(
                    (Join-Path $p 'steamapps\common\ShadowOfMordor'),
                    (Join-Path $p 'steamapps\common\Middle-earth Shadow of Mordor')
                )
            }
        }
    }
    foreach ($c in $candidates) { if (Test-Path $c) { return (Resolve-Path $c).Path } }
    # ask Steam's library folders.vdf
    throw "Install not found. Re-run with: identity.ps1 -InstallPath <path to the game folder>"
}


$install = Find-Install -Hint $InstallPath
Write-Host "install: $install"

$exeRel = 'x64\ShadowOfMordor.exe'
$exe = Join-Path $install $exeRel
if (-not (Test-Path $exe)) {
    # some builds ship the exe at the root
    $alt = Join-Path $install 'ShadowOfMordor.exe'
    if (Test-Path $alt) { $exeRel = 'ShadowOfMordor.exe'; $exe = $alt }
    else { throw "exe not found under the install: $exe" }
}

$hash = (Get-FileHash $exe -Algorithm SHA256).Hash
$version = (Get-Item $exe).VersionInfo.FileVersion
$product = (Get-Item $exe).VersionInfo.ProductVersion
$size = (Get-Item $exe).Length
Write-Host "exe: $exeRel, $size bytes"
Write-Host "SHA-256: $hash"
Write-Host "FileVersion: $version  ProductVersion: $product"
Write-Host "OS: $([Environment]::OSVersion.VersionString)  x64: $([Environment]::Is64BitOperatingSystem)"

# Steam build id from the appmanifest beside the library
$libRoot = Split-Path -Parent (Split-Path -Parent $install)   # <library>\steamapps\common\X -> <library>\steamapps
$manifest = Get-ChildItem -Path $libRoot -Filter "appmanifest_241930.acf" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $manifest) {
    # game folder may not be named as expected: search every Steam library
    foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        $vdf = Join-Path $root 'Steam\steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches).Matches) {
                $p = $m.Groups[1].Value -replace '\\\\', '\'
                $f = Join-Path $p 'steamapps\appmanifest_241930.acf'
                if (Test-Path $f) { $manifest = Get-Item $f; break }
            }
        }
        if ($manifest) { break }
    }
}
$buildId = $null
if ($manifest) {
    $m = (Select-String -Path $manifest.FullName -Pattern '"buildid"\s+"(\d+)"')
    if ($m -and $m.Matches.Count -gt 0) {
        $buildId = $m.Matches[0].Groups[1].Value
        Write-Host "Steam buildid: $buildId (from $($manifest.Name))"
    } else {
        Write-Host 'Steam buildid: manifest found but no buildid line - record it by hand from steamdb.info/app/241930'
    }
} else {
    Write-Host "Steam buildid: not found (appmanifest_241930.acf missing) - record it by hand from steamdb.info/app/241930"
}

# DLC manifests (GOTY vs base) - content config decides the target build
$dlcs = @()
if ($manifest) {
    foreach ($f in (Get-ChildItem -Path (Split-Path -Parent $manifest.FullName) -Filter "appmanifest_*.acf" -ErrorAction SilentlyContinue)) {
        if ($f.Name -match 'appmanifest_(2\d{5})\.acf' -and $f.Name -ne 'appmanifest_241930.acf') {
            $dlcs += ($f.BaseName -replace 'appmanifest_', '')
        }
    }
}
Write-Host "other app manifests present (DLC family): $($dlcs -join ', ')"

$out = [ordered]@{
    game        = 'Middle-earth: Shadow of Mordor'
    store       = 'steam'
    appid       = 241930
    install     = $install
    exe_rel     = $exeRel
    exe_sha256  = $hash
    file_version = $version
    product_version = $product
    buildid     = $buildId
    os          = [Environment]::OSVersion.VersionString
    recorded    = (Get-Date).ToString('o')
}
$out | ConvertTo-Json | Out-File (Join-Path $here 'identity.json') -Encoding utf8
Write-Host "wrote $(Join-Path $here 'identity.json')"
