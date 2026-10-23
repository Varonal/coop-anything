# Control (2019)

| | |
|---|---|
| Engine | Northlight (Remedy, proprietary) |
| Versions tested | none yet — research-only session; target is Control Ultimate Edition (Steam appid 870780) |
| Projects | none found; modding base: [Control Plugin Loader](https://www.nexusmods.com/control/mods/16), [Loose Files Loader](https://www.nexusmods.com/control/mods/11) |
| QA level | none |
| Last updated | 2026-10-23 |

## Where things stand

You cannot play Control in co-op today. No co-op or multiplayer mod exists for it
(searched 2026-10-23: GitHub, Nexus, ModDB, Steam forums via web search; Reddit only
partially). The only co-op in the universe is the official spin-off FBC Firebreak,
which is a separate game, not a mod of Control's campaign.

## Existing work

- No co-op attempt found for Control, on any engine version or store.
- Modding infrastructure that a co-op mod would build on:
  - [Control Plugin Loader](https://www.nexusmods.com/control/mods/16) (reg2k): DLL
    loader (xinput1_4.dll, newer builds use iphalpapi.dll) for native-code engine hooks.
    Community reports say it broke after some Ultimate Edition updates and needed an
    updated DLL; works on Steam Deck/Proton with `WINEDLLOVERRIDES`.
  - [Loose Files Loader](https://www.nexusmods.com/control/mods/11) (reg2k): override
    packfile contents without repacking.
  - [neat](https://github.com/TomEvin/neat) (TomEvin): Northlight archive unpack/repack.
  - [control-unpack](https://github.com/profMagija/control-unpack): Control format
    extractors.
  - [NorthlightTools](https://github.com/GrzybDev/NorthlightTools): Python format tools.
  - [OpenAWE](https://github.com/OpenAWE-Project/OpenAWE): engine reimplementation;
    targets Alan Wake first, Control only as a stated long-term goal.
- Same-engine neighbour: Alan Wake 2 has [praydog's mod loader]
  (https://github.com/praydog/alan-wake-2-mod-loader); no multiplayer there either.

## How the game works (for co-op)

- Closed binary, no shipped multiplayer of any kind: no replication layer, no server
  code. Everything would have to be built.
- Northlight's gameplay layer is Lua scripts on top of a C++ object model (Remedy:
  <https://www.remedygames.com/northlight>). Unknown whether Control's compiled/loose
  scripts are extractable and hot-reloadable via the Loose Files Loader.
- The realistic injection point is the Plugin Loader: a native DLL inside the game
  process, like other closed-engine co-op mods (see
  [playbook/how-coop-mods-work.md](../../playbook/how-coop-mods-work.md)).

## What we changed

Nothing in the game. This session was triage and research only; findings are recorded
in [NOTES.md](NOTES.md) and the directory entry was enriched.

## QA

Not applicable yet — no mod exists to test.

## How to play

Not possible today. Alternatives while the gap stays open: FBC Firebreak (official
3-player co-op in the same universe) or other covered games in
[DIRECTORY.md](../../DIRECTORY.md).

## Known issues

n/a (no mod).

## Next steps

1. Record the game's identity (store, build id, exe SHA-256) and copy the install into
   an isolated test folder.
2. Dump packfiles with neat/control-unpack; check for readable Lua gameplay scripts.
3. Stand up the Plugin Loader on the current Ultimate Edition build; map actor update
   and input paths.
4. Write the design doc: host-authority sync, puppet player first, then enemies, then
   story triggers. Expect a multi-month reverse-engineering effort; claim the game with
   an issue and look for collaborators before starting.
