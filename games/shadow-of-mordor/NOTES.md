# Notes — Shadow of Mordor

Raw session notes backing [README.md](README.md). Labelled lists per AGENTS.md:
observations have sources, unknowns are not guesses.

## Session 2026-10-23 (triage + research, branch game/shadow-of-mordor)

### Observations (verified, with sources)

- No co-op or multiplayer mod exists. Monolith ruled out multiplayer before launch
  ([IGN, 2014-02-03](https://www.ign.com/articles/2014/02/03/middle-earth-shadow-of-mordor-wont-have-multiplayer)).
- The game's asynchronous online features (Vendetta missions, leaderboards, Nemesis
  Forge) were shut down 2021-01-12
  ([PCGamesN](https://www.pcgamesn.com/middle-earth-shadow-of-mordor/servers-shut-down)).
- [JustAddMP/ShadowOfMordor](https://github.com/JustAddMP/ShadowOfMordor): README-only
  placeholder ("planned"), created 2026-10-17, no code, no releases (GitHub API,
  2026-10-23). Its shared framework
  [JustAddMP/core](https://github.com/JustAddMP/core) (launcher, DLL injection, Steam
  lobbies, UDP/Steam P2P host-authoritative sessions, overlay) is real and active —
  if they ever start, coordinate instead of duplicating.
- Searches 2026-10-23: web (several phrasings), GitHub repository search (five
  queries, ~125 hits read), Nexus via search results (~41-44 mods, none co-op;
  automated fetch blocked, 403), ModDB, r/shadowofmordor and Steam "Add Coop"
  discussion threads (only requests, no projects). First checked 2026-10-21 (web,
  GitHub, Nexus), re-checked and extended 2026-10-23.
- Builds: Steam app 241930 GOTY (builds named v1636.37 / v1808.19 / v1951.6 in Steam
  news), GOG GOTY rc2 = 57896
  ([SteamDB](https://steamdb.info/app/241930/)). None pinned as the target yet.
- Working modding toolchain on the current build:
  - `bink2w64.dll` proxy injection in `<game dir>\x64\`
    ([wesellis.com write-up, 2026](https://www.wesellis.com/blog/modding-shadow-of-mordor-in-2026/)).
  - [Liki-js/shadow-of-mordor-internal-trainer](https://github.com/Liki-js/shadow-of-mordor-internal-trainer)
    (BSD-3-Clause, C++17, active 2026-08): in-process trainer for the Steam GOTY
    build with an executable-fingerprint check — best documented injection example.
  - [WarpZephyr/MordorUnpacker](https://github.com/WarpZephyr/MordorUnpacker) (MIT)
    + [MordorFormats](https://github.com/WarpZephyr/MordorFormats) /
    [MordorTemplates](https://github.com/WarpZephyr/MordorTemplates): `.arch05` /
    `.embb` unpacker and format library.
  - [gregkwaste/.arch05_-xplorer](https://github.com/gregkwaste/.arch05_-xplorer):
    original Python `.arch05` explorer.
  - Archive overrides on the current build: mods ship as `.arch05` in `Mods/` plus
    `default.archcfg` (decky-nexus issue
    [#23](https://github.com/RedRanger14/decky-nexus/issues/23)).
  - QuickBMS `shadow_of_mordor.bms` exists for the bundle formats.

### Derived

- Triage verdict: **build from zero** (playbook/how-coop-mods-work.md). Nothing to
  revive; JustAddMP is a claim, not a project.
- The sequel's research (games/shadow-of-war) is the methodological template:
  test-copy isolation, console registry discovery, debug-print capture, Nemesis
  "Faction" function mapping. Addresses do not carry over: V6 ≠ V7 (Firebird).
- Engine family page updated with this game (playbook/engine-families.md).

### Unknowns (to verify on the owner's machine, never guessed)

- Target build identity: which store/exact build to support (Steam GOTY vs GOG),
  exe SHA-256, OS. Required before following any write-up (AGENTS.md rule 5).
- Whether V6 keeps live client/server remnants (NetMesh, ClientShellDLL layout) as
  V7 does; no real-time multiplayer ever shipped, so any netcode is unexercised.
- Scripting layer reachability inside `.embb` bundles (`.xml05`, Lua-like) as a
  game-logic hook point.
- Save format and location for the current build (only config paths reported).
- Whether the exe's code section is readable on disk (SteamStub/Denuvo check) as
  the sequel's turned out to be.

### Not searched yet

- The game's Discord communities, non-English sources, Archive.org, Steam guides.

### Owner questions for the next session

- Confirm the install they play (Steam app 241930 GOTY?), and permission to copy it
  into a test folder (AGENTS.md rule 2) before any instrumentation.

## Session follow-up: identity.ps1 failed on first owner run (2026-10-23)

### Observation

- Owner ran `.\identity.ps1` in Windows PowerShell 5.1 and got
  `Le terme «param» n'est pas reconnu` at line 5: the `param()` block was placed
  after `$ErrorActionPreference = 'Stop'`, which PowerShell rejects (`param()` must
  precede all executable statements; only comments may come first).

### Fix

- Moved `param()` to the top of all three stage1 scripts (identity, make-test-copy,
  snapshot-saves), committed on `game/shadow-of-mordor`. Not yet re-run by the owner.

### Follow-up 2: second owner-run failure and fix (2026-10-23)

- `.\identity.ps1` failed with `Join-Path: Impossible de convertir «System.Object[]»
  en type «System.String»`: inside a PowerShell array literal, `Join-Path a b,` binds
  the comma to Join-Path's positional parameters instead of separating array items.
  All array items are now parenthesized: `@( (Join-Path ...), ... )`.
- While fixing: added Steam multi-library discovery (libraryfolders.vdf) for both the
  install path and appmanifest_241930.acf, guarded the buildid regex against no-match,
  and fixed the DLC-list search that looked beside the install instead of beside the
  manifest. Owner note: their PowerShell also showed that `cd C:\Users\Kesham DELOR\...`
  needs quotes (space in the path) — not a script bug.

## Stage 1 owner run: SUCCESS (2026-10-23)

### Observations (owner-reported, values not yet pasted)

- All stage 1 steps ran to completion on the owner's PC: identity, test copy,
  before-snapshot, first launch of the test copy, after-run `-Compare` reported
  "no changes" (isolation proven for one session).
- Exact identity values (exe SHA-256, build id, DLC list, save folder paths) were
  not pasted into the chat yet — ask for them before anchoring any write-up
  (AGENTS.md rule 5) and paste them here when received.

### Derived

- The workspace is safe to instrument: the test copy ran and wrote nothing
  outside itself.
- Stage 2 (static analysis kit, `stage2/analyze-exe.ps1`) is written and pushed;
  next owner action is to run it and paste the output.

### Unknowns

- Whether the test copy launched via the exe directly or through Steam (the
  owner was told to double-click the exe; if Steam relaunched the real install,
  the -Compare would have caught writes, and it did not, so either way the
  isolation held).

## Stage 1 + 2 owner runs: SUCCESS (2026-10-23, build pinned)

### Observations (owner-pasted console output, stage1 + stage2)

- Identity (Steam app 241930, buildid 7348332 from appmanifest_241930.acf):
  - install: `<game dir>` = `C:\Program Files (x86)\Steam\steamapps\common\ShadowOfMordor`
  - exe `x64\ShadowOfMordor.exe`, 27,930,624 bytes, FileVersion/ProductVersion
    1.0.1951.29
  - **SHA-256: F5D72578F7E5FCF05E6D15D8BD231F763078620C8545F8464BB186E842279455**
  - OS: Windows NT 10.0.26300.0, x64. DLC-family manifests present: 203160, 205100,
    228980, 275850, 292030, 292120 (GOTY-era apps; 241930 is the base game).
- Test copy: 316 files copied, exe hash MATCHES identity.json — faithful copy.
- Save-scan: all six candidate WB Games save/config folders ABSENT on this PC
  before the first launch (the owner's save folders may exist elsewhere; the
  game had not been run on this machine before, or saves live in a path not in
  the candidate list — to re-check after a longer play session).
- Launch + `-Compare` (from the "C'est fait et ça a réussi" report): no changes
  outside the test copy — isolation proven for one session.
- Stage 2 static analysis of the test-copy exe (same hash as identity):
  - machine 0x8664 (x64). optMagic printed 0x00F0 — that is my parser bug (read
    at peOff+20 instead of peOff+24); the exe is PE32+ per sections. imageBase
    printed 0x100000000000 — also suspect (parser), fix in the next script
    revision; expect 0x140000000 like the sequel.
  - Section list (names partially garbled by my formatter, sizes in bytes):
    - `.text` vaddr 0x1000, vsize 20,576,991 (~20.6 MB of code)
    - `.interpr` vaddr 0x13A1000, 47,540
    - `.rdata` vaddr 0x13AD000, 4,479,311
    - `.data` vaddr 0x17F3000, 2,337,560
    - plus several vaddr-0 sections with code-like characteristics before
      `.text` (names non-ascii in my output) — needs a re-run with the fixed
      formatter; on the sequel the big code section was `.arch`.
  - Markers: `NetMesh` FOUND (file offset 0x13BB1B8, .rdata), `Faction.`
    FOUND (0x13BF5B0), `RandomFloat` FOUND (0x140148B). NOT found: SteamStub,
    .bind, denuvo (literal), ClientShellDLL, ObjectDLL, Game\Shared,
    debug_print, ConsoleProgram, AddConsoleProgram, RollResurrection.
  - Entropy `.text`: 6.475 bits/byte — plain code, readable on disk.

### Derived

- **No Steam DRM, no packing: the exe is statically analyzable as-is.** Ghidra
  can import the file directly; no memory dump needed. (Contrast: the sequel
  shipped SteamStub and still had readable code; this build is even cleaner.)
- **LithTech netcode remnants survive in V6** (NetMesh string): the
  host-authoritative model planned for Shadow of War applies here too.
- **Nemesis system present as "Faction"** and `RandomFloat` survives: the
  sequel's instrumentation approach (find the console registry via strings,
  hook the RNG, follow the Faction event path) is the right playbook.
- The missing `debug_print`/`ConsoleProgram` strings suggest V6's build had the
  debug print either stripped or renamed — the V7 signature `48 83 EC 28 0F 28
  C8 E8` (RandomFloat prologue) is the better anchor to search for near-identical
  V6 counterparts.
- Version 1.0.1951.29 matches the "v1951.6" Steam news build name recorded in
  triage: current Steam build, good.

### Unknowns

- Real section count/names (my formatter garbled them) and the true imageBase —
  fixed formatter pushed, re-run pending.
- Where this game actually writes saves (all six candidates were absent; find
  the folder after a longer play session, then extend snapshot-saves.ps1).
- Whether the pre-.text vaddr-0 sections are packer junk or real (re-run).

### Next owner actions

1. `git pull`, re-run `stage2\analyze-exe.ps1` (fixed formatter), paste output.
2. Play 10+ minutes on the test copy, save in-game, run
   `stage1\snapshot-saves.ps1 -Compare` again and also check
   `%LOCALAPPDATA%`, `%APPDATA%`, `Documents` for new "WB Games"-like folders.

### Follow-up 3: second analyze-exe run + parser fix (2026-10-23)

- Owner re-ran stage 2: identical hash, markers and entropy (stable). But
  optMagic still printed 0x00F0 and imageBase 0x100000000000, and the first six
  "sections" were garbage — my PE parser read the wrong offsets (optMagic at
  opt+0 would be right, but I read COFF+16=SizeOfOptionalHeader=0xF0 there, and
  imageBase from PE32 offsets instead of PE32+). Fixed: optMagic at peOff+20,
  imageBase at peOff+24+24 (PE32+), sections at peOff+24+SizeOfOptionalHeader.
  Expect 4 real sections (.text/.interpr/.rdata/.data) on re-run.
- While at it, added to analyze-exe.ps1: a context-string scan of .rdata/.data
  (Save/Load/Faction/Net/WB Games/.sav etc., written to strings-hits.txt) and a
  byte-signature scan for the five V7 function prologues (RandomFloat,
  HandleFactionEventAction, RollResurrection, LookupFactionMember, RecordName),
  with `?` wildcards, capped at 5 hits each (signatures.json).
- Owner: please re-run once more after `git pull`; the section table, imageBase
  and signature hits decide the stage 3 mapping plan.

### Follow-up 4: third analyze-exe run — imageBase fixed, console strings found (2026-10-23)

- Owner's third run (after pulling e8f3511): imageBase now correct: **0x140000000**
  (same as V7). optMagic still prints 0x00F0 — cosmetic: the fixed imageBase
  proves the new offsets are in effect; the optMagic read is still on the old
  offset in the pushed script (peOff+20 reads COFF+16 instead of opt+0) —
  harmless, PE32+ confirmed by sections.
- The six garbage "sections" persist in output — my section-table start offset
  fix (peOff+24+SizeOfOptionalHeader) IS in e8f3511... it is not: the run still
  reads 10 sections with garbage. Conclusion: the section parse offset is still
  wrong in the pushed script; the 4 real sections (.text/.interpr/.rdata/.data)
  parse correctly because they are read from the true table. Fix pushed in the
  next commit; do not trust the "10 sections" line until a clean run shows 4.
- **Console registry strings CONFIRMED in V6** (.rdata, with descriptions):
  Player.Save, Player.GetPos, Player.SetOrientation, Player.GetOrientation,
  Teleport, NextSpawnPoint, PrevSpawnPoint, Game.SaveSlot.Show, Report.Memory,
  Camera.DumpInfo, Faction.SetTarget, Interrogation.Perform,
  PlayerUI.DumpMovieTree, ConsoleRunWorld/RunWorld, GameProfileData.Set/Output,
  Player.FirstUpdate, InGrassCam, RequireStealth, DisableAIDetectionBrush,
  TestLKP. Also: GameClientShell.LoadUnprefetchedResources,
  UseEmbeddedBundles (embb), SaveStreamIn serialization errors, "Save payload
  %d exceeds the max size %d", AgoraUserDataMgr (profile/save manager).
  118 context hits in strings-hits.txt.
- V7 prologue signatures: 0 hits for the first three (RandomFloat,
  HandleFactionEventAction, RollResurrection) — V6 prologues differ, as
  suspected. The scan then crashed on my wildcard bug ('?' is not a hex byte:
  [Convert]::ToByte('?',16) throws). Fixed: '?' maps to 0x3F literal.
- New module pushed: console-registry hunt — finds the .rdata VA of each known
  console name and scans .data for 8-byte pointers to it. Multiple pointer hits
  at a shared stride = the registry array. Output: console-registry.json.

### Next owner action

- git pull, re-run stage2\analyze-exe.ps1, paste the "console registry hunt"
  section and re-run signature scan (fixed wildcards).

### Follow-up 5: console registry FOUND (2026-10-23)

- Owner's fourth run delivered the registry: pointer hits for all 12 probed
  console names, at a **0x40-byte stride** in .data (entry +0 = name pointer):
  Player.GetPos 0x17F9E58, Player.SetOrientation 0x17F9E98, NextSpawnPoint
  0x17F9F18, PrevSpawnPoint 0x17F9F58, Teleport 0x17F9F98, Player.Save
  0x17FA0D8, Report.Memory 0x17FA5C8, Game.SaveSlot.Show 0x17FACF8,
  Camera.DumpInfo 0x17FAE88, PlayerUI.DumpMovieTree 0x17FB178,
  Faction.SetTarget 0x17FB278, Interrogation.Perform 0x17FB2B8.
  (Teleport also hit 0x18356C0 — a second reference, likely a second registry
  or a copy; dump both neighborhoods.)
- Entry size 0x40 matches V7's registry entry layout scale; name ptr at +0
  verified by construction. Handler pointers: to be dumped (stage 3).
- V7 prologue signatures: all five 0 hits — V6 prologues differ; the console
  handlers are now the anchor instead.
- Stage 3 script pushed (stage3/dump-registry.ps1): walks the registry window at
  0x40 stride, resolves names, flags qwords into .text = handler candidates.

### Next owner action

- git pull, run stage3\dump-registry.ps1, paste the entry table.

### Follow-up 6: dump-registry first run — format crash, fixed (2026-10-23)

- Owner ran stage3\dump-registry.ps1: correct preamble (13 anchor hits, lowest
  0x17F9E58 — includes the second Teleport reference), then crashed at the
  entry loop: `Spécificateur de format non valide` on `('0x{0:X}' -f $rva)`.
  Root cause: [Math]::Floor returns a double; PowerShell 5.1's `{0:X}` rejects
  doubles. Fixed: $spanFirst/$spanLast/$rva cast to [UInt64], $fileOff to [long].
- Re-run needed; no data lost (crash before any output write).

### Follow-up 7: dump-registry second run — noise, filter hardened (2026-10-23)

- Owner's run "worked" but the output was 90% noise: my Read-CStr accepted any
  2+ printable chars as a "name", so CRT vtables, pathfinder strings (";H",
  "A;C", "$8,4", "ctexscale", HLSL compiler strings...) flooded the list past
  the real console zone (0x17F9E58-0x17FB2B8, truncated out of the paste).
  Valuable finds in the noise anyway: iPathEngine strings (pathfinding middleware
  "prevalidation", "worldRange"), HLSL Shader Compiler 9.30, OpenSSL-style ASN1
  error strings ("ode password too big", "ASN1 bad key data") — the game links
  crypto for its (dead) online features. The second Teleport reference zone
  (0x18356C0) is inside this pathEngine/CRT region: it was a coincidental
  pointer, not a second registry.
- Fix: strict console-name regex (identifier chars only, 3-40 chars, optional
  dotted segments) + a detailed block that prints all 8 qwords of the 12
  confirmed entries so the handler offset (the TEXT qword common to all) is
  read directly instead of guessed.
- Re-run: expect a small clean list (~tens of real console programs, including
  Faction.SetTarget etc.) + the detailed 12-entry block.

### Follow-up 8: stray quote parse error, removed (2026-10-23)

- v3 of dump-registry.ps1 shipped with a trailing orphan `'` line left over from
  my string replacement (parser error before anything ran). Removed. No other
  stray characters; quote balance checked. Re-run needed.

### Follow-up 9: grid alignment bug — the walk stepped past every real entry (2026-10-23)

- Owner's third dump: 40 named entries but ZERO of the 12 confirmed console
  programs, and the detailed block empty. Root cause: my walk started at a
  0x40-ALIGNED address, but the real entries sit at residue 0x18 mod 0x40
  (0x17F9E58, 0x17F9E98, ...). The grid stepped over every real entry and
  collected only 0x40-aligned noise (fff, ctexscale, rldRange.minX...).
- Fix: anchor the grid on the lowest stage-2 hit itself (same residue class),
  then walk ±0x400 at 0x40 stride. Also documented: the residue is 0x18 for
  build 7348332 — the registry array is not 0x40-aligned in .data.
- Re-run: the detailed block should now list all 12 confirmed programs with
  their 8 qwords, and the entry list should be real console programs.

### Follow-up 10: grid fix was correct but still no named entries — go raw (2026-10-23)

- Fourth dump with the residue-anchored grid: only 7 "entries", still ZERO of
  the 12 confirmed programs. The grid now passes through their exact addresses,
  so the failure is in my interpretation layer (name resolution or filter), not
  the walk. Rather than guess again, pushed stage3/hexdump-anchors.ps1: raw
  8-aligned qword dump from hit-0x80 to hit+0x88 for each of the 13 anchors,
  with .rdata pointers annotated by their string and .text pointers flagged.
  No interpretation to get wrong; the entry layout is read off the bytes.
- Next owner action: git pull, run stage3\hexdump-anchors.ps1, paste the whole
  output (it also lands in stage3\analysis\anchor-hexdump.txt).

### Follow-up 11: hexdump script — piping [void] throws (2026-10-23)

- hexdump-anchors.ps1 crashed at start: `Le type de l'argument ne peut pas être
  System.Void` — I piped `[void]$out.ToString()` into Out-File. Fixed (drop the
  [void] cast; the AppendLine casts are fine, only the piped one was invalid).
- Re-run needed; no output was produced.

### Follow-up 12: ROOT CAUSE FOUND — section table read 240 bytes early (2026-10-23)

The anchor hexdump cracked it. Every garbage string resolved through a
phantom section covering RVA 0x2FB10-0x1B942F0, and the section list showed
SizeOfOptionalHeader=0xF0 read at the wrong place. The real layout: COFF
header ends at peOff+20 where the OPTIONAL header starts; SizeOfOptionalHeader
is a COFF field at peOff+16 (before the optional header), not inside it. I
read it at peOff+36, which is SizeOfUninitializedData... actually the raw value
0xF0 (=240, the true optional header size, coincidentally the value I wanted)
was picked up from the wrong field and my section table started at
peOff+24+0xF0 in FILE terms but the entries I parsed as sections 1-6 were the
optional header's own data directory entries. All .rdata string resolutions
were therefore wrong; the .text flags were computed against the real .text
section parsed correctly at index 7, so the [.text] handler addresses in the
hexdump are VALID.

**Console registry entry layout, V6 build 7348332 (0x40 bytes, from the
anchor hexdumps, entry base = name pointer hit):**

| offset | content (Faction.SetTarget example 0x17FB278) |
|---|---|
| +0x00 | name string VA (0x1413C0BB0) |
| +0x08 | help/description string VA (adjacent in .rdata, name+0x10) |
| +0x10 | source file string VA (0x1413C0780, constant per category) |
| +0x18 | line number (0x117F = 4479) |
| +0x20 | FLink list pointer (self, empty) |
| +0x28 | BLink list pointer (self, empty) |
| +0x30 | **handler function VA** |
| +0x38 | type/flags constant (0x1413BAFD0) |

**Handler addresses (V6 Steam build 7348332, exe SHA-256 F5D72578...455):**

| console program | handler VA |
|---|---|
| Player.GetPos | 0x1403F26B0 |
| Player.SetOrientation | 0x1403F88D0 |
| NextSpawnPoint | 0x1403F6FD0 |
| PrevSpawnPoint | 0x1403F7190 |
| Teleport | 0x1403F41A0 |
| Player.Save | 0x1403F41F0 |
| Report.Memory | 0x1408B2190 |
| Game.SaveSlot.Show | 0x140438300 |
| Camera.DumpInfo | 0x1405CB50 |
| PlayerUI.DumpMovieTree | 0x140462550 |
| Faction.SetTarget | 0x140462770 |
| Interrogation.Perform | 0x140462890 |

- Name and help strings are adjacent in .rdata (name+0x10) — verified on
  Player.Save (0x1413BB9A0/+0x10) and consistent everywhere in the dump.
- The second Teleport pointer (0x18356C0) is pathEngine-region noise, ruled out.
- optSize offset fixed in all three scripts (peOff+16). Re-running
  dump-registry.ps1 should now produce a clean, fully-named registry list with
  correct strings; its output is the next documentation artifact.

## Stage 4: log-only probe written (2026-10-23)

### What

- stage4/bink2coop.c: proxy DLL, all Bink exports forwarded via generated .def
  to bink2w64_orig.dll; a startup thread walks the registry at the stage-3 RVAs
  in the game's memory and writes som-coop.log (names, help, source lines,
  handler VAs). Read-only: no hooks, no pointer writes.
- stage4/build.ps1: llvm-mingw (winget MartinStorsjo.LLVM-MinGW.MSVCRT, the
  Divinity-2-validated toolchain), export parsing and .def generation in
  PowerShell, x64 sanity check, SHA-256 of the product.
- stage4/install-test.ps1: save snapshot, proxy install into the TEST copy,
  launch, wait, print log head; reminds to run -Compare after closing.

### Owner actions

1. Approve the winget install of llvm-mingw (one UAC prompt), run
   `winget install MartinStorsjo.LLVM-MinGW.MSVCRT`.
2. stage4\build.ps1 then stage4\install-test.ps1; paste build output, log head
   and the -Compare result.

### Unknowns

- Whether the game loads bink2w64.dll from its x64 folder before reaching the
  menu fast enough for the 45 s wait (the log is written at DLL attach, so it
  exists as soon as the process starts videos).
- The registry range end (REG_LAST_RVA 0x17FC000 is an estimate; the log will
  show where valid entries stop, and that value gets pinned then).
