# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Latest gameplay implementation checkpoint verified by CI:** 21386b54aa0432c1f5fdb796411c30a41d060350
- **Latest completed gameplay workflow:** Run #30, run ID 43098662842
- **Documentation refresh:** subsequent documentation-only commits advanced ai/game-build beyond that gameplay checkpoint; re-read the current branch HEAD at the beginning of each run.
- **Run #30 result:** completed successfully; its gameplay checkpoint was persisted to ai/game-build.
- **Workflow configuration branch:** main
- **Latest adaptive temporary-limit retry workflow commit:** 36c16722d6ebc2a4bd66433ec5e9ec15ee17b7fa
- **Important verification boundary:** the adaptive retry changes were committed after Run #30 and have not yet been exercised by a fresh live workflow run. They are workflow improvements, not evidence of new gameplay verification.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Update this file after every meaningful implementation or verification run. Do not copy its hashes or run numbers into a permanent handoff prompt.

## Current project status

Pocket Habitat has an implemented prototype gameplay loop and project-owned rule modules, but it is not yet a verified multiplayer-ready game. Static CI passing does not establish runtime correctness.

**Current highest-priority objective:** build a real player-owned habitat lifecycle with independent world state and safe cross-server persistence. The prototype currently uses shared world/resource/creature runtime state in important places.

## Latest verified workflow results — Run #30

Run #30 completed on 2026-11-11 and persisted checkpoint 21386b54aa0432c1f5fdb796411c30a41d060350.

| Check or stage | Result |
|---|---|
| Implementation | SUCCESS |
| Independent review | SUCCESS |
| Conditional repair | SUCCESS |
| QA | SUCCESS |
| Rojo build | PASSED |
| StyLua check src | PASSED; zero errors, warnings, and parse errors |
| Selene src | PASSED |
| TestEZ execution | NOT EXECUTED |
| Roblox Studio gameplay | NOT EXECUTED |
| Two-client multiplayer | NOT EXECUTED |
| DataStore integration/stress | NOT EXECUTED |
| Artifact upload | SUCCESS |

The uploaded artifact was named pocket-habitat-pipeline-30. The generated .rbxl build is a build artifact, not proof of a playable or fully tested experience.

The Run #30 reviewer made an incorrect suggestion to pass Player manually to client RemoteFunction:InvokeServer calls. QA correctly rejected that suggestion. Roblox supplies the calling Player automatically as the first OnServerInvoke callback argument. Preserve the correct client/server signature documented in docs/AUTONOMOUS_AGENT_GUIDE.md.

## Implemented source systems

These systems exist in project-owned source and have passed the applicable Run #30 static checks. Their full in-engine behavior has not been verified in Roblox Studio.

- Server startup and remote creation/registration.
- Shared world construction through WorldBuilder.
- Server-side resource gathering and inventory reward calls.
- Planting, watering, growth-stage checks, and harvesting through PlantManager.
- Shared PlantRules validation for plot interactions.
- EconomyManager inventory/currency/upgrade logic.
- Shared EconomyRules inventory-capacity validation.
- Player session load/save manager using PocketHabitat_v2_PlayerData.
- Quest definitions and a quest manager.
- Creature discovery checks and runtime creature creation.
- Client ProximityPrompt interaction handling and server remote calls.
- TestEZ specifications for PlantRules and EconomyRules.

The source includes additional plant, creature, upgrade, and quest definitions. A definition is not proof of a complete, integrated gameplay feature. Verify the implementation and player-facing behavior before marking content complete.

## Known architecture gaps to verify and address

These were confirmed by source inspection at the current source checkpoint. Re-check the current code before changing them.

### 1. Player-owned habitats are not fully implemented

WorldBuilder initializes a shared Workspace.HabitatWorld with fixed garden plot/resource positions. The source does not yet provide a complete isolated habitat allocation, restoration, ownership registry, spawn, and cleanup lifecycle for each player.

Required direction:
- Allocate each player's habitat on the server.
- Key ownership to the Player/UserId known by the server.
- Restore and instantiate that player's plots/world state.
- Spawn players at their own habitat.
- Prevent overlap and cross-player interaction.
- Handle rejoin, character respawn, disconnect, and server shutdown without duplicate instances or lost state.

### 2. Resource state/cooldowns are shared

ResourceManager has a shared module-level node registry and cooldown state. Resource nodes use fixed world positions, so corresponding resources are not yet independent per player.

Required direction:
- Scope node identity, availability, cooldowns, and rewards to the owning habitat/session.
- Validate the server-resolved node and owner.
- Prevent concurrent requests from duplicating rewards.
- Keep one player's gathering from changing another player's resources.

