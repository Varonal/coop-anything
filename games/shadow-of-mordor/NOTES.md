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
