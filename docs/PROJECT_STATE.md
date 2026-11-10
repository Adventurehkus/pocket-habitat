# Pocket Habitat — Project State

## Current status
- **Current milestone:** Milestone 0 — Foundation (completed).
- **Status:** Documentation suite and CI toolchain foundation are in place. Rokit-managed tools installed, Wally dependencies installed, and Rojo build verified. StyLua and Selene checks passed against the current placeholder-only game source tree; repeat them after gameplay scripts are added.
- **Last AI run:** Workflow run 42906659145.
- **Latest checkpoint:** `5bac5eb` — toolchain setup, dependency installation, build validation, and state update were persisted to `ai/game-build`.
- **Workflow conclusion:** The agent step ended with Gemini's free-tier 15-requests-per-minute quota error during its final response. The separate persistence step succeeded, so the checkpoint was not lost.

## Implemented and documented
- Pocket Habitat game concept and core loops are documented in `GAME_DESIGN.md`.
- Development milestones are recorded in `ROADMAP.md`.
- Proposed server-authoritative architecture is described in `TECHNICAL_ARCHITECTURE.md`.
- Asset pipeline, testing strategy, and monetization proposal are documented in their respective files.
- Project configuration files are present: `default.project.json`, `rokit.toml`, `wally.toml`, `selene.toml`, `.stylua.toml`, and `opencode.json`.
- `.gitignore` and concise project-specific `AGENTS.md` are present.

## Actual checks from the latest foundation run
- Rokit installation using the official Linux installer: PASSED (Rokit 1.2.0).
- Initial `rokit install` was blocked by Rokit's trust guard for StyLua. `rokit install --no-trust-check` then installed the pinned CI tools successfully.
- Tool version checks: Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, and Wally 0.3.2: PASSED.
- `wally install`: PASSED; TestEZ 0.4.1 was installed under `DevPackages`.
- `rojo build default.project.json`: PASSED (0 errors, 0 warnings) after the expected project folders were restored/configured.
- `stylua --check .`: PASSED (0 errors, 0 warnings); there were no gameplay Luau scripts to format yet.
- `selene .`: PASSED (0 errors, 0 warnings); there were no gameplay Luau scripts to lint yet.
- TestEZ was installed but no test suite was run. Roblox engine and manual Studio tests have not been run.
- Agent final response exceeded Gemini's free-tier 15-requests-per-minute quota. GitHub Actions still committed the work as checkpoint `5bac5eb`.

## Known gaps
- Milestone 1 — Playable core: habitat, resources, planting/growth, creature discovery, and player feedback.
- Implement server-authoritative logic, asset loading, and client interactions in subsequent milestones.
- Repeat formatting and lint checks once source scripts exist; add actual TestEZ tests and Roblox engine/manual playtests.

## Exact next task
- Begin Milestone 1: implement the playable core in small, verifiable increments, preserving server authority, multiplayer isolation, and PC/mobile support.
