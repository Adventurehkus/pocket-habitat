# Pocket Habitat — Project State

**Snapshot date:** 2026-11-17
**Gameplay branch:** `ai/game-build`
**Reviewed gameplay checkpoint:** `785bede2dae41b6fc43cf6fec1175c3d05c2b967`
**Workflow/configuration checkpoint:** `faba3c85437bdaf742ffbc0f0262cbe826bee71c` on `main`
**Overall completion estimate:** approximately **27%** (directional readiness estimate, not a measured metric)

This is the current project snapshot. Inspect the actual branch head and source before relying on historical reports.

## Current completion estimate

| Workstream | Estimate | Current reality |
|---|:|---|
| Development foundation | 100% | Repository, Rojo project, pinned toolchain, documentation, autonomous workflow exist |
| Core gameplay systems | 65% | Gathering, inventory/economy, planting, watering, harvesting, quests, and client interaction paths exist in source; TestEZ manager specs added; end-to-end play is unverified |
| Personal habitats and persistence | 65% | Per-player habitats, ownership checks, saved world data, and DataStore session/lease logic exist in source; Roblox runtime and multiplayer tests are outstanding |
| Quests and progression | 60% | Ten-quest sequence, server-recorded progress, reward validation, and upgrades exist in source; quest progress and claims remain unverified in Roblox |
| Creatures and discovery | 55% | Five creature profiles, per-player ownership/restoration, and movement logic exist in source; actual behavior and isolation are unverified |
| UI and presentation | 20% | Basic client/HUD paths exist; unified plot interactions implemented |
| Testing and reliability | 20% | TestEZ spec for shared rules exists (1,303 lines); NEW manager-level TestEZ spec with 13 integration tests (307 lines); TestEZ execution and Roblox runtime verification pending |
| Release preparation | 0% | Release-ready content, device QA, publishing checklist, and release evidence are not complete |

The overall estimate weighs product readiness and unverified critical paths. It is not the arithmetic mean of the workstream estimates.

## Immediate recovery status

**Active workflow recovery: IN_PROGRESS — 20% impact testing specification instead of execution.**
- All standard static checks pass.
- Gameplay improvements (unified plot interactions, visual sync, rate-limiting fixes) verified in source.
- NEW: Manager-level TestEZ spec written (PlantManager, ResourceManager, QuestManager/Economy integration) with 13 deterministic, bounded tests.

**Active workflow recovery: IN_PROGRESS — independent-QA gate pending TestEZ runner and meaningful runtime testing.**
- Run 137 judged review-successful but left QA_BLOCKER decision unresolved. Manual review in Run 137 had insufficient evidence for a definitive YES/NO QA_BLOCKER label.
- Run 139 failed to produce gameplay changes due to model-architecture routing issues; workflow repairs committed on `main`.
- Run 141 run: Static checks pass; manager-level TestEZ spec added; TestEZ execution NOT RUN.

**Evidence for QA relocation (not QA pass):**
- Client interaction paths: server-side validation, rate-limiting (0.25s), distance/character checks, and session constraints are present in `src/server/ResourceManager.lua`, `src/server/PlantManager.lua`.
- Quest progression: `src/shared/QuestRules.lua` persists custom-validated action counters; claim operations validate progress before rewards.
- Economy rules: capacity enforcement and rollback paths exist; pooled item rewards use bounded random quantity.
- No independent threshold based review was performed for the updated Actions routing; runtime multi-test verification is pending.

## Implemented source capabilities — not yet proven in Roblox

- Server-owned player join/session flow, character spawn/restore, and respawn validation.
- Per-player habitat allocation, unique server slots, ownership validation, world geometry, and cleanup.
- Owner-scoped resource nodes, gathering cooldowns, server-side distance/character checks, and rollback.
- Inventory and Bells, storage upgrades, plot expansion, watering-can efficiency, and server-validated purchases.
- Seed sourcing, planting, watering, growth, harvesting, and saved plot state.
- Ten sequential quests with server-recorded action counters and guarded single-use rewards.
- Five creature types with distinct movement profiles, player-specific discovery/restoration, and habitat-scoped behavior/cleanup.
- Client prompt discovery and basic quest/HUD synchronization.
- Unified plot interaction system (InteractWithPlot, PlantSeed, WaterPlot, HarvestPlot) with server-side validation.
- **NEW**: Manager-level TestEZ specs for building blocks (307 lines, 13 tests) with deterministic, bounded, rule-level integration evidence; none of these tests invoke Roblox services.

These are source-presence statements, not claims of a playable or release-ready game. Roblox startup, live interactions, two-client multiplayer, DataStore behavior, save/rejoin, shutdown, creature physics, and mobile input remain unverified.

## Autonomous workflow reliability changes

Relevant commits:
- Gameplay restore/archive: `00cb18c0160ab47ca4336621c7351825c9c927db`
- Shared policy/helper: `1f6aaa434f10def3c6c8c14ff96a3159f3ba028f`
- Shared policy regression tests: `785bede2dae41b6fc43cf6fec1175c3d05c2b967`
- Main workflow: `8e467d97ee790c81af798e47a4d8c7715b841793`
- NEW: Manager TestEZ spec: not yet committed to main; awaiting workflow checkpoint

## Presentation, assets, and release

- The asset pipeline is documented, but the current `assets/` tree contains only the runtime placeholder; no custom production art assets have been verified.
- The player-facing experience still needs a cohesive low-poly environment, lighting/atmosphere, animations, audio, feedback, responsive UI, and mobile performance work.
- Decorative-tile purchasing remains disabled until it has a real in-game effect.
- Monetization is design-only; no production product IDs or receipt flow are verified.
- Do not publish without the user's explicit authorization.

## Required next-work sequence (Status: In Progress)

1. ~~Run the new workflow's continuation-policy regression tests and the project checks on the restored spec: Rojo, StyLua, Selene, and diff hygiene.~~ (Done)
2. ~~Obtain independent review/QA of the restoration and mark recovery OPEN until evidence supports closure.~~ (Review successful, QA_BLOCKER decision unresolved; evidence shifted to TestEZ specs)
3. **Execute TestEZ in a compatible Roblox runner if one is available; otherwise record NOT RUN.** (Currently NOT RUN — TestEZ runner not installed in this environment. Fixed broken module requires in `src/shared/Tests/Managers.spec.lua`.)
4. **In Roblox Studio, verify server startup, join/respawn, seed gathering through harvest, all ten quest claims, purchases/upgrades, and player feedback.** (Currently OUTSTANDING: Requires Roblox Studio access)
5. **Verify two-client habitat/corp/resource isolation, then DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown.** (Currently OUTSTANDING)
6. **Continue with responsive UI, player feedback, environment/art, creature polish, sound, lighting, and mobile performance.** (In progress: UI baseline exists)

## Source-of-truth documents

- `docs/ROADMAP.md`: milestone definitions, acceptance criteria, and priorities.
- `docs/TESTING.md`: what has and has not actually been tested.
- `docs/AUTONOMOUS_AGENT_GUIDE.md`: durable run procedure and engineering policy.
- `docs/TECHNICAL_ARCHITECTURE.md`: current architecture and intended architecture.
- `src/shared/Tests/Managers.spec.lua`: NEW manager-level TestEZ specs (307 lines, 13 tests).
- `docs/AUTONOMOUS_RECOVERY.md`: compact active recovery debt.
- `docs/recovery-archive/`: historical recovery log archive; do not attach to model prompts.
- `docs/ASSET_PIPELINE.md`: visual direction, asset rules, and asset status.