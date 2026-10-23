# Stage 1 — isolated test workspace (Phase 2)

Scripts run on the owner's Windows PC. They prepare a safe test environment for
Middle-earth: Shadow of Mordor (Steam app 241930) before any modding or
instrumentation, following [playbook/methods.md](../../../playbook/methods.md):

- the owner's install, saves and store folders are **read-only** to these scripts,
- every copy is hashed and manifested,
- save/config folders are hashed before and after each run to prove isolation.

**Status: written, NOT yet executed (no Windows host in this session).** Every
script prints what it did; nothing is claimed verified until a run is pasted into
[../NOTES.md](../NOTES.md).

## Order

1. `identity.ps1` — record the game's identity (install path, exe, SHA-256, Steam
   build id). Writes `identity.json` next to itself. Run this first; its output is
   required before following any write-up (AGENTS.md rule 5).
2. `make-test-copy.ps1` — copy the install into an isolated test folder
   (`-Dest` overrides the default under `%LOCALAPPDATA%\Temp`). Never edits the
   source install. Writes a file manifest so later changes are detectable.
3. `snapshot-saves.ps1` — hash every folder the game might write (WB Games save
   and config folders, Steam userdata for app 241930) before a test run, and
   compare after (`-Compare`) to prove nothing leaked into the owner's real
   saves. Repeat the comparison after every session that ran the game.

## Ground rules (from AGENTS.md)

- Never launch the test copy before `snapshot-saves.ps1` has a "before" snapshot.
- Never run the owner's real install for tests.
- Paste each run's output into `../NOTES.md` with the date.
