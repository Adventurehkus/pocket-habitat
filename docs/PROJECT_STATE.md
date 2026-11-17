# Pocket Habitat — Project State

**Snapshot date:** 2026-11-17
**Gameplay branch:** `ai/game-build`  
**Reviewed gameplay checkpoint:** `785bede2dae41b6fc43cf6fec1175c3d05c2b967`  
**Workflow/configuration checkpoint:** `8e467d97ee790c81af798e47a4d8c7715b841793` on `main`  
**Overall completion estimate:** approximately **25%** (directional readiness estimate, not a measured metric)

This is the current project snapshot. Inspect the actual branch head and source before relying on historical reports.

## Current completion estimate

| Workstream | Estimate | Current reality |
|---|---:|---|
| Development foundation | 100% | Repository, Rojo project, pinned toolchain, documentation, and autonomous workflow exist |
| Core gameplay systems | 60% | Gathering, inventory/economy, planting, watering, harvesting, quests, and client interaction paths exist in source; end-to-end play is unverified |
| Personal habitats and persistence | 65% | Per-player habitats, ownership checks, saved world data, and DataStore session/lease logic exist in source; Roblox runtime and multiplayer tests are outstanding |
| Quests and progression | 60% | Ten-quest sequence, server-recorded progress, reward validation, and upgrades exist in source; claims and persistence remain unverified in Roblox |
| Creatures and discovery | 55% | Five creature profiles, per-player ownership/restoration, and movement logic exist in source; actual behavior and isolation are unverified |
| UI and presentation | 15% | Basic client/HUD paths exist; responsive inventory, discovery, feedback, environment, audio, and polish remain |
| Testing and reliability | 10% | The 1,303-line TestEZ spec has been restored; static checks and Rojo build pass, but TestEZ execution and Roblox runtime verification are still pending |
| Release preparation | 0% | Release-ready content, device QA, publishing checklist, and release evidence are not complete |

The overall estimate weighs product readiness and unverified critical paths. It is not the arithmetic mean of the workstream estimates.

## Immediate recovery status

**Active recovery debt (`docs/AUTONOMOUS_RECOVERY.md`): RESOLVED — The UI toggle button defect is fixed and independently verified; test spec restoration is verified via static analysis and Rojo build.**

- `src/shared/PocketHabitat.spec.lua` was restored from the intact revision at commit `6cfdc9ea061b8c80ab2a93651b11cc97b81187a8`.
- The empty `src/shared/PocketHabitat.spec.lua.restored` placeholder was removed.
- Restoration is a source change, not proof of validation. TestEZ is NOT RUN unless a compatible runner actually executes it.

**CreatureManager validation (Run 128 cycle 4): RESOLVED — defensive validation implemented and verified via static analysis.**

## Implemented source capabilities — not yet proven in Roblox

- Server-owned player join/session flow, character spawn/restore, and respawn validation.
- Per-player habitat allocation, unique server slots, ownership validation, world geometry, and cleanup.
- Owner-scoped resource nodes, gathering cooldowns, server-side distance/character checks, and reward rollback.
- Inventory and Bells, storage upgrades, plot expansion, watering-can efficiency, and server-validated purchases.
- Seed sourcing, planting, watering, growth, harvesting, and saved plot state.
- Ten sequential quests with server-recorded action counters and guarded single-use rewards.
- Five creature types with distinct movement profiles, player-specific discovery/restoration, and habitat-scoped behavior/cleanup.
- Client prompt discovery and basic quest/HUD synchronization.

These are source-presence statements, not claims of a playable or release-ready game. Roblox startup, live interactions, two-client multiplayer, DataStore behavior, save/rejoin, shutdown, creature physics, and mobile input remain unverified.

## Autonomous workflow reliability changes

Relevant commits:
- Gameplay restore/archive: `00cb18c0160ab47ca4336621c7351825c9c927db`
- Shared policy/helper: `1f6aaa434f10def3c6c8c14ff96a3159f3ba028f`
- Shared policy regression tests: `785bede2dae41b6fc43cf6fec1175c3d05c2b967`
- Main workflow: `8e467d97ee790c81af798e47a4d8c7715b841793`

## Presentation, assets, and release

- The asset pipeline is documented, but the current `assets/` tree contains only the runtime placeholder; no custom production art assets have been verified.
- The player-facing experience still needs a cohesive low-poly environment, lighting/atmosphere, animations, audio, feedback, responsive UI, and mobile performance work.
- Decorative-tile purchasing remains disabled until it has a real in-game effect.
- Monetization is design-only; no production product IDs or receipt flow are verified.
- Do not publish without the user's explicit authorization.

## Required next-work sequence (Status: In Progress)

1. ~~Run the new workflow's continuation-policy regression tests and the project checks on the restored spec: Rojo, StyLua, Selene, and diff hygiene.~~ (Done)
2. ~~Obtain independent review/QA of the restoration and mark recovery RESOLVED only when evidence supports it.~~ (Done)
3. Execute TestEZ in a compatible Roblox runner if one is available; otherwise record NOT RUN. (Currently NOT RUN, static checks passed)
4. In Roblox Studio, verify server startup, join/respawn, seed gathering through harvest, all ten quest claims, purchases/upgrades, and player feedback. (Currently NOT RUN)
5. Verify two-client habitat/creature/resource isolation, then DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown. (Currently NOT RUN)
6. Continue with responsive UI, player feedback, environment/art, creature polish, sound, lighting, and mobile performance. (In progress: UI baseline exists)

## Source-of-truth documents

- `docs/ROADMAP.md`: milestone definitions, acceptance criteria, and priorities.
- `docs/TESTING.md`: what has and has not actually been tested.
- `docs/AUTONOMOUS_RECOVERY.md`: compact active recovery debt.
- `docs/recovery-archive/`: historical recovery log archive; do not attach to model prompts.
- `docs/ASSET_PIPELINE.md`: visual direction, asset rules, and asset status.