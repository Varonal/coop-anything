# Stage 3b — raw hexdump around each known console-string pointer anchor.
# No interpretation: for every .data address that stage 2 found pointing at a
# known console name, dump 0x80 bytes before and after, and annotate every
# 8-aligned qword that resolves into .rdata (as a string) or .text (as a code
# address). The entry layout is then read directly from the bytes.
param(
    [string]$ExePath = (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a\x64\ShadowOfMordor.exe'),
    [string]$RegistryJson = (Join-Path $PSScriptRoot '..\stage2\analysis\console-registry.json'),
    [string]$OutDir = (Join-Path $PSScriptRoot 'analysis')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $ExePath)) { throw "exe not found: $ExePath (use the TEST copy)" }
if (-not (Test-Path $RegistryJson)) { throw "run stage2\analyze-exe.ps1 first" }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$bytes = [System.IO.File]::ReadAllBytes($ExePath)
$peOff = [BitConverter]::ToInt32($bytes, 0x3C)
$optSize = [BitConverter]::ToUInt16($bytes, $peOff + 16)
$numSections = [BitConverter]::ToUInt16($bytes, $peOff + 6)
$sectOff = $peOff + 24 + $optSize
$sections = @()
for ($i = 0; $i -lt $numSections; $i++) {
    $o = $sectOff + 40 * $i
    $sections += [pscustomobject]@{
        name = ([System.Text.Encoding]::ASCII.GetString($bytes, $o, 8)).Trim([char]0)
        vaddr = [BitConverter]::ToUInt32($bytes, $o + 12)
        vsize = [BitConverter]::ToUInt32($bytes, $o + 8)
        rawSize = [BitConverter]::ToUInt32($bytes, $o + 16)
        rawPtr = [BitConverter]::ToUInt32($bytes, $o + 20)
    }
}
$text = $sections | Where-Object { $_.name -eq '.text' }
$rdata = $sections | Where-Object { $_.name -eq '.rdata' }
$data = $sections | Where-Object { $_.name -eq '.data' }
$imageBase = [BitConverter]::ToUInt64($bytes, $peOff + 24 + 24)

function Va-ToFile {
    param([UInt64]$va)
    $rva = $va - $imageBase
    foreach ($s in $sections) {
        if ($rva -ge $s.vaddr -and $rva -lt ($s.vaddr + $s.vsize)) { return [long]($s.rawPtr + ($rva - $s.vaddr)) }
    }
    return -1
}
function Read-CStr {
    param([long]$fileOff)
    if ($fileOff -lt 0 -or $fileOff -ge $bytes.Length) { return $null }
    $sb = New-Object System.Text.StringBuilder
    for ($i = $fileOff; $i -lt [Math]::Min($fileOff + 80, $bytes.Length); $i++) {
        if ($bytes[$i] -eq 0) { break }
        if ($bytes[$i] -ge 0x20 -and $bytes[$i] -le 0x7E) { [void]$sb.Append([char]$bytes[$i]) } else { break }
    }
    return $sb.ToString()
}

$reg = Get-Content $RegistryJson -Raw | ConvertFrom-Json
$out = New-Object System.Text.StringBuilder
foreach ($e in $reg) {
    foreach ($r in $e.ptr_rvas) {
        $hitRva = [Convert]::ToUInt64($r, 16)
        $hitFile = [long]$hitRva - $data.vaddr + $data.rawPtr
        [void]$out.AppendLine("=== $($e.name)  .data RVA 0x$('{0:X}' -f $hitRva)  (anchor qword should be the name ptr $($e.str_va)) ===")
        # 8-aligned window: from hit-0x80 to hit+0x88
        $startFile = [Math]::Max($data.rawPtr, $hitFile - 0x80 - ($hitFile % 8))
        for ($off = $startFile; $off -lt $hitFile + 0x88; $off += 8) {
            $rvaHere = $off - $data.rawPtr + $data.vaddr
            $q = [BitConverter]::ToUInt64($bytes, $off)
            $tag = ''
            $rel = ''
            if ($off -eq $hitFile) { $tag = ' <- anchor' }
            if ($q -gt $imageBase) {
                $r = $q - $imageBase
                if ($r -ge $text.vaddr -and $r -lt ($text.vaddr + $text.vsize)) { $tag += '  [.text]' }
                elseif ($r -ge $rdata.vaddr -and $r -lt ($rdata.vaddr + $rdata.vsize)) {
                    $str = Read-CStr (Va-ToFile $q)
                    $tag += "  [.rdata] ""$str"""
                }
            }
            [void]$out.AppendLine(("  +0x{0:X6}  {1}{2}" -f $rvaHere, ('0x{0:X16}' -f $q), $tag))
        }
        [void]$out.AppendLine('')
    }
}
$outFile = Join-Path $OutDir 'anchor-hexdump.txt'
$out.ToString() | Out-File $outFile -Encoding utf8
Write-Host $out.ToString()
Write-Host "written to $outFile"
