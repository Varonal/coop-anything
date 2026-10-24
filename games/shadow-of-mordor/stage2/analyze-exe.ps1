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
$optMagic = $br.ReadUInt16()          # PE32+ = 0x20B
$fs.Position = $peOff + 24 + 24       # PE32+ image base is at opt+24
$imageBase = $br.ReadUInt64()
$fs.Position = $peOff + 16           # SizeOfOptionalHeader is the COFF field at peOff+16
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
Write-Host ("sections: {0} (from the PE header)" -f $numSections)
foreach ($s in $sections) {
    $n = $s.name
    if ($n -notmatch '^[\x21-\x7E]+$') { $n = '(non-ascii: ' + (($s.name.ToCharArray() | ForEach-Object { '{0:X2}' -f [byte][char]$_ }) -join ' ') + ')' }
    Write-Host ("  {0,-10} vaddr {1}  vsize {2,10}  rawSize {3,10}  rawPtr {4}  chars {5}" -f $n, $s.vaddr, $s.vsize, $s.rawSize, $s.rawPtr, $s.characteristics)
}
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



# --- string dump of .rdata/.data: console programs, save paths, net symbols ---
Write-Host ''
Write-Host '--- string scan (looking for console programs, save paths, net symbols) ---'
function Section-Range {
    param($sections, [string]$name)
    foreach ($s in $sections) {
        if ($s.name -eq $name) {
            return @{ rawPtr = [Convert]::ToInt64($s.rawPtr, 16); rawSize = $s.rawSize }
        }
    }
    return $null
}
$stringHits = @()
foreach ($secName in @('.rdata', '.data')) {
    $r = Section-Range -sections $sections -name $secName
    if (-not $r) { continue }
    $chunk = New-Object byte[] $r.rawSize
    [Array]::Copy($bytes, $r.rawPtr, $chunk, 0, $r.rawSize)
    $text = [System.Text.Encoding]::ASCII.GetString($chunk)
    $patterns = @('Save', 'Load', 'Dump', 'Teleport', 'Faction', 'Quest', 'Console', 'Cheat', 'Game.', 'Player.', 'World.', 'Net', 'Host', 'Client', 'Session', 'wb games', 'WB Games', 'ShadowOfMordor', '.sav', 'Leaderboard', 'Vendetta', 'Nemesis')
    foreach ($pat in $patterns) {
        $idx = 0
        $count = 0
        while ($count -lt 6) {
            $i = $text.IndexOf($pat, $idx, [System.StringComparison]::OrdinalIgnoreCase)
            if ($i -lt 0) { break }
            $start = [Math]::Max(0, $i - 25)
            $len = [Math]::Min(100, $text.Length - $start)
            $frag = $text.Substring($start, $len)
            $frag = ($frag -replace '[^\x20-\x7E]', '.')
            $stringHits += ('{0}+0x{1:X}: {2}' -f $secName, ($r.rawPtr + $i), $frag)
            $count++
            $idx = $i + $pat.Length
        }
    }
}
$stringHits | Select-Object -Unique | Out-File (Join-Path $OutDir 'strings-hits.txt') -Encoding utf8
Write-Host ("{0} context hits written to strings-hits.txt (top lines below)" -f ($stringHits | Select-Object -Unique).Count)
$stringHits | Select-Object -Unique -First 25 | ForEach-Object { Write-Host ("  " + $_) }

# --- byte-signature scan (V7-derived, informational for V6) ---
Write-Host ''
Write-Host '--- byte signature scan (prologues of the V7 functions; V6 counterparts may differ slightly) ---'
$sigs = @(
    @{ name = 'RandomFloat (V7: 1B3C6C)';      hex = '48 83 EC 28 0F 28 C8 E8' },
    @{ name = 'HandleFactionEventAction (V7: 40C304)'; hex = '48 89 5C 24 08 48 89 6C 24 18 48 89 74 24 20 57 41 54 41 55 41 56 41 57 48 83 EC 70 4C 8B FA' },
    @{ name = 'RollResurrection (V7: 6DBD4C)'; hex = '48 89 5C 24 10 48 89 74 24 20 55 57 41 54 41 56 41 57 48 8B EC 48 83 EC 60 48 8B 99 28 02 00 00' },
    @{ name = 'LookupFactionMember (V7: 18DDCC)'; hex = '8B 52 08 E9 ? ? ? ? 48 8B 49 20' },
    @{ name = 'RecordName (V7: 18BDB0)';       hex = '48 85 C9 74 18 F6 41 01 02 74 12 48 8B 41 20' }
)
$sigReport = @()
foreach ($sig in $sigs) {
    $pattern = $sig.hex -split ' ' | ForEach-Object { if ($_ -eq '?') { 0x3F } else { [Convert]::ToByte($_, 16) } }
    $hits = @()
    for ($i = 0; $i -le $bytes.Length - $pattern.Count; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $pattern.Count; $j++) {
            if ($pattern[$j] -ne 0x3F -and $bytes[$i + $j] -ne $pattern[$j]) { $ok = $false; break }
        }
        if ($ok) { $hits += $i; if ($hits.Count -ge 5) { break } }
    }
    $sigReport += [pscustomobject]@{ signature = $sig.name; hits = $hits.Count; offsets = ($hits | ForEach-Object { '0x{0:X}' -f $_ }) }
    Write-Host ('{0,-45} {1} hit(s) {2}' -f $sig.name, $hits.Count, (($hits | ForEach-Object { '0x{0:X}' -f $_ }) -join ' '))
}
$sigReport | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'signatures.json') -Encoding utf8


