# Run #32 — Milestone 2 implementation notes and corrections

> This file supersedes the earlier inaccurate "Critical Fixes Applied" checklist. Run #32 made partial changes, but it did **not** complete the milestone or verify the claimed runtime behavior. The canonical detailed issue list is `project-state/run-32-audit.md`.

## What is actually present in the final Run #32 source

### Habitat folder allocation — PARTIAL

- Added `src/server/HabitatManager.lua`.
- Creates `Workspace.Habitats`.
- Allocates a folder named `Habitat_<UserId>`.
- Keeps a per-server table mapping UserId to folder.
- Provides lookup and removal helpers.
- `ServerMain.server.lua` calls allocation after successful data load.
- Final committed ServerMain calls `HabitatManager.removeHabitat(player)` during PlayerRemoving.

This does not yet provide a complete habitat lifecycle, character spawn/respawn, safe restoration, collision-free placement, or complete ownership validation.

### Resource cooldowns — PARTIAL IMPROVEMENT

- `ResourceManager.lua` now stores cooldowns in `playerCooldowns[UserId][nodeId]`.
- This removes the previous single global cooldown table.
- It is in-memory only and does not prove exact node-instance ownership or full per-habitat resource state.
- The cooldown is currently set before inventory reward grant; full inventory can therefore trigger a cooldown without a reward.

### World building — PARTIAL AND CURRENTLY BLOCKED

- `WorldBuilder.buildHabitat(folder, owner)` builds a habitat beneath the provided folder.
- Its old `WorldBuilder.init()` function was removed.
- `ServerMain.server.lua` still calls `WorldBuilder.init()`. This mismatch is a P0 startup blocker and must be corrected first.
- BaseOffset does not separate habitats: it increments only 0.1 studs on a diagonal and repeats every 1,000 UserIds while each baseplate is 100×100 studs.
- Leaves/berries and plot borders add BaseOffset a second time; paths are not consistently positioned relative to the habitat origin.

### Client prompt discovery — PARTIAL AND RACE-PRONE

- Final source uses `Players.PlayerAdded`, not the invalid `LocalPlayer.PlayerAdded` property described by the review.
- However, `ConnectToPlayerHabitat(_player)` is only called from that PlayerAdded event. Add an unconditional startup lookup for an already-existing local player habitat.
- The `Habitats.ChildAdded` handler scans any new habitat folder instead of restricting itself to the local player's folder. It may scan before descendant prompts have been inserted.
- The client must connect only to its own habitat and handle descendant additions/removals safely. Server validation remains mandatory.

### Cleanup — PRESENT FOR PLAYER REMOVAL, NOT FULLY VERIFIED

- The final `ServerMain.server.lua` does call `HabitatManager.removeHabitat(player)` in PlayerRemoving. The earlier reviewer statement that this call was missing is stale for the final committed version.
- No Roblox runtime test verified cleanup, rejoin, duplicate allocation, or shutdown behavior.
- DataStoreManager's final-save failure semantics remain unsafe; see the audit.

## Corrections to earlier automated review / QA claims

- Reviewer: "LocalPlayer.PlayerAdded is invalid." The final committed code uses `Players.PlayerAdded`; the remaining problem is a possible missed initial lookup and event-order race.
- Reviewer: "PlayerRemoving cleanup is missing." Final committed ServerMain includes `HabitatManager.removeHabitat(player)`.
- QA: "BaseOffset solves world-space overlap." False: 0.1-stud diagonal increments cannot separate 100×100 baseplates.
- QA: "Habitat spawning is wired." False: no CharacterAdded or character-positioning logic exists in HabitatManager/ServerMain.
- QA: did not detect that ServerMain calls the removed `WorldBuilder.init()` function.

These discrepancies demonstrate why reviewers must verify claims against final committed source and why static CI/LLM QA cannot replace runtime testing.

## Run #32 verification boundaries

Passed:
- Rojo build.
- StyLua check of src (0 errors, 0 warnings, 0 parse errors).
- Selene src.
- `git diff --check` was reported passing by the repair agent.
- Gameplay checkpoint and artifact persistence.

Not executed:
- TestEZ.
- Roblox server startup or engine simulation.
- Roblox Studio playtest.
- Two-client multiplayer.
- DataStore integration, contention, save/rejoin, or shutdown testing.
- Manual prompt, plot, resource, spawn, mobile, or touch testing.

## Next work

Follow `project-state/run-32-audit.md` in priority order. At minimum:
1. Fix the missing WorldBuilder API call.
2. Correct habitat slot allocation and all geometry transforms.
3. Fix local-player prompt discovery.
4. Add exact server-side plot/resource ownership and distance checks.
5. Implement spawn/respawn and save restoration.
6. Implement failure-safe cross-server DataStore session ownership.
7. Isolate creature runtime.
8. Add automated tests and validate in Roblox Studio with two clients.

**Do not call Milestone 2 complete, and do not label the game playable, until the milestone acceptance criteria pass.**
