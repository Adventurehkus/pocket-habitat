# Pocket Habitat — Development Roadmap

This is a living priority queue. The checked-out source and docs/PROJECT_STATE.md describe factual implementation status; this file defines priority and acceptance criteria. Do not infer runtime success from source presence or a successful Rojo build.

Status labels:
- **Complete:** integrated and verified to the stated level.
- **Implemented, runtime-unverified:** source exists and static checks pass; Roblox behavior is not yet verified.
- **In progress:** partial implementation or missing integration.
- **Blocked:** a known issue prevents the path from working.
- **Planned:** not implemented.

## Current snapshot — 2026-11-20

**Estimated overall readiness: approximately 27% (directional).**
**Recovery status: RESOLVED (Run #152).**
**Vertical slice validation: Task QSA-101 passed source-level checks (Run #153). Seed-to-Plant-to-Creature lifecycle vertical slice verified at source level (this cycle).**
All automation-resolvable source-level issues fixed or confirmed non-actionable. Rojo build, stylua, selene, and git diff checks pass. Task QSA-101 (Quest-Feature Integration with Server Authority Checks) achieved source-level pass in Run #153. Complete gameplay loop integration (gather → plant → water → harvest → claim quest → discover creature → purchase upgrade) verified with all server-authority checks. Quest claim → Creature discovery integration gap resolved. Runtime verification (TestEZ, Roblox Studio, multiplayer, DataStore, save/rejoin) blocked by environment constraints. Full evidence in docs/AUTONOMOUS_RECOVERY.md and docs/recovery-archive/AUTONOMOUS_RECOVERY_2026-11-15_PRE_COMPACTION.md.

## Milestone 0 — Foundation
**Status: COMPLETE.**

## Milestone 1 — Playable prototype loop
**Status: SOURCE-LEVEL IMPLEMENTATION PRESENT; SERVER-AUTHORITY VALIDATED; RUNTIME-UNVERIFIED.**

**Progress indicator for Milestone 1:**
- Task QSA-101 (Quest-Feature Integration with Server Authority Checks): Pass (Run #153)
- Seed-to-Plant-to-Creature lifecycle vertical slice: Source-level verified (this cycle)
- All core manager modules (ResourceManager, PlantManager, QuestManager, CreatureManager, DataStoreManager, EconomyManager, HabitatManager) have comprehensive server-authority checks

Acceptance:
- [ ] Server starts without runtime errors.
- [ ] New player joins and respawns correctly.
- [ ] Gathering, planting, watering, harvesting, rewards, and player feedback work in Studio.
- [x] Actions are server-authoritative and fail safely (validated at source via Run #152 recovery checks).
- [x] Quest and upgrade paths source implementation exists with validation (Run #40 Plot consolidation verified).
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
**Status: PARTIALLY IMPLEMENTED; test specifications exist in source; execution blocked by environment.**

## Current priority

1. **Recovery status**: RESOLVED — All automation-resolvable source checks (Rojo, stylua, selene, git diff) pass; critical findings investigated and confirmed clean. Task QSA-101 vertical slice achieved source-level pass in Run #153.
2. **Quest feature integration**: COMPLETE at source level — QUEST_MANAGER_CLAIM_QUEST handler implements all server-authority checks (ownership, interval, resource prerequisites, economy validation, creature discovery state, DataStore persistence). Quest→Creature discovery integration gap fixed (QuestManager now calls CreatureManager.checkDiscoveries after reward grant).
3. **Seed-to-Plant-to-Creature lifecycle vertical slice**: COMPLETE at source level — Full gameplay loop integration verified with server-authority checks across all managers.
4. **Next vertical slice candidate**: Creature behavior implementation (server-scoped AI loops, habitat-bound movement, multiplayer isolation) or EconomyManager upgrade effects (decorative_tile visual implementation).
5. **Runtime verification**: Blocked by environment — TestEZ, Roblox Studio, multiplayer, DataStore persistence require Roblox-compatible runner.

Do not count recovery checkpoint resolution or source-level vertical slice validation as development progress. A validated cycle requires implementation, independent review, deterministic validation, independent QA, and checkpoint persistence.