# --- console registry hunt: find .data pointers to known console-program strings ---
Write-Host ''
Write-Host '--- console registry hunt (pointers in .data to console strings) ---'
# Console program names found by the string scan (V6 build 7348332).
$consoleNames = @('Player.Save', 'Player.GetPos', 'Player.SetOrientation', 'Teleport', 'NextSpawnPoint', 'PrevSpawnPoint', 'Game.SaveSlot.Show', 'Report.Memory', 'Camera.DumpInfo', 'Faction.SetTarget', 'Interrogation.Perform', 'PlayerUI.DumpMovieTree')
$dataSec = $sections | Where-Object { $_.name -eq '.data' }
$rdataSec = $sections | Where-Object { $_.name -eq '.rdata' }
if ($dataSec -and $rdataSec) {
    $dataPtr = [Convert]::ToInt64($dataSec.rawPtr, 16)
    $dataRva = [Convert]::ToInt64($dataSec.vaddr, 16)
    $rdataPtr = [Convert]::ToInt64($rdataSec.rawPtr, 16)
    $rdataRva = [Convert]::ToInt64($rdataSec.vaddr, 16)
    $imageBase64 = [Convert]::ToUInt64($imageBase)
    $regReport = @()
    foreach ($name in $consoleNames) {
        # find the string in .rdata (file bytes), compute its VA
        $pat = [System.Text.Encoding]::ASCII.GetBytes($name)
        $strOff = -1
        for ($i = $rdataPtr; $i -le $rdataPtr + $rdataSec.rawSize - $pat.Length; $i++) {
            $ok = $true
            for ($j = 0; $j -lt $pat.Length; $j++) { if ($bytes[$i + $j] -ne $pat[$j]) { $ok = $false; break } }
            if ($ok -and $bytes[$i + $pat.Length] -eq 0) { $strOff = $i; break }
        }
        if ($strOff -lt 0) { Write-Host ("  {0,-24} string not found" -f $name); continue }
        $strVa = $imageBase64 + [UInt64]($rdataRva + ($strOff - $rdataPtr))
        $needle = [BitConverter]::GetBytes([UInt64]$strVa)
        # scan .data for 8-byte pointers to that VA
        $hits = @()
        for ($i = $dataPtr; $i -le $dataPtr + $dataSec.rawSize - 8; $i += 4) {
            $ok = $true
            for ($j = 0; $j -lt 8; $j++) { if ($bytes[$i + $j] -ne $needle[$j]) { $ok = $false; break } }
            if ($ok) { $hits += $i; if ($hits.Count -ge 4) { break } }
        }
        $hitRvas = ($hits | ForEach-Object { '0x{0:X}' -f ($dataRva + ($_ - $dataPtr)) })
        $regReport += [pscustomobject]@{ name = $name; str_va = ('0x{0:X}' -f $strVa); ptr_hits = $hits.Count; ptr_rvas = $hitRvas }
        Write-Host ("  {0,-24} strVA 0x{1:X}  {2} pointer hit(s) in .data {3}" -f $name, $strVa, $hits.Count, ($hitRvas -join ' '))
    }
    $regReport | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'console-registry.json') -Encoding utf8
    if (($regReport | Where-Object { $_.ptr_hits -gt 0 }).Count -ge 3) {
        Write-Host 'Multiple pointer hits: likely the console registry. Adjacent entries share a stride;'
        Write-Host 'record the .data RVAs - the registry base and entry layout follow from them (stage 3).'
    }
}
Write-Host ''
Write-Host "analysis written to $OutDir"
Write-Host 'Paste the console output (and markers.json, sections.json) back to the agent.'
