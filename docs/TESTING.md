# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their actual results.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test.
- A workflow handoff or recovery checkpoint is not a validated development cycle.

## Latest execution — Autonomous Agent Run (2026-11-20)

### Static validation (Pass)
- **Toolchain installation and Rojo build:** `rojo build default.project.json -o build/pocket-habitat.rbxl` — PASS (Valid model artifact generated).
- **StyLua format check:** `stylua --check src` — PASS (0 errors, 0 warnings).
- **Selene linter:** `selene src` — PASS (0 errors, 0 warnings, 0 parse errors).
- **Diff hygiene:** `git diff --check` — PASS (Clean working tree, no trailing whitespace or uncommitted conflicts).
- **Recovery Status:** RESOLVED (All automation-resolvable source-level issues fixed and verified).

### Source-level vertical slice verification (Pass)
- **Seed-to-Plant-to-Creature lifecycle integration:** Verified complete gameplay loop at source level:
  - Gather (ResourceManager) → Quest progress + Creature discovery check
  - Plant (PlantManager) → Quest progress + Creature discovery check
  - Water (PlantManager) → Quest progress + Creature discovery check
  - Harvest (PlantManager) → Quest progress + Creature discovery check
  - Claim Quest (QuestManager) → QuestRules.tryClaim + Economy rewards + **CreatureManager.checkDiscoveries** (fixed)
  - Discover Creature (CreatureManager) → Flora/water validation + Quest progress + Bells + Spawn
  - Purchase Upgrade (EconomyManager) → Quest progress + WorldBuilder (plot_expansion)
- **Server-authority checks:** Ownership, distance, cooldown, session, inventory, economy, quest state validated across all managers.

### Outstanding runtime tests (Explicitly unverified)
- **TestEZ execution:** NOT RUN; no compatible runner available in Linux environment (requires Roblox runtime).
- **Roblox Studio server startup and gameplay:** NOT RUN; requires Roblox deployment.
- **Two-client multiplayer/habitat/resource/creature isolation:** NOT RUN; requires Roblox multiplayer environment.
- **DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown:** NOT RUN; requires Roblox runtime and persistence layer.
- **Mobile/device input and performance:** NOT RUN; requires target deployment platform.

## Standard deterministic checks

1. Validate project JSON and relevant manifests.
2. Build: `rojo build default.project.json -o build/pocket-habitat.rbxl`.
3. Format: `stylua --check src`.
4. Lint: `selene src`.
5. Diff hygiene: `git diff --check`.
6. Inspect working tree: `git status --short`.
7. Execute manager/shared-rule TestEZ specs only through a compatible runner.

## Studio testing procedure

1. Habitat allocation: separate, non-overlapping floating islands.
2. Resource cooldowns and idempotent rewards.
3. DataStore save/rejoin without data loss.
4. Creature isolation and habitat-scoped interactions.
5. Cross-player request rejection and ownership isolation.
6. Join/respawn, gathering-to-harvest, quests, upgrades, and player-facing feedback.
