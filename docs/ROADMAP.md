# Pocket Habitat — Development Roadmap

This is a living priority queue. The checked-out source and docs/PROJECT_STATE.md describe factual implementation status; this file defines priority and acceptance criteria. Do not infer runtime success from source presence or a successful Rojo build.

Status labels:
- **Complete:** integrated and verified to the stated level.
- **Implemented, runtime-unverified:** source exists and static checks pass; Roblox behavior is not yet verified.
- **In progress:** partial implementation or missing integration.
- **Blocked:** a known issue prevents the path from working.
- **Planned:** not implemented.

## Current snapshot — 2026-11-20

**Estimated overall readiness: approximately 30% (directional).**
**Recovery status: RESOLVED (Run #152).**
**Vertical slice validation: Task QSA-101 passed source-level checks (Run #153). Seed-to-Plant-to-Creature lifecycle vertical slice verified at source level. Decorative Tile implementation vertical slice completed (Cycle 164).**
All automation-resolvable source-level issues fixed or confirmed non-actionable. Rojo build, stylua, selene, and git diff checks pass. Task QSA-101 and complete gameplay loop integration (gather → plant → water → harvest → claim quest → discover creature → purchase upgrade) achieved source-level pass. Quest claim → Creature discovery integration gap resolved. decorative_tile upgrade implemented with visual effects, server-authority validation, and data persistence. Runtime verification (TestEZ, Roblox Studio, multiplayer, DataStore, save/rejoin) blocked by environment constraints.

## Milestone 0 — Foundation
**Status: COMPLETE.**

## Milestone 1 — Playable prototype loop
**Status: SOURCE-LEVEL IMPLEMENTATION PRESENT; SERVER-AUTHORITY VALIDATED; RUNTIME-UNVERIFIED.**

**Progress indicator for Milestone 1:**
- Task QSA-101 (Quest-Feature Integration with Server Authority Checks): Pass (Run #153)
- Seed-to-Plant-to-Creature lifecycle vertical slice: Source-level verified
- Decorative Tile upgrade: Implemented and server-authority validated (Cycle 164)
- All core manager modules (ResourceManager, PlantManager, QuestManager, CreatureManager, DataStoreManager, EconomyManager, HabitatManager, WorldBuilder) have comprehensive server-authority checks

Acceptance:
- [ ] Server starts without runtime errors.
- [ ] New player joins and respawns correctly.
- [ ] Gathering, planting, watering, harvesting, rewards, and player feedback work in Studio.
- [x] Actions are server-authoritative and fail safely (validated at source via Run #152 recovery checks).
- [x] Quest and upgrade paths source implementation exists with validation (decorative_tile implemented in Cycle 164).
- [ ] Two-client testing passes.
- [ ] Save/rejoin restores data without overwriting existing records.

## Milestone 2 — Personal habitats and multiplayer/data reliability
**Status: SOURCE-LEVEL IMPLEMENTATION PRESENT; SERVER-AUTHORITY CHECKS PRESENT; RUNTIME-UNVERIFIED.**

## Milestone 3 — Progression integrity and content
**Status: PARTIALLY IMPLEMENTED; VALIDATION CHECKS EXISTS; TESTEZ EXECUTION PENDING.**

## Milestone 4 — Player experience and presentation
**Status: PARTIALLY IMPLEMENTED / PLANNED.**

## Milestone 5 — QA and hardening
**Status: ENGINE-LEVEL VALIDATION CHECKS EXISTS; RUNTIME EXECUTION PENDING.**

## Milestone 6 — Release
**Status: PLANNED.**

## Milestone 7 — Testing and reliability
**Status: PARTIALLY IMPLEMENTED; visual effects exist (decorative tiles, creatures, plants); test specifications exist in source; execution blocked by environment.**

## Current priority

1. **Recovery status**: RESOLVED — All automation-resolvable source checks (Rojo, stylua, selene, git diff) pass; critical findings investigated and confirmed clean. Task QSA-101 vertical slice achieved source-level pass in Run #153.
2. **Quest feature integration**: COMPLETE at source level — QUEST_MANAGER_CLAIM_QUEST handler implements all server-authority checks (ownership, interval, resource prerequisites, economy validation, creature discovery state, DataStore persistence). Quest→Creature discovery integration gap fixed (QuestManager now calls CreatureManager.checkDiscoveries after reward grant).
3. **Seed-to-Plant-to-Creature lifecycle vertical slice**: COMPLETE at source level — Full gameplay loop integration verified with server-authority checks across all managers.
4. **Decorative Tile upgrade**: COMPLETE at source level.
   - WorldBuilder.addDecorativeTiles creates 8 configurable Sandstone decorative tiles with proper habitat scoping and restoration.
   - EconomyManager accepts decorative_tile upgrade with cost/level validation.
   - Plot expansion includes bonus decorative tile placement based on upgrade level.
   - Data persistence via decorativeTileCount in session data (restored on habitat rebuild).
5. **Runtime verification**: Blocked by environment — TestEZ, Roblox Studio, multiplayer, DataStore persistence require Roblox-compatible runner.

Do not count recovery checkpoint resolution or source-level vertical slice validation as development progress. A validated cycle requires implementation, independent review, deterministic validation, independent QA, and checkpoint persistence.