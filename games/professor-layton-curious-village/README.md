# Professor Layton and the Curious Village (2007)

| | |
|---|---|
| Engine | proprietary Level-5 NDS binary (ARM9/ARM7), closed source |
| Versions tested | EU A5FP revision 0, in BizHawk 2.11.1 melonDS core |
| Projects | private local prototype; no public release |
| QA level | automated (PC bots and DSi-mode display demo; no Wi-Fi or hardware test) |
| Last updated | 2026-11-14 |

## Where things stand

No public co-op project was found in the searches recorded in [NOTES.md](NOTES.md).
A private PC prototype now runs one authoritative DS game instance and lets two bots
share its screens and take turns using the stylus. A DSi-only display client compiles
and its JPEG demo boots in melonDS DSi mode, but the network client has not joined the
relay. It is not playable on real hardware yet.

## Existing work

- No public co-op project for this game. ROM-hacking tools exist and may help later:
  [Flora](https://github.com/patataofcourse/Flora) (Curious Village, multiple regions),
  [LaytonEditor](https://github.com/C3RV1/LaytonEditor).
- Related infrastructure, not co-op for this game: BizHawk melonDS Lua sockets and
  input APIs ([BizHawk Lua API](https://tasvideos.org/Bizhawk/LuaFunctions)), DS
  networking in DSi mode ([BlocksDS DSWiFi](https://blocksds.skylyrac.net/dswifi/)),
  and PC-to-DSi video streaming ([RNDS-Stream](https://github.com/gavff64/RNDS-Stream)).

## How the game works (for co-op)

The original DS game is a closed Level-5 binary with no local multiplayer mode or
known game-side networking. Its saves and puzzle state belong to one game instance.
The prototype leaves the ROM unchanged: one PC emulator owns the game, while each DS
is intended to act as a network screen and controller. This provides one shared game
state, but it does not add separate player characters or independent puzzle actions.

## What we changed

Nothing in the game itself. A private local prototype implements a loopback relay,
two-screen JPEG streaming, merged face-button input, exclusive stylus ownership, and a
BizHawk Lua socket bridge. The bridge converts the emulator's dual-screen capture to
two 256×192 JPEG images and applies the relay's input snapshot.

## QA

- The private bot suite passed 34 tests on 2026-11-14. It covers packet validation,
  input merging and stylus handoff, disconnect cleanup, bounded frame backlog, and
  the BizHawk bridge's framing and screenshot conversion. Its source remains in the
  ignored local prototype, not in this hub.
- A bot-driven smoke test ran the EU A5FP revision 0 copy in BizHawk 2.11.1. Bot one
  tapped **New Game**; after the transition, bot two tapped the `a` key on the name
  screen. The name field changed, and both bots received byte-identical JPEG screens
  for matching frame sequences. This verifies PC emulator control and frame sharing;
  it does not verify a DSi network connection or console performance.
- The private `run_host.py` wrapper was tested with two local bots. It launched the
  game and relay; one bot started a game, the other changed the name field, and both
  received matching frames. The synthetic DSi-only client demo displayed both JPEG
  screens in melonDS DSi mode. A DSi network attempt stopped at Wi-Fi association
  timeout in the emulator and did not reach the relay.
- A TCP chaos smoke passed with 35 ms one-way delay: bots shared the same frame,
  input acknowledgement took 141.9 ms, and disconnecting the stylus owner cleared
  its held buttons and touch. A second isolated NAND attempt produced no TCP socket
  within 35 seconds; the failure stage is unknown. Both are emulator/relay checks,
  not real DSi network evidence.
- BizHawk 2.11.1 has a known conflict between Lua analog stylus input and the default
  mouse bindings. On the isolated test configuration, the mouse was unbound from
  `Touch`, `Touch X`, and `Touch Y`; with that configuration the input reached the game.
  [BizHawk issue #4535](https://github.com/TASEmulators/BizHawk/issues/4535).

## How to play

Not playable yet. The private PC prototype is not a release. The DSi-only client has
not completed a relay connection or a real-hardware test.

## Known issues

- The DSi client compiles, but its DSWiFi association and relay connection remain
  unverified. There is no join menu or reconnect loop.
- The real-console launch mode and homebrew compatibility are untested. WPA2 requires
  DSi mode in DSWiFi; saved access-point configuration is not verified.
- Hardware frame rate, text readability, latency, audio, and disconnect recovery are
  unknown.
- The prototype's six-digit session code is transmitted in plaintext and is not a
  security mechanism. It is loopback-only by default.

## Next steps

1. Trace DSWiFi association and melonDS networking until one DSi client joins the
   relay and displays the shared game.
2. Verify the client's touch and button input on a real DSi XL through TWiLight Menu++.
3. Test two separate DSi clients together, including stylus handoff and disconnects.
4. Add reconnect handling and a supported one-click host/join flow after the DSi path
   works end to end.
