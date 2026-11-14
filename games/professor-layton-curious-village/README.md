# Professor Layton and the Curious Village (2007)

| | |
|---|---|
| Engine | proprietary Level-5 NDS binary (ARM9/ARM7), closed source |
| Versions tested | none yet; target ROMs: EU A5FP, US A5FE, JP A5FJ |
| Projects | none found |
| QA level | none |
| Last updated | 2026-11-14 |

## Where things stand

No co-op or multiplayer mod exists for this game, and the ROM has no local multiplayer
mode (its only wireless feature is Nintendo WFC weekly puzzle DLC). There is also no
decompilation, recompilation or PC port. A shared-instance co-op played from several
real DSi consoles has been claimed (see the draft PR body; the claim issue could not be
opened on the upstream repo from this account). Raw session notes, sources and the plan
are in [NOTES.md](NOTES.md).

## Existing work

- None for co-op. ROM-hacking tools exist and will help reverse engineering later:
  [Flora](https://github.com/patataofcourse/Flora) (Curious Village, all regions),
  [LaytonEditor](https://github.com/C3RV1/LaytonEditor).
- Related infrastructure, not co-op for this game: BizHawk melonDS core Lua socket
  bridge ([bizhook](https://pypi.org/project/bizhook/1.1.0/),
  [universal-ds-lua-script](https://github.com/DevreeseJorik/universal-ds-lua-script)),
  DS memory-sync precedent in this hub ([issue #301](https://github.com/cranebeaker/coop-anything/issues/301),
  Pokemon HGSS), real-DSi networking ([BlocksDS DSWiFi](https://blocksds.skylyrac.net/dswifi/index.html),
  [dsi-link](https://github.com/ArmstrongThomas/dsi-link)) and PC-to-DSi MJPEG streaming
  ([RNDS-Stream](https://github.com/gavff64/RNDS-Stream), ~10-20 fps on DSi).

## How the game works (for co-op)

Closed Level-5 NDS binary; no script layer exposed, no netcode. Save and puzzle state
live in the emulated RAM / save file; ROM data uses custom `.arc`/`.pcm` containers.
For co-op the plan is not to modify the ROM but to drive one authoritative emulator
instance and let each player's DSi act as a networked screen+controller (thin client).

## What we changed

Nothing in the game yet. This entry adds the directory gap and the research notes.

## QA

None yet. Next step is a bot-driven PC prototype (two scripted clients against one
BizHawk melonDS instance) per `playbook/automated-qa.md`.

## How to play

Not playable yet.

## Known issues

Everything; the project is at research stage.

## Next steps

1. PC prototype: BizHawk melonDS core + Lua bridge + relay; verify input injection
   into guest RAM (KEYINPUT/touch registers) and MJPEG capture of the framebuffer.
2. Bot QA with two scripted clients before any human or hardware test.
3. DSi XL thin-client homebrew (BlocksDS SDK + DSWiFi WPA2 + JPEGDEC), run from a
   flashcart, against the relay.
