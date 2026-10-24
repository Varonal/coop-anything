# Stage 4 — log-only probe (first mod component)

A `bink2w64.dll` proxy for the TEST copy. All Bink exports forward to the
renamed original (`bink2w64_orig.dll`), so videos keep playing; the added code
only walks the console registry in memory at startup and writes `som-coop.log`.
**No hooks, no pointer writes, no game files modified beyond the proxy dll.**

Pinned to Steam build 7348332 (exe v1.0.1951.29, SHA-256 F5D72578...455):
registry RVAs from stage 3 (first 0x17F9E18, stride 0x40, entry layout
name +0 / help +8 / source +0x10 / line +0x18 / handler +0x30).

## Order (on the owner's Windows PC)

1. Install the toolchain (one time, needs your approval):
   `winget install MartinStorsjo.LLVM-MinGW.MSVCRT`
2. `cd games\shadow-of-mordor\stage4; .\build.ps1`
   - copies `bink2w64.dll` -> `bink2w64_orig.dll` in the TEST copy's x64 folder,
   - generates the forwarding .def from the original's exports,
   - builds the x64 proxy and prints its SHA-256.
3. `.\install-test.ps1` — snapshots saves (stage 1 tool), installs the proxy,
   launches the game, waits 45 s, prints the first 40 log lines.
4. Close the game, then `..\stage1\snapshot-saves.ps1 -Compare` (must stay
   "no changes" — the probe is read-only, this proves it).

What the log gives us: the full console registry as seen at runtime (real
loaded addresses, possibly ASLR-relocated), validating the static analysis and
giving the live handler addresses. From there: hook `Faction.SetTarget` and
`Player.Save` handlers next (with your go-ahead), which is the Nemesis-event
tap the co-op sync builds on.
