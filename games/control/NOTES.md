# Control (2019) — working notes

Session 2026-10-23, phases 0–4 (triage, research, choice of approach). No game files
were touched: no install or saves present in the sandbox, and ground rules forbid
touching the owner's install anyway. Everything below comes from web research.

## Observations (sourced)

- Control Ultimate Edition, Steam appid 870780, uses Remedy's proprietary **Northlight**
  engine. Single-player only; the story follows one protagonist (Jesse).
  Source: https://twinfinite.net/guides/control-co-op-multiplayer-is-there/
- No co-op or multiplayer mod for Control exists as of 2026-10-23. Web search found only
  wishes on Reddit and news about official spin-offs. Source: searches below.
- The repo already had a gap entry: `data/directory.yaml` "Alan Wake 2 and Control",
  kind: gap, checked 2026-10-16.
- Modding infrastructure that does exist:
  - **Control Plugin Loader** (reg2k), a DLL loader (ships as xinput1_4.dll / newer
    iphalpapi.dll) that lets native-code mods hook low-level engine parts.
    https://www.nexusmods.com/control/mods/16
  - **Loose Files Loader** (reg2k): replaces files in the game's packfiles without
    repacking. https://www.nexusmods.com/control/mods/11
  - **neat** (TomEvin): Northlight Engine Archive Tool, unpack/create .rmdp archives.
    https://github.com/TomEvin/neat
  - **control-unpack** (profMagija): extractors/converters for Control file formats.
    https://github.com/profMagija/control-unpack
  - **NorthlightTools** (GrzybDev): Python tools for Northlight formats.
    https://github.com/GrzybDev/NorthlightTools
  - **OpenAWE**: open-source reimplementation of the Alan Wake-era Northlight; Control
    support is a stated secondary goal only. https://github.com/OpenAWE-Project/OpenAWE
  - Community reports (Nexus post tab): loaders broke after Ultimate Edition game
    updates and needed updated DLLs; works on Steam Deck via WINEDLLOVERRIDES.
- Northlight gameplay scripting is **Lua** (Remedy's own description:
  https://www.remedygames.com/northlight). Gameplay is a C++ object model with Lua on top.
- Official co-op in the same universe: **FBC Firebreak** (3-player PvE spin-off), and
  the announced "Condor"/Vanguard project. Not mods of Control itself.

## Derived

- Triage answers: closed binary, no netcode shipped, no deathmatch/replication layer,
  no public source. Per the playbook's difficulty table this is the hardest row:
  "Closed binary, no MP, no scripting" — except a DLL loader exists, so the realistic
  path is native hooks via the Plugin Loader, not pure asset mods.
- No decompilation of Control exists (OpenAWE targets Alan Wake 1 first; Control is a
  different, much later Northlight generation). So the sm64coopdx model is not available.
- The best reuse is the **Plugin Loader**: a co-op mod would be a native DLL injected
  into the host process, replicating a second player as a remote-controlled actor and
  syncing world state over a direct-IP/LAN socket or Steam networking. That is
  multi-month reverse engineering: puppet actor, input replay, save/story trigger sync.
- A campaign "de A à Z" (full story co-op) is the hardest scope; story triggers and
  solo scripted sequences are the known desync sources in comparable projects.

## Guesses (unverified)

- The Lua gameplay layer could allow syncing script state (mission flags, doors,
  checkpoints) without full native replication, if scripts can be hot-reloaded via
  loose files. Unknown: whether Control's Lua sources ship readable in the packfiles.
- Quantum Break / Alan Wake 2 modding knowledge (AW2 has praydog's mod loader:
  https://github.com/praydog/alan-wake-2-mod-loader) partially transfers to Control
  since they share engine lineage. Unknown how much.

## Unknowns

- Control's build/version identity here (store, build id, exe SHA-256) — no install in
  this sandbox. Must be recorded before any write-up is followed on the owner's PC.
- Whether the game's Lua scripts are extractable and reloadable at runtime.
- Any private/Discord-only co-op experiment; Reddit could not be searched exhaustively.

## Next steps

1. Record game identity on the owner's machine (store, build id, exe SHA-256), copy the
   install into a test folder, never touch the original.
2. Dump the packfiles with neat/control-unpack; check for readable Lua gameplay scripts.
3. Get the Plugin Loader working on the Ultimate Edition build; enumerate engine
   functions around actor update and input.
4. Design doc: host-authority sync model (per playbook/how-coop-mods-work.md), puppet
   player first, then enemies, then story triggers.
5. Claim the game with an issue once real work starts (repo has issues disabled today).

## Sources searched

- Web search "Control game co-op multiplayer mod Remedy Northlight" (2026-10-23)
- Web search "Control Ultimate Edition mod loader Lua scripting modding" (2026-10-23)
- Web search "Northlight engine Control modding reverse engineering github tools" (2026-10-23)
- Repo internal: DIRECTORY.md gap entry (checked 2026-10-16), playbook/engine-families.md
