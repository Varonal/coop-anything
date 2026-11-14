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
  recompilation or PC port of the original DS build found. Level-5 has announced a
  distinct *Curious Village Remake* for Switch 2/Switch/PS5/Steam in 2027; it is not
  available for this test and does not run on DS. [Official remake page](https://www.layton.jp/fushigi-remake/en/).
- Multiplayer in the DS game: no local-wireless mode found in the manuals or searches.
  Nintendo documents the weekly puzzle downloads over WFC, and a contemporary review
  explicitly notes the lack of multiplayer. Netplay route A is provisionally excluded.
  [Nintendo FR game page](https://www.nintendo.com/fr-fr/Jeux/Nintendo-DS/Professeur-Layton-et-l-etrange-village-272563.html),
  [JeuxActu review](https://www.jeuxactu.com/test-pr-layton-et-l-etrange-village-29398.htm).
- Already done? No. No Layton entry in DIRECTORY.md / `games/`; `gh issue/pr list
  --search layton` on cranebeaker/coop-anything: nothing; web and GitHub searches:
  no co-op project (only ROM sites, reviews, romhack tooling). See the `searched:`
  list in the new directory entry.
- Local ROM identity (header code/revision and SHA-256) is recorded in the
  ignored `local/identity.md`; the ROM itself stays outside Git.

## Research findings

### Observations (each with its source)

- BizHawk 2.11.1's melonDS NDS core exposes the documented Lua APIs for
  `joypad.set`, `joypad.setanalog`, socket-server request/response, and captured
  screenshots. These APIs are now exercised by the private game smoke test below.
  [BizHawk 2.11.1 release](https://github.com/TASEmulators/BizHawk/releases/tag/2.11.1),
  [BizHawk Lua API](https://tasvideos.org/Bizhawk/LuaFunctions).
- BizHawk issue #4535 reports that mouse bindings can override scripted analog
  touchscreen coordinates in 2.11.1. The local test reproduced the conflict:
  the relay sent `(128,72)`, but `joypad.get()` showed `(0,96)`. Unbinding the
  mouse from all three NDS controls (`Touch`, `Touch X`, `Touch Y`) fixed it;
  the isolated game test then received the requested coordinates and progressed.
  [issue #4535](https://github.com/TASEmulators/BizHawk/issues/4535).
- The installed local emulator is melonDS 1.1. The upstream Lua-scripting PR
  #1671 is still open; no scripting or remote-control interface has been
  confirmed in the installed executable. [melonDS PR #1671](https://github.com/melonDS-emu/melonDS/pull/1671).
- Local test observation (2026-11-14): a byte-for-byte copy of the owner's EU
  A5FP revision 0 dump booted in a copied melonDS 1.1 executable and reached the
  title screen, showing both DS screens. No gameplay input was sent. Private
  hashes and paths are in ignored `local/identity.md`; the test copy is also
  ignored and is not included in the hub contribution.
- Local gameplay observation (2026-11-14): the same private A5FP revision 0 copy
  ran in BizHawk 2.11.1 with its melonDS NDS core. Two loopback bots received
  byte-identical 256×192 JPEG images for the same frame sequence. Bot one tapped
  **New Game** at `(128,72)` and reached the name-entry screen; bot two then tapped
  the `a` key at `(43,96)`, which changed the game's name field. The smoke harness
  verified both state changes and both clients' matching screen frames. This is
  PC-emulator evidence only; it is not a DSi or Wi-Fi test. The ROM and emulator
  copies, logs, screenshots, and source remain under ignored `local/`.
- Local DSi display observation (2026-11-14): a BlocksDS DSi-only synthetic demo
  booted in the isolated melonDS 1.1 profile with DSi mode explicitly reported in
  the File menu (`GBA slot: none (DSi)`). It decoded and displayed different
  generated 256×192 JPEG patterns on both screens. This only tests the DSi-only
  binary's display and JPEG decoder; it does not use the relay or Wi-Fi.
- Local DSi network attempt (2026-11-14): the DSi-only client compiled with
  build-time relay settings and booted in that same melonDS DSi profile while the
  host relay reported ready. After a diagnostic build added stage labels, the
  client displayed `WIFI ASSOCIATION TIMED OUT`; the relay continued to report
  zero clients. The profile used melonDS indirect networking (`DirectMode=false`).
  This identifies the stage where this emulator attempt stopped, but not whether
  the cause was missing/incompatible saved AP settings or the emulator's Wi-Fi
  path. No successful DS-client TCP session is claimed.
- Local alternate-NAND network attempt (2026-11-14): the second user-provided DSi
  firmware/NAND set was copied to a separate ignored melonDS profile and the
  DSi-only client was launched there for 35 seconds. No TCP socket was observed
  for that emulator process. The alternate source files were not modified; the
  isolated NAND was restored from its pre-test copy. This does not prove whether
  association, ROM startup, or routing failed, so it is not a successful client
  test.
- Local first-run settings attempt (2026-11-14): the first isolated NAND displayed
  melonDS's multilingual first-time console setup screen. Keyboard and touchscreen
  input did not advance it, so no Wi-Fi profile was saved; the isolated NAND was
  restored from its pre-test copy. No original firmware or NAND file was changed.
- Local TCP chaos smoke (2026-11-14): `run_tcp_chaos_smoke.py` passed through a
  loopback proxy with 35 ms one-way delay, received input acknowledgement in
  141.9 ms, and confirmed both bots received the same frame. Dropping the
  stylus-owning bot's connection cleared its held buttons and touch. This checks
  relay delay and disconnect cleanup, not DSi radio behavior.
- Host-entry smoke observation (2026-11-14): the private `run_host.py` entry point
  compiled the DSi-only client, launched the isolated BizHawk game and relay, and
  served two local bots. The bots received identical frames; bot one started a
  new game and bot two changed the name field. Result: `PASS`, with measured
  title-screen deltas `144.02/143.09` and name-field delta `138.00`. This checks
  the PC host wrapper, not DSi Wi-Fi or hardware.
- The private bot suite was rerun on 2026-11-14: all 34 tests passed. The separate
  BizHawk display-capture helper did not create its expected screenshot within
  its 30-second deadline; the reason remains unknown. The successful visual DSi
  demo observation above came from melonDS itself, not that helper.
- Rechecked on 2026-11-14: the BizHawk game smoke passed with both bots sharing the
  same frames and taking turns with the stylus (`name-field-delta=22.61`); the
  host-wrapper smoke passed with two bots (`title-delta=144.02/143.09`,
  `name-delta=138.00`). These results remain PC-only.
- BlocksDS setup sources disagree about native Windows support. The BlocksDS
  Windows page describes a native MSYS2 installation, while the current Wonderful
  Toolchain installation page says native Windows is unavailable and recommends
  WSL. The official Wonderful bootstrap and BlocksDS packages are now installed
  in WSL Ubuntu. The bootstrap and each downloaded package were SHA-256 checked;
  hashes and versions are in ignored `local/identity.md` and
  `local/tools/blocksds/packages-sha256.txt`.
  [BlocksDS Windows setup](https://blocksds.skylyrac.net/docs/setup/windows/),
  [Wonderful Toolchain installation](https://wonderful.asie.pl/doc/general/getting-started/).
- The official BlocksDS DSWiFi docs confirm TCP sockets and state that WPA2
  requires `WIFI_ATTEMPT_DSI_MODE`. DSi mode does not support DSWiFi's local
  multiplayer AP mode, which this IP relay does not need. The installed SDK
  includes `arm7_dswifi_maxmod.elf`; `blocksds-gbajpeg` supplies a baseline JPEG
  decoder. Its docs report 350 ms for a representative image on GBA hardware;
  DSi XL decode speed remains unknown.
  [DSWifi introduction](https://blocksds.skylyrac.net/dswifi/index.html),
  [DSWifi Internet guide](https://blocksds.skylyrac.net/dswifi/md_documentation_2internet__mode.html),
  [JPEG package usage](https://blocksds.skylyrac.net/tutorial/intermediate/filesystems/).
- Installed versions are BlocksDS `1.25.0-1` and `blocksds-gbajpeg`
  `20241201-1`. The ARM9 default Makefile selects a non-Wi-Fi ARM7 core, so a
  client linking `-ldswifi9` must explicitly select
  `arm7_dswifi_maxmod.elf`. `ndstool` supports DSi unit codes 0, 2, and 3; unit
  code 3 would be DSi-only and is deferred until the target launcher is known.
  [BlocksDS build process](https://blocksds.skylyrac.net/docs/internal/build_process/),
  [BlocksDS changelog](https://blocksds.skylyrac.net/docs/changelog/).
- Precedent for DS in this hub: claim issue #301 (Pokemon HeartGold/SoulSilver, FR
  ROM IPKF01) uses BizHawk 2.11.1 NDS core + a Lua bridge + a Python relay,
  memory-sync co-op. [issue #301](https://github.com/cranebeaker/coop-anything/issues/301).
- melonDS standalone: local wireless / online Wi-Fi listed as work in progress in
  2026 packaging; the libretro core emulates WFC replacement servers and says LAN
  multiplayer does not work through the Internet. Standalone native Lua is only an
  unmerged PR (#1671). [libretro melonDS DS docs](https://docs.libretro.com/library/melonds_ds/),
  [melonDS PR 1671](https://github.com/melonDS-emu/melonDS/pull/1671).
- BlocksDS DSWiFi supports TCP/UDP over IPv4/IPv6. Its normal DS-compatible mode
  supports open/WEP access points; WPA2 requires explicitly starting the library
  in DSi mode. The DSi-mode launcher path on the target console is unknown. Since
  this design uses router-based IP sockets, it does not need DSi local-wireless
  mode. [DSWifi Internet mode](https://blocksds.skylyrac.net/dswifi/md_documentation_2internet__mode.html),
  [BlocksDS Wi-Fi guide](https://blocksds.skylyrac.net/tutorial/advanced/wifi/).
- Proof a real DSi holds a TCP connection to a PC server from homebrew:
  `dsi-link` (ArmstrongThomas) — DSi LL + DSpico, WPA2, TCP 17494, verified
  2026-10-21. [repo](https://github.com/ArmstrongThomas/dsi-link).
- Video PC to DSi over Wi-Fi has experimental prior art: RNDS-Stream uses
  RubyNDS/JPEGDEC and reports 20 fps with frame skipping or 10-15 fps at full
  DSi resolution. Its README says Fedora KDE/X11-only, one local-network server,
  no security implementation, and lists disconnect and readability limitations.
  No licence file was found at the repository's standard `LICENSE` path, so this
  project will not reuse its code unless a licence is verified. Performance and
  multi-client support remain unverified for our use. [RNDS-Stream README](https://github.com/gavff64/RNDS-Stream),
  [source README](https://raw.githubusercontent.com/gavff64/RNDS-Stream/main/README.md).
  The older streamer-ds (dbeef) managed only ~0.6 s/frame at 256px on an original DS
  (WEP-era Wi-Fi). [repo](https://github.com/dbeef/streamer-ds).
- ROM-hack tooling for this exact game (useful for RE later): Flora (patataofcourse;
  Curious Village JP/US/EU-AUS/KO, EU/AUS guaranteed compatible) and LaytonEditor
  (C3RV1). The ROM uses custom `.arc`/`.pcm` containers, not standard NARC.
  [Flora](https://github.com/patataofcourse/Flora),
  [LaytonEditor](https://github.com/C3RV1/LaytonEditor),
  [GBAtemp graphics thread](https://gbatemp.net/threads/graphics-in-professor-layton.135678/).

### Derived (my conclusions, not sources)

- Route: a single authoritative emulator on the PC plus N thin clients matches the
  owner's request for one shared game. A single process avoids divergent copies of
  the game world; it does not remove network delays, stale video, lost connections,
  or ordering and arbitration bugs in the relay.
- The on-hardware alternative (every DS runs the ROM and the instances sync state)
  was set aside: it needs deep RE plus a patch of a closed ARM9 binary to sync on
  real hardware, and Layton has no netcode. The thin-client model only needs input
  injection into the emulator and video streaming to the DS, both with prior art above.
- The shared-emulator thin-client route is now supported by a PC-only test: one
  emulator remains authoritative, and clients receive the same frame while taking
  turns with the game's single stylus. It shares one game state but does not make
  the game expose separate player characters or independent progress.
- For Windows development, the BlocksDS page also points WSL users to its Linux
  instructions, while the current Wonderful Toolchain page recommends WSL. Use
  that common path until the native-install documentation is reconciled.
- The relay grants the stylus exclusively and OR-merges digital buttons. Its
  loopback bot tests cover ownership handoff and stale-input release; the game
  smoke test confirms both clients can take the stylus in sequence.
- A 10 Hz capture cadence is configured in the Lua bridge, not yet measured on
  hardware. Text readability, frame rate, network latency, DSi compatibility, and
  audio remain unverified.

### Guesses (unverified, must be checked before relying on them)

- BizHawk can run under Xvfb on Linux for bot-driven QA without a desktop.
- The current BizHawk Lua screenshot/socket bridge can sustain the capture rate
  and frame sizes required by multiple clients during a long hardware session.
- The target DSi XL's flashcart/launcher starts the thin-client homebrew in DSi
  mode, which is required for WPA2; saved AP settings can be used as expected.

### Unknowns

- Whether the owner's gh token can open the claim issue on cranebeaker/coop-anything
  (`createIssue` not accessible); issues are disabled on the Varonal fork. The claim
  is carried in the draft PR body for now.
- Whether the real-console launcher starts this homebrew in DSi mode and whether
  the DSi has a saved access point compatible with DSWiFi.
- Whether the emulator screenshot API sustains long-running streaming without
  blocking or accumulating stale frames.
- Whether the DSi can decode and display the stream at readable speed while sending
  complete input snapshots over the chosen Wi-Fi network.

## Plan

- Phases 0-1 (triage + initial research): recorded here; environment details have
  since been verified locally and several assumptions corrected above.
- 2026-11-14 PC relay checkpoint: the private ignored prototype passed 34 tests
  with `python -I run_qa.py`, including protocol validation, arbitration, client
  demultiplexing, the BizHawk bridge framing, and JPEG splitting/resizing.
- 2026-11-14 game smoke checkpoint: `python -I run_bizhawk_smoke.py` launched the
  isolated A5FP copy in BizHawk 2.11.1, let bot one start a new game, then let bot
  two type `a` on the name screen. It asserted that the game left the title screen,
  the name field changed, and both clients received byte-identical screens at
  matching frame sequences. This verifies a PC shared-instance proof of concept;
  it does not verify DSi hardware.
- 2026-11-14 client build checkpoint: a BlocksDS DSi-only client now compiles with
  DSWiFi TCP and the baseline JPEG decoder. The synthetic display path boots in
  melonDS DSi mode, but the network client has not joined the relay in melonDS.
  Keep the local build, ROM, firmware, and test assets out of the hub contribution.
- Next: trace DSWiFi association and melonDS networking, then get one real DSi
  client to join the private relay before preparing files for two consoles. Verify
  frame acknowledgement, touch forwarding, and disconnect handling on hardware.
  Hardware, readable frame rate, and real Wi-Fi remain unverified.
- Ship: one-click host/join relay, README with known issues (fps, audio, pen
  arbitration).
