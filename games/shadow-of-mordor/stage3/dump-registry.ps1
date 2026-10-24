# Stage 3 — dump the console registry entries found by stage 2 (Phase 3).
# The registry lives in .data ON DISK; each entry is 0x40 bytes with the name
# pointer at +0. This script dumps every 0x40-byte entry around the known hits,
# resolves name strings, and flags qwords that point into .text (handler
# candidates). Read-only; runs on the test copy's exe.
param(
    [string]$ExePath = (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a\x64\ShadowOfMordor.exe'),
    [string]$RegistryJson = (Join-Path $PSScriptRoot '..\stage2\analysis\console-registry.json'),
    [string]$OutDir = (Join-Path $PSScriptRoot 'analysis')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $ExePath)) { throw "exe not found: $ExePath (use the TEST copy)" }
if (-not (Test-Path $RegistryJson)) { throw "run stage2\analyze-exe.ps1 first (missing console-registry.json)" }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# PE basics
$bytes = [System.IO.File]::ReadAllBytes($ExePath)
$peOff = [BitConverter]::ToInt32($bytes, 0x3C)
$optSize = [BitConverter]::ToUInt16($bytes, $peOff + 20 + 16)
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
$data = $sections | Where-Object { $_.name -eq '.data' }
$rdata = $sections | Where-Object { $_.name -eq '.rdata' }
$imageBase = [BitConverter]::ToUInt64($bytes, $peOff + 24 + 24)
Write-Host ("imageBase 0x{0:X}  .text vaddr 0x{1:X} vsize 0x{2:X}  .data vaddr 0x{3:X}" -f $imageBase, $text.vaddr, $text.vsize, $data.vaddr)

function Va-ToFile {
    param([UInt64]$va)
    $rva = $va - $imageBase
    foreach ($s in $sections) {
        if ($rva -ge $s.vaddr -and $rva -lt ($s.vaddr + $s.vsize)) {
            return [long]($s.rawPtr + ($rva - $s.vaddr))
        }
    }
    return -1
}
function Read-CStr {
    param([long]$fileOff)
    if ($fileOff -lt 0 -or $fileOff -ge $bytes.Length) { return $null }
    $sb = New-Object System.Text.StringBuilder
    for ($i = $fileOff; $i -lt [Math]::Min($fileOff + 64, $bytes.Length); $i++) {
        if ($bytes[$i] -eq 0) { break }
        if ($bytes[$i] -ge 0x20 -and $bytes[$i] -le 0x7E) { [void]$sb.Append([char]$bytes[$i]) } else { break }
    }
    if ($sb.Length -ge 2) { return $sb.ToString() }
    return $null
}

# Anchor entries from stage 2: use the LOWEST known hit RVA per name, then dump
# the whole neighborhood at 0x40 stride, from the lowest hit minus a margin.
$reg = Get-Content $RegistryJson -Raw | ConvertFrom-Json
$hitRvas = @()
foreach ($e in $reg) { foreach ($r in $e.ptr_rvas) { $hitRvas += [Convert]::ToUInt64($r, 16) } }
$hitRvas = $hitRvas | Sort-Object -Unique
$anchor = $hitRvas[0]
Write-Host ("{0} anchor pointer hits, lowest 0x{1:X}" -f $hitRvas.Count, $anchor)
# align down to 0x40 and walk a window of 64 entries before/after the span
# The registry grid is anchored on the hit RVAs themselves: real entries sit at
# (hit mod 0x40), which is 0x18 on this build. Walking from a 0x40-aligned base
# steps right past every real entry (that is exactly what happened on the first
# dumps). Anchor on the lowest hit and walk the stride from there.
$grid = [UInt64]$hitRvas[0] % 0x40
$spanFirst = [UInt64]($hitRvas[0] - 0x400)
$spanFirst = $spanFirst - ($spanFirst % 0x40) + $grid   # same residue as the hits
$spanLast = [UInt64]($hitRvas[-1] + 0x400)

$entries = @()
for ([UInt64]$rva = $spanFirst; $rva -le $spanLast; $rva += 0x40) {
    $fileOff = [long]$rva - $data.vaddr + $data.rawPtr
    if ($fileOff -lt 0 -or ($fileOff + 0x40) -gt ($data.rawPtr + $data.rawSize)) { continue }
    # qword 0 = name pointer (verified by the stage-2 hits)
    $nameVa = [BitConverter]::ToUInt64($bytes, $fileOff)
    $name = $null
    if ($nameVa -gt $imageBase) {
        $raw = Read-CStr (Va-ToFile $nameVa)
        # strict console-name shape: identifier chars only, 3-40 chars,
        # starts with a letter; kills CRT/vtable noise (";H", "A;C", "$8,4")
        if ($raw -and $raw -match '^[A-Za-z][A-Za-z0-9]{2,}(\.[A-Za-z0-9]+)*$' -and $raw.Length -le 40) { $name = $raw }
    }
    if (-not $name) { continue }
    # dump all qwords; flag those pointing into .text or .rdata
    $qwords = @()
    for ($k = 0; $k -lt 8; $k++) {
        $v = [BitConverter]::ToUInt64($bytes, $fileOff + 8 * $k)
        $kind = ''
        if ($v -gt $imageBase) {
            $r = $v - $imageBase
            if ($r -ge $text.vaddr -and $r -lt ($text.vaddr + $text.vsize)) { $kind = 'TEXT' }
            elseif ($r -ge $rdata.vaddr -and $r -lt ($rdata.vaddr + $rdata.vsize)) { $kind = 'rdata' }
        }
        $qwords += [pscustomobject]@{ off = ('+0x{0:X}' -f (8 * $k)); va = ('0x{0:X}' -f $v); kind = $kind }
    }
    $entries += [pscustomobject]@{
        entry_rva = ('0x{0:X}' -f $rva)
        name = $name
        qwords = $qwords
        text_ptrs = ($qwords | Where-Object { $_.kind -eq 'TEXT' } | ForEach-Object { $_.va })
    }
}

Write-Host ("{0} named entries dumped (strict name filter)" -f $entries.Count)
$entries | ConvertTo-Json -Depth 5 | Out-File (Join-Path $OutDir 'registry-entries.json') -Encoding utf8

# Detailed view of the 12 stage-2-confirmed console programs: show every qword
# so the handler offset (the qword that points into .text in ALL of them) is
# unambiguous.
$known = @('Player.Save','Player.GetPos','Player.SetOrientation','Teleport','NextSpawnPoint','PrevSpawnPoint','Game.SaveSlot.Show','Report.Memory','Camera.DumpInfo','Faction.SetTarget','Interrogation.Perform','PlayerUI.DumpMovieTree')
Write-Host ''
Write-Host '--- detailed: stage-2 confirmed entries ---'
foreach ($e in $entries) {
    if ($known -contains $e.name) {
        Write-Host ("{0}  {1}" -f $e.entry_rva, $e.name)
        foreach ($q in $e.qwords) { Write-Host ("    {0}  {1}  {2}" -f $q.off, $q.va, $q.kind) }
    }
}

Write-Host ''
Write-Host '--- all named entries (one line each) ---'
foreach ($e in $entries) {
    Write-Host ("{0,-12} {1,-40} text ptrs: {2}" -f $e.entry_rva, $e.name, ($e.text_ptrs -join ' '))
}
Write-Host ''
Write-Host "full dump: $OutDir\registry-entries.json"
Write-Host 'In the detailed block, the qword offset flagged TEXT in every confirmed entry is the handler pointer offset.'
