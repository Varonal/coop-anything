# Middle-earth: Shadow of Mordor (2014)
   | |
 |---|---|
 | Engine | LithTech "Jupiter" line, internal version V6 (Monolith's own numbering); predecessor of Firebird (V7) |
 | Versions tested | none in this hub yet; current store build is the Game of the Year Edition (Steam app 241930, builds named v1636.37 / v1808.19 / v1951.6 in Steam news; GOG GOTY rc2 = 57896) |
 | Projects | none playable; [JustAddMP/ShadowOfMordor](https://github.com/JustAddMP/ShadowOfMordor) is a placeholder (README only, created 2026-10-17); research here |
 | QA level | none (no co-op exists yet) |
 | Last updated | 2026-10-23 |

## Where things stand

There is no co-op for Shadow of Mordor, and never was: Monolith confirmed in January
2014 the game is "wholly a single-player experience" ([IGN](https://www.ign.com/articles/2014/02/03/middle-earth-shadow-of-mordor-wont-have-multiplayer)).
Its only online features (Vendetta missions, leaderboards, Nemesis Forge import) were
asynchronous and went offline on 2021-01-12 ([PCGamesN](https://www.pcgamesn.com/middle-earth-shadow-of-mordor/servers-shut-down)).
This folder holds triage and research for a from-scratch co-op. Raw notes with every
source: [NOTES.md](NOTES.md).

## Existing work

- [JustAddMP/ShadowOfMordor](https://github.com/JustAddMP/ShadowOfMordor): README-only
  placeholder ("planned"), created 2026-10-17, one commit, no code (GitHub API,
  2026-10-23). Part of an org whose shared framework
  [JustAddMP/core](https://github.com/JustAddMP/core) (launcher, DLL injection,
  Steam lobbies, UDP/Steam P2P host-authoritative sessions, overlay) is real and
  active. Nothing to revive; coordinate if they start.
- No other co-op or multiplayer mod found: web search with several phrasings, GitHub
  repository search (five queries, ~125 hits read), Nexus top/list pages via search
  results (~41-44 mods, none co-op), ModDB, unanswered community threads
  (r/shadowofmordor, Steam "Add Coop" discussion), 2026-10-23.
- Modding tools that work on the current build (the foundation a co-op mod needs):
  - `bink2w64.dll` proxy DLL injection in `<game dir>\x64\` (documented working in a
    2026 write-up, [wesellis.com](https://www.wesellis.com/blog/modding-shadow-of-mordor-in-2026/)).
  - [Liki-js/shadow-of-mordor-internal-trainer](https://github.com/Liki-js/shadow-of-mordor-internal-trainer)
    (BSD-3-Clause, C++17, active 2026-08): an in-process trainer for the Steam GOTY
    build with an executable-fingerprint check, game-aware hooks and a Ghidra/CE
    analysis folder — the best-documented working injection example on this build.
  - [WarpZephyr/MordorUnpacker](https://github.com/WarpZephyr/MordorUnpacker) (MIT),
    [MordorFormats](https://github.com/WarpZephyr/MordorFormats) and
    [MordorTemplates](https://github.com/WarpZephyr/MordorTemplates): current
    `.arch05`/`.embb` unpacker and format library.
  - [gregkwaste/.arch05_-xplorer](https://github.com/gregkwaste/.arch05_-xplorer):
    the original Python `.arch05` explorer.
  - Archive overrides work on the current build: mods ship as `.arch05` in `Mods/`
    plus `default.archcfg` (decky-nexus issue
    [#23](https://github.com/RedRanger14/decky-nexus/issues/23)).

## How the game works (for co-op)

- **Engine.** LithTech V6, the direct predecessor of the Firebird engine used by the
  sequel. The hub's Shadow of War research
  ([games/shadow-of-war](../shadow-of-war/README.md)) found a surviving LithTech
  client/server source layout (`ClientShellDLL`, `ObjectDLL`, `Shared`), a NetMesh
  with hosting, a 680-entry console registry and a hookable debug print in V7.
  Whether the same structures exist and are live in V6 is **unknown** — the older
  Jupiter EX games (F.E.A.R.) shipped real multiplayer, Mordor did not, so any netcode
  present is unexercised and must be mapped from scratch.
- **Data.** `.arch05` archives containing `.embb` bundles; unpack/repack tooling
  exists (above). Scripting layer inside the bundles is XML/Lua-like (`.xml05`,
  QuickBMS `shadow_of_mordor.bms` exists) — a possible hook point for game logic.
- **Saves.** Not yet mapped for the current build; 2025 Steam forum reports mention
  `Documents\WB Games\Shadow of Mordor` for configs. Steam Cloud applies (app 241930).
- **Online.** Nothing real-time; servers off since 2021-01-12. The game must be
  tested with outbound connections failed (the SoW notes show the method:
  fail connects, don't refuse sockets).

## What we changed

No co-op changes. This session added the research write-up, the notes, and the
directory gap entry.

## QA

- No co-op code exists, so no co-op QA. Nothing was run against a game install.

## How to play

Nothing to play yet.

## Known issues

None (no release).

## Next steps

1. Record the game identity from the owner's install (store, build, exe SHA-256);
   pick Steam GOTY vs GOG as the target build.
2. Isolated test copy + guard (save redirect, offline-connection failing, Steam
   remote-storage write block) following the Shadow of War method in
   [playbook/methods.md](../../playbook/methods.md).
3. Injection via the `bink2w64.dll` proxy; study Liki-js's trainer for the current
   build's fingerprint and hook style.
4. Map: console registry / debug print, player object and camera, Nemesis event path,
   save format.
5. Networking model: host-authoritative shared world (host runs the only Nemesis
   world; clients mirror events; clients do not save while connected) — same design
   as the Shadow of War claim (issue cranebeaker/coop-anything#93).