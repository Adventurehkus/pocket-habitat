# Pocket Habitat — Agent Instructions

## Project
Build Pocket Habitat, a colorful, polished, low-poly Roblox habitat-building simulator. Players explore a small habitat, collect resources, grow plants, discover creatures, complete quests, earn currency, and unlock upgrades and biomes.

## Development priorities
1. Complete a small, playable MVP before expanding scope.
2. Use Luau and the existing Rojo/Rokit project configuration.
3. Keep all gameplay authority on the server: currency, inventory, harvesting, rewards, quests, unlocks, plant state, creature ownership, purchases, and persistence.
4. Validate every client request on the server. Use cooldowns, distance/ownership checks, and idempotent reward handling.
5. Use DataStoreService carefully: version player data, handle failures, save on departure, and autosave without excessive requests.
6. Create original low-poly environments and assets with native Roblox geometry or procedural generation. Avoid copied/copyrighted assets and unnecessary Toolbox dependencies.
7. Make UI responsive for mouse, keyboard, and touch.
8. Keep multiplayer player data and habitats isolated.

## Repository rules
- main contains the workflow; ai/game-build is the game source branch.
- The GitHub Actions workflow checks out ai/game-build and automatically commits/pushes changed files after each run, including partial work on failure.
- Do not create, rename, or switch Git branches.
- Do not run git commit or git push from the agent. The workflow handles checkpointing.
- Do not publish to Roblox or request/store publishing credentials in the coding agent.
- Never invent tools. Use only the tools exposed to the OpenCode session. Use the shell tool for shell commands.
- Inspect relevant files only. Avoid repeated full-repository scans and unnecessary context.
- Preserve existing work. Make small, testable edits.
- Do not claim a check passed unless it actually ran and passed.

## Toolchain
Use versions pinned in rokit.toml: Rojo, StyLua, Selene, and Wally. Keep default.project.json mappings valid. Use TestEZ when tests are added.

## Milestones
0. Foundation: project layout, documentation, pinned tools, ignore rules, build/lint/format checks.
1. Playable core: starter habitat, basic resource gathering, planting/growth, first creature discovery, player feedback.
2. Progression: inventory, currency, quests, upgrades, unlocking, save/load.
3. Presentation: coherent environment, lighting, creatures, UI, animations, and feedback.
4. QA: server authority, exploit resistance, persistence, multiplayer, performance, client/device testing.
5. Release preparation: product configuration, presentation, documentation, and release checklist.

## Documentation
Keep these files accurate and concise:
- docs/GAME_DESIGN.md
- docs/ROADMAP.md
- docs/PROJECT_STATE.md
- docs/TECHNICAL_ARCHITECTURE.md
- docs/ASSET_PIPELINE.md
- docs/TESTING.md
- docs/MONETIZATION.md

PROJECT_STATE.md must state completed work, current milestone, implemented systems, known issues, actual test results, and the exact next task.

## Definition of done
A milestone is complete only when its implementation exists, relevant checks have actually run, and the documentation accurately describes the result and remaining work.