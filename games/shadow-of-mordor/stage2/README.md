# Stage 2 — static analysis of the exe (Phase 3)

One script, run on the owner's Windows PC, against the exe of the **test copy**
(not the real install):

```powershell
cd games\shadow-of-mordor\stage2
.\analyze-exe.ps1
```

It prints and writes into `stage2\analysis\`:

- `exe-sha256.txt` — the exe hash (must match `stage1\identity.json`).
- `sections.json` + console table — PE sections, image base, machine (expect
  x64/PE32+). For Shadow of War the 31 MB `.arch` section held the game code;
  look for its V6 counterpart here.
- `markers.json` — presence and file offset of strings that decide the plan:
  - `SteamStub`, `.bind` — Steam DRM (Shadow of War's code was byte-readable on
    disk anyway; entropy tells us if that holds here),
  - `denuvo` — usually absent as a literal string; low entropy is the real test,
  - `ClientShellDLL`, `ObjectDLL`, `Game\Shared`, `NetMesh` — LithTech
    client/server layout surviving in V6 → host-authoritative co-op is plausible,
  - `ConsoleProgram` / `AddConsoleProgram`, `debug_print`, `Faction.`,
    `RandomFloat`, `RollResurrection` — the instrumentation doors found in V7;
    any hit means the same technique applies.
- `entropy.tsv` — bits/byte of the code sections. `< 6.5` = plain code, static
  analysis directly on the file; `> 7.5` = packed/encrypted, dump from memory
  instead (see games/shadow-of-war NOTES, session b).

Status: written, NOT executed yet. Paste the full console output back; the
results go into [../NOTES.md](../NOTES.md) and decide stage 3 (Ghidra import and
function mapping, or memory-dump-first).
