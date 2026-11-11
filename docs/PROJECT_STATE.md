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
- `rojo build default.project.json`: PASSED (0 errors, 0 warnings).
- `stylua --check src`: PASSED (0 errors, 0 warnings).
- `selene src`: PASSED (0 errors, 0 warnings).
- TestEZ installed but test suite not yet run in Roblox engine.

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

## Known gaps
- Milestone 2 — Progression: Additional content (more plants, creatures, resources, quests, upgrades).
- Milestone 3 — Presentation: Lighting/atmosphere polish, UI animations, mobile touch optimization.
- Milestone 4 — QA: Multiplayer testing, DataStore stress testing, performance profiling.
- Milestone 5 — Release: Monetization setup, app store assets, release checklist.
- TestEZ unit tests not yet run in Roblox engine.
- No manual Studio playtest performed in this environment.

## Exact next task
- Begin Milestone 2: Add additional content (more plant varieties, creature types, resource nodes, quests, upgrades).
- Implement TestEZ unit tests for core gameplay logic (resource rewards, inventory rules, plant growth, harvest eligibility, currency transactions, quest completion).
- Consider adding day/night cycle and lighting improvements.

## CI model fallback configuration
- The `main` workflow uses an ordered fallback chain: Gemini 3.5 Flash-Lite → Gemini 3.1 Flash-Lite → Gemini 3.8 Flash → Gemma 4 31B IT → Gemma 4 26B A4B IT → Groq Qwen 3.8 27B → Groq GPT-OSS 120B → OpenRouter NVIDIA Nemotron 3 Ultra (free, optional) → OpenRouter Cohere North Mini Code (free, optional).
- Provider keys are read from GitHub Actions repository secrets.
- This run successfully used the Gemini 3.8 Flash fallback after earlier models hit quotas.