### 3. Creature runtime ownership is shared

CreatureManager creates a shared Workspace.Creatures folder and keeps a global registry keyed by creature ID. Discovery checks use player data, but runtime instances and lifecycle are not fully player-scoped. The wander bounds are fixed rather than derived from an owner's habitat, and source inspection found only some creature-specific model branches.

Required direction:
- Scope instances and registry keys by owner and creature.
- Restore discovered creatures for the correct habitat.
- Keep movement within the owning habitat.
- Make discovery/rewards idempotent and independent between players.
- Implement genuinely distinct supported creature appearances and behavior.

### 4. DataStore cross-server session ownership is missing

DataStoreManager uses GetAsync/SetAsync with an in-memory activeSessions table and bounded retries. That protects only one server process; it is not a cross-server lease/lock. Save ownership is not protected by an atomic UpdateAsync ownership token.

Required direction:
- Add a server-specific session token and expiring lease acquired atomically.
- Renew/validate the lease as appropriate.
- Ensure only the current owner can write.
- Treat failed reads separately from genuinely absent saves.
- Never overwrite old progression with defaults after a failed load.
- Release ownership safely after the final save.
- Preserve the existing PocketHabitat_v2_PlayerData schema through explicit migrations.

### 5. Quest progression is incomplete

Source inspection found ten quest definitions in Constants but only six entries in QuestManager's quest order. The harvest objective had an unconditional completion branch, upgrade objectives lacked corresponding validation, and some progress was inferred from current inventory/plot state rather than durable action counters.

Required direction:
- Make all intended quests reachable.
- Record progress from server-confirmed actions.
- Validate real harvests, upgrades, planting, gathering, and creature discoveries.
- Persist progress and make rewards idempotent.
- Never accept client-supplied completion or progress.

### 6. Upgrade effects and world integration are incomplete

Source inspection found that plot expansion updates player plot data but does not fully construct matching world geometry/prompts. Some defined upgrades (including decorative and watering improvements) did not have verified gameplay effects.

Required direction:
- Connect each purchasable upgrade to a visible and functional effect.
- Do not sell unavailable or decorative-only effects as working functionality.
- Ensure expanded plots are created, owned, restored, and usable.
- Keep purchase/grant ordering transaction-safe.

## Test coverage and verification gaps

- src/shared/PocketHabitat.spec.lua contains TestEZ specs for production PlantRules and EconomyRules logic.
- The specs cover validation, seed ownership/selection, watering constraints, growth/harvest eligibility, malformed state, inventory capacity, and invalid inventory data.
- TestEZ was installed as a dependency in CI but the spec suite has not been executed by a compatible Roblox/TestEZ runner.
- Remote integration, DataStore session locks, habitat lifecycle, two-player isolation, and live client/UI behavior remain unverified.
- No manual Studio playtest, two-client multiplayer test, mobile touch test, or DataStore stress/rejoin test is claimed.

## Workflow and provider routing status

The model/provider configuration remains in opencode.json on ai/game-build. The GitHub Actions orchestration is maintained in .github/workflows/ai-build.yml on main.

The workflow was updated after Run #30 to add:
- Classification for shared daily quota, model-specific daily quota, request-size rejection, authentication errors, model unavailability, model/provider rate limits, and transient capacity/network failures.
- Provider-supplied retry-delay parsing, including Retry-After headers and textual retry hints.
- Separate model and provider cooldowns.
- Alternative-provider attempts before waiting, followed by automatic resumption of the original stage.
- Bounded retry policies: four attempts per model per stage, up to 50 model calls per stage, up to two hours waiting per stage, and four hours total waiting within a 350-minute job.
- Startup regression fixtures for failure classification and retry-delay parsing.

This workflow change is committed but has not yet had a live CI run. The workflow does not query real remaining account balances. A configured model may still be unavailable because of account quotas, temporary limits, provider service state, or invalid credentials.

## Current priority and exact next task

**Next task:** implement the first complete vertical slice of player-owned habitats, starting with a server-owned habitat registry/allocation and a reliable lifecycle integrated with player join, character spawn, and cleanup. Before editing, inspect the current WorldBuilder, ServerMain, DataStoreManager, PlantManager, ResourceManager, CreatureManager, and remote call sites. Design the minimum compatible data/runtime boundary so later resource and creature isolation can attach to it.

Do not attempt to build every subsystem at once. First produce one working, testable per-player habitat slice and update this state/roadmap with the next dependency. Treat DataStore cross-server locking as a critical dependent workstream; do not claim persistence isolation until it is implemented and tested.

