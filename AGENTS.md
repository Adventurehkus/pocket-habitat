# Pocket Habitat — Agent Instructions

Develop Pocket Habitat: a polished, low-poly Roblox habitat builder about collecting resources, growing plants, discovering creatures, completing quests, and upgrading a personal habitat.

## Rules
- Use Luau and the existing Rojo/Rokit versions in rokit.toml.
- Keep gameplay server-authoritative; validate client requests and protect rewards, inventory, purchases, progression, and player data.
- Use safe, versioned DataStore persistence and isolate multiplayer player data.
- Prefer original, efficient Roblox geometry and assets; make UI work on mouse, keyboard, and touch.
- Preserve existing code. Make small, tested changes. Never claim unrun tests passed.
- Do not publish to Roblox or use publishing credentials.
- Only use tools exposed in the OpenCode session. Use bash for shell commands. Do not invent git/task/run tools.
- Do not create or switch branches, commit, or push. GitHub Actions saves changes to ai/game-build automatically.

## Milestones
0 Foundation: layout, docs, pinned tools, checks.
1 Playable core: habitat, resources, planting/growth, creature discovery, feedback.
2 Progression: inventory, currency, quests, upgrades, unlocks, saves.
3 Presentation: environment, creatures, UI, lighting, feedback.
4 QA: security, persistence, multiplayer, devices, performance.
5 Release preparation: monetization setup, presentation, release checklist.

## Required docs
Maintain docs/GAME_DESIGN.md, ROADMAP.md, PROJECT_STATE.md, TECHNICAL_ARCHITECTURE.md, ASSET_PIPELINE.md, TESTING.md, MONETIZATION.md. Keep PROJECT_STATE.md accurate about current milestone, implemented systems, actual tests, issues, and exact next task.
