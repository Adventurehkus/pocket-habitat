# Pocket Habitat — Development Roadmap

## Milestone 0: Foundation ✅ COMPLETE
- Repository layout and Rojo project configuration (`default.project.json`).
- Rokit version pinning (`rokit.toml`) and dependency setup (`wally.toml`).
- Required documentation suite (`docs/`).
- Initial project structure (`src/server`, `src/shared`, `src/client`, `assets/runtime`).
- Verification of checks and initial project state.
- CI toolchain: Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, Wally 0.3.2, TestEZ 0.4.1.

## Milestone 1: Playable Core ✅ COMPLETE
- Basic habitat island environment setup with baseplate, pond, paths.
- Server-authoritative resource collection nodes (6 nodes: wood, stone, dewdrops, berry seeds).
- ProximityPrompts on all interactables for cross-device support.
- Planting and growth mechanics (2 plant types: berry bush, flower).
- Watering system with dewdrop consumption and growth stages.
- Harvest validation with crop and bell rewards.
- Initial creature discovery (2 creatures: Meadow Bunny, Dew Sprite).
- Creature visual models with idle wandering behavior.
- Basic client-server feedback loops (particles, floating text, sounds, notifications).
- Quest system with 6 sequential starter quests.
- Currency economy (Bells) with server-validated transactions.
- Upgrade system (Plot Expansion, Storage Expansion).
- Safe, versioned DataStore persistence with retry logic and session locking.

## Milestone 2: Progression 🔄 IN PROGRESS
- [x] Safe, versioned DataStore persistence manager.
- [x] Persistent inventory management system.
- [x] Currency economy (Bells transactions).
- [x] Quest tracking and reward system.
- [x] Habitat upgrades and zone unlocking.

### Content Expansion (2026-11-11)
- [x] 3 new plant varieties with unique attributes (Sun Petal, Moonflower, Glowcap)
- [x] 3 new creature types with unique behaviors (Leafling, Tortoise, Cloud Finch)
- [ ~~] Additional resource nodes (rare/special resources) — Pending
- [x] Expanded quest chains with branching objectives (4 new quests)
- [x] More habitat upgrades (2 new upgrades added: Decorative Tile, Watering Can)

## Milestone 3: Presentation 📋 PLANNED
- Low-poly environment polishing and atmospheric lighting (day/night cycle).
- Dynamic creature animations and behavior states (eating, sleeping, social).
- Immersive UI design across all devices (animations, transitions).
- Sound effects (SFX) and ambient music integration.
- Visual polish: weather effects, seasonal changes, particle variety.

## Milestone 4: Quality Assurance (QA) 📋 PLANNED
- Server-authoritative security hardening & validation (penetration testing).
- Persistence error recovery and robust save migration.
- Multiplayer data isolation and synchronization checks (2+ players).
- Cross-device input and performance optimization.
- Automated TestEZ unit test suite for core logic.
- Roblox engine integration tests via Open Cloud.

## Milestone 5: Release Preparation 📋 PLANNED
- Monetization setup (gamepasses and developer products).
- Final polish, balance pass, and release checklist.
- Readiness review (without publishing credentials).
- App store assets (icons, screenshots, trailer).
- Community feedback integration plan.

## Current Focus
**Milestone 2 content expansion** — The core gameplay loop is complete and verified. Next priority is adding breadth: more plants, creatures, resources, quests, and upgrades to create a richer progression experience.
