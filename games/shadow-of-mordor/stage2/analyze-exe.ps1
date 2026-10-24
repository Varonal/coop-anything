# Stage 2 — static analysis of the exe (Phase 3)
param(
    [string]$ExePath = '',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutDir) { $OutDir = Join-Path $here 'analysis' }
if (-not $ExePath) {
    # default: the exe of the TEST COPY (never the owner's install)
    $idJson = Join-Path $here '..\stage1\identity.json'
    $cand = @(
        (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a\x64\ShadowOfMordor.exe'),
        (Join-Path $env:LOCALAPPDATA 'Temp\som-test-a\ShadowOfMordor.exe')
    )
    $ExePath = $cand | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $ExePath) { throw "exe not found. Run stage1\make-test-copy.ps1 first, or pass -ExePath <path to ShadowOfMordor.exe> (use the TEST copy, never the real install)." }
}
if (-not (Test-Path $ExePath)) { throw "exe not found: $ExePath" }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Write-Host "exe: $ExePath"
$hash = (Get-FileHash $ExePath -Algorithm SHA256).Hash
Write-Host "SHA-256: $hash"
"$hash" | Out-File (Join-Path $OutDir 'exe-sha256.txt') -Encoding utf8

# --- PE parse: machine, sections, characteristics ---
$fs = [System.IO.File]::OpenRead($ExePath)
$br = New-Object System.IO.BinaryReader($fs)
$fs.Position = 0x3C
$peOff = $br.ReadInt32()
$fs.Position = $peOff + 4
$machine = $br.ReadUInt16()
$numSections = $br.ReadUInt16()
$fs.Position = $peOff + 20
$optMagic = $br.ReadUInt16()
$fs.Position = $peOff + 24 + 92
$imageBase = $br.ReadUInt64()
$optSize = 0
$fs.Position = $peOff + 20 + 16
$optSize = $br.ReadUInt16()
$sectOff = $peOff + 24 + $optSize
$sections = @()
for ($i = 0; $i -lt $numSections; $i++) {
    $fs.Position = $sectOff + 40 * $i
    $nameBytes = $br.ReadBytes(8)
    $name = ([System.Text.Encoding]::ASCII.GetString($nameBytes)).Trim([char]0)
    $vsize = $br.ReadUInt32(); $vaddr = $br.ReadUInt32(); $rawSize = $br.ReadUInt32(); $rawPtr = $br.ReadUInt32()
    $fs.Position = $sectOff + 40 * $i + 36
    $chars = $br.ReadUInt32()
    $sections += [pscustomobject]@{ name = $name; vaddr = ('0x{0:X}' -f $vaddr); vsize = $vsize; rawSize = $rawSize; rawPtr = ('0x{0:X}' -f $rawPtr); characteristics = ('0x{0:X8}' -f $chars) }
}
$br.Close(); $fs.Close()

Write-Host ("machine: 0x{0:X4} (0x8664 = x64)  optMagic: 0x{1:X4} (0x20B = PE32+)" -f $machine, $optMagic)
Write-Host ("imageBase: 0x{0:X}" -f $imageBase)
Write-Host "sections:"
$sections | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
$sections | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'sections.json') -Encoding utf8

# --- checks ---
$bytes = [System.IO.File]::ReadAllBytes($ExePath)
function Find-Ascii {
    param([byte[]]$b, [string]$s)
    $p = [System.Text.Encoding]::ASCII.GetBytes($s)
    for ($i = 0; $i -le $b.Length - $p.Length; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $p.Length; $j++) { if ($b[$i + $j] -ne $p[$j]) { $ok = $false; break } }
        if ($ok) { return $i }
    }
    return -1
}
$report = @()
foreach ($marker in @('.bind', 'SteamStub', '.bind Section', 'denuvo', 'DENUVO', 'ClientShellDLL', 'ObjectDLL', 'Game\Shared', 'NetMesh', 'debug_print', 'Faction.', 'ConsoleProgram', 'AddConsoleProgram', 'RandomFloat', 'RollResurrection')) {
    $off = Find-Ascii -b $bytes -s $marker
    $found = if ($off -ge 0) { $true } else { $false }
    $rva = 'n/a'
    if ($found) {
        # file offset -> RVA via sections (informational)
        foreach ($s in $sections) {
            $rp = [Convert]::ToInt64($s.rawPtr, 16)
            $va = [Convert]::ToInt64($s.vaddr, 16)
            if ($off -ge $rp -and $off -lt ($rp + $s.rawSize)) {
                $rva = '0x{0:X}' -f ($off - $rp + $va)
                break
            }
        }
        Write-Host ("   (in section, RVA ≈ {0})" -f $rva)
    }
    $report += [pscustomobject]@{ marker = $marker; found = $found; file_offset = ('0x{0:X}' -f $off); rva = $rva }
    Write-Host ("{0,-18} {1}" -f $marker, $(if ($found) { "FOUND at file offset 0x{0:X}" -f $off } else { 'not found' }))
}
$report | ConvertTo-Json | Out-File (Join-Path $OutDir 'markers.json') -Encoding utf8

# --- entropy per section (packed/encrypted code detection) ---
foreach ($s in $sections) {
    if ($s.name -in @('.text', '.arch', '.code', 'CODE', '.sdata', 'sdata')) {
        $rp = [Convert]::ToInt64($s.rawPtr, 16)
        $len = [Math]::Min($s.rawSize, $bytes.Length - $rp)
        if ($len -gt 0) {
            $freq = New-Object 'int[]' 256
            for ($i = 0; $i -lt $len; $i++) { $freq[$bytes[$rp + $i]]++ }
            $ent = 0.0
            foreach ($f in $freq) { if ($f -gt 0) { $p = $f / $len; $ent -= $p * [Math]::Log($p, 2) } }
            Write-Host ("entropy {0}: {1:N3} bits/byte (7.5+ = packed/encrypted, <6.5 = plain code)" -f $s.name, $ent)
            ("{0}`t{1:N3}" -f $s.name, $ent) | Out-File (Join-Path $OutDir 'entropy.tsv') -Append -Encoding utf8
        }
    }
}

Write-Host ''
Write-Host "analysis written to $OutDir"
Write-Host 'Paste the console output (and markers.json, sections.json) back to the agent.'
