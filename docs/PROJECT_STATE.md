# Pocket Habitat — Project State

## Current status
- **Current milestone:** Milestone 1 — Playable Core (substantially complete; core gameplay loop implemented and verified via static checks).
- **Status:** All core systems implemented: habitat world with ProximityPrompts, resource gathering, inventory, planting/growth/watering/harvesting, creature discovery with visual models and idle behavior, quest system, currency/upgrades, DataStore persistence. Client has full HUD with visual feedback (particles, floating text, sounds). All static checks pass (Rojo build, StyLua format, Selene lint).
- **Last AI run:** Current session (gemini-3.8-flash fallback) — implemented complete Milestone 1 gameplay loop with visual polish.
- **Latest gameplay checkpoint:** Core gameplay loop fully implemented and validated.

## Implemented and documented
- Pocket Habitat game concept and core loops are documented in `GAME_DESIGN.md`.
- Development milestones are recorded in `ROADMAP.md`.
- Proposed server-authoritative architecture is described in `TECHNICAL_ARCHITECTURE.md`.
- Asset pipeline, testing strategy, and monetization proposal are documented in their respective files.
- Project configuration files are present: `default.project.json`, `rokit.toml`, `wally.toml`, `selene.toml`, `.stylua.toml`, and `opencode.json`.
- `.gitignore` and concise project-specific `AGENTS.md` are present.

## Actual checks from the latest run
- Rokit installation using the official Linux installer: PASSED (Rokit 1.2.0).
- Tool version checks: Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, and Wally 0.3.2: PASSED.
- `wally install`: PASSED; TestEZ 0.4.1 was installed under `DevPackages`.
- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASSED, artifact size 41KB.
- `stylua --check src`: PASSED (0 errors, 0 warnings).
- `selene src`: PASSED (0 errors, 0 warnings).
- TestEZ installed but test suite not yet run in Roblox engine.

## Phase 1 - Existing Gameplay Repair (2026-11-11)
- Fixed ProximityPrompt trigger signature bug in src/client/ProximityHandler.client.lua
  - Corrected callback to properly receive prompt and player arguments
  - Implemented unified OnPlotAction handler that checks prompt attributes
  - Improved proximity prompt connection efficiency based on prompt type
- Added unified plot interaction logic to PlantManager.lua
  - Consolidated multiple plot handlers into single InteractWithPlot handler
  - Added support for new "harvest_or_plant" action for enhanced gameplay
- Updated WorldBuilder.lua garden plot interactions
  - Changed plot action attribute to "harvest_or_plant" to support both planting and harvesting
- Improved PlantManager architecture
  - Legacy PlantSeed/WaterPlot/HarvestPlot handlers now route to unified handler
  - Enhanced plot management with cleaner, more maintainable code
- Fixed variable shadowing warnings in PlantManager.lua
- All static checks continue to pass (stylua, selene), rojo build successful

## Milestone 1 — Playable Core: COMPLETED SYSTEMS

### Habitat and World
- Floating low-poly island environment with baseplate, pond, paths, and decorative elements.
- Individual habitat areas per player (server-authoritative, multiplayer-safe).
- Resource nodes with recognizable appearances: Trees (wood), Rocks (stone), Dew pools (dewdrops), Berry bushes (seeds).
- Garden plots (4 starter, expandable via upgrades) with visual borders and paths.
- ProximityPrompts on all interactive objects for mouse/keyboard/touch/gamepad support.

### Resource Collection
- 6 resource nodes with cooldowns and server-authoritative gathering.
- Distance validation (30 stud max) and ownership validation.
- Resource respawning with configurable cooldowns.
- Inventory tracking with capacity limits (expandable via upgrades).
- Visual feedback: particles, floating text, sounds on gather.

### Inventory System
- Per-player inventory with item quantities.
- Server-controlled additions/removals with validation.
- Capacity system (base 50 + 25 per storage upgrade level).
- UI representation with real-time sync.

### Planting and Growth
- Two plant types: Berry Bush (30s, 2 water) and Flower (45s, 3 water).
- Server-controlled growth stages (planted → growing → ready).
- Watering requirement with dewdrop consumption.
- Harvest validation (growth time + water count).
- Harvest rewards: crops + bells.
- Protection against premature/repeated harvesting.
- Visual feedback: particles, floating text, sounds for plant/water/harvest.

### Creature Discovery
- Two creatures: Meadow Bunny (1 flora, 1 water) and Dew Sprite (3 flora, 5 water).
- Attraction based on flora density and water availability.
- Discovery notification with bell rewards.
- Visual creature models with distinct appearances (bunny with ears/tail, sprite with glow/particles).
- Idle wandering behavior using Humanoid MoveTo.
- Prevention of duplicate discoveries.

### Currency and Upgrades
- Bells as primary progression currency.
- Server-validated transactions (spend/add).
- Two upgrades: Plot Expansion (max 4, cost ×2) and Storage Expansion (max 3, cost ×1.5).
- Plot expansion dynamically adds new garden plots with ProximityPrompts.
- Visual feedback on purchase.

