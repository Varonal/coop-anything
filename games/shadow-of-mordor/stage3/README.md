# Stage 3 — console registry dump (Phase 3)

Stage 2 localized the console registry: entries at a **0x40-byte stride** in
`.data` (RVAs 0x17F9E58, 0x17F9E98, 0x17F9F18, 0x17F9F58, 0x17F9F98, ...
0x17FB2B8 for build 7348332 / exe v1.0.1951.29, SHA-256 F5D72578...455), name
pointer at entry +0.

`dump-registry.ps1` reads the exe of the test copy, walks the registry window at
0x40 stride, resolves each entry's name string, and flags qwords pointing into
`.text` — those are the console handler function addresses (plus help text and
source-file pointers into `.rdata`).

Run after a stage 2 run (it reads `stage2\analysis\console-registry.json`):

```powershell
cd games\shadow-of-mordor\stage3
.\dump-registry.ps1
```

Paste the console output back. With the handler addresses we can build the first
in-game instrument: a `bink2w64.dll` proxy that walks the registry and hooks the
Faction/Save handlers to log Nemesis events — the seed of the co-op sync.
