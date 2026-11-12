# Pocket Habitat QA Verification Notes

## Current source review

The current worktree confirms and fixes these issues:

- `ServerMain` calls `WorldBuilder.init()`, which is defined in `WorldBuilder.lua`.
- `QuestManager.init()` owns the quest-claim RemoteFunction; no nonexistent `QuestManager.claimQuest` call overrides it.
- Habitat slots are allocated per server without UserId-modulo collisions and released for reuse.
- Resource lookup checks the NodeId on the server-created Part; the builder now sets that attribute.
- Prompt discovery binds only the local player's habitat and handles existing prompts, later descendants, and habitat removal.
- Client `InvokeServer` calls do not manually pass `LocalPlayer`; server `OnServerInvoke` handlers receive the Player as their first parameter.

These are source-level findings, not Roblox runtime test results.

## Checks run for this worktree update

- `rojo build default.project.json -o /tmp/pocket-habitat-validation.rbxl`: PASS; output file was verified non-empty and removed.
- `stylua --check src`: PASS.
- `selene src`: PASS; 0 errors, 0 warnings, 0 parse errors.
- `git diff --check`: FAIL due trailing whitespace in the pre-existing added `temp_test.lua`; that unrelated file was not modified.
- Roblox engine/Studio, multiplayer, DataStore, TestEZ, and manual tests: NOT RUN.

The supplied pipeline logs under `/home/runner/work/_temp` were not readable by the available tools (permission denied); their claims could not be checked directly.

## Remaining verification and implementation gaps

- Character spawn/respawn, saved-world restoration, cross-server DataStore leases and failure-safe saves, and creature runtime isolation are incomplete.
- Plot data/schema count consistency and simultaneous interaction behavior need dedicated tests.
- No engine-level evidence establishes that the game is playable or multiplayer-safe.