### Quests and Onboarding
- 6 starter quests: Gather Wood (3), Collect Stone (2), Plant Berry (1), Water Plants (2), Harvest (1), Discover Creature (1).
- Server-validated completion with real player action tracking.
- Sequential quest progression with bell rewards.
- UI shows current quest and progress.

### Persistence
- Versioned DataStore (PocketHabitat_v2_PlayerData).
- Retry logic with exponential backoff (3 attempts).
- Session locking via in-memory activeSessions table.
- Graceful handling of failed loads (kicks player to protect data).
- Player departure and game shutdown save handling.
- Default data for new players with starter resources.

### Visual Feedback & Game Feel
- Particle effects for all major actions (gather, plant, water, harvest, upgrade, discover).
- Floating text for rewards and status updates.
- Sound effects for all interactions.
- Notification banner for server messages.
- Cohesive low-poly aesthetic with distinct materials/colors.
- Creature models with animations (idle wandering).

## Milestone 2 — Progression: IN PROGRESS SYSTEMS

### Additional Plants (2026-11-11 ADDITION)
- Added Sun Petal (60s, 1 water, 1-2 harvest, 35 bells)
- Added Moonflower (90s, 4 water, 1-2 harvest, 60 bells)
- Added Glowcap Mushroom (70s, 2 water, 2-4 harvest, 50 bells)
- All plants have unique colors and balances.

### Additional Creatures (2026-11-11 ADDITION)
- Added Leafling (2 flora, 2 water, 75 bells) — woodland creature with ears
- Added Pebble Tortoise (0 flora, 1 water, 65 bells) — slow-moving stone creature
- Added Cloud Finch (2 flora, 2 water, 85 bells) — fluffy bird with crest
- Expanded discovery criteria and rewards.

### Additional Upgrades (2026-11-11 ADDITION)
- Added Decorative Garden Tile (50+ bells) — beautification with multiplier 1.8, max 5
- Added Watering Can Bottle (200+ bells) — dewdrop efficiency, multiplier 1.3, max 3
- Provides more meaningful progression choices.

### Expanded Quests (2026-11-11 ADDITION)
- Added quest to grow Sun Petal (harvest 2, 60 bells)
- Added quest to expand plots to level 3 (120 bells)
- Added quest to attract Leafling (80 bells)
- Added quest to discover five creatures total (150 bells)

## Known gaps
- Milestone 2 — Progression: Additional content (more plants, creatures, resources, quests, upgrades).
- Milestone 3 — Presentation: Lighting/atmosphere polish, UI animations, mobile touch optimization.
- Milestone 4 — QA: Multiplayer testing, DataStore stress testing, performance profiling.
- Milestone 5 — Release: Monetization setup, app store assets, release checklist.
- TestEZ unit tests not yet run in Roblox engine.
- No manual Studio playtest performed in this environment.

## Exact next task
- **Phase 1 Complete**: All critical gameplay systems repaired and consolidated
  - ProximityPrompt handling fixed and optimized
  - PlantManager unified and enhanced with "harvest_or_plant" action
  - All static checks passing, Rojo build successful
- **Next Priority**: Continue Milestone 2 content expansion
  - Implement TestEZ unit tests for core gameplay logic (resource rewards, inventory rules, plant growth, harvest eligibility, currency transactions, quest completion)
  - Continue adding additional content (more plant varieties, creature types, resources, quests, upgrades)
  - Consider adding day/night cycle and lighting improvements as part of presentation polish
- **Immediate Action**: Update and run all static validation checks to confirm completed work

## CI multi-provider pipeline configuration

- Workflow orchestration is maintained on `main` in `.github/workflows/ai-build.yml`.
- OpenCode provider and model definitions are maintained on `ai/game-build` in `opencode.json`.
- Pipeline order: implementation → independent read-only review → conditional repair → deterministic Rojo/StyLua/Selene validation → independent read-only QA → conditional final repair and revalidation.
- Existing Google, Groq, and OpenRouter models remain configured.
- Added optional provider routes: Cloudflare Workers AI GLM-4.7 Flash; Cohere North Mini Code, Command A+, and Command A Reasoning; Groq GPT-OSS 20B; OpenRouter Recursive Flint, Inkling 2 Small, ERNIE 5.5 Flash Preview, Nemotron 3.5 Lightning, and Nemotron 3.5 Super VL.
- GitHub Copilot Free is an optional Copilot CLI Auto adapter for write-capable implementation/repair stages; it is not an OpenCode API model and is excluded from read-only review/QA.
- Optional Actions secrets: `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`, `COHERE_API_KEY`, and `COPILOT_GITHUB_TOKEN`. Existing `GEMINI_API_KEY`, `GROQ_API_KEY`, and `OPENROUTER_API_KEY` remain unchanged.
- Shared quota pools are tracked at provider level where applicable: Cloudflare Workers AI Neurons, Cohere trial API calls, OpenRouter free requests, and Copilot Free AI Credits. Model retries are limited to one RPM/TPM retry.
- Exact account quotas are not queried by the workflow; inspect provider dashboards. A model being configured does not mean it was invoked during a run.
- Free OpenRouter Inkling/NVIDIA endpoints may log prompts and use session data for service/model improvement. Do not send secrets or confidential data to these endpoints.

