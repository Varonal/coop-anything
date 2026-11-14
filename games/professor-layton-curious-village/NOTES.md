# Professor Layton and the Curious Village (NDS) — session notes, 2026-11-14

Session goal from the owner: one single shared game instance that several friends play
together, each on their own DS ("un seul et même jeu partagé sur plusieurs DS, tous les
joueurs interagissent avec le même jeu via leur DS"), target hardware: a real DSi XL.

## Triage (playbook/triage.md)

- Game: Professor Layton and the Curious Village, Nintendo DS, Level-5. JP 2007-02-15,
  EU 2007-11-09 ("Professeur Layton et l'Étrange Village"), NA 2008-02-10.
  Product codes: EU `NTR-P-A5FP` (GameTDB `A5FP`, En/Fr/De/Es/It), US `NTR-A5FE-USA`,
  JP `NTR-P-A5FJ`. Sources: [Wikipedia](https://en.wikipedia.org/wiki/Professor_Layton_and_the_Curious_Village),
  [GameTDB A5FP](https://www.gametdb.com/DS/A5FP), [uvlist SKUs](https://www.uvlist.net/game-173199-Professor+Layton+and+the+Curious+Village).
- Engine: proprietary Level-5 NDS binary (ARM9 + ARM7), closed source. No decomp,
  recompilation or PC port found (searched 2026-11-14; the 2018 "Curious Village HD"
  is an official mobile remaster, not a PC port of the DS build).
- Multiplayer in the engine: none. The ROM's only wireless use is Nintendo WFC for
  weekly puzzle downloads (a dead service; DLC puzzles are preloaded in the ROM per
  a [GBAtemp thread](https://gbatemp.net/threads/professor-layton-and-the-curious-village.79439/)).
  No local-wireless mode, so emulator netplay (route A) does not apply.
- Already done? No. No Layton entry in DIRECTORY.md / `games/`; `gh issue/pr list
  --search layton` on cranebeaker/coop-anything: nothing; web and GitHub searches:
  no co-op project (only ROM sites, reviews, romhack tooling). See the `searched:`
  list in the new directory entry.
- Owner's dump: SHA-256 to be recorded in `local/identity.md` by the owner only.

## Research findings

### Observations (each with its source)

- BizHawk's melonDS NDS core supports Lua with a socket API (`comm` module);
  `bizhook` (PyPI) wraps it, and `universal-ds-lua-script` targets DeSmuME and the
  BizHawk melonDS core. [TASVideos BizHawk Lua functions](https://tasvideos.org/Bizhawk/LuaFunctions),
  [bizhook](https://pypi.org/project/bizhook/1.1.0/),
  [DevreeseJorik/universal-ds-lua-script](https://github.com/DevreeseJorik/universal-ds-lua-script).
- Precedent for DS in this hub: claim issue #301 (Pokemon HeartGold/SoulSilver, FR
  ROM IPKF01) uses BizHawk 2.11.1 NDS core + a Lua bridge + a Python relay,
  memory-sync co-op. [issue #301](https://github.com/cranebeaker/coop-anything/issues/301).
- melonDS standalone: local wireless / online Wi-Fi listed as work in progress in
  2026 packaging; the libretro core emulates WFC replacement servers and says LAN
  multiplayer does not work through the Internet. Standalone native Lua is only an
  unmerged PR (#1671). [libretro melonDS DS docs](https://docs.libretro.com/library/melonds_ds/),
  [melonDS PR 1671](https://github.com/melonDS-emu/melonDS/pull/1671).
- Real DSi networking from a flashcart homebrew: the BlocksDS DSWiFi library does
  TCP/UDP over IPv4/IPv6, and in DSi mode via "Advanced Setup" connections 4-6 it
  does WPA/WPA2 (mbed TLS). [BlocksDS dswifi docs](https://blocksds.skylyrac.net/dswifi/index.html),
  [DS-Homebrew wiki, Wi-Fi](https://wiki.ds-homebrew.com/ds-index/wifi).
- Proof a real DSi holds a TCP connection to a PC server from homebrew:
  `dsi-link` (ArmstrongThomas) — DSi LL + DSpico, WPA2, TCP 17494, verified
  2026-10-21. [repo](https://github.com/ArmstrongThomas/dsi-link).
- Video PC to DSi over Wi-Fi exists and is fast enough for a static-screen game:
  RNDS-Stream (gavff64, RubyNDS, MIT) streams a PC window as MJPEG to a DSi run from
  a flashcart, about 20 fps with frame skipping, 10-15 fps at full DSi resolution,
  JPEG decoded on-console (JPEGDEC); no audio yet. [repo](https://github.com/gavff64/RNDS-Stream),
  [Hackaday, 2026-10-07](https://hackaday.com/2026/10/07/streaming-games-means-the-nintendo-dsi-will-never-be-obsolete/).
  The older streamer-ds (dbeef) managed only ~0.6 s/frame at 256px on an original DS
  (WEP-era Wi-Fi). [repo](https://github.com/dbeef/streamer-ds).
- ROM-hack tooling for this exact game (useful for RE later): Flora (patataofcourse;
  Curious Village JP/US/EU-AUS/KO, EU/AUS guaranteed compatible) and LaytonEditor
  (C3RV1). The ROM uses custom `.arc`/`.pcm` containers, not standard NARC.
  [Flora](https://github.com/patataofcourse/Flora),
  [LaytonEditor](https://github.com/C3RV1/LaytonEditor),
  [GBAtemp graphics thread](https://gbatemp.net/threads/graphics-in-professor-layton.135678/).

### Derived (my conclusions, not sources)

- Route: `playbook/console-emulators.md` route B, but shaped as a single authoritative
  instance (one emulator on a PC) plus N thin clients (the real DSi XLs), instead of
  two emulators syncing. One instance = no desync possible, and it matches the owner's
  ask ("un seul et même jeu").
- The on-hardware alternative (every DS runs the ROM and the instances sync state)
  was set aside: it needs deep RE plus a patch of a closed ARM9 binary to sync on
  real hardware, and Layton has no netcode. The thin-client model only needs input
  injection into the emulator and video streaming to the DS, both with prior art above.
- Input arbitration: one touch "pen"; the relay grants it to one player at a time
  (hold-to-claim or turn passing). Face buttons can simply be OR-merged. Exact policy
  deferred to the prototype.
- Layton is mostly static 2D screens, so MJPEG at 10-20 fps on the DSi is playable
  for this game. Audio streaming is a separate problem (RNDS-Stream has none);
  options: PC-side audio, or skip.

### Guesses (unverified, must be checked before relying on them)

- DS input registers (KEYINPUT 0x04000130, touch registers 0x04000136+) are writable
  through the BizHawk melonDS core's memory domains from Lua.
- BizHawk can run under Xvfb on Linux for bot-driven QA without a desktop.
- The emulator framebuffer is capturable from Lua or from a PC-side scraper for the
  MJPEG stream.

### Unknowns

- Whether the owner's gh token can open the claim issue on cranebeaker/coop-anything
  (`createIssue` not accessible); issues are disabled on the Varonal fork. The claim
  is carried in the draft PR body for now.
- Owner's ROM revision and SHA-256, flashcart model for the DSi XL, home Wi-Fi
  security (recorded in `local/identity.md` once known).
- Whether melonDS/BizHawk exposes the framebuffer cheaply enough for MJPEG capture.

## Plan

- Phases 0-1 (triage + research): done, this file.
- Phase 2-6, PC prototype first (bots only, per playbook/automated-qa.md): BizHawk
  melonDS core + Lua socket bridge, Python relay as authority, two scripted bot
  clients; assert that injected input lands in guest RAM and that MJPEG frames flow
  to both clients.
- Hardware phase: BlocksDS SDK homebrew `.nds` thin client for the DSi XL (DSWiFi WPA2
  via Advanced Setup 4-6, TCP to the relay, JPEGDEC MJPEG decode, keys/touch up),
  run from a flashcart. Tested only after the PC loop works.
- Ship: one-click host/join relay, README with known issues (fps, audio, pen
  arbitration).
