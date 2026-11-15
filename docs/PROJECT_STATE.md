# Pocket Habitat — Project State

**Snapshot date:** 2026-11-15  
**Gameplay branch:** `ai/game-build`  
**Snapshot commit:** `2f651313d4b855b3333d9670ac9585d7add0f026`  
**Overall completion estimate:** approximately **25%** (directional project-readiness estimate, not a measured metric)

This is the authoritative current-state snapshot. Historical run reports below or in other documents must not override the latest branch state described here. Always inspect the actual source and latest recovery record before starting work.

## Current completion estimate

| Workstream | Estimate | Current reality |
|---|---:|---|
| Development foundation | 100% | Repository, Rojo project, pinned toolchain, documentation, and automated workflow exist |
| Core gameplay systems | 60% | Gathering, inventory/economy, planting, watering, harvesting, and client interaction paths exist in source; end-to-end play is unverified |
| Personal habitats and persistence | 65% | Per-player habitat allocation, ownership checks, saved world data, and DataStore session/lease logic exist in source; Roblox runtime and multiplayer tests are outstanding |
| Quests and progression | 60% | Ten-quest sequence, server-recorded progress, reward validation, and several upgrades exist in source; claims and persistence are unverified in Roblox |
| Creatures and discovery | 55% | Five creature profiles, per-player ownership/restoration, and movement logic exist in source; actual behavior and isolation are unverified |
| UI and presentation | 15% | Basic client/HUD paths exist; cohesive responsive inventory, quest, discovery, feedback, and polished presentation remain |
| Testing and reliability | 5% | Static tooling has passed on earlier checkpoints, but TestEZ has not been run and the current test file has a critical regression; no Roblox runtime evidence |
| Release preparation | 0% | No release-ready art/content pass, device QA, publishing checklist, or release evidence |

The overall estimate is intentionally lower than the source-feature estimates because a functioning Roblox experience still requires integrated runtime proof, reliable persistence/multiplayer, a usable player experience, content/art, and release QA. Do not calculate overall completion by averaging the rows.

## Important current blocker — test suite regression

At the snapshot commit, `src/shared/PocketHabitat.spec.lua` has been replaced with whitespace-stripped content. The Run #88 cycle-2 independent reviewer classified this as **CRITICAL** and found examples such as `localReplicatedStorage` and `localfunctionmakeData`, which do not preserve the intended Luau token boundaries. The reviewer states the spec file is syntactically invalid and cannot serve as a TestEZ suite.

- Recovery marker: **OPEN** in `docs/AUTONOMOUS_RECOVERY.md`.
- Required repair: restore the test file from its last known-good pre-corruption revision (inspect parent commit `6cfdc9ea061b8c80ab2a93651b11cc97b81187a8`), then review the diff and run formatter/linter/build checks.
- Do not claim the current TestEZ suite is usable or that its tests pass.
- No new gameplay feature work should bypass this recovery item.

Older static-check PASS records refer to earlier source snapshots. They are not evidence that the current branch head passes validation after this corruption.

## Implemented source capabilities — not yet proven in Roblox

The current source contains the following systems:

- Server-owned player join/session flow, character spawn/restore, and respawn validation.
- Per-player habitat allocation, unique server slots, ownership validation, world geometry, and cleanup.
- Resource nodes resolved from the player's own habitat, server-side distance/character checks, per-player cooldowns, and reward rollback paths.
- Inventory, Bells, storage capacity, plot expansion, watering-can efficiency, and server-validated purchase logic.
- Plant seed sourcing, planting, watering, growth, harvesting, and saved plant/plot state.
- Ten sequential quests with server-recorded action counters, target-specific discovery/harvest validation, and guarded single-use rewards.
- Five creature types with distinct movement profiles, player-specific discovery/restoration, and habitat-scoped behavior/cleanup.
- Client prompt discovery and basic quest/HUD synchronization.

These are source-presence statements, not claims of a playable or release-ready game. Roblox startup, live interactions, two-client multiplayer, real DataStore behavior, save/rejoin, shutdown, creature physics, and mobile input remain unverified.

## Presentation, assets, and release

- The asset pipeline is documented, but the current `assets/` tree contains only the runtime placeholder; no custom production art assets have been verified.
- The player-facing experience still needs a cohesive low-poly environment, lighting/atmosphere, animations, audio, feedback, and responsive UI.
- Decorative-tile purchasing remains disabled until it has a real in-game effect.
- Monetization is design-only; no production product IDs or receipt flow are verified.
- Publishing is not authorized by this snapshot and must not occur without the user's explicit approval.

## Autonomous workflow status

- Run #115 (ID `43719238566`) completed with a successful workflow result because it dispatched a continuation. Its own log reports **0 autonomous development cycles**, **0 validated checkpoints**, and **no repository changes saved**; the stop reason was `no_implementation_progress`. The workflow's green result must not be interpreted as gameplay progress.
- Run #116 (ID `43730225075`) was **in progress at the time of this snapshot**. Its outcome is unknown until checked again.
- Quota/continuation workflow improvements are development infrastructure. They do not count as game-feature completion unless they produce reviewed and validated gameplay changes.

## Required next-work sequence

1. **Repair recovery first:** restore and inspect `src/shared/PocketHabitat.spec.lua` from the last good revision; preserve the full test intent and normal Luau formatting.
2. Run `rojo build default.project.json -o build/pocket-habitat.rbxl`, `stylua --check src`, `selene src`, and `git diff --check`; record the actual results against the repaired commit.
3. Execute TestEZ in a compatible Roblox runner. Installing TestEZ or having spec files present does not count as execution.
4. In Roblox Studio, verify server startup, join/respawn, seed gathering through harvest, all ten quest claims, purchases/upgrades, and player feedback.
5. Verify two-client habitat/creature/resource isolation, then DataStore load/save/rejoin, lease contention/renewal, failure handling, and shutdown.
6. Build the actual player experience: responsive UI, clear interaction feedback, environment/art, creature polish, sound, lighting, and mobile performance.
7. Complete balancing, content, and release QA. Do not publish without explicit user authorization.

## Source-of-truth documents

- `docs/ROADMAP.md`: milestone definitions, feature acceptance criteria, and priorities.
- `docs/TESTING.md`: what has and has not actually been tested.
- `docs/AUTONOMOUS_RECOVERY.md`: open recovery debt and its evidence.
- `docs/ASSET_PIPELINE.md`: visual direction, asset rules, and asset status.
