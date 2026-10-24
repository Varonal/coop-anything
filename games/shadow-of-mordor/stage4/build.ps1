# Stage 4 build: bink2w64.dll proxy (log-only probe), 64-bit, via llvm-mingw.
# Toolchain: MartinStorsjo.LLVM-MinGW.MSVCRT via winget (validated by the
# Divinity 2 stage1 work; see playbook/methods.md and that game's NOTES).
param(
    [string]$GameExeDir = (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a\x64'),
    [string]$MingwBin = ''
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $MingwBin) {
    $wingetPkg = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $found = Get-ChildItem -Path $wingetPkg -Filter 'MartinStorsjo.LLVM-MinGW*' -Directory -ErrorAction SilentlyContinue
    if ($found) {
        $MingwBin = (Get-ChildItem -Path $found[0].FullName -Recurse -Filter 'x86_64-w64-mingw32-gcc.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).DirectoryName
    }
    if (-not $MingwBin) {
        throw "llvm-mingw not found. Install it first (owner approval required):
  winget install MartinStorsjo.LLVM-MinGW.MSVCRT
then re-run, or pass -MingwBin <path to its bin folder>."
    }
}
$cc = Join-Path $MingwBin 'x86_64-w64-mingw32-gcc.exe'
if (-not (Test-Path $cc)) { throw "compiler not found: $cc" }
Write-Host "compiler: $cc"

# 1) The real Bink DLL must be renamed in the TEST copy only.
$orig = Join-Path $GameExeDir 'bink2w64.dll'
$renamed = Join-Path $GameExeDir 'bink2w64_orig.dll'
if (-not (Test-Path $orig)) {
    if (Test-Path $renamed) { Write-Host 'bink2w64.dll already renamed to _orig.' }
    else { throw "bink2w64.dll not found in $GameExeDir - point -GameExeDir at the TEST copy's x64 folder" }
} else {
    if (Test-Path $renamed) { throw 'both bink2w64.dll and bink2w64_orig.dll exist - clean up first' }
    Copy-Item $orig $renamed          # copy, do not move: the original file is preserved
    Write-Host "copied bink2w64.dll -> bink2w64_orig.dll (original left in place until our proxy is verified)"
}

# 2) Generate the forwarding .def from the ORIGINAL dll's exports
# (dumpbin-free: parse the PE export directory with PowerShell).
$bytes = [System.IO.File]::ReadAllBytes($renamed)
$peOff = [BitConverter]::ToInt32($bytes, 0x3C)
$optSize = [BitConverter]::ToUInt16($bytes, $peOff + 16)
$sectOff = $peOff + 24 + $optSize
$numSections = [BitConverter]::ToUInt16($bytes, $peOff + 6)
$sections = @()
for ($i = 0; $i -lt $numSections; $i++) {
    $o = $sectOff + 40 * $i
    $sections += [pscustomobject]@{
        vaddr = [BitConverter]::ToUInt32($bytes, $o + 12)
        vsize = [BitConverter]::ToUInt32($bytes, $o + 8)
        rawPtr = [BitConverter]::ToUInt32($bytes, $o + 20)
    }
}
$expDirRva = [BitConverter]::ToUInt32($bytes, $peOff + 24 + 112)
function Rva-ToFile {
    param([uint32]$rva)
    foreach ($s in $sections) {
        if ($rva -ge $s.vaddr -and $rva -lt ($s.vaddr + $s.vsize)) { return [long]($s.rawPtr + ($rva - $s.vaddr)) }
    }
    return -1
}
$expOff = Rva-ToFile $expDirRva
$ordBase = [BitConverter]::ToUInt32($bytes, $expOff + 16)
$numNames = [BitConverter]::ToUInt32($bytes, $expOff + 24)
$namesRva = [BitConverter]::ToUInt32($bytes, $expOff + 32)
$namesOff = Rva-ToFile $namesRva
$names = @()
for ($i = 0; $i -lt $numNames; $i++) {
    $nRva = [BitConverter]::ToUInt32($bytes, $namesOff + 4 * $i)
    $nOff = Rva-ToFile $nRva
    $sb = New-Object System.Text.StringBuilder
    for ($j = $nOff; $j -lt $bytes.Length; $j++) {
        if ($bytes[$j] -eq 0) { break }
        [void]$sb.Append([char]$bytes[$j])
    }
    $names += $sb.ToString()
}
Write-Host ("original bink2w64.dll exports: {0} named functions" -f $names.Count)

$defPath = Join-Path $here 'bink2coop.def'
$def = "LIBRARY bink2w64`n"
foreach ($n in $names) { $def += "$n=bink2w64_orig.$n`n" }
# ordinal-only exports would need @ord entries; named forwarding covers Bink
[System.IO.File]::WriteAllText($defPath, $def)
Write-Host "wrote $defPath"

# 3) Compile the proxy.
& $cc -shared -o (Join-Path $here 'bink2w64.dll') (Join-Path $here 'bink2coop.c') $defPath -luser32
if ($LASTEXITCODE -ne 0) { throw "gcc failed: $LASTEXITCODE" }
$h = (Get-FileHash (Join-Path $here 'bink2w64.dll') -Algorithm SHA256).Hash
Write-Host "built bink2w64.dll SHA-256: $h"

# 4) Sanity: PE32+ (x64) DLL.
$dllBytes = [System.IO.File]::ReadAllBytes((Join-Path $here 'bink2w64.dll'))
$dpe = [BitConverter]::ToInt32($dllBytes, 0x3C)
$machine = [BitConverter]::ToUInt16($dllBytes, $dpe + 4)
if ($machine -ne 0x8664) { throw 'built DLL is not x64!' }
Write-Host 'machine: 0x8664 (x64) OK'
Write-Host ''
Write-Host 'Next: install.ps1 places this proxy into the TEST copy and you launch the game from there.'